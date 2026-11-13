"""Build RPM payload fixtures only inside an explicitly enabled Linux VM."""

import gzip
import json
import os
from pathlib import Path
import shutil
import stat
import struct
import subprocess
import sys


def cpio_entry(name, data, mode, inode):
    """Encode one newc entry, with deliberately different package ownership."""
    name = name.encode() + b"\0"
    fields = (inode, mode, 12345, 12345, 1, 1, len(data),
              0, 0, 0, 0, len(name), 0)
    header = b"070701" + b"".join(f"{value:08x}".encode() for value in fields)
    result = header + name
    result += b"\0" * (-len(result) % 4)
    result += data + b"\0" * (-len(data) % 4)
    return result


def build_real_rpm(archive, source=False):
    """Build a binary or source RPM with rpmbuild inside the fixture tree."""
    top = archive.parent / 'rpmbuild'
    for directory in ('BUILD', 'RPMS', 'SOURCES', 'SPECS', 'SRPMS'):
        (top / directory).mkdir(parents=True, exist_ok=True)
    spec = top / 'SPECS/fixture.spec'
    spec.write_text('''Name: filemin-rpm-test
Version: 1
Release: 1
Summary: Filemin extraction fixture
License: MIT
BuildArch: noarch

%description
Filemin extraction fixture.

%install
mkdir -p %{buildroot}/opt/filemin-rpm-test
echo payload > %{buildroot}/opt/filemin-rpm-test/file.txt
chmod 6755 %{buildroot}/opt/filemin-rpm-test/file.txt

%files
%attr(6755,root,root) /opt/filemin-rpm-test/file.txt
''')
    result = subprocess.run(['rpmbuild', '--define', f'_topdir {top}',
                             '-bs' if source else '-bb', str(spec)],
                            capture_output=True, text=True)
    if result.returncode:
        raise RuntimeError(result.stdout + result.stderr)
    output = top / ('SRPMS' if source else 'RPMS')
    shutil.copyfile(next(output.rglob('*.rpm')), archive)


def main():
    """Read a fixture description and create its RPM beneath the VM task tree."""
    if (os.environ.get('FILEMIN_RPM_VM_TEST') != '1'
            or sys.platform != 'linux' or os.geteuid() != 0):
        raise SystemExit('Disposable root Linux VM required')
    spec = json.loads(Path(sys.argv[1]).read_text())
    archive = Path(spec['archive'])
    kind = spec['kind']
    if kind in ('real', 'source'):
        build_real_rpm(archive, source=(kind == 'source'))
        return
    if kind in ('corrupt', 'fresh-corrupt'):
        archive.write_bytes(b'not an RPM')
        return

    # Use an RPM envelope with a gzip-compressed newc payload. Digests are
    # intentionally absent: extraction must validate paths regardless of trust.
    entries = []
    if kind in ('symlink', 'existing-link'):
        if kind == 'symlink':
            entries.append(('escape', spec['outside'].encode(), stat.S_IFLNK | 0o777))
        entries.append(('escape/marker', b'changed', stat.S_IFREG | 0o644))
    else:
        entries.append((spec['entry'], b'payload', stat.S_IFREG | 0o6755))
        if kind == 'partial':
            entries.append(('../escape', b'changed', stat.S_IFREG | 0o644))
        if kind == 'normal':
            entries.extend([
                ('relative-link', b'file.txt', stat.S_IFLNK | 0o777),
                ('absolute-link', (spec['outside'] + '/marker').encode(),
                 stat.S_IFLNK | 0o777),
            ])
    payload = b''.join(cpio_entry(name, data, mode, number)
                       for number, (name, data, mode) in enumerate(entries, 1))
    payload += cpio_entry('TRAILER!!!', b'', 0, len(entries) + 1)
    lead = struct.pack('>4sBBHH66sHH16s', b'\xed\xab\xee\xdb', 3, 0,
                       0, 1, b'filemin-rpm-fixture', 1, 5, b'')
    header = b'\x8e\xad\xe8\x01' + struct.pack('>III', 0, 0, 0)
    archive.write_bytes(lead + header + header + gzip.compress(payload))


if __name__ == '__main__':
    main()
