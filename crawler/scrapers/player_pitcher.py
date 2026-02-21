"""
선수 투수 기본 기록 크롤러
https://www.koreabaseball.com/Record/Player/PitcherBasic/BasicOld.aspx

실제 컬럼: 순위, 선수명, 팀명, ERA, G, CG, SHO, W, L, SV, HLD, WPCT, TBF, IP, H, HR, BB, HBP, SO, R, ER
WHIP / K/9 / FIP 는 직접 계산
IP 형식: "180 2/3" → 분수 변환 필요
"""

from .base_scraper import BaseScraper

URL = 'https://www.koreabaseball.com/Record/Player/PitcherBasic/BasicOld.aspx'

_IP_FRACTIONS = {'1/3': 0.333, '2/3': 0.667}


def _parse_ip(val: str) -> float:
    """이닝 파싱: "180 2/3" → 180.667"""
    val = str(val).strip()
    if ' ' in val:
        parts = val.split(' ', 1)
        try:
            full = int(parts[0])
            frac = _IP_FRACTIONS.get(parts[1].strip(), 0.0)
            return round(full + frac, 3)
        except (ValueError, IndexError):
            return 0.0
    try:
        return float(val)
    except ValueError:
        return 0.0


class PlayerPitcherScraper(BaseScraper):

    URL = URL

    def scrape(self, season: int) -> list[dict]:
        print(f'[투수] {season}시즌 크롤링 시작...')
        raw_rows = self._crawl_all_pages(season)
        result = [self._parse_row(row, season) for row in raw_rows if row.get('선수명')]
        print(f'[투수] 총 {len(result)}명 수집 완료')
        return result

    def _parse_row(self, row: dict, season: int) -> dict:
        ip  = _parse_ip(row.get('IP', '0'))
        h   = self._safe_int(row.get('H', '0'))
        hr  = self._safe_int(row.get('HR', '0'))
        bb  = self._safe_int(row.get('BB', '0'))
        hbp = self._safe_int(row.get('HBP', '0'))
        so  = self._safe_int(row.get('SO', '0'))
        er  = self._safe_int(row.get('ER', '0'))

        # WHIP 직접 계산 (페이지에 없음)
        whip = round((bb + h) / ip, 2) if ip > 0 else 0.0

        return {
            'name':   row.get('선수명', ''),
            'team':   row.get('팀명', ''),
            'games':  self._safe_int(row.get('G', '0')),
            'wins':   self._safe_int(row.get('W', '0')),
            'losses': self._safe_int(row.get('L', '0')),
            'saves':  self._safe_int(row.get('SV', '0')),
            'holds':  self._safe_int(row.get('HLD', '0')),
            'cg':     self._safe_int(row.get('CG', '0')),
            'sho':    self._safe_int(row.get('SHO', '0')),
            'tbf':    self._safe_int(row.get('TBF', '0')),
            'ip':     ip,
            'hits':   h,
            'hr':     hr,
            'bb':     bb,
            'hbp':    hbp,
            'so':     so,
            'runs':   self._safe_int(row.get('R', '0')),
            'er':     er,
            'era':    self._safe_float(row.get('ERA', '0')),
            'whip':   whip,
            'season': season,
        }
