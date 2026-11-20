"""Test the log viewer CGI against a private systemd journal.

Run on Linux with systemd-journal-remote installed:
python3 t/fixtures/logviewer-journal-search.py WEBMIN_ROOT [VIEW_LOG_CGI]
"""

import os
import re
import shutil
import subprocess
import sys
import tempfile
import time
from pathlib import Path
from urllib.parse import urlencode


def check_journal(directory, root, viewer):
    """Create dated journal entries and query them through Webmin's CGI."""
    source = directory / "fixture.journal"
    now = int(time.time())
    outside, old, middle, newest = [word + " needle.[x]" for word in
                                    ("outside", "old", "middle", "new")]
    messages = [outside, old, "before", middle, "after", "needleXx", newest]
    messages += [f"unrelated {i}" for i in range(120)]
    records = []
    for i, message in enumerate(messages):
        timestamp = now - 9 * 3600 if i == 0 else now - 3600 + i
        records.append(f"__REALTIME_TIMESTAMP={timestamp * 1000000}\n"
                       f"__MONOTONIC_TIMESTAMP={i * 1000000}\n"
                       "_BOOT_ID=85aefe73b267421a87073350f386a011\n"
                       f"_SYSTEMD_UNIT={'sample' if message == middle else 'other'}.service\n"
                       "SYSLOG_IDENTIFIER=journal-fixture\n"
                       f"MESSAGE={message}\n\n")
    importer = os.environ.get("JOURNAL_REMOTE", "/usr/lib/systemd/systemd-journal-remote")
    subprocess.run([importer, f"--output={source}", "-"],
                   input="".join(records), text=True, check=True, timeout=30)

    # Use real journalctl and an isolated Webmin configuration for every request.
    journalctl = shutil.which("journalctl")
    wrapper = directory / "journalctl"
    wrapper.write_text(f'#!/bin/sh\nexec "{journalctl}" --file="$TEST_JOURNAL" "$@"\n')
    wrapper.chmod(0o700)
    config = directory / "etc"
    module = config / "logviewer"
    module.mkdir(parents=True)
    (directory / "var").mkdir()
    (config / "config").write_text("os_type=debian-linux\nos_version=13\nlang=en\n")
    (config / "miniserv.conf").write_text(f"root={root}\nport=10000\n")
    (config / "webmin.acl").write_text("root: logviewer\n")
    (module / "units.cache").write_text("sample.service=Sample\n")
    env = dict(os.environ, WEBMIN_CONFIG=str(config), WEBMIN_VAR=str(directory / "var"),
               SERVER_ROOT=str(root), SCRIPT_NAME="/logviewer/view_log.cgi",
               REQUEST_METHOD="GET", REMOTE_USER="root", TEST_JOURNAL=str(source),
               PATH=str(directory) + os.pathsep + os.environ["PATH"])

    def search(reverse=1, **fields):
        """Submit the filter form and return the displayed log messages in order."""
        (module / "config").write_text(f"reverse={reverse}\nlines=100\ninclude_context=1\n")
        form = dict(idx="journal-1", filter="needle.[x]", since="--since '8 hours ago'")
        form.update(fields)
        page = subprocess.check_output(["perl", str(viewer)], cwd=root / "logviewer",
                                       env=dict(env, QUERY_STRING=urlencode(form)),
                                       text=True, timeout=30)
        result = re.search(r"<pre>(.*?)</pre>", page, re.S)
        if result is None:
            raise AssertionError("Log viewer did not return a results block")
        return [line.split("journal-fixture: ", 1)[1] for line in result[1].splitlines()
                if "journal-fixture: " in line]

    # All matching lines are older than the newest 100 entries.
    matches = [newest, middle, old]
    assert search(lines=2, filter="") == messages[-2:][::-1]
    assert search() == matches
    assert search(since="") == matches + [outside]
    assert search(lines=2) == matches[:2]
    assert search(lines=2, reverse=0) == matches[:2][::-1]
    assert search(lines=2, since="", reverse=0) == [middle, newest]
    assert search(lines=1, filter=r"middle needle\.\[x\]$", regex=1) == [middle]
    assert search(lines=1, filter="middle", surrounding=1) == ["after", middle, "before"]
    assert search(lines=1, filter="middle", surrounding=1, reverse=0) == ["before", middle, "after"]
    assert search(lines=2, filter="journal-fixture:") == messages[-2:][::-1]
    assert search(idx="journal-a-sample.service") == [middle]
    assert search(filter="absent") == []


if __name__ == "__main__":
    root = Path(sys.argv[1]).resolve()
    viewer = Path(sys.argv[2]).resolve() if len(sys.argv) > 2 else root / "logviewer/view_log.cgi"
    with tempfile.TemporaryDirectory() as temporary:
        check_journal(Path(temporary), root, viewer)
    print("Journal search checks passed")
