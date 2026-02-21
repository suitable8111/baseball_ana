"""
팀 타자 기록 크롤러
https://www.koreabaseball.com/Record/Team/Hitter/Basic1.aspx

실제 컬럼: 순위, 팀명, AVG, G, PA, AB, R, H, 2B, 3B, HR, TB, RBI, SAC, SF
테이블 class: tData tt  (선수 통계의 tData01 과 다름)
페이지네이션 없음 (10개 팀)
"""

import time
from .base_scraper import BaseScraper

URL = 'https://www.koreabaseball.com/Record/Team/Hitter/Basic1.aspx'


class TeamHitterScraper(BaseScraper):

    URL = URL

    def scrape(self, season: int) -> list[dict]:
        print(f'[팀 타자] {season}시즌 크롤링 시작...')

        # GET으로 hidden 필드 취득
        soup = self._fetch(self.URL)
        hidden = self._get_all_hidden(soup)

        # 시즌 POST
        hidden['__EVENTTARGET'] = ''
        hidden['__EVENTARGUMENT'] = ''
        hidden[self.KEY_SEASON] = str(season)
        hidden[self.KEY_SERIES] = '0'
        soup = self._fetch(self.URL, hidden)

        # tData 클래스로 파싱 (팀 페이지는 tData01 이 아님)
        raw_rows = self._parse_team_table(soup)
        result = [self._parse_row(row, season) for row in raw_rows if row.get('팀명')]
        print(f'[팀 타자] {len(result)}팀 수집 완료')
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
        ab  = self._safe_int(row.get('AB', '0'))
        h   = self._safe_int(row.get('H', '0'))
        h2b = self._safe_int(row.get('2B', '0'))
        h3b = self._safe_int(row.get('3B', '0'))
        hr  = self._safe_int(row.get('HR', '0'))
        bb  = self._safe_int(row.get('BB', '0'))
        hbp = self._safe_int(row.get('HBP', '0'))
        pa  = self._safe_int(row.get('PA', '0'))
        avg = self._safe_float(row.get('AVG', '0'))

        # OBP, SLG, OPS 계산
        singles = max(0, h - h2b - h3b - hr)
        slg = round((singles + 2*h2b + 3*h3b + 4*hr) / ab, 3) if ab > 0 else 0.0
        obp_denom = ab + bb + hbp
        obp = round((h + bb + hbp) / obp_denom, 3) if obp_denom > 0 else 0.0

        return {
            'team':    row.get('팀명', ''),
            'games':   self._safe_int(row.get('G', '0')),
            'pa':      pa,
            'ab':      ab,
            'runs':    self._safe_int(row.get('R', '0')),
            'hits':    h,
            'doubles': h2b,
            'triples': h3b,
            'hr':      hr,
            'tb':      self._safe_int(row.get('TB', '0')),
            'rbi':     self._safe_int(row.get('RBI', '0')),
            'sac':     self._safe_int(row.get('SAC', '0')),
            'sf':      self._safe_int(row.get('SF', '0')),
            'avg':     avg,
            'obp':     obp,
            'slg':     slg,
            'ops':     round(obp + slg, 3),
            'season':  season,
        }
