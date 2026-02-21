"""
선수 주루 기록 크롤러
https://www.koreabaseball.com/Record/Player/Runner/Basic.aspx
"""

from .base_scraper import BaseScraper

URL = 'https://www.koreabaseball.com/Record/Player/Runner/Basic.aspx'


class PlayerRunnerScraper(BaseScraper):

    URL = URL

    def scrape(self, season: int) -> list[dict]:
        print(f'[주루] {season}시즌 크롤링 시작...')
        raw_rows = self._crawl_all_pages(season)
        result = [self._parse_row(row, season) for row in raw_rows if row.get('선수명')]
        print(f'[주루] 총 {len(result)}명 수집 완료')
        return result

    def _parse_row(self, row: dict, season: int) -> dict:
        return {
            'name':    row.get('선수명', ''),
            'team':    row.get('팀명', ''),
            'games':   self._safe_int(row.get('G', '0')),
            'sb':      self._safe_int(row.get('SB', row.get('도루', '0'))),
            'cs':      self._safe_int(row.get('CS', row.get('도루실패', '0'))),
            'sb_pct':  self._safe_float(row.get('SB%', row.get('도루성공률', '0'))),
            'season':  season,
        }
