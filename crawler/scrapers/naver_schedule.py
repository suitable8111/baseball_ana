#!/usr/bin/env python3
"""
Naver Sports KBO 경기 일정 & 라인업 크롤러

Usage:
  # 오늘 일정 (기본)
  python naver_schedule.py

  # 특정 날짜
  python naver_schedule.py --date 2025-09-03

  # 날짜 범위
  python naver_schedule.py --from 2025-09-01 --to 2025-09-07

  # 라인업 포함 (느림)
  python naver_schedule.py --date 2025-09-03 --preview
"""

import argparse
import json
import sys
from datetime import datetime

import requests

SCHEDULE_URL = "https://api-gw.sports.naver.com/schedule/games"
PREVIEW_URL = "https://api-gw.sports.naver.com/schedule/games/{game_id}/preview"

HEADERS = {
    "User-Agent": (
        "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) "
        "AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148"
    ),
    "Referer": "https://m.sports.naver.com/",
    "Accept": "application/json, text/plain, */*",
}

# KBO team code → Korean name (for reference)
TEAM_CODES = {
    "SS": "삼성",
    "LT": "롯데",
    "LG": "LG",
    "KT": "KT",
    "SK": "SSG",
    "NC": "NC",
    "WO": "키움",
    "HT": "KIA",
    "OB": "두산",
    "HH": "한화",
}


def fetch_schedule(from_date: str, to_date: str) -> list[dict]:
    params = {
        "fields": "all",
        "fromDate": from_date,
        "toDate": to_date,
        "size": 50,
    }
    r = requests.get(SCHEDULE_URL, headers=HEADERS, params=params, timeout=10)
    r.raise_for_status()
    data = r.json()
    games = data.get("result", {}).get("games", [])
    # KBO 경기만 필터
    return [g for g in games if g.get("upperCategoryId") == "kbaseball"]


def fetch_preview(game_id: str) -> dict:
    url = PREVIEW_URL.format(game_id=game_id)
    r = requests.get(url, headers=HEADERS, timeout=10)
    r.raise_for_status()
    return r.json().get("result", {}).get("previewData", {})


def extract_game(g: dict) -> dict:
    return {
        "gameId": g.get("gameId"),
        "gameDate": g.get("gameDate"),
        "gameDateTime": g.get("gameDateTime"),
        "stadium": g.get("stadium"),
        "statusCode": g.get("statusCode"),
        "homeTeamCode": g.get("homeTeamCode"),
        "homeTeamName": g.get("homeTeamName"),
        "awayTeamCode": g.get("awayTeamCode"),
        "awayTeamName": g.get("awayTeamName"),
        "homeTeamScore": g.get("homeTeamScore"),
        "awayTeamScore": g.get("awayTeamScore"),
        "homeStarterName": g.get("homeStarterName"),
        "awayStarterName": g.get("awayStarterName"),
        "homeTeamScoreByInning": g.get("homeTeamScoreByInning", []),
        "awayTeamScoreByInning": g.get("awayTeamScoreByInning", []),
        "homeTeamRheb": g.get("homeTeamRheb", []),
        "awayTeamRheb": g.get("awayTeamRheb", []),
        "winner": g.get("winner"),
    }


def main():
    parser = argparse.ArgumentParser(description="Naver KBO schedule scraper")
    parser.add_argument("--date", help="조회 날짜 (YYYY-MM-DD)")
    parser.add_argument("--from", dest="from_date", help="시작 날짜 (YYYY-MM-DD)")
    parser.add_argument("--to", dest="to_date", help="종료 날짜 (YYYY-MM-DD)")
    parser.add_argument(
        "--preview", action="store_true", help="라인업/선발 정보도 가져오기 (느림)"
    )
    args = parser.parse_args()

    if args.date:
        from_date = to_date = args.date
    elif args.from_date and args.to_date:
        from_date, to_date = args.from_date, args.to_date
    else:
        today = datetime.today().strftime("%Y-%m-%d")
        from_date = to_date = today

    print(f"일정 조회: {from_date} ~ {to_date}", file=sys.stderr)
    games = fetch_schedule(from_date, to_date)
    print(f"KBO 경기 {len(games)}개 발견", file=sys.stderr)

    result = []
    for g in games:
        entry = extract_game(g)
        if args.preview and g.get("gameId"):
            try:
                preview = fetch_preview(g["gameId"])
                entry["preview"] = preview
                print(f"  라인업: {g['gameId']}", file=sys.stderr)
            except Exception as e:
                print(f"  라인업 오류 {g['gameId']}: {e}", file=sys.stderr)
        result.append(entry)

    print(json.dumps(result, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
