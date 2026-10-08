"""One-session local key entry page; forwards only to FanDazi's encrypted settings API."""
import json
import os
from pathlib import Path
import secrets
import threading
import urllib.parse
import urllib.request
from http.server import HTTPServer, BaseHTTPRequestHandler

STATE = Path(os.environ['LOCALAPPDATA']) / 'FanDaziAI'

class Setup(BaseHTTPRequestHandler):
    def log_message(self, *_): pass

    def page(self, status, content):
        raw = ('<!doctype html><html lang="zh-CN"><meta charset="utf-8">'
               '<title>饭搭子 · 本机密钥配置</title>'
               '<style>body{font-family:system-ui;background:#faf8ee;color:#2b4035;max-width:520px;'
               'margin:70px auto;padding:24px}input,button{box-sizing:border-box;width:100%;padding:14px;'
               'margin:12px 0;border:1px solid #cbdac8;border-radius:12px}button{background:#3f7864;color:white}</style>'
               + content + '</html>').encode()
        self.send_response(status)
        self.send_header('Content-Type', 'text/html; charset=utf-8')
        self.send_header('Content-Length', str(len(raw)))
        self.send_header('Cache-Control', 'no-store')
        self.send_header('Referrer-Policy', 'same-origin')
        self.send_header('X-Frame-Options', 'DENY')
        self.send_header('Content-Security-Policy', "default-src 'none'; style-src 'unsafe-inline'; form-action 'self'; frame-ancestors 'none'; base-uri 'none'")
        self.end_headers()
        self.wfile.write(raw)

    def valid(self):
        return (self.headers.get('Host') == f'127.0.0.1:{self.server.server_port}'
                and secrets.compare_digest(self.path, self.server.entry_path))

    def do_GET(self):
        if not self.valid(): return self.page(403, '<p>配置链接无效。</p>')
        if self.server.completed: return self.page(200, '<h1>密钥已加密保存</h1><p>模型：gpt-image-2。可以返回饭搭子。</p>')
        self.page(200, '<h1>饭搭子 · 本机密钥配置</h1><p>仅在本机加密保存；不会发送到聊天。图片模型：gpt-image-2。</p>'
                  '<form method="post"><label for="key">OpenAI API 密钥</label>'
                  '<input id="key" name="key" type="password" autocomplete="off" required maxlength="512">'
                  '<button type="submit">加密保存到饭搭子</button></form>')

    def do_POST(self):
        if not self.valid() or self.headers.get('Origin') != f'http://127.0.0.1:{self.server.server_port}':
            return self.page(403, '<p>仅接受本机配置页面。</p>')
        if self.server.completed: return self.page(409, '<p>本次配置已完成。</p>')
        try:
            length = int(self.headers.get('Content-Length', '0'))
            if not 0 < length <= 2048: raise ValueError()
            key = urllib.parse.parse_qs(self.rfile.read(length).decode()).get('key', [''])[0].strip()
            if not key.startswith('sk-') or len(key) > 512: raise ValueError()
            bridge = json.loads((STATE / 'bridge.json').read_text())
            request = urllib.request.Request(f'http://127.0.0.1:{int(bridge["port"])}/config',
                json.dumps({'api_key': key, 'image_model': 'gpt-image-2'}).encode(),
                {'Authorization': 'Bearer ' + bridge['token'], 'Content-Type': 'application/json'})
            with urllib.request.urlopen(request, timeout=10) as response:
                if not json.load(response).get('configured'): raise ValueError()
            self.server.completed = True
            self.page(200, '<h1>密钥已加密保存</h1><p>模型：gpt-image-2。密钥不在此页回显，可以返回饭搭子。</p><p>账户额度与模型权限尚需实际调用验证。</p>')
        except Exception:
            self.page(400, '<h1>尚未保存</h1><p>请重新打开本机配置链接，检查密钥或本机服务。</p>')

if __name__ == '__main__':
    http = HTTPServer(('127.0.0.1', 0), Setup)
    http.entry_path = '/setup/' + secrets.token_urlsafe(32)
    http.completed = False
    print(f'http://127.0.0.1:{http.server_port}{http.entry_path}', flush=True)
    threading.Timer(900, http.shutdown).start()
    http.serve_forever()
    http.server_close()
