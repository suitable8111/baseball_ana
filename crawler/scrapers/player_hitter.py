"""
선수 타자 기본 기록 크롤러
https://www.koreabaseball.com/Record/Player/HitterBasic/BasicOld.aspx

실제 컬럼: 순위, 선수명, 팀명, AVG, G, PA, AB, H, 2B, 3B, HR, RBI, SB, CS, BB, HBP, SO, GDP, E
OBP / SLG / OPS는 해당 페이지에 없으므로 processors/advanced_stats.py에서 계산
"""

from .base_scraper import BaseScraper

URL = 'https://www.koreabaseball.com/Record/Player/HitterBasic/BasicOld.aspx'


class PlayerHitterScraper(BaseScraper):

    URL = URL

    def scrape(self, season: int) -> list[dict]:
        print(f'[타자] {season}시즌 크롤링 시작...')
        raw_rows = self._crawl_all_pages(season)
        result = [self._parse_row(row, season) for row in raw_rows if row.get('선수명')]
        print(f'[타자] 총 {len(result)}명 수집 완료')
        return result

    def _parse_row(self, row: dict, season: int) -> dict:
        ab  = self._safe_int(row.get('AB', '0'))
        h   = self._safe_int(row.get('H', '0'))
        h2b = self._safe_int(row.get('2B', '0'))
        h3b = self._safe_int(row.get('3B', '0'))
        hr  = self._safe_int(row.get('HR', '0'))
        bb  = self._safe_int(row.get('BB', '0'))
        hbp = self._safe_int(row.get('HBP', '0'))
        pa  = self._safe_int(row.get('PA', '0'))
        avg = self._safe_float(row.get('AVG', '0'))

        # OBP, SLG, OPS 계산 (페이지에 없으므로 직접 계산)
        singles = max(0, h - h2b - h3b - hr)
        slg = round((singles + 2*h2b + 3*h3b + 4*hr) / ab, 3) if ab > 0 else 0.0
        obp_denom = ab + bb + hbp
        obp = round((h + bb + hbp) / obp_denom, 3) if obp_denom > 0 else 0.0
        ops = round(obp + slg, 3)

        return {
            'name':    row.get('선수명', ''),
            'team':    row.get('팀명', ''),
            'games':   self._safe_int(row.get('G', '0')),
            'pa':      pa,
            'ab':      ab,
            'runs':    0,  # 이 뷰에서는 득점(R) 컬럼 없음
            'hits':    h,
            'doubles': h2b,
            'triples': h3b,
            'hr':      hr,
            'rbi':     self._safe_int(row.get('RBI', '0')),
            'sb':      self._safe_int(row.get('SB', '0')),
            'cs':      self._safe_int(row.get('CS', '0')),
            'bb':      bb,
            'hbp':     hbp,
            'so':      self._safe_int(row.get('SO', '0')),
            'dp':      self._safe_int(row.get('GDP', '0')),
            'avg':     avg,
            'obp':     obp,
            'slg':     slg,
            'ops':     ops,
            'season':  season,
        }
