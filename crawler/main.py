"""
KBO 야구 통계 크롤러 메인 실행 파일

사용법:
  python main.py --season 2025           # 2025시즌 전체 크롤링
  python main.py --season 2025 --type hitter   # 타자만
  python main.py --season 2025 --type pitcher  # 투수만
  python main.py --season 2025 --type team     # 팀 통계만
  python main.py --season 2025 --dry-run       # Firebase 업로드 없이 테스트
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


def main():
    parser = argparse.ArgumentParser(description='KBO 야구 통계 크롤러')
    parser.add_argument('--season', type=int, default=2025, help='크롤링 시즌 (기본: 2025)')
    parser.add_argument(
        '--type',
        choices=['all', 'hitter', 'pitcher', 'defense', 'runner', 'team', 'rank'],
        default='all',
        help='크롤링 유형 (기본: all)'
    )
    parser.add_argument('--dry-run', action='store_true', help='Firebase 업로드 없이 JSON 저장')
    args = parser.parse_args()

    season = args.season
    dry_run = args.dry_run
    ctype = args.type

    print(f'=== KBO 크롤러 시작 ===')
    print(f'시즌: {season} | 유형: {ctype} | dry-run: {dry_run}')
    print('=' * 30)

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

    print('=== 크롤링 완료 ===')


if __name__ == '__main__':
    main()
