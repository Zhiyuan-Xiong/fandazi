"""Explicit test fixture server; never started by the app launcher."""
import base64
import json
from pathlib import Path
import sys
import threading
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'ai_service'))
import server
from test_service import meal_fixture

root = Path(__file__).resolve().parents[1]
def fake_analyze(settings, body):
    notes = body.get('notes', '')
    if notes == 'TEST_FAIL': raise server.ServiceError('测试：AI 失败，可重试。', 502)
    meal = meal_fixture()
    if notes == 'TEST_NONFOOD':
        meal.update(is_food=False, items=[], message='测试：这不是食物照片。')
    return {'meal': meal, 'test_fixture': True}

def fake_sticker(settings, body):
    return {'image_base64': base64.b64encode((root / 'assets/figma/31d5f64980827f8b93ac.png').read_bytes()).decode(), 'mime': 'image/png', 'test_fixture': True}

server.analyze = fake_analyze
server.sticker = fake_sticker
service = server.ThreadingHTTPServer(('127.0.0.1', 0), server.Handler)
service.token = 'local-integration-test-only'
service.settings = server.Settings(root / 'qa/food-test-settings')
service.work = threading.Lock()
(root / 'qa/food-test-bridge.json').write_text(json.dumps({'port': service.server_port, 'token': service.token}))
print('FIXTURE_SERVER_READY', flush=True)
service.serve_forever()
