"""
팀 투수 기록 크롤러
https://www.koreabaseball.com/Record/Team/Pitcher/Basic1.aspx

실제 컬럼: 순위, 팀명, ERA, G, W, L, SV, HLD, WPCT, IP, H, HR, BB, HBP, SO, R, ER, WHIP
IP 형식: "1290 1/3" → 분수 이닝 변환 필요
"""

from .base_scraper import BaseScraper

URL = 'https://www.koreabaseball.com/Record/Team/Pitcher/Basic1.aspx'

_IP_FRACTIONS = {'1/3': 0.333, '2/3': 0.667}


def _parse_ip(val: str) -> float:
    """이닝 파싱: "190 2/3" → 190.667, "144" → 144.0"""
    val = val.strip()
    if ' ' in val:
        parts = val.split(' ', 1)
        full = int(parts[0])
        frac = _IP_FRACTIONS.get(parts[1].strip(), 0.0)
        return round(full + frac, 3)
    try:
        return float(val)
    except ValueError:
        return 0.0


class TeamPitcherScraper(BaseScraper):

    URL = URL

    def scrape(self, season: int) -> list[dict]:
        print(f'[팀 투수] {season}시즌 크롤링 시작...')

        soup = self._fetch(self.URL)
        hidden = self._get_all_hidden(soup)

        hidden['__EVENTTARGET'] = self.KEY_SEASON
        hidden['__EVENTARGUMENT'] = ''
        hidden[self.KEY_SEASON] = str(season)
        hidden[self.KEY_SERIES] = '0'
        soup = self._fetch(self.URL, hidden)

        raw_rows = self._parse_team_table(soup)
        result = [self._parse_row(row, season) for row in raw_rows if row.get('팀명')]
        print(f'[팀 투수] {len(result)}팀 수집 완료')
        return result

    def _parse_team_table(self, soup) -> list[dict]:
        table = soup.find('table', class_='tData')
        if not table:
            return []
        headers = [th.get_text(strip=True) for th in table.find('thead').find_all('th')]
        rows = []
        tbody = table.find('tbody')
        if tbody:
            for tr in tbody.find_all('tr'):
                cells = [td.get_text(strip=True) for td in tr.find_all('td')]
                if cells:
                    rows.append(dict(zip(headers, cells)))
        return rows

    def _parse_row(self, row: dict, season: int) -> dict:
        return {
            'team':   row.get('팀명', ''),
            'games':  self._safe_int(row.get('G', '0')),
            'wins':   self._safe_int(row.get('W', '0')),
            'losses': self._safe_int(row.get('L', '0')),
            'saves':  self._safe_int(row.get('SV', '0')),
            'holds':  self._safe_int(row.get('HLD', '0')),
            'ip':     _parse_ip(row.get('IP', '0')),
            'hits':   self._safe_int(row.get('H', '0')),
            'hr':     self._safe_int(row.get('HR', '0')),
            'bb':     self._safe_int(row.get('BB', '0')),
            'hbp':    self._safe_int(row.get('HBP', '0')),
            'so':     self._safe_int(row.get('SO', '0')),
            'runs':   self._safe_int(row.get('R', '0')),
            'er':     self._safe_int(row.get('ER', '0')),
            'era':    self._safe_float(row.get('ERA', '0')),
            'whip':   self._safe_float(row.get('WHIP', '0')),
            'season': season,
        }
