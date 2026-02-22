"""
선수 타자 기록 크롤러
Basic1: https://www.koreabaseball.com/Record/Player/HitterBasic/Basic1.aspx
  컬럼: 순위, 선수명, 팀명, AVG, G, PA, AB, R, H, 2B, 3B, HR, TB, RBI, SAC, SF
Basic2: https://www.koreabaseball.com/Record/Player/HitterBasic/Basic2.aspx
  컬럼: 순위, 선수명, 팀명, AVG, BB, IBB, HBP, SO, GDP, SLG, OBP, OPS, MH, RISP, PH-BA

두 페이지를 (선수명, 팀명) 기준으로 병합 → 전체 타자 지표 구성
"""

from .base_scraper import BaseScraper

URL1 = 'https://www.koreabaseball.com/Record/Player/HitterBasic/Basic1.aspx'
URL2 = 'https://www.koreabaseball.com/Record/Player/HitterBasic/Basic2.aspx'


class PlayerHitterScraper(BaseScraper):

    URL = URL1  # _crawl_all_pages 기본 URL (사용 안 되지만 BaseScraper 규약)

    def scrape(self, season: int) -> list[dict]:
        print(f'[타자] {season}시즌 크롤링 시작...')

        # Basic1: 타수/안타/루타 계열
        rows1 = self._crawl_all_pages(season, url=URL1)

        # Basic2: 볼넷/삼진/출루율/장타율 계열
        rows2 = self._crawl_all_pages(season, url=URL2)

        # (선수명, 팀명) 기준으로 Basic2 인덱싱
        idx2 = {(r.get('선수명', ''), r.get('팀명', '')): r for r in rows2}

        result = []
        for row in rows1:
            if not row.get('선수명'):
                continue
            key = (row.get('선수명', ''), row.get('팀명', ''))
            merged = {**row, **idx2.get(key, {})}
            result.append(self._parse_row(merged, season))

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

        # OBP/SLG/OPS: Basic2에서 직접 제공; 없으면 계산
        obp = self._safe_float(row.get('OBP', '0'))
        slg = self._safe_float(row.get('SLG', '0'))
        if obp == 0.0:
            obp_denom = ab + bb + hbp
            obp = round((h + bb + hbp) / obp_denom, 3) if obp_denom > 0 else 0.0
        if slg == 0.0 and ab > 0:
            singles = max(0, h - h2b - h3b - hr)
            slg = round((singles + 2*h2b + 3*h3b + 4*hr) / ab, 3)

        return {
            'name':    row.get('선수명', ''),
            'team':    row.get('팀명', ''),
            'games':   self._safe_int(row.get('G', '0')),
            'pa':      pa,
            'ab':      ab,
            'runs':    self._safe_int(row.get('R', '0')),
            'hits':    h,
            'doubles': h2b,
            'triples': h3b,
            'hr':      hr,
            'rbi':     self._safe_int(row.get('RBI', '0')),
            'sb':      0,   # SB/CS는 player_runner 페이지에서 제공
            'cs':      0,
            'bb':      bb,
            'hbp':     hbp,
            'so':      self._safe_int(row.get('SO', '0')),
            'dp':      self._safe_int(row.get('GDP', '0')),
            'avg':     avg,
            'obp':     obp,
            'slg':     slg,
            'ops':     round(obp + slg, 3),
            'season':  season,
        }
