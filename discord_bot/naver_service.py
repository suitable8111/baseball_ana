"""
Naver Sports API 비동기 클라이언트
Flutter의 NaverService를 Python/aiohttp로 포팅
"""

import aiohttp
from datetime import datetime

_BASE = "https://api-gw.sports.naver.com"
_HEADERS = {
    "User-Agent": (
        "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) "
        "AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1"
    ),
    "Referer": "https://m.sports.naver.com/",
    "Origin": "https://m.sports.naver.com",
    "Accept": "application/json, text/plain, */*",
    "Accept-Language": "ko-KR,ko;q=0.9,en;q=0.8",
}
_TIMEOUT = aiohttp.ClientTimeout(total=15)


async def fetch_schedule(date: datetime) -> list[dict]:
    """KBO 당일 경기 목록 반환"""
    date_str = date.strftime("%Y-%m-%d")
    params = {
        "fields": "all",
        "fromDate": date_str,
        "toDate": date_str,
        "size": "200",
    }
    async with aiohttp.ClientSession(headers=_HEADERS, timeout=_TIMEOUT) as session:
        async with session.get(f"{_BASE}/schedule/games", params=params) as resp:
            if resp.status != 200:
                raise Exception(f"일정 로드 실패 (HTTP {resp.status})")
            data = await resp.json(content_type=None)

    games: list = (data.get("result") or {}).get("games") or []
    return [
        g for g in games
        if g.get("upperCategoryId") == "kbaseball"
        and g.get("gameId")
        and g.get("homeTeamName")
        and g.get("awayTeamName")
    ]
