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

### Phase 2 - 승부 예측
- 1. 알고리즘 설계: 몬테카를로 시뮬레이션 (Monte Carlo)
가장 권장하는 방식은 몬테카를로 시뮬레이션입니다. 각 타석의 결과(안타, 홈런, 삼진 등)를 확률적으로 계산하여 수만 번 반복 실행해 보는 방식이죠.
데이터 가공: JSON 데이터를 기반으로 선수별 '이벤트 확률' 테이블을 만듭니다.
예: 타자 A의 출루율(OBP), 장타율(SLG) / 투수 B의 피안타율, 피홈런율.
Log-5 공식 활용: 빌 제임스가 고안한 공식으로, 특정 투수와 타자가 만났을 때의 결과 확률을 계산합니다.
예: (타자 평균 * 투수 평균 / 리그 평균) / ... 식의 계산을 통해 개별 매치업의 확률을 도출합니다.
시뮬레이션 로직: 1회부터 9회까지 각 타석의 결과를 난수(Random Number)로 결정하고 주자 상황을 업데이트하는 엔진을 Python으로 작성합니다.
단순히 승패 기록만 있는 것이 아니라, 각 타석에서 발생할 수 있는 세부 지표들이 포함되어 있어 정교한 확률 모델을 만들 수 있습니다. 데이터가 시뮬레이션에 어떻게 활용될 수 있는지 구체적인 분석 결과를 알려드립니다.1. 시뮬레이션 가능 여부 및 데이터 활용 분석가진 JSON 데이터의 필드들을 시뮬레이션 알고리즘에 다음과 같이 매칭할 수 있습니다.타자 데이터 (player_hitter_2025.json): 각 타석(PA)에서 발생할 확률을 계산하는 핵심 소스입니다.이벤트 확률 계산: pa(타석)를 분모로 두고 hits, doubles, triples, hr, bb, hbp, so 등을 나누면 해당 타자가 안타, 홈런, 볼넷 등을 기록할 기초 확률이 나옵니다.세부 지표 활용: babip(인플레이 타구 안타율)나 k_pct(삼진율) 등을 사용하여 투수와의 상성에 따른 확률 조정이 가능합니다.투수 데이터 (player_pitcher_2025.json): 타자의 확률을 억제하거나 증폭시키는 '조정자' 역할을 합니다.억제력 계산: 투수의 k9(9이닝당 삼진), bb9(9이닝당 볼넷), hr9(9이닝당 홈런)를 통해 타자의 기본 확률을 해당 투수에 맞게 보정합니다.주루 및 수비 데이터 (player_runner, player_defense): 경기의 디테일을 완성합니다.주루: sb_pct(도루 성공률)를 통해 주자가 나갔을 때 도루 시도 및 성공 여부를 시뮬레이션합니다.수비: errors 데이터를 활용해 평범한 타구가 실책으로 이어져 주자가 추가 진루하는 상황을 구현할 수 있습니다.2. 알고리즘 적용 가이드 (Log-5 공식 추천)단순히 타자 확률만 쓰지 않고, Log-5 공식을 적용하면 훨씬 현실적인 시뮬레이션이 가능합니다.$$P = \frac{\frac{(\text{타자 확률} \times \text{투수 확률})}{\text{리그 평균 확률}}}{\frac{(\text{타자 확률} \times \text{투수 확률})}{\text{리그 평균 확률}} + \frac{((1-\text{타자 확률}) \times (1-\text{투수 확률}))}{(1-\text{리그 평균 확률})}}$$이 공식을 사용하면 "리그 평균보다 홈런을 잘 치는 타자"가 "리그 평균보다 홈런을 안 맞는 투수"를 만났을 때의 기대 확률을 수학적으로 도출할 수 있습니다.
먼저 Python 코드가 JSON 데이터를 읽어 현재 상황의 **기대 득점(RE24)**이나 **승리 확률(WPA)**의 기초가 되는 수치를 계산합니다.
입력: 현재 이닝, 점수 차, 주자 상황, 현재 타자/투수 데이터
출력: 해당 타석에서 안타/홈런/아웃이 발생할 확률 (앞서 만든 Log-5 활용)
AI 프롬프트용 요약: 계산된 확률과 선수들의 오늘 컨디션(최근 전적)을 텍스트로 요약합니다.

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
