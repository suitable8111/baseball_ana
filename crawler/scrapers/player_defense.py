"""
선수 수비 기록 크롤러
https://www.koreabaseball.com/Record/Player/Defense/Basic.aspx
"""

from .base_scraper import BaseScraper

URL = 'https://www.koreabaseball.com/Record/Player/Defense/Basic.aspx'


class PlayerDefenseScraper(BaseScraper):

    URL = URL

    def scrape(self, season: int) -> list[dict]:
        print(f'[수비] {season}시즌 크롤링 시작...')
        raw_rows = self._crawl_all_pages(season)
        result = [self._parse_row(row, season) for row in raw_rows if row.get('선수명')]
        print(f'[수비] 총 {len(result)}명 수집 완료')
        return result

    def _parse_row(self, row: dict, season: int) -> dict:
        return {
            'name':     row.get('선수명', ''),
            'team':     row.get('팀명', ''),
            'position': row.get('POS', row.get('포지션', '')),
            'games':    self._safe_int(row.get('G', '0')),
            'innings':  self._safe_float(row.get('Inn', row.get('이닝', '0'))),
            'putouts':  self._safe_int(row.get('PO', row.get('자살', '0'))),
            'assists':  self._safe_int(row.get('A', row.get('보살', '0'))),
            'errors':   self._safe_int(row.get('E', row.get('실책', '0'))),
            'dp':       self._safe_int(row.get('DP', row.get('병살', '0'))),
            'fpct':     self._safe_float(row.get('FPct', row.get('수비율', '0'))),
            'season':   season,
        }
