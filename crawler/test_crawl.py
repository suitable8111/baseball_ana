"""
크롤러 동작 테스트 스크립트
실행: python test_crawl.py
"""

import time
import re
import requests
from bs4 import BeautifulSoup

URL = 'https://www.koreabaseball.com/Record/Player/HitterBasic/BasicOld.aspx'

SEASON_KEY = 'ctl00$ctl00$ctl00$cphContents$cphContents$cphContents$ddlSeason$ddlSeason'
SERIES_KEY = 'ctl00$ctl00$ctl00$cphContents$cphContents$cphContents$ddlSeries$ddlSeries'
TEAM_KEY   = 'ctl00$ctl00$ctl00$cphContents$cphContents$cphContents$ddlTeam$ddlTeam'
POS_KEY    = 'ctl00$ctl00$ctl00$cphContents$cphContents$cphContents$ddlPos$ddlPos'
PAGE_KEY   = 'ctl00$ctl00$ctl00$cphContents$cphContents$cphContents$hfPage'
ORDER_COL  = 'ctl00$ctl00$ctl00$cphContents$cphContents$cphContents$hfOrderByCol'
ORDER_BY   = 'ctl00$ctl00$ctl00$cphContents$cphContents$cphContents$hfOrderBy'
PAGER_BASE = 'ctl00$ctl00$ctl00$cphContents$cphContents$cphContents$ucPager$'


def get_headers(session, url):
    """GET 요청 후 ViewState + 기본 필드 반환"""
    r = session.get(url, timeout=15)
    r.encoding = 'utf-8'
    soup = BeautifulSoup(r.text, 'lxml')
    return soup


def get_viewstate(soup):
    def val(id_):
        tag = soup.find('input', {'id': id_})
        return tag['value'] if tag else ''
    return {
        '__EVENTTARGET': '',
        '__EVENTARGUMENT': '',
        '__LASTFOCUS': '',
        '__VIEWSTATE': val('__VIEWSTATE'),
        '__VIEWSTATEGENERATOR': val('__VIEWSTATEGENERATOR'),
        '__EVENTVALIDATION': val('__EVENTVALIDATION'),
    }


def base_post_data(season=2024):
    return {
        SEASON_KEY: str(season),
        SERIES_KEY: '0',
        TEAM_KEY: '',
        POS_KEY: '',
        PAGE_KEY: '1',
        ORDER_COL: 'HRA',
        ORDER_BY: 'DESC',
    }


def parse_table(soup):
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


def get_page_buttons(soup):
    """페이지 버튼 목록 반환: [(번호, target), ...]"""
    buttons = []
    for a in soup.find_all('a', href=True):
        m = re.search(r"__doPostBack\('([^']+)'", a['href'])
        if m and 'ucPager' in m.group(1):
            buttons.append((a.get_text(strip=True), m.group(1)))
    return buttons


def post_page(session, soup, event_target='', extra=None):
    vs = get_viewstate(soup)
    vs['__EVENTTARGET'] = event_target
    data = {**vs, **(extra or {})}
    time.sleep(1.5)
    r = session.post(URL, data=data, timeout=15)
    r.encoding = 'utf-8'
    return BeautifulSoup(r.text, 'lxml')


def crawl_season(season=2024):
    session = requests.Session()
    session.headers.update({'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)'})

    print(f'\n=== {season}시즌 타자 기록 크롤링 ===')

    # 1. 초기 GET
    soup = get_headers(session, URL)

    # 2. 시즌 선택 POST
    base = base_post_data(season)
    soup = post_page(session, soup, extra=base)
    headers, rows = parse_table(soup)
    buttons = get_page_buttons(soup)

    print(f'컬럼: {headers}')
    print(f'1페이지: {len(rows)}명')
    print(f'페이지 버튼: {[(b[0], b[1].split("$")[-1]) for b in buttons]}')

    all_rows = list(rows)

    # 3. 나머지 페이지 수집 (btnNo2, btnNo3 ... 숫자 버튼만)
    visited = {1}
    current_soup = soup

    while True:
        buttons = get_page_buttons(current_soup)
        # 숫자 페이지 버튼 중 아직 안 방문한 것만
        next_buttons = [
            (int(label), target)
            for label, target in buttons
            if label.isdigit() and int(label) not in visited
        ]
        if not next_buttons:
            break

        page_num, target = next_buttons[0]
        visited.add(page_num)
        page_base = {**base, PAGE_KEY: str(page_num)}

        print(f'\n페이지 {page_num} 요청 중...')
        current_soup = post_page(session, current_soup, event_target=target, extra=page_base)
        _, page_rows = parse_table(current_soup)
        print(f'  → {len(page_rows)}명')
        if not page_rows:
            break
        all_rows.extend(page_rows)

    print(f'\n총 수집: {len(all_rows)}명')
    if all_rows:
        print('\n[샘플 - 상위 5명]')
        for r in all_rows[:5]:
            print(f"  {r.get('순위',''):>3}. {r.get('선수명',''):6} {r.get('팀명',''):4} "
                  f"AVG={r.get('AVG','')}")

    return headers, all_rows


if __name__ == '__main__':
    headers, data = crawl_season(2024)
    print(f'\n완료: {len(data)}건')
