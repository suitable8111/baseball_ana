"""
팀 순위 + 상대 전적 크롤러
https://www.koreabaseball.com/Record/TeamRank/TeamRankDaily.aspx

테이블 1: 날짜 기준 순위표
  컬럼: 순위, 팀명, 경기, 승, 패, 무, 승률, 게임차, 최근10경기, 연속, 홈, 방문

테이블 2: 팀간 상대 전적 매트릭스 (10×10)
  각 셀: '승-패-무' 또는 '■' (자기 팀)
"""

from .base_scraper import BaseScraper

URL = 'https://www.koreabaseball.com/Record/TeamRank/TeamRankDaily.aspx'

# 시즌별 최종 경기 날짜 (YYYYMMDD)
SEASON_END_DATES = {
    2025: '20251004',
    2024: '20241019',
    2023: '20231005',
    2022: '20221025',
}


class TeamRankScraper(BaseScraper):

    URL = URL

    def scrape(self, season: int) -> dict:
        """
        반환값:
        {
            'standings': [...],      # 팀 순위 리스트
            'head_to_head': [...],   # 팀간 상대전적 리스트
            'date': '2025-10-04',
            'season': 2025,
        }
        """
        print(f'[팀 순위] {season}시즌 크롤링 시작...')

        # GET → hidden 필드 취득
        soup = self._fetch(self.URL)
        hidden = self._get_all_hidden(soup)

        # 날짜 기준 POST
        raw_date = SEASON_END_DATES.get(season, f'{season}1004')
        date_str = f'{raw_date[:4]}-{raw_date[4:6]}-{raw_date[6:]}'

        hidden['__EVENTTARGET'] = ''
        hidden['__EVENTARGUMENT'] = ''
        hidden['hfSearchYear'] = str(season)
        hidden['hfSearchDate'] = raw_date
        hidden['txtCanlendar'] = date_str
        hidden['ddlSeries'] = ''
        hidden['hfSearchSeries'] = '0'
        soup = self._fetch(self.URL, hidden)

        # 두 개의 tData 테이블 파싱
        tables = soup.find_all('table', class_='tData')
        standings = []
        head_to_head = []

        if tables:
            standings = self._parse_standings(tables[0], season)
        if len(tables) >= 2:
            head_to_head = self._parse_head_to_head(tables[1], season)

        print(f'[팀 순위] 순위표 {len(standings)}팀, 상대전적 {len(head_to_head)}팀 수집 완료')
        return {
            'standings': standings,
            'head_to_head': head_to_head,
            'date': date_str,
            'season': season,
        }

    def _parse_standings(self, table, season: int) -> list[dict]:
        headers = [th.get_text(strip=True) for th in table.find('thead').find_all('th')]
        rows = []
        tbody = table.find('tbody')
        if not tbody:
            return rows
        for tr in tbody.find_all('tr'):
            cells = [td.get_text(strip=True) for td in tr.find_all('td')]
            if not cells:
                continue
            row = dict(zip(headers, cells))
            rows.append(self._parse_standing_row(row, season))
        return rows

    def _parse_standing_row(self, row: dict, season: int) -> dict:
        def parse_wtl(s: str):
            """'W-T-L' 형식 파싱 (예: '41-1-29' → wins=41, ties=1, losses=29)"""
            parts = s.split('-')
            if len(parts) == 3:
                return (
                    self._safe_int(parts[0]),
                    self._safe_int(parts[1]),
                    self._safe_int(parts[2]),
                )
            return 0, 0, 0

        home_str = row.get('홈', '0-0-0')
        away_str = row.get('방문', '0-0-0')
        hw, ht, hl = parse_wtl(home_str)
        aw, at, al = parse_wtl(away_str)

        gb_raw = row.get('게임차', '0')
        gb = 0.0 if gb_raw in ('-', '') else self._safe_float(gb_raw)

        return {
            'rank':    self._safe_int(row.get('순위', '0')),
            'team':    row.get('팀명', ''),
            'games':   self._safe_int(row.get('경기', '0')),
            'wins':    self._safe_int(row.get('승', '0')),
            'losses':  self._safe_int(row.get('패', '0')),
            'ties':    self._safe_int(row.get('무', '0')),
            'pct':     self._safe_float(row.get('승률', '0')),
            'gb':      gb,
            'last10':  row.get('최근10경기', ''),
            'streak':  row.get('연속', ''),
            'home_w':  hw,
            'home_t':  ht,
            'home_l':  hl,
            'away_w':  aw,
            'away_t':  at,
            'away_l':  al,
            'season':  season,
        }

    def _parse_head_to_head(self, table, season: int) -> list[dict]:
        """
        상대 전적 매트릭스 파싱
        헤더: ['팀명', 'LG', '두산', '삼성', ..., '합계']
        각 셀: '승-패-무' 또는 '■' (자기 팀)
        """
        headers = [th.get_text(strip=True) for th in table.find('thead').find_all('th')]
        # 헤더에 포함된 "(승-패-무)" 접미사 제거
        opponent_names = [n.replace('(승-패-무)', '').strip() for n in headers[1:]]

        rows = []
        tbody = table.find('tbody')
        if not tbody:
            return rows

        for tr in tbody.find_all('tr'):
            cells = [td.get_text(strip=True) for td in tr.find_all('td')]
            if not cells:
                continue

            team_name = cells[0]
            matchups = {}
            total_w, total_l, total_t = 0, 0, 0

            for i, opp in enumerate(opponent_names):
                if i + 1 >= len(cells):
                    break
                val = cells[i + 1]

                if opp == '합계':
                    parts = val.split('-')
                    if len(parts) == 3:
                        total_w = self._safe_int(parts[0])
                        total_l = self._safe_int(parts[1])
                        total_t = self._safe_int(parts[2])
                    continue

                if val in ('■', '-', ''):
                    matchups[opp] = None
                    continue

                parts = val.split('-')
                if len(parts) == 3:
                    matchups[opp] = {
                        'w': self._safe_int(parts[0]),
                        'l': self._safe_int(parts[1]),
                        't': self._safe_int(parts[2]),
                    }
                else:
                    matchups[opp] = None

            rows.append({
                'team':    team_name,
                'matchups': matchups,
                'total_w': total_w,
                'total_l': total_l,
                'total_t': total_t,
                'season':  season,
            })

        return rows
