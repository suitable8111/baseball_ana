"""
팀 순위 + 상대 전적 크롤러
https://www.koreabaseball.com/Record/TeamRank/TeamRank.aspx

ASP.NET UpdatePanel 방식: async postback 필요
테이블 0: 팀 순위표 (순위, 팀명, 경기, 승, 패, 무, 승률, 게임차, 최근10경기, 연속, 홈, 방문)
테이블 1: 팀간 상대전적 매트릭스 (10×10)

TeamRankDaily.aspx (일자별)는 현재 날짜 기준 최신 데이터 전용.
"""

import time
from bs4 import BeautifulSoup
from .base_scraper import BaseScraper, CRAWL_DELAY

URL_SEASON = 'https://www.koreabaseball.com/Record/TeamRank/TeamRank.aspx'
URL_DAILY  = 'https://www.koreabaseball.com/Record/TeamRank/TeamRankDaily.aspx'

KEY_YEAR   = 'ctl00$ctl00$ctl00$cphContents$cphContents$cphContents$ddlYear'
KEY_SERIES = 'ctl00$ctl00$ctl00$cphContents$cphContents$cphContents$ddlSeries'
SM_KEY     = 'ctl00$ctl00$ctl00$cphContents$cphContents$cphContents$ScriptManager'

_ASYNC_HEADERS = {
    'X-MicrosoftAjax': 'Delta=true',
    'X-Requested-With': 'XMLHttpRequest',
    'Content-Type': 'application/x-www-form-urlencoded; charset=UTF-8',
}


class TeamRankScraper(BaseScraper):

    URL = URL_SEASON

    # ─── 시즌 최종 순위 ──────────────────────────────────────────────

    def scrape(self, season: int) -> dict:
        """
        TeamRank.aspx (시즌별) 크롤링.
        반환: {'standings': [...], 'head_to_head': [...], 'season': season}
        """
        print(f'[팀 순위] {season}시즌 크롤링 시작...')

        # 1. GET → hidden 필드 취득
        soup = self._fetch(URL_SEASON)
        hidden = self._get_all_hidden(soup)

        # 2. UpdatePanel async postback으로 연도 변경
        hidden['__EVENTTARGET']  = KEY_YEAR
        hidden['__EVENTARGUMENT'] = ''
        hidden[KEY_YEAR]   = str(season)
        hidden[KEY_SERIES] = '0'
        hidden['__ASYNCPOST'] = 'true'
        hidden[SM_KEY] = f'{SM_KEY}|{KEY_YEAR}'

        soup2 = self._fetch_delta(URL_SEASON, hidden)

        # 3. tData 테이블 2개 파싱
        tables = soup2.find_all('table')
        standings    = self._parse_standings(tables[0], season) if tables else []
        head_to_head = self._parse_head_to_head(tables[1], season) if len(tables) >= 2 else []

        print(f'[팀 순위] 순위표 {len(standings)}팀, 상대전적 {len(head_to_head)}팀 수집 완료')
        return {'standings': standings, 'head_to_head': head_to_head, 'season': season}

    # ─── 일자별 최신 순위 ─────────────────────────────────────────────

    def scrape_daily(self) -> dict:
        """
        TeamRankDaily.aspx (일자별) 에서 현재 날짜 기준 최신 데이터 반환.
        반환: {'standings': [...], 'head_to_head': [...]}
        """
        print('[팀 순위/일자별] 최신 데이터 크롤링...')
        soup = self._fetch(URL_DAILY)

        tables = soup.find_all('table', class_='tData')
        standings    = self._parse_standings(tables[0], season=0) if tables else []
        head_to_head = self._parse_head_to_head(tables[1], season=0) if len(tables) >= 2 else []

        print(f'[팀 순위/일자별] 순위표 {len(standings)}팀, 상대전적 {len(head_to_head)}팀')
        return {'standings': standings, 'head_to_head': head_to_head}

    # ─── 내부 헬퍼 ───────────────────────────────────────────────────

    def _fetch_delta(self, url: str, post_data: dict) -> BeautifulSoup:
        """UpdatePanel async postback → Delta 응답 파싱 → BeautifulSoup"""
        resp = self.session.post(url, data=post_data, headers={
            **dict(self.session.headers), **_ASYNC_HEADERS
        }, timeout=15)
        resp.raise_for_status()
        resp.encoding = 'utf-8'
        time.sleep(CRAWL_DELAY)
        html = self._parse_delta(resp.text)
        return BeautifulSoup(html or '', 'lxml')

    @staticmethod
    def _parse_delta(text: str) -> str:
        """Delta 응답 (len|type|id|content|) 에서 updatePanel HTML 추출"""
        pos = 0
        while pos < len(text):
            pipe1 = text.find('|', pos)
            if pipe1 == -1:
                break
            try:
                length = int(text[pos:pipe1])
            except ValueError:
                break
            pipe2 = text.find('|', pipe1 + 1)
            seg_type = text[pipe1+1:pipe2]
            pipe3 = text.find('|', pipe2 + 1)
            content = text[pipe3+1:pipe3+1+length]
            pos = pipe3 + 1 + length + 1
            if seg_type == 'updatePanel':
                return content
        return ''

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
            parts = s.split('-')
            if len(parts) == 3:
                return self._safe_int(parts[0]), self._safe_int(parts[1]), self._safe_int(parts[2])
            return 0, 0, 0

        hw, ht, hl = parse_wtl(row.get('홈', '0-0-0'))
        aw, at, al = parse_wtl(row.get('방문', '0-0-0'))
        gb_raw = row.get('게임차', '0')
        gb = 0.0 if gb_raw in ('-', '') else self._safe_float(gb_raw)

        return {
            'rank':   self._safe_int(row.get('순위', '0')),
            'team':   row.get('팀명', ''),
            'games':  self._safe_int(row.get('경기', '0')),
            'wins':   self._safe_int(row.get('승', '0')),
            'losses': self._safe_int(row.get('패', '0')),
            'ties':   self._safe_int(row.get('무', '0')),
            'pct':    self._safe_float(row.get('승률', '0')),
            'gb':     gb,
            'last10': row.get('최근10경기', ''),
            'streak': row.get('연속', ''),
            'home_w': hw, 'home_t': ht, 'home_l': hl,
            'away_w': aw, 'away_t': at, 'away_l': al,
            'season': season,
        }

    def _parse_head_to_head(self, table, season: int) -> list[dict]:
        headers = [th.get_text(strip=True) for th in table.find('thead').find_all('th')]
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
            total_w = total_l = total_t = 0

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
                'team':     team_name,
                'matchups': matchups,
                'total_w':  total_w,
                'total_l':  total_l,
                'total_t':  total_t,
                'season':   season,
            })

        return rows
