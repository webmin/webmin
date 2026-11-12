"""Test zero DNS TTLs through HTTP on a disposable Linux guest.

Usage: python3 t/fixtures/bind-zero-ttl-live.py /tmp/task-directory
Starts a private MiniServ with fixture accounts and zone files. Installed
Webmin and BIND configurations are not used. Never run on the workstation.
"""
from html.parser import HTMLParser
from pathlib import Path
import base64
import http.client
import os
import re
import secrets
import signal
import socket
import subprocess
import sys
import tempfile
import time
import urllib.parse

if sys.platform != 'linux':
    raise RuntimeError('Run only inside a disposable Linux test guest')
task = Path(sys.argv[1]).resolve()
if not task.is_dir() or not any(p in task.parents for p in (Path('/tmp'), Path('/var/tmp'))):
    raise RuntimeError('Supply an existing task directory under /tmp or /var/tmp')
source = Path(__file__).resolve().parents[2]
os.umask(0o077)
checks = 0


def check(condition, message):
    """check(condition, message): report success or stop on a failed assertion."""
    global checks
    if not condition:
        raise AssertionError(message)
    checks += 1
    print('PASS: ' + message, flush=True)


def write_config(path, values):
    """write_config(path, values): write configuration inside the fixture."""
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(''.join(f'{key}={value}\n' for key, value in values.items()))


def request(path, form=None):
    """request(path, [form]): send an authenticated GET or form POST."""
    conn = http.client.HTTPConnection('127.0.0.1', port, timeout=15)
    headers = {'Authorization': authorization,
               'Referer': f'http://127.0.0.1:{port}/bind8/'}
    body = None
    if form is not None:
        # Form values use the same encoding as the bulk-update form.
        body = urllib.parse.urlencode(form)
        headers['Content-Type'] = 'application/x-www-form-urlencoded'
    try:
        conn.request('POST' if form is not None else 'GET', path, body, headers)
        response = conn.getresponse()
        return response.status, response.read().decode(errors='replace')
    finally:
        conn.close()


class RecordRows(HTMLParser):
    """Read rendered table cells without depending on presentation markup."""

    def __init__(self):
        """RecordRows(): initialize the row and cell buffers."""
        super().__init__()
        self.rows = []
        self.row = []
        self.cell = None

    def handle_starttag(self, tag, attrs):
        """handle_starttag(tag, attrs): start a row or a data cell."""
        if tag == 'tr':
            self.row = []
        elif tag == 'td':
            self.cell = []

    def handle_data(self, data):
        """handle_data(data): collect text from the current data cell."""
        if self.cell is not None:
            self.cell.append(data)

    def handle_endtag(self, tag):
        """handle_endtag(tag): retain completed cells and rows."""
        if tag == 'td' and self.cell is not None:
            self.row.append(''.join(self.cell).strip())
            self.cell = None
        elif tag == 'tr':
            self.rows.append(self.row)


class RecordForm(HTMLParser):
    """Collect edit links and the selected inputs in an A-record form."""

    def __init__(self):
        """RecordForm(): initialize links, submitted fields and form state."""
        super().__init__()
        self.links = []
        self.fields = {}
        self.active = False
        self.select = None

    def handle_starttag(self, tag, attrs):
        """handle_starttag(tag, attrs): read links and successful controls."""
        attrs = dict(attrs)
        if tag == 'a' and 'edit_record.cgi?' in attrs.get('href', ''):
            self.links.append(attrs['href'])
        elif tag == 'form':
            self.active = attrs.get('action', '').endswith('save_record.cgi')
        elif self.active and tag == 'input' and 'disabled' not in attrs:
            kind = attrs.get('type', 'text')
            if kind in ('submit', 'button', 'reset') or not attrs.get('name'):
                return
            if kind in ('radio', 'checkbox') and 'checked' not in attrs:
                return
            self.fields[attrs['name']] = attrs.get('value', '')
        elif self.active and tag == 'select':
            self.select = attrs.get('name')
        elif self.select and tag == 'option':
            if self.select not in self.fields or 'selected' in attrs:
                self.fields[self.select] = attrs.get('value', '')

    def handle_endtag(self, tag):
        """handle_endtag(tag): stop collecting a completed form or select."""
        if tag == 'form':
            self.active = False
        elif tag == 'select':
            self.select = None


def edit_form(zone, record):
    """edit_form(zone, record): follow the real record link and read its form."""
    query = urllib.parse.urlencode(dict(zone=zone, type='ALL'))
    status, body = request('/bind8/edit_recs.cgi?' + query)
    listing = RecordForm()
    listing.feed(body)
    links = [link for link in listing.links if urllib.parse.parse_qs(
        urllib.parse.urlsplit(link).query).get('id', [''])[0].startswith(record + '.' + zone + './A/')]
    check(status == 200 and len(links) == 1, zone + ': edit link for ' + record)
    path = urllib.parse.urljoin('/bind8/', links[0])
    status, body = request(path)
    form = RecordForm()
    form.feed(body)
    check(status == 200 and form.fields.get('type') == 'A', zone + ': edit form loads')
    return form.fields


def check_edit_save(zone, record, ttl, value, unit=''):
    """check_edit_save(zone, record, ttl, value, [unit]): round-trip form TTLs."""
    fields = edit_form(zone, record)
    expected = ('1' if ttl is None else '0', value, unit)
    actual = tuple(fields.get(key) for key in ('ttl_def', 'ttl', 'ttlunit'))
    check(actual == expected, zone + ': ' + record + ' editor preserves TTL controls')
    # Submit the values actually rendered by Webmin, without correcting the TTL.
    status, body = request('/bind8/save_record.cgi', fields)
    check(status == 302, zone + ': unchanged record saves successfully')
    names = (record, record + '.' + zone + '.')
    records = [line.split() for line in zones[zone].read_text().splitlines()
               if line.split() and line.split()[0] in names]
    check(len(records) == 1, zone + ': saved record remains present once')
    stored = None if records[0][1] == 'IN' else records[0][1]
    check(stored == ttl, zone + ': saved record keeps its TTL')
    reopened = edit_form(zone, record)
    actual = tuple(reopened.get(key) for key in ('ttl_def', 'ttl', 'ttlunit'))
    check(actual == expected, zone + ': reopened editor keeps its TTL controls')


def check_records(name, inherited, query=''):
    """check_records(name, inherited, [query]): verify the live TTL column."""
    path = '/bind8/edit_recs.cgi?' + urllib.parse.urlencode(dict(zone=name, type='ALL'))
    status, body = request(path + query)
    check(status == 200 and 'ARRAY reference' not in body, name + ': records request succeeds')
    table = RecordRows()
    table.feed(body)
    expected = {'inherited': inherited, 'explicit': '0', 'nonzero': '120',
                'NSEC3PARAM': '0', 'RRSIG': '0'}
    for label, ttl in expected.items():
        matches = [row for row in table.rows if any(
            cell == label or cell.startswith(label + '.') for cell in row)]
        # Resource type precedes TTL, regardless of the selection column.
        matches = [row for row in matches if any(
            kind in row for kind in ('A', 'NSEC3PARAM', 'RRSIG'))]
        check(len(matches) == 1, name + ': finds ' + label)
        row = matches[0]
        index = next(i for i, value in enumerate(row) if value in ('A', 'NSEC3PARAM', 'RRSIG'))
        check(row[index + 1] == ttl, name + ': ' + label + ' TTL is ' + ttl)


# Credentials exist only in guest memory and private fixture files.
password = secrets.token_urlsafe(32)
hashed = subprocess.check_output(
    ['perl', '-e', 'local $/; print crypt(<STDIN>, q($6$ttlfixture$));'],
    input=password.encode(), timeout=10).decode()
authorization = 'Basic ' + base64.b64encode(f'admin:{password}'.encode()).decode()
with tempfile.TemporaryDirectory(prefix='live-', dir=task) as directory:
    work = Path(directory)
    conf, var = work/'config', work/'var'
    conf.mkdir()
    (var/'locks').mkdir(parents=True)
    zones = {}
    for name, ttl in [('zero.invalid', 0), ('positive.invalid', 3600), ('absent.invalid', None)]:
        # Explicit zero DNSSEC TTLs must not inherit the zone's default.
        zone = work/(name + '.zone')
        zone.write_text(('' if ttl is None else f'$TTL {ttl}\n') +
            f'@ 3600 IN SOA ns.{name}. hostmaster.{name}. (1 3600 600 86400 300)\n'
            f'@ 3600 IN NS ns.{name}.\n'
            'ns 3600 IN A 192.0.2.10\n'
            'inherited IN A 192.0.2.11\n'
            'explicit 0 IN A 192.0.2.12\n'
            'nonzero 120 IN A 192.0.2.13\n'
            'units 1H IN A 192.0.2.14\n'
            'zerounits 0S IN A 192.0.2.15\n'
            '@ 0 IN NSEC3PARAM 1 0 0 -\n'
            f'@ 0 IN RRSIG NSEC3PARAM 13 2 0 20270101000000 20260101000000 12345 {name}. Zml4dHVyZQ==\n')
        zones[name] = zone
    named = work/'named.conf'
    named.write_text(''.join(f'zone "{name}" {{ type master; file "{path}"; }};\n'
                             for name, path in zones.items()))
    write_config(conf/'config', dict(os_type='generic-linux', os_version=0,
                 lang='en', log=0, tempdir=var/'tmp', noselfwebminup=1))
    (conf/'var-path').write_text(str(var)+'\n')
    write_config(conf/'bind8/config', dict(named_conf=named, short_names=0,
                 ipv6_mode=1, spf_record=0, soa_style=0, soa_start=0,
                 updserial_on=1, largezones=0, rev_def=1))
    (conf/'bind8/version').write_text('9.18.0\n')
    write_config(conf/'bind8/admin.acl', dict(zones='*', inviews='*', types='',
                 ro=0, params=1, multiple=1))
    (conf/'miniserv.users').write_text(f'admin:{hashed}:0\n')
    (conf/'webmin.acl').write_text('admin: bind8\n')
    (conf/'webmin.groups').write_text('')
    with socket.socket() as sock:
        sock.bind(('127.0.0.1', 0))
        port = sock.getsockname()[1]
    write_config(conf/'miniserv.conf', dict(port=port, bind='127.0.0.1',
        root=source, ssl=0, pidfile=var/'pid', logfile=var/'requests',
        errorlog=var/'errors', userfile=conf/'miniserv.users',
        env_WEBMIN_CONFIG=conf, env_WEBMIN_VAR=var, session=0,
        passdelay=0, no_pam=1, syslog=0, log=0, forkcgis=0,
        addtype_cgi='internal/cgi', allow='127.0.0.1', precache='none'))
    server = subprocess.Popen(
        ['perl', str(source/'miniserv.pl'), '--nofork', str(conf/'miniserv.conf')],
        stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL, start_new_session=True)
    try:
        # Wait for HTTP, but stop promptly if the fixture server exits.
        for attempt in range(100):
            if server.poll() is not None:
                raise RuntimeError('Fixture MiniServ stopped during startup')
            try:
                request('/bind8/edit_recs.cgi?zone=zero.invalid&type=ALL')
                break
            except OSError:
                time.sleep(.1)
        else:
            raise RuntimeError('Fixture MiniServ did not start')
        # Editing must preserve explicit zero, inheritance and TTL units.
        for name in zones:
            check_edit_save(name, 'explicit', '0', '0')
            check_edit_save(name, 'inherited', None, '')
        check_edit_save('positive.invalid', 'nonzero', '120', '120')
        check_edit_save('positive.invalid', 'units', '1H', '1', 'H')
        check_edit_save('positive.invalid', 'zerounits', '0', '0')

        check_records('zero.invalid', '0')
        check_records('positive.invalid', '3600')
        check_records('absent.invalid', 'Default')
        check_records('zero.invalid', '0', '&search=invalid')

        # Exercise real bulk writes, including both directions through zero.
        for old, new in [(0, 600), (600, 0)]:
            status, body = request('/bind8/mass_update.cgi',
                dict(d='zero.invalid', type='ttl', old_def=0, old=old, new=new))
            content = zones['zero.invalid'].read_text()
            check(status == 200 and re.search(r'^\$TTL\s+' + str(new) + r'\s*$',
                  content, re.M | re.I), f'bulk change {old} to {new} reaches the zone file')
            check_records('zero.invalid', str(new))
            check(re.search(r'^explicit(?:\.zero\.invalid\.)?\s+0\s+IN\s+A', content, re.M),
                  'bulk changes preserve explicit record TTLs')

        # Invalid values must leave the zone file unchanged.
        for invalid in ['', '-1', 'abc']:
            before = zones['zero.invalid'].read_bytes()
            request('/bind8/mass_update.cgi',
                dict(d='zero.invalid', type='ttl', old_def=1, new=invalid))
            check(zones['zero.invalid'].read_bytes() == before,
                  'invalid bulk TTL is rejected: ' + repr(invalid))
    finally:
        # Terminate only this fixture's process group, including CGI children.
        try:
            os.killpg(server.pid, signal.SIGTERM)
            server.wait(timeout=10)
        except subprocess.TimeoutExpired:
            os.killpg(server.pid, signal.SIGKILL)
            server.wait(timeout=5)
        except ProcessLookupError:
            server.wait(timeout=5)
print(f'All {checks} live HTTP checks passed; fixture files and processes removed.')
