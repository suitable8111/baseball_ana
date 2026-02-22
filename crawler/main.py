"""
KBO 야구 통계 크롤러 메인 실행 파일

사용법:
  # 단일 시즌
  python main.py --season 2025 --dry-run

  # 다중 시즌 (범위)
  python main.py --seasons 2020-2025 --dry-run

  # 다중 시즌 (목록)
  python main.py --seasons 2022,2023,2024,2025 --dry-run

  # 유형 지정
  python main.py --season 2025 --type hitter --dry-run
  python main.py --seasons 2020-2025 --type all --dry-run

  유형: all | hitter | pitcher | defense | runner | team | rank
  데이터 범위: 2002 ~ 2025 (koreabaseball.com 제공)
"""

import argparse
import json
import os
from dotenv import load_dotenv

from scrapers.player_hitter import PlayerHitterScraper
from scrapers.player_pitcher import PlayerPitcherScraper
from scrapers.player_defense import PlayerDefenseScraper
from scrapers.player_runner import PlayerRunnerScraper
from scrapers.team_hitter import TeamHitterScraper
from scrapers.team_pitcher import TeamPitcherScraper
from scrapers.team_rank import TeamRankScraper
from processors.advanced_stats import enrich_hitter, enrich_pitcher
import firebase_uploader as uploader

load_dotenv()

KBO_FIRST_SEASON = 2002  # koreabaseball.com 통계 최초 연도


def parse_seasons(value: str) -> list[int]:
    """
    다중 시즌 파싱
    - '2025'        → [2025]
    - '2022-2025'   → [2022, 2023, 2024, 2025]
    - '2022,2023'   → [2022, 2023]
    """
    value = value.strip()
    if '-' in value and ',' not in value:
        parts = value.split('-')
        if len(parts) == 2:
            start, end = int(parts[0]), int(parts[1])
            return list(range(start, end + 1))
    if ',' in value:
        return [int(s.strip()) for s in value.split(',')]
    return [int(value)]


def run_hitter(season: int, dry_run: bool):
    scraper = PlayerHitterScraper()
    data = scraper.scrape(season)
    data = [enrich_hitter(d) for d in data]

    if dry_run:
        _save_json(data, f'output/player_hitter_{season}.json')
    else:
        uploader.upload_player_hitters(data, season)


def run_pitcher(season: int, dry_run: bool):
    scraper = PlayerPitcherScraper()
    data = scraper.scrape(season)
    data = [enrich_pitcher(d) for d in data]

    if dry_run:
        _save_json(data, f'output/player_pitcher_{season}.json')
    else:
        uploader.upload_player_pitchers(data, season)


def run_defense(season: int, dry_run: bool):
    scraper = PlayerDefenseScraper()
    data = scraper.scrape(season)

    if dry_run:
        _save_json(data, f'output/player_defense_{season}.json')
    else:
        uploader.upload_player_defense(data, season)


def run_runner(season: int, dry_run: bool):
    scraper = PlayerRunnerScraper()
    data = scraper.scrape(season)

    if dry_run:
        _save_json(data, f'output/player_runner_{season}.json')
    else:
        uploader.upload_player_runners(data, season)


def run_team(season: int, dry_run: bool):
    hitter_scraper = TeamHitterScraper()
    pitcher_scraper = TeamPitcherScraper()

    hitter_data = hitter_scraper.scrape(season)
    pitcher_data = pitcher_scraper.scrape(season)

    if dry_run:
        _save_json(hitter_data, f'output/team_hitter_{season}.json')
        _save_json(pitcher_data, f'output/team_pitcher_{season}.json')
    else:
        uploader.upload_team_hitters(hitter_data, season)
        uploader.upload_team_pitchers(pitcher_data, season)


def run_rank(season: int, dry_run: bool):
    scraper = TeamRankScraper()
    data = scraper.scrape(season)

    if dry_run:
        _save_json(data['standings'], f'output/team_standings_{season}.json')
        _save_json(data['head_to_head'], f'output/team_head_to_head_{season}.json')
    else:
        # TODO: Firebase 세팅 후 구현
        pass


FLUTTER_ASSETS_DIR = os.path.join(
    os.path.dirname(__file__), '..', 'flutter_app', 'assets', 'data'
)


def _save_json(data: list, path: str):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, 'w', encoding='utf-8') as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
    print(f'[dry-run] 저장 완료: {path} ({len(data)}건)')

    # Flutter assets/data/ 에도 자동 복사
    assets_dir = os.path.abspath(FLUTTER_ASSETS_DIR)
    if os.path.exists(assets_dir):
        import shutil
        filename = os.path.basename(path)
        dest = os.path.join(assets_dir, filename)
        shutil.copy2(path, dest)
        print(f'[dry-run] Flutter assets 복사: {dest}')


def run_one_season(season: int, ctype: str, dry_run: bool):
    """단일 시즌 크롤링"""
    if season < KBO_FIRST_SEASON:
        print(f'[경고] {season}년은 지원 범위({KBO_FIRST_SEASON}~) 밖입니다. 건너뜁니다.')
        return

    print(f'\n{"=" * 40}')
    print(f'  시즌: {season} | 유형: {ctype} | dry-run: {dry_run}')
    print(f'{"=" * 40}')

    if ctype in ('all', 'hitter'):
        run_hitter(season, dry_run)
    if ctype in ('all', 'pitcher'):
        run_pitcher(season, dry_run)
    if ctype in ('all', 'defense'):
        run_defense(season, dry_run)
    if ctype in ('all', 'runner'):
        run_runner(season, dry_run)
    if ctype in ('all', 'team'):
        run_team(season, dry_run)
    if ctype in ('all', 'rank'):
        run_rank(season, dry_run)


def main():
    parser = argparse.ArgumentParser(
        description='KBO 야구 통계 크롤러',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
예시:
  python main.py --season 2025 --dry-run
  python main.py --seasons 2023-2025 --type hitter --dry-run
  python main.py --seasons 2022,2024,2025 --dry-run
        """,
    )

    season_group = parser.add_mutually_exclusive_group()
    season_group.add_argument(
        '--season', type=int, default=None,
        help=f'단일 시즌 (기본: 2025, 범위: {KBO_FIRST_SEASON}~)',
    )
    season_group.add_argument(
        '--seasons', type=str, default=None,
        help='다중 시즌. 범위: "2020-2025", 목록: "2022,2023,2025"',
    )

    parser.add_argument(
        '--type',
        choices=['all', 'hitter', 'pitcher', 'defense', 'runner', 'team', 'rank'],
        default='all',
        help='크롤링 유형 (기본: all)',
    )
    parser.add_argument('--dry-run', action='store_true', help='Firebase 업로드 없이 JSON 저장')
    args = parser.parse_args()

    dry_run = args.dry_run
    ctype = args.type

    # 시즌 목록 결정
    if args.seasons:
        seasons = parse_seasons(args.seasons)
    elif args.season:
        seasons = [args.season]
    else:
        seasons = [2025]

    print(f'=== KBO 크롤러 시작 ===')
    print(f'시즌: {seasons} | 유형: {ctype} | dry-run: {dry_run}')

    for season in seasons:
        run_one_season(season, ctype, dry_run)

    print(f'\n=== 크롤링 완료 ({len(seasons)}개 시즌) ===')


if __name__ == '__main__':
    main()
