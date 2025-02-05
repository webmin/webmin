
""" Unit tests for websocketserver """
import unittest
from unittest.mock import patch, MagicMock

from websockify.websocketserver import HttpWebSocket


class HttpWebSocketTest(unittest.TestCase):
    @patch("websockify.websocketserver.WebSocket.__init__", autospec=True)
    def test_constructor(self, websock):
        # Given
        req_obj = MagicMock()

        # When
        sock = HttpWebSocket(req_obj)

        # Then
        websock.assert_called_once_with(sock)
        self.assertEqual(sock.request_handler, req_obj)

    @patch("websockify.websocketserver.WebSocket.__init__", MagicMock(autospec=True))
    def test_send_response(self):
        # Given
        req_obj = MagicMock()
        sock = HttpWebSocket(req_obj)

        # When
        sock.send_response(200, "message")

        # Then
        req_obj.send_response.assert_called_once_with(200, "message")

    @patch("websockify.websocketserver.WebSocket.__init__", MagicMock(autospec=True))
    def test_send_response_default_message(self):
        # Given
        req_obj = MagicMock()
        sock = HttpWebSocket(req_obj)

        # When
        sock.send_response(200)

        # Then
        req_obj.send_response.assert_called_once_with(200, None)

    @patch("websockify.websocketserver.WebSocket.__init__", MagicMock(autospec=True))
    def test_send_header(self):
        # Given
        req_obj = MagicMock()
        sock = HttpWebSocket(req_obj)

        # When
        sock.send_header("keyword", "value")

        # Then
        req_obj.send_header.assert_called_once_with("keyword", "value")

    @patch("websockify.websocketserver.WebSocket.__init__", MagicMock(autospec=True))
    def test_end_headers(self):
        # Given
        req_obj = MagicMock()
        sock = HttpWebSocket(req_obj)

        # When
        sock.end_headers()

        # Then
        req_obj.end_headers.assert_called_once_with()

