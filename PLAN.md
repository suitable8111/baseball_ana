# KBO 야구 분석 시스템 - 프로젝트 계획서

> 목표: statiz.co.kr 수준의 KBO 야구 통계 분석 앱 (Flutter + Python)

---

## 1. 프로젝트 개요

| 항목 | 내용 |
|------|------|
| **프로젝트명** | baseball_ana |
| **목표 레퍼런스** | statiz.co.kr |
| **데이터 소스** | koreabaseball.com (공식 KBO 기록실) |
| **프론트엔드** | Flutter (기존 ja/bay 앱 구조 참고) |
| **백엔드/크롤링** | Python (requests + BeautifulSoup) |
| **데이터베이스** | Firebase Firestore + 로컬 캐시 (sqflite) |
| **상태관리** | Provider |
| **차트** | fl_chart |

---

## 2. 데이터 소스 (크롤링 대상)

### 선수 통계
| 구분 | URL |
|------|-----|
| 타자 기본 | https://www.koreabaseball.com/Record/Player/HitterBasic/BasicOld.aspx |
| 투수 기본 | https://www.koreabaseball.com/Record/Player/PitcherBasic/BasicOld.aspx |
| 수비 | https://www.koreabaseball.com/Record/Player/Defense/Basic.aspx |
| 주루 | https://www.koreabaseball.com/Record/Player/Runner/Basic.aspx |

### 팀 통계
| 구분 | URL |
|------|-----|
| 팀 타자 | https://www.koreabaseball.com/Record/Team/Hitter/Basic1.aspx |
| 팀 투수 | https://www.koreabaseball.com/Record/Team/Pitcher/Basic1.aspx |
| 팀 수비 | https://www.koreabaseball.com/Record/Team/Defense/Basic.aspx |
| 팀 주루 | https://www.koreabaseball.com/Record/Team/Runner/Basic.aspx |

### 팀 순위
| 구분 | URL |
|------|-----|
| 팀 순위 + 상대전적 | https://www.koreabaseball.com/Record/TeamRank/TeamRankDaily.aspx |

> 테이블 1: 날짜 기준 순위표 (순위, 팀, 경기, 승/패/무, 승률, 게임차, 최근10경기, 연속, 홈, 방문)
> 테이블 2: 팀간 상대 전적표 (10×10 매트릭스, 각 셀 = 승-패-무)

---

## 3. 핵심 기능 (Features)

### Phase 1 - 기본 기능
- [x] 선수 타자 통계 테이블 (AVG, OBP, SLG, OPS, HR, RBI, H, AB, G 등)
- [x] 선수 투수 통계 테이블 (ERA, WHIP, W, L, IP, K, BB 등)
- [x] 선수 수비 통계 테이블
- [x] 선수 주루 통계 테이블
- [x] 팀 전체 통계 (타자/투수)
- [x] 시즌 연도 필터 (드롭다운)
- [x] 팀 필터
- [x] 컬럼별 정렬
- [x] **팀 순위표** (순위, 승/패/무, 승률, 게임차, 최근10경기, 연속, 홈/방문)
- [x] **팀간 상대 전적표** (10×10 매트릭스)

### Phase 2 - 심화 기능
- [ ] 고급 지표 계산 (OPS+, wOBA, BABIP, FIP, K%, BB%)
- [ ] 선수 상세 프로필 페이지 (연도별 커리어 기록)
- [ ] 리더보드 (지표별 Top N 선수)
- [ ] 바 차트 / 라인 차트 시각화 (fl_chart)
- [ ] 선수 비교 기능 (최대 3명)

### Phase 3 - 부가 기능
- [ ] 검색 기능 (선수명 검색)
- [ ] 즐겨찾기 (선수 북마크)
- [ ] 팀별 로스터 뷰
- [ ] 다크/라이트 테마 전환
- [ ] Firebase Auth (Google 로그인)

---

## 4. 기술 스택

```
baseball_ana/
├── crawler/          ← Python 크롤러 (백엔드)
│   ├── main.py
│   ├── scrapers/
│   │   ├── player_hitter.py
│   │   ├── player_pitcher.py
│   │   ├── player_defense.py
│   │   ├── player_runner.py
│   │   ├── team_hitter.py
│   │   ├── team_pitcher.py
│   │   ├── team_defense.py
│   │   ├── team_runner.py
│   │   └── team_rank.py      ← 팀 순위 + 상대전적 (NEW)
│   ├── processors/
│   │   └── advanced_stats.py  ← OPS, BABIP, FIP 등 계산
│   ├── firebase_uploader.py
│   └── requirements.txt
│
└── flutter_app/      ← Flutter 앱 (프론트엔드)
    ├── lib/
    │   ├── main.dart
    │   ├── models/
    │   │   ├── player_hitter.dart
    │   │   ├── player_pitcher.dart
    │   │   ├── player_defense.dart
    │   │   ├── player_runner.dart
    │   │   ├── team_stats.dart
    │   │   └── team_rank.dart            ← 팀 순위 + 상대전적 (NEW)
    │   ├── providers/
    │   │   ├── auth_provider.dart
    │   │   ├── hitter_provider.dart
    │   │   ├── pitcher_provider.dart
    │   │   ├── team_provider.dart
    │   │   ├── team_rank_provider.dart   ← 팀 순위 (NEW)
    │   │   ├── filter_provider.dart
    │   │   └── theme_provider.dart
    │   ├── screens/
    │   │   ├── home_screen.dart          ← 메인 (팀 순위 요약)
    │   │   ├── player_hitter_screen.dart ← 선수 타자 통계
    │   │   ├── player_pitcher_screen.dart
    │   │   ├── player_defense_screen.dart
    │   │   ├── player_runner_screen.dart
    │   │   ├── team_stats_screen.dart    ← 팀 통계
    │   │   ├── team_rank_screen.dart     ← 팀 순위 + 상대전적 (NEW)
    │   │   ├── player_detail_screen.dart ← 선수 상세/커리어
    │   │   ├── leaderboard_screen.dart   ← 지표별 Top N
    │   │   ├── compare_screen.dart       ← 선수 비교
    │   │   └── auth_screen.dart
    │   ├── services/
    │   │   ├── firebase_service.dart
    │   │   └── stats_calculator.dart    ← 고급 지표 계산 (Dart)
    │   └── widgets/
    │       ├── stats_table.dart          ← 공통 통계 테이블 위젯
    │       ├── sortable_column.dart
    │       ├── player_card.dart
    │       ├── season_filter.dart
    │       ├── team_filter.dart
    │       └── stats_chart.dart          ← fl_chart 래퍼
    └── pubspec.yaml
```

---

## 5. 주요 통계 지표 정의

### 타자
| 지표 | 공식 | 설명 |
|------|------|------|
| AVG | H / AB | 타율 |
| OBP | (H+BB+HBP) / (AB+BB+HBP+SF) | 출루율 |
| SLG | (1B + 2×2B + 3×3B + 4×HR) / AB | 장타율 |
| OPS | OBP + SLG | 출루율+장타율 |
| BABIP | (H-HR) / (AB-SO-HR+SF) | 인플레이 타율 |
| ISO | SLG - AVG | 순수 장타력 |
| BB% | BB / PA | 볼넷 비율 |
| K% | SO / PA | 삼진 비율 |
| wOBA | 가중치 출루율 (Phase 2) | - |

### 투수
| 지표 | 공식 | 설명 |
|------|------|------|
| ERA | 9 × ER / IP | 평균자책점 |
| WHIP | (BB+H) / IP | 이닝당 출루 허용 |
| K/9 | 9 × K / IP | 9이닝당 삼진 |
| BB/9 | 9 × BB / IP | 9이닝당 볼넷 |
| HR/9 | 9 × HR / IP | 9이닝당 홈런 |
| K/BB | K / BB | 삼진/볼넷 비율 |
| FIP | (13×HR + 3×BB - 2×K) / IP + 상수 | 수비무관 평균자책 |

---

## 6. 개발 일정 (Phase별)

### Phase 1 - 크롤러 + 기본 UI (2주)
```
Week 1: Python 크롤러 개발
  - requests + BeautifulSoup 설정
  - 8개 URL 크롤링 모듈 작성
  - Firebase Firestore 업로드
  - 스케줄러 (cron / Cloud Functions)

Week 2: Flutter 기본 UI
  - 프로젝트 세팅 (pubspec.yaml)
  - Firebase 연동
  - 타자/투수 통계 테이블 구현
  - 시즌/팀 필터
```

### Phase 2 - 심화 분석 (2주)
```
Week 3: 고급 지표 + 차트
  - 고급 지표 계산 (BABIP, FIP, wOBA)
  - fl_chart 시각화 (바 차트, 라인 차트)
  - 리더보드 화면

Week 4: 선수 상세 + 비교
  - 선수 상세 프로필 (커리어 전체)
  - 선수 비교 기능
  - 검색 기능
```

### Phase 3 - 완성도 (1주)
```
Week 5: 마무리
  - 다크/라이트 테마
  - 즐겨찾기
  - 성능 최적화 (페이지네이션, 캐싱)
  - 앱 아이콘 / UI polish
```

---

## 7. 기존 프로젝트 참고 사항

### japanstudy (ja) 에서 참고할 것
- Provider 패턴 구조 (MultiProvider, ChangeNotifierProxyProvider)
- Firebase Auth + Firestore 연동 방식
- ThemeProvider (다크/라이트 모드)
- stats_screen.dart → 통계 화면 레이아웃 참고
- ranking_screen.dart → 리더보드 UI 참고

### baby_food_app (bay) 에서 참고할 것
- sqflite 로컬 DB 캐싱 (오프라인 지원)
- go_router 라우팅
- table_calendar → 날짜별 기록 (기록실 기능 시 참고)
- fl_chart 차트 사용 패턴

---

## 8. Python 크롤러 주요 사항

```python
# 크롤링 전략
# koreabaseball.com은 ASP.NET WebForms 기반
# ViewState 처리 필요 → requests.Session() + POST 방식
# 또는 Selenium으로 브라우저 렌더링

# 파라미터
# - leId: 1 (정규시즌)
# - srId: 0 (전체)
# - teamId: 팀별 필터
# - seasonId: 연도 (2024, 2023, ...)
# - pageIndex: 페이지 번호

# 크롤링 주기
# - 시즌 중: 1일 1회 (cron)
# - 시즌 외: 수동 업데이트
```

---

## 9. Firebase Firestore 구조

```
firestore/
├── seasons/
│   └── {year}/              ← 2024, 2023, ...
│       ├── player_hitter/
│       │   └── {playerId}/  ← 선수별 문서
│       ├── player_pitcher/
│       ├── player_defense/
│       ├── player_runner/
│       ├── team_hitter/
│       │   └── {teamId}/
│       ├── team_pitcher/
│       ├── team_defense/
│       ├── team_runner/
│       ├── team_standings/  ← 팀 순위표 (NEW)
│       └── team_h2h/        ← 상대 전적 (NEW)
└── metadata/
    └── last_updated         ← 최종 크롤링 시각
```

---

## 10. 우선순위 To-Do

1. **[완료]** Python 크롤러 환경 세팅 (`crawler/requirements.txt`)
2. **[완료]** Flutter 프로젝트 생성 (`flutter create flutter_app`)
3. **[완료]** 타자/투수/수비/주루 크롤러 + Flutter 통계 테이블 표시
4. **[완료]** 팀 통계 크롤러 + Flutter 팀 통계 화면
5. **[완료]** 팀 순위 + 상대전적 크롤러 + Flutter 순위 화면
6. **[다음]** 고급 지표 + 차트 (Phase 2)

---

*계획서 작성일: 2026-02-21*
