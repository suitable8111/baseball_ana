"""
KBO 공식 사이트 크롤러 베이스 클래스
koreabaseball.com은 ASP.NET WebForms 기반
핵심: 응답 페이지의 모든 hidden input을 다음 POST에 포함해야 페이지 전환 작동
"""

import re
import time
import os
import requests
from bs4 import BeautifulSoup
from dotenv import load_dotenv

load_dotenv()

CRAWL_DELAY = float(os.getenv('CRAWL_DELAY', 1.5))

HEADERS = {
    'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) '
                  'AppleWebKit/537.36 (KHTML, like Gecko) '
                  'Chrome/120.0.0.0 Safari/537.36',
    'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
    'Accept-Language': 'ko-KR,ko;q=0.9,en;q=0.8',
    'Referer': 'https://www.koreabaseball.com/',
}

# 팀 코드 매핑 (POST value → 팀명)
TEAM_CODE_MAP = {
    'LG': 'LG', 'HH': '한화', 'SK': 'SSG', 'SS': '삼성',
    'NC': 'NC', 'KT': 'KT', 'LT': '롯데', 'HT': 'KIA',
    'OB': '두산', 'WO': '키움',
}


class BaseScraper:
    """KBO 사이트 크롤러 공통 베이스 클래스"""

    URL = ''  # 서브클래스에서 정의

    # 폼 필드 키 (실제 name 어트리뷰트)
    KEY_SEASON  = 'ctl00$ctl00$ctl00$cphContents$cphContents$cphContents$ddlSeason$ddlSeason'
    KEY_SERIES  = 'ctl00$ctl00$ctl00$cphContents$cphContents$cphContents$ddlSeries$ddlSeries'
    KEY_TEAM    = 'ctl00$ctl00$ctl00$cphContents$cphContents$cphContents$ddlTeam$ddlTeam'
    KEY_POS     = 'ctl00$ctl00$ctl00$cphContents$cphContents$cphContents$ddlPos$ddlPos'
    KEY_PAGE    = 'ctl00$ctl00$ctl00$cphContents$cphContents$cphContents$hfPage'
    PAGER_BASE  = 'ctl00$ctl00$ctl00$cphContents$cphContents$cphContents$ucPager$'

    def __init__(self):
        self.session = requests.Session()
        self.session.headers.update(HEADERS)

    def _fetch(self, url: str, post_data: dict = None) -> BeautifulSoup:
        """GET 또는 POST 요청 후 BeautifulSoup 반환"""
        if post_data is None:
            response = self.session.get(url, timeout=15)
        else:
            response = self.session.post(url, data=post_data, timeout=15)
        response.raise_for_status()
        response.encoding = 'utf-8'
        time.sleep(CRAWL_DELAY)
        return BeautifulSoup(response.text, 'lxml')

    def _get_all_hidden(self, soup: BeautifulSoup) -> dict:
        """페이지 내 모든 hidden input의 name/value를 dict로 반환
        (다음 POST에 그대로 포함해야 ASP.NET 상태 유지)"""
        data = {}
        for inp in soup.find_all('input'):
            name = inp.get('name', '')
            if name:
                data[name] = inp.get('value', '') or ''
        return data

    def _get_page_buttons(self, soup: BeautifulSoup) -> list[tuple[int, str]]:
        """숫자 페이지 버튼 목록: [(페이지번호, __EVENTTARGET), ...]"""
        buttons = []
        for a in soup.find_all('a', href=True):
            m = re.search(r"__doPostBack\('([^']+)'", a['href'])
            if m and 'ucPager' in m.group(1):
                label = a.get_text(strip=True)
                if label.isdigit():
                    buttons.append((int(label), m.group(1)))
        return buttons

    def _parse_table(self, soup: BeautifulSoup) -> tuple[list[str], list[dict]]:
        """tData01 테이블 파싱 → (헤더, 데이터 행 list of dict)"""
        table = soup.find('table', class_='tData01')
        if not table:
            return [], []

        headers = [th.get_text(strip=True) for th in table.find('thead').find_all('th')]
        rows = []
        tbody = table.find('tbody')
        if tbody:
            for tr in tbody.find_all('tr'):
                cells = [td.get_text(strip=True) for td in tr.find_all('td')]
                if cells:
                    rows.append(dict(zip(headers, cells)))
        return headers, rows

    def _crawl_all_pages(self, season: int, team: str = '') -> list[dict]:
        """시즌/팀 기준 전체 페이지 크롤링"""
        # 1. GET으로 초기 hidden 필드 취득
        soup = self._fetch(self.URL)
        hidden = self._get_all_hidden(soup)

        # 2. 시즌 선택 POST
        hidden['__EVENTTARGET'] = ''
        hidden['__EVENTARGUMENT'] = ''
        hidden[self.KEY_SEASON] = str(season)
        hidden[self.KEY_SERIES] = '0'
        hidden[self.KEY_TEAM]   = team
        soup = self._fetch(self.URL, hidden)

        # 3. 전체 페이지 수집
        all_rows: list[dict] = []
        visited = {1}

        while True:
            _, rows = self._parse_table(soup)
            all_rows.extend(rows)
            print(f'  → 페이지 {max(visited)}: {len(rows)}행')

            # 다음 미방문 페이지 탐색
            buttons = self._get_page_buttons(soup)
            next_pages = [(p, t) for p, t in buttons if p not in visited]
            if not next_pages:
                break

            next_page, target = next_pages[0]
            visited.add(next_page)

            # 응답 페이지의 hidden 필드를 그대로 사용 (핵심!)
            hidden = self._get_all_hidden(soup)
            hidden['__EVENTTARGET'] = target
            hidden['__EVENTARGUMENT'] = ''
            hidden[self.KEY_PAGE] = str(next_page)
            soup = self._fetch(self.URL, hidden)

        return all_rows

    def _safe_int(self, val: str) -> int:
        try:
            return int(str(val).replace(',', '').strip())
        except (ValueError, AttributeError):
            return 0

    def _safe_float(self, val: str) -> float:
        try:
            return float(str(val).replace(',', '').strip())
        except (ValueError, AttributeError):
            return 0.0

    def scrape(self, season: int) -> list[dict]:
        """서브클래스에서 구현"""
        raise NotImplementedError
