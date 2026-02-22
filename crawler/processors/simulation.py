#!/usr/bin/env python3
"""
KBO 몬테카를로 경기 예측 엔진 (Python 레퍼런스 구현)

Log-5 공식으로 타자-투수 매치업 확률을 조정한 뒤,
9이닝 × N회 경기를 시뮬레이션하여 승리 확률과 득점 분포를 반환합니다.

사용법:
  python simulation.py --home LG --away 삼성 --season 2025
  python simulation.py --home KIA --away 한화 --home-pitcher 네일 --away-pitcher 폰세 --n 20000
"""

import json
import random
import argparse
from pathlib import Path
from dataclasses import dataclass

# ── 경로 ────────────────────────────────────────────────────────────────────────
ASSETS = Path(__file__).parent.parent.parent / 'flutter_app' / 'assets' / 'data'


# ── 데이터 클래스 ────────────────────────────────────────────────────────────────

@dataclass
class BatterProfile:
    name: str
    team: str
    hr: float       # 타석당 홈런
    triple: float   # 타석당 3루타
    double: float   # 타석당 2루타
    single: float   # 타석당 1루타
    bb: float       # 타석당 볼넷+사구
    so: float       # 타석당 삼진

    @property
    def out(self) -> float:
        return max(0.0, 1.0 - self.hr - self.triple - self.double
                   - self.single - self.bb - self.so)


@dataclass
class PitcherProfile:
    name: str
    team: str
    hr: float       # 대면타자당 피홈런
    triple: float   # 대면타자당 피3루타
    double: float   # 대면타자당 피2루타
    single: float   # 대면타자당 피1루타
    bb: float       # 대면타자당 볼넷+사구
    so: float       # 대면타자당 삼진


@dataclass
class LeagueAvg:
    hr: float
    triple: float
    double: float
    single: float
    bb: float
    so: float


@dataclass
class SimulationResult:
    home_team: str
    away_team: str
    home_pitcher: str
    away_pitcher: str
    iterations: int
    home_wins: int
    away_wins: int
    ties: int
    home_avg_score: float
    away_avg_score: float
    home_score_dist: dict   # score → probability
    away_score_dist: dict


# ── 핵심 알고리즘 ────────────────────────────────────────────────────────────────

def log5(b: float, p: float, lg: float) -> float:
    """
    Bill James Log-5 공식.
    타자(b), 투수(p), 리그 평균(lg)을 결합해 이 매치업의 기대 확률 반환.
    """
    if lg <= 0 or lg >= 1:
        return b
    num = (b * p) / lg
    den = num + ((1 - b) * (1 - p)) / (1 - lg)
    return (num / den) if den > 0 else 0.0


def matchup_probs(
    batter: BatterProfile,
    pitcher: PitcherProfile,
    league: LeagueAvg,
) -> dict:
    """각 이벤트에 대해 Log-5 조정된 타석 결과 확률 반환."""
    hr     = log5(batter.hr,     pitcher.hr,     league.hr)
    triple = log5(batter.triple, pitcher.triple, league.triple)
    double = log5(batter.double, pitcher.double, league.double)
    single = log5(batter.single, pitcher.single, league.single)
    bb     = log5(batter.bb,     pitcher.bb,     league.bb)
    so     = log5(batter.so,     pitcher.so,     league.so)

    total_event = hr + triple + double + single + bb + so
    out = max(0.0, 1.0 - total_event)
    total = total_event + out
    if total <= 0:
        return {'hr': 0, 'triple': 0, 'double': 0, 'single': 0, 'bb': 0, 'so': 0, 'out': 1}

    return {
        'hr':     hr / total,
        'triple': triple / total,
        'double': double / total,
        'single': single / total,
        'bb':     bb / total,
        'so':     so / total,
        'out':    out / total,
    }


def sample_event(probs: dict) -> str:
    """누적 확률에 기반해 타석 결과 샘플링."""
    r = random.random()
    cum = 0.0
    for ev in ('hr', 'triple', 'double', 'single', 'bb', 'so', 'out'):
        cum += probs.get(ev, 0)
        if r <= cum:
            return ev
    return 'out'


def advance_runners(bases: list, event: str) -> tuple:
    """
    주자 진루 처리.
    bases = [1루있음, 2루있음, 3루있음]
    반환: (새 주자 상태, 득점수)
    """
    r1, r2, r3 = bases
    runs = 0

    if event == 'hr':
        runs = sum([r1, r2, r3]) + 1
        return [False, False, False], runs

    if event == 'triple':
        runs = sum([r1, r2, r3])
        return [False, False, True], runs

    if event == 'double':
        runs += int(r3) + int(r2)
        new_r3 = False
        if r1:
            if random.random() < 0.4:   # 40% 3루 진루
                new_r3 = True
            else:
                runs += 1               # 60% 홈인
        return [False, True, new_r3], runs

    if event == 'single':
        runs += int(r3)
        new_r3 = False
        if r2:
            if random.random() < 0.4:   # 40% 3루 머무름
                new_r3 = True
            else:
                runs += 1               # 60% 홈인
        new_r2 = r1
        return [True, new_r2, new_r3], runs

    if event == 'bb':
        # 강제 진루
        if r1 and r2 and r3:
            return [True, True, True], 1
        new_r3 = r3 or (r1 and r2)
        new_r2 = r2 or r1
        return [True, new_r2, new_r3], 0

    # so, out
    return list(bases), 0


def simulate_half_inning(
    lineup: list,
    pitcher: PitcherProfile,
    league: LeagueAvg,
    start_batter: int,
) -> tuple:
    """한 이닝(공격) 시뮬레이션. 반환: (득점, 다음 타자 인덱스)"""
    outs = 0
    runs = 0
    bases = [False, False, False]
    idx = start_batter
    n = len(lineup)

    while outs < 3:
        batter = lineup[idx % n]
        probs = matchup_probs(batter, pitcher, league)
        event = sample_event(probs)

        if event in ('so', 'out'):
            outs += 1
        else:
            bases, r = advance_runners(bases, event)
            runs += r
        idx += 1

    return runs, idx % n


def simulate_game(
    home_lineup: list,
    away_lineup: list,
    home_pitcher: PitcherProfile,
    away_pitcher: PitcherProfile,
    league: LeagueAvg,
    innings: int = 9,
) -> tuple:
    """9이닝 경기 시뮬레이션. 반환: (홈 득점, 원정 득점)"""
    home_score = away_score = 0
    home_bat = away_bat = 0

    for _ in range(innings):
        # 원정팀 공격 (vs 홈 투수)
        r, away_bat = simulate_half_inning(away_lineup, home_pitcher, league, away_bat)
        away_score += r
        # 홈팀 공격 (vs 원정 투수)
        r, home_bat = simulate_half_inning(home_lineup, away_pitcher, league, home_bat)
        home_score += r

    return home_score, away_score


def run_monte_carlo(
    home_lineup: list,
    away_lineup: list,
    home_pitcher: PitcherProfile,
    away_pitcher: PitcherProfile,
    league: LeagueAvg,
    n: int = 10_000,
) -> SimulationResult:
    """N회 몬테카를로 시뮬레이션 실행."""
    home_wins = away_wins = ties = 0
    home_total = away_total = 0
    home_dist: dict = {}
    away_dist: dict = {}

    for _ in range(n):
        hs, as_ = simulate_game(home_lineup, away_lineup, home_pitcher, away_pitcher, league)
        home_total += hs
        away_total += as_
        home_dist[hs] = home_dist.get(hs, 0) + 1
        away_dist[as_] = away_dist.get(as_, 0) + 1
        if hs > as_:
            home_wins += 1
        elif as_ > hs:
            away_wins += 1
        else:
            ties += 1

    return SimulationResult(
        home_team=home_pitcher.team,
        away_team=away_pitcher.team,
        home_pitcher=home_pitcher.name,
        away_pitcher=away_pitcher.name,
        iterations=n,
        home_wins=home_wins,
        away_wins=away_wins,
        ties=ties,
        home_avg_score=home_total / n,
        away_avg_score=away_total / n,
        home_score_dist={k: v / n for k, v in home_dist.items()},
        away_score_dist={k: v / n for k, v in away_dist.items()},
    )


# ── 데이터 로딩 / 프로파일 생성 ──────────────────────────────────────────────────

def compute_league_avg(hitters: list) -> LeagueAvg:
    """전체 타자 합산으로 리그 평균 이벤트율 계산."""
    total_pa = sum(h['pa'] for h in hitters if h['pa'] > 0)
    if total_pa == 0:
        return LeagueAvg(hr=0.027, triple=0.004, double=0.045, single=0.172, bb=0.113, so=0.168)

    hr     = sum(h.get('hr', 0) for h in hitters) / total_pa
    triple = sum(h.get('triples', 0) for h in hitters) / total_pa
    double = sum(h.get('doubles', 0) for h in hitters) / total_pa
    single = sum(
        max(0, h.get('hits', 0) - h.get('doubles', 0) - h.get('triples', 0) - h.get('hr', 0))
        for h in hitters
    ) / total_pa
    bb = sum(h.get('bb', 0) + h.get('hbp', 0) for h in hitters) / total_pa
    so = sum(h.get('so', 0) for h in hitters) / total_pa

    return LeagueAvg(hr=hr, triple=triple, double=double, single=single, bb=bb, so=so)


def make_batter_profile(h: dict) -> BatterProfile:
    pa = max(h.get('pa', 1), 1)
    hits = h.get('hits', 0)
    dbl  = h.get('doubles', 0)
    tri  = h.get('triples', 0)
    hr   = h.get('hr', 0)
    sng  = max(0, hits - dbl - tri - hr)
    bb   = h.get('bb', 0) + h.get('hbp', 0)
    so   = h.get('so', 0)
    return BatterProfile(
        name=h['name'], team=h['team'],
        hr=hr / pa, triple=tri / pa, double=dbl / pa,
        single=sng / pa, bb=bb / pa, so=so / pa,
    )


def make_pitcher_profile(p: dict, league: LeagueAvg) -> PitcherProfile:
    ip   = p.get('ip', 0)
    hits = p.get('hits', 0)
    hr   = p.get('hr', 0)
    bb   = p.get('bb', 0) + p.get('hbp', 0)
    so   = p.get('so', 0)

    # TBF 추정 (tbf 필드가 0인 경우)
    tbf = p.get('tbf', 0)
    if tbf == 0:
        tbf = max(1, round(3 * ip + hits + bb))

    hr_rate  = hr / tbf
    bb_rate  = bb / tbf
    so_rate  = so / tbf

    # 비홈런 안타를 리그 비율대로 분배
    non_hr_hits = max(0, hits - hr)
    hit_rate    = non_hr_hits / tbf
    lg_hit = league.single + league.double + league.triple
    if lg_hit > 0:
        sng_rate = hit_rate * (league.single / lg_hit)
        dbl_rate = hit_rate * (league.double / lg_hit)
        tri_rate = hit_rate * (league.triple / lg_hit)
    else:
        sng_rate = hit_rate * 0.78
        dbl_rate = hit_rate * 0.20
        tri_rate = hit_rate * 0.02

    return PitcherProfile(
        name=p['name'], team=p['team'],
        hr=hr_rate, triple=tri_rate, double=dbl_rate,
        single=sng_rate, bb=bb_rate, so=so_rate,
    )


def build_lineup(hitters: list, team: str, max_n: int = 9) -> list:
    """팀 타자를 OPS 내림차순으로 정렬해 최대 9명 라인업 구성."""
    team_hitters = [h for h in hitters if h['team'] == team]
    team_hitters.sort(key=lambda h: h.get('ops', 0), reverse=True)
    profiles = [make_batter_profile(h) for h in team_hitters[:max_n]]
    if not profiles:
        raise ValueError(f'타자 데이터 없음: {team}')
    # 9명 미만이면 반복
    while len(profiles) < 9:
        profiles = (profiles * 2)[:9]
    return profiles


def pick_pitcher(pitchers: list, team: str, name: str = '') -> dict:
    """팀 투수 중 지정 이름 또는 최다이닝 투수 반환."""
    team_pitchers = [p for p in pitchers if p['team'] == team]
    if not team_pitchers:
        raise ValueError(f'투수 데이터 없음: {team}')
    if name:
        match = [p for p in team_pitchers if p['name'] == name]
        if match:
            return match[0]
    return max(team_pitchers, key=lambda p: p.get('ip', 0))


# ── CLI ──────────────────────────────────────────────────────────────────────────

def main():
    parser = argparse.ArgumentParser(description='KBO 몬테카를로 경기 예측')
    parser.add_argument('--home', required=True, help='홈팀명 (예: LG)')
    parser.add_argument('--away', required=True, help='원정팀명 (예: 삼성)')
    parser.add_argument('--home-pitcher', default='', help='홈 선발투수 (생략 시 최다이닝)')
    parser.add_argument('--away-pitcher', default='', help='원정 선발투수 (생략 시 최다이닝)')
    parser.add_argument('--season', type=int, default=2025)
    parser.add_argument('--n', type=int, default=10_000, help='시뮬레이션 횟수')
    parser.add_argument('--seed', type=int, default=None)
    args = parser.parse_args()

    if args.seed is not None:
        random.seed(args.seed)

    with open(ASSETS / f'player_hitter_{args.season}.json', encoding='utf-8') as f:
        hitters = json.load(f)
    with open(ASSETS / f'player_pitcher_{args.season}.json', encoding='utf-8') as f:
        pitchers = json.load(f)

    league        = compute_league_avg(hitters)
    home_lineup   = build_lineup(hitters, args.home)
    away_lineup   = build_lineup(hitters, args.away)
    home_p_data   = pick_pitcher(pitchers, args.home, args.home_pitcher)
    away_p_data   = pick_pitcher(pitchers, args.away, args.away_pitcher)
    home_pitcher  = make_pitcher_profile(home_p_data, league)
    away_pitcher  = make_pitcher_profile(away_p_data, league)

    print(f"\n{'='*54}")
    print(f"  {args.home} (홈) vs {args.away} (원정)  |  {args.season}시즌")
    print(f"  홈 선발: {home_pitcher.name}  |  원정 선발: {away_pitcher.name}")
    print(f"  시뮬레이션: {args.n:,}회")
    print(f"{'='*54}")

    result = run_monte_carlo(home_lineup, away_lineup, home_pitcher, away_pitcher, league, n=args.n)

    hw = result.home_wins / args.n * 100
    aw = result.away_wins / args.n * 100
    tw = result.ties / args.n * 100

    print(f"\n  홈팀 승리 확률  : {hw:.1f}%")
    print(f"  원정팀 승리 확률: {aw:.1f}%")
    print(f"  무승부 확률     : {tw:.1f}%")
    print(f"\n  예상 점수: {args.home} {result.home_avg_score:.2f} - {result.away_avg_score:.2f} {args.away}")

    for label, dist in [(f'{args.home} 득점 분포', result.home_score_dist),
                        (f'{args.away} 득점 분포', result.away_score_dist)]:
        print(f"\n  {label} (상위 8):")
        for score, prob in sorted(dist.items(), key=lambda x: -x[1])[:8]:
            bar = '█' * int(prob * 40)
            print(f"    {score:2d}점: {prob*100:5.1f}% {bar}")


if __name__ == '__main__':
    main()
