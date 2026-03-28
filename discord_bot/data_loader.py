"""
로컬 JSON 데이터 로더 — 시작 시 1회 로드 후 메모리 캐시
경로: DATA_DIR 환경변수 (기본값: ../flutter_app/assets/data)
"""

import json
import os
from pathlib import Path

_cache: dict[str, list] = {}


def _data_dir() -> Path:
    env = os.getenv("DATA_DIR")
    if env:
        return Path(env)
    return Path(__file__).parent / "../flutter_app/assets/data"


def _load(filename: str) -> list:
    if filename not in _cache:
        path = _data_dir() / filename
        with open(path, "r", encoding="utf-8") as f:
            _cache[filename] = json.load(f)
    return _cache[filename]


def get_hitters(season: int = 2025) -> list[dict]:
    return _load(f"player_hitter_{season}.json")


def get_pitchers(season: int = 2025) -> list[dict]:
    return _load(f"player_pitcher_{season}.json")


def get_standings(season: int = 2025) -> list[dict]:
    return _load(f"team_standings_{season}.json")


def get_h2h(season: int = 2025) -> list[dict]:
    return _load(f"team_head_to_head_{season}.json")


def get_team_hitters(season: int = 2025) -> list[dict]:
    return _load(f"team_hitter_{season}.json")


def get_team_pitchers(season: int = 2025) -> list[dict]:
    return _load(f"team_pitcher_{season}.json")


def preload_all(season: int = 2025) -> None:
    """봇 시작 시 호출 — 모든 데이터를 미리 캐싱해 첫 응답 지연 방지"""
    for fn in [
        f"player_hitter_{season}.json",
        f"player_pitcher_{season}.json",
        f"team_standings_{season}.json",
        f"team_head_to_head_{season}.json",
        f"team_hitter_{season}.json",
        f"team_pitcher_{season}.json",
    ]:
        try:
            _load(fn)
            print(f"  ✓ {fn}")
        except Exception as e:
            print(f"  ✗ {fn}: {e}")
