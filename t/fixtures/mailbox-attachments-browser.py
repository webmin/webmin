"""Run on a disposable Linux VM with Chromium; no installed Webmin is changed.

Usage: python3 t/fixtures/mailbox-attachments-browser.py [baseline-detach.cgi]
The optional baseline must reproduce the XML, override and UTF-16 HTML attacks.
"""
import base64
import http.server
import json
import pathlib
import re
import shutil
import subprocess
import sys
import tempfile
import threading
import urllib.request

root = pathlib.Path(__file__).resolve().parents[2]
baseline = pathlib.Path(sys.argv[1]).resolve() if len(sys.argv) > 1 else None
responses = {}
svg = b'''<svg xmlns="http://www.w3.org/2000/svg" onload="document.documentElement.setAttribute('data-xss','yes')"><text x="2" y="12">XML fixture</text></svg>'''
html = b'''<h1>Preview</h1><b>Formatting</b><script>document.documentElement.setAttribute('data-xss','yes')</script>'''
png = base64.b64decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aHicAAAAASUVORK5CYII=')


def render(mime, data, filename, request, old=False):
    """Capture the actual CGI headers and MIME-decoded body."""
    case = dict(type=mime, data=base64.b64encode(data).decode(),
                filename=filename, request=request)
    command = ['perl', str(root / 't/fixtures/mailbox-attachment-response.pl')]
    if old:
        command.append(str(baseline))
    result = subprocess.run(command, input=json.dumps(case).encode(),
                            capture_output=True, check=True, timeout=15)
    headers, body = result.stdout.split(b'\n\n', 1)
    return dict(line.decode().split(': ', 1) for line in headers.splitlines()), body


class Handler(http.server.BaseHTTPRequestHandler):
    """Serve fixture responses only on this VM's loopback interface."""
    def do_GET(self):
        if self.path not in responses:
            self.send_error(404)
            return
        headers, body = responses[self.path]
        self.send_response(200)
        for key, value in headers.items():
            self.send_header(key, value)
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, *_):
        pass


server = http.server.ThreadingHTTPServer(('127.0.0.1', 0), Handler)
thread = threading.Thread(target=server.serve_forever, daemon=True)
thread.start()
url = f'http://127.0.0.1:{server.server_port}'
profile = pathlib.Path(tempfile.mkdtemp(prefix='mailbox-browser-'))
checks = 0


def check(condition, description):
    """Fail immediately and count successful assertions."""
    global checks
    assert condition, description
    checks += 1
    print('PASS:', description, flush=True)


def dom(path):
    """Use an isolated browser profile without the user's desktop state."""
    result = subprocess.run([
        'chromium', '--headless', '--no-sandbox', '--disable-gpu',
        '--disable-background-networking', '--disable-component-update',
        '--no-first-run', '--disable-dev-shm-usage', '--no-proxy-server',
        f'--user-data-dir={profile}', '--virtual-time-budget=1500',
        '--dump-dom', url + path,
    ], capture_output=True, text=True, timeout=30)
    assert result.returncode == 0, result.stderr[-2000:]
    return result.stdout


try:
    print(subprocess.check_output(['chromium', '--version'], text=True).strip())
    # Confirm before/after script behavior, including encoding-based filter bypass.
    cases = [
        ('xml', 'application/xml', svg, 'fixture.xml', {}),
        ('text-xml', 'text/xml', svg, 'fixture.xml', {}),
        ('override', 'text/plain', html, 'fixture.txt', {'type': 'text/html'}),
        ('html-utf16', 'text/html', html.decode().encode('utf-16'), 'fixture.html', {}),
    ]
    for name, mime, data, filename, request in cases:
        for old in ([True, False] if baseline else [False]):
            path = f'/{name}-{old}'
            responses[path] = render(mime, data, filename, request, old)
            document = dom(path)
            executed = bool(re.search(r'<(?:html|svg)\b[^>]*data-xss="yes"', document))
            check(executed == old, f'{name}: ' + ('baseline executes' if old else 'patched is inert'))
            if name == 'html-utf16':
                check('<h1>Preview</h1>' in document, 'UTF-16 HTML still renders')

    # Preserve formatted HTML, while denying access from its Webmin-origin parent.
    responses['/preview'] = render('text/html', html, 'preview.html', {})
    document = dom('/preview')
    check('<h1>Preview</h1><b>Formatting</b>' in document, 'HTML formatting preserved')
    check('data-xss="yes"' not in document, 'HTML script does not execute')
    responses['/isolation'] = ({'Content-Type': 'text/html'}, b'''<iframe src="/preview"></iframe>
<script>setTimeout(() => { document.body.dataset.isolated = String(document.querySelector('iframe').contentDocument === null); }, 500);</script>''')
    check('data-isolated="true"' in dom('/isolation'), 'HTML preview has an isolated origin')

    # Use a real image decoder, not just MIME/header assertions.
    responses['/image'] = render('image/png', png, 'image.png', {})
    responses['/image-check'] = ({'Content-Type': 'text/html'}, b'''<img src="/image" onload="document.body.dataset.width = this.naturalWidth">''')
    check('data-width="1"' in dom('/image-check'), 'PNG preview decodes correctly')
    check(responses['/image'][1] == png, 'PNG bytes preserved')

    # Fetch downloads over HTTP and compare their complete binary bodies.
    for index, (mime, data, filename, request) in enumerate([
        ('text/html', html, 'page.html', {'save': 1}),
        ('image/svg+xml', svg, 'drawing.svg', {'save': 1}),
        ('image/png', png, 'image.png', {'save': 1}),
        ('application/pdf', b'%PDF-1.4\nfixture\0\xff', 'document.pdf', {}),
        ('application/zip', b'PK\x03\x04\0\xff\r\nfixture', 'archive.zip', {}),
        ('text/plain', html, 'text.txt', {'type': 'text/html', 'save': 1}),
    ]):
        path = f'/download-{index}'
        responses[path] = render(mime, data, filename, request)
        with urllib.request.urlopen(url + path, timeout=10) as response:
            check(response.read() == data, f'{filename}: download bytes preserved')
            check(response.headers['Content-Disposition'] == f'Attachment; filename="{filename}"',
                  f'{filename}: download disposition and filename preserved')
    print(f'{checks} browser/HTTP checks passed', flush=True)
finally:
    server.shutdown()
    server.server_close()
    thread.join()
    shutil.rmtree(profile)
