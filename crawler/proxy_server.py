#!/usr/bin/env python3
"""
Flutter Web 개발용 Naver API CORS 프록시 서버

Usage:
  python proxy_server.py           # 기본 포트 8765
  python proxy_server.py --port 9000

Flutter 앱에서는 NAVER_PROXY=http://localhost:8765 환경변수 또는
NaverService의 _proxyBase를 활성화하세요.
"""

import argparse
from http.server import BaseHTTPRequestHandler, HTTPServer
from urllib.parse import urlparse, parse_qs, urlencode
import requests

NAVER_HEADERS = {
    "User-Agent": (
        "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) "
        "AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1"
    ),
    "Referer": "https://m.sports.naver.com/",
    "Origin": "https://m.sports.naver.com",
    "Accept": "application/json, text/plain, */*",
    "Accept-Language": "ko-KR,ko;q=0.9,en;q=0.8",
}


class ProxyHandler(BaseHTTPRequestHandler):
    def log_message(self, format, *args):
        print(f"[proxy] {format % args}")

    def _cors_headers(self):
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "*")

    def do_OPTIONS(self):
        self.send_response(200)
        self._cors_headers()
        self.end_headers()

    def do_GET(self):
        parsed = urlparse(self.path)
        path = parsed.path  # e.g. /schedule/games  or /schedule/games/XXX/preview

        # strip leading /naver prefix if present
        if path.startswith("/naver"):
            path = path[len("/naver"):]

        target_url = f"https://api-gw.sports.naver.com{path}"
        if parsed.query:
            target_url += f"?{parsed.query}"

        try:
            r = requests.get(target_url, headers=NAVER_HEADERS, timeout=10)
            self.send_response(r.status_code)
            self.send_header("Content-Type", "application/json; charset=utf-8")
            self._cors_headers()
            self.end_headers()
            self.wfile.write(r.content)
        except Exception as e:
            self.send_response(502)
            self._cors_headers()
            self.end_headers()
            self.wfile.write(str(e).encode())


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--port", type=int, default=8765)
    args = parser.parse_args()

    server = HTTPServer(("localhost", args.port), ProxyHandler)
    print(f"프록시 서버 시작: http://localhost:{args.port}")
    print("Flutter NaverService의 _useProxy = true 로 설정 후 앱 재시작")
    print("종료: Ctrl+C")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\n서버 종료")


if __name__ == "__main__":
    main()
