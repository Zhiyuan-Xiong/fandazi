import base64
import copy
import io
import json
from pathlib import Path
import tempfile
import unittest
import threading
import urllib.request
import urllib.error
from PIL import Image
import server

def meal_fixture():
    return {'is_food': True, 'title': '测试数据：番茄鸡蛋面', 'message': '仅用于本地测试，不是实际 AI 识别。',
            'items': [{'name': '番茄鸡蛋面', 'portion_g': 300, 'kcal_low': 350, 'kcal_high': 500,
                       'protein_g': 20, 'carbs_g': 60, 'fat_g': 12, 'confidence': 'medium'}],
            'assumptions': ['测试估算范围；未调用 AI。'],
            'recipe': {'title': '测试食谱：番茄鸡蛋面', 'minutes': 15,
                       'ingredients': ['番茄', '鸡蛋', '面条'], 'steps': ['准备食材。', '炒番茄与鸡蛋，加水煮面。']}}

def photo_fixture():
    stream = io.BytesIO()
    image = Image.new('RGB', (60, 40), '#dcac66')
    exif = Image.Exif()
    exif[274] = 6
    image.save(stream, 'JPEG', exif=exif)
    return base64.b64encode(stream.getvalue()).decode()

class ServiceTests(unittest.TestCase):
    def test_loopback_authentication_and_unconfigured_api(self):
        with tempfile.TemporaryDirectory() as folder:
            http = server.ThreadingHTTPServer(('127.0.0.1', 0), server.Handler)
            http.token = 'test-transport-token'
            http.settings = server.Settings(Path(folder))
            http.work = threading.Lock()
            worker = threading.Thread(target=http.serve_forever, daemon=True)
            worker.start()
            url = f'http://127.0.0.1:{http.server_port}'
            try:
                with self.assertRaises(urllib.error.HTTPError) as error: urllib.request.urlopen(url + '/health')
                self.assertEqual(error.exception.code, 403)
                headers = {'Authorization': 'Bearer ' + http.token, 'Content-Type': 'application/json'}
                request = urllib.request.Request(url + '/health', headers=headers)
                with urllib.request.urlopen(request) as response: self.assertFalse(json.load(response)['configured'])
                request = urllib.request.Request(url + '/config', b'{}', {**headers, 'Origin': 'https://example.com'})
                with self.assertRaises(urllib.error.HTTPError) as error: urllib.request.urlopen(request)
                self.assertEqual(error.exception.code, 403)
                request = urllib.request.Request(url + '/analyze', json.dumps({'image_base64': photo_fixture()}).encode(), headers)
                with self.assertRaises(urllib.error.HTTPError) as error: urllib.request.urlopen(request)
                self.assertEqual(error.exception.code, 503)
            finally:
                http.shutdown()
                http.server_close()
                worker.join()

    def test_photo_normalization(self):
        image = Image.open(io.BytesIO(server.normalize_photo(photo_fixture())))
        self.assertEqual(image.size, (40, 60))
        self.assertFalse(image.getexif())

    def test_invalid_photo(self):
        with self.assertRaises(server.ServiceError): server.normalize_photo('not-a-photo')

    def test_numeric_validation(self):
        for key, value in [('portion_g', 0), ('kcal_low', -1), ('fat_g', float('nan')), ('carbs_g', '60')]:
            data = meal_fixture()
            data['items'][0][key] = value
            with self.assertRaises(server.ServiceError): server.validate_meal(data)
        data = meal_fixture()
        data['items'][0]['kcal_high'] = 20
        with self.assertRaises(server.ServiceError): server.validate_meal(data)

    def test_non_food_never_gets_calories(self):
        data = meal_fixture()
        data['is_food'] = False
        with self.assertRaises(server.ServiceError): server.validate_meal(data)
        data['items'] = []
        self.assertFalse(server.validate_meal(data)['is_food'])

    def test_response_request_and_schema(self):
        class Settings:
            data = {'vision_model': 'gpt-4.1-mini'}
            def key(self): return 'unit-test-placeholder'
        captured = []
        def fake(path, key, payload):
            captured.append(payload)
            return {'status': 'completed', 'output': [{'content': [{'type': 'output_text', 'text': json.dumps(meal_fixture())}]}]}
        result = server.analyze(Settings(), {'image_base64': photo_fixture(), 'notes': '小份'}, fake)
        self.assertEqual(result['meal']['items'][0]['portion_g'], 300)
        self.assertFalse(captured[0]['store'])
        self.assertTrue(captured[0]['text']['format']['strict'])
        self.assertTrue(captured[0]['input'][0]['content'][1]['image_url'].startswith('data:image/jpeg;base64,'))

    def test_refusal_and_truncation(self):
        class Settings:
            data = {'vision_model': 'gpt-4.1-mini'}
            def key(self): return 'unit-test-placeholder'
        for response in [{'status': 'incomplete'}, {'status': 'completed', 'output': [{'content': [{'type': 'refusal'}]}]}]:
            with self.assertRaises(server.ServiceError): server.analyze(Settings(), {'image_base64': photo_fixture()}, lambda *_: response)

    def test_no_key_does_not_make_network_call(self):
        with self.assertRaises(server.ServiceError) as error: server.post_openai('responses', '', {})
        self.assertEqual(error.exception.status, 503)

    def test_encrypted_local_settings(self):
        with tempfile.TemporaryDirectory() as folder:
            settings = server.Settings(Path(folder))
            settings.update({'api_key': 'unit-test-not-a-real-key'})
            self.assertNotIn('unit-test-not-a-real-key', settings.path.read_text())
            self.assertEqual(settings.key(), 'unit-test-not-a-real-key')
            self.assertNotIn('encrypted_key', settings.status())
            settings.update({'clear_key': True})
            self.assertEqual(settings.key(), '')

    def test_image_edit_sends_photo_and_original_style(self):
        class Settings:
            data = {'image_model': 'gpt-image-2'}
            def key(self): return 'unit-test-placeholder'
        png = io.BytesIO()
        sticker = Image.new('RGBA', (16, 16), (100, 160, 80, 255))
        sticker.putpixel((0, 0), (0, 0, 0, 0))
        sticker.save(png, 'PNG')
        def fake(path, key, payload, content_type, timeout):
            self.assertEqual(path, 'images/edits')
            self.assertIn(b'filename="meal.jpg"', payload)
            self.assertIn(b'filename="style.png"', payload)
            self.assertIn(b'transparent', payload)
            self.assertIn(b'name="model"\r\n\r\ngpt-image-2\r\n', payload)
            self.assertNotIn(b'input_fidelity', payload)
            self.assertNotIn(b'output_compression', payload)
            self.assertIn(b'name="output_format"\r\n\r\npng\r\n', payload)
            self.assertIn(b'reference style takes priority', payload)
            return {'data': [{'b64_json': base64.b64encode(png.getvalue()).decode()}]}
        self.assertEqual(server.sticker(Settings(), {'image_base64': photo_fixture()}, fake)['mime'], 'image/png')

    def test_sticker_rejects_opaque_or_empty_output(self):
        class Settings:
            data = {'image_model': 'gpt-image-2'}
            def key(self): return 'unit-test-placeholder'
        for opacity in (0, 255):
            png = io.BytesIO()
            Image.new('RGBA', (16, 16), (100, 160, 80, opacity)).save(png, 'PNG')
            response = {'data': [{'b64_json': base64.b64encode(png.getvalue()).decode()}]}
            with self.assertRaisesRegex(server.ServiceError, '透明背景'):
                server.sticker(Settings(), {'image_base64': photo_fixture()}, lambda *_: response)

if __name__ == '__main__': unittest.main()
