"""
KBO 승부 예측 엔진
Flutter SimulationService + AccuracyProvider의 알고리즘을 Python으로 포팅

알고리즘:
  1. 몬테카를로 시뮬레이션 (Log-5 타석 확률 기반, 10,000회)
  2. Log-5 팀 품질 (피타고라스 70% + 최근10경기 30%) × 홈/원정 편향
  3. FIP 기반 선발 투수 조정 (1점 차 ≈ 4%)
  4. 상대 전적 미세 조정 (±5% 이내)
  5. 시뮬 신호 20% 블렌드
"""

import re
import random
from typing import Optional

from data_loader import (
    get_hitters, get_pitchers, get_standings,
    get_h2h, get_team_hitters, get_team_pitchers,
)

# ── 리그 평균 ────────────────────────────────────────────────────────────────

def _league_avg(hitters: list[dict]) -> dict:
    total_pa = sum(h.get("pa", 0) for h in hitters)
    if total_pa <= 0:
        return dict(hr=0.027, triple=0.004, dbl=0.045, single=0.172, bb=0.113, so=0.168)
    hr = triple = dbl = single = bb = so = 0.0
    for h in hitters:
        pa = h.get("pa", 0)
        hits = float(h.get("hits", 0))
        d = float(h.get("doubles", 0))
        t = float(h.get("triples", 0))
        h2 = float(h.get("hr", 0))
        hr += h2
        triple += t
        dbl += d
        single += max(0.0, hits - d - t - h2)
        bb += float(h.get("bb", 0)) + float(h.get("hbp", 0))
        so += float(h.get("so", 0))
    return dict(
        hr=hr / total_pa, triple=triple / total_pa, dbl=dbl / total_pa,
        single=single / total_pa, bb=bb / total_pa, so=so / total_pa,
    )


# ── 선수 프로파일 ─────────────────────────────────────────────────────────────

def _batter_profile(h: dict) -> dict:
    pa = float(h.get("pa", 0))
    if pa <= 0:
        return dict(name=h.get("name", ""), team=h.get("team", ""),
                    hr=0.0, triple=0.0, dbl=0.0, single=0.0, bb=0.0, so=0.0)
    hits = float(h.get("hits", 0))
    d = float(h.get("doubles", 0))
    t = float(h.get("triples", 0))
    h2 = float(h.get("hr", 0))
    sng = max(0.0, hits - d - t - h2)
    bb = float(h.get("bb", 0)) + float(h.get("hbp", 0))
    so = float(h.get("so", 0))
    return dict(
        name=h.get("name", ""), team=h.get("team", ""),
        hr=h2 / pa, triple=t / pa, dbl=d / pa,
        single=sng / pa, bb=bb / pa, so=so / pa,
    )


def _pitcher_profile(p: dict, league: dict) -> dict:
    ip = float(p.get("ip", 0))
    hits = float(p.get("hits", 0))
    hr = float(p.get("hr", 0))
    bb = float(p.get("bb", 0)) + float(p.get("hbp", 0))
    so = float(p.get("so", 0))

    tbf = float(p.get("tbf", 0))
    if tbf <= 0:
        tbf = max(1.0, 3 * ip + hits + bb)

    hr_r = hr / tbf
    bb_r = bb / tbf
    so_r = so / tbf
    non_hr = max(0.0, hits - hr)
    hit_r = non_hr / tbf
    lg_hit = league["single"] + league["dbl"] + league["triple"]
    if lg_hit > 0:
        sng_r = hit_r * (league["single"] / lg_hit)
        dbl_r = hit_r * (league["dbl"] / lg_hit)
        tri_r = hit_r * (league["triple"] / lg_hit)
    else:
        sng_r, dbl_r, tri_r = hit_r * 0.78, hit_r * 0.20, hit_r * 0.02

    return dict(
        name=p.get("name", ""), team=p.get("team", ""),
        hr=hr_r, triple=tri_r, dbl=dbl_r, single=sng_r, bb=bb_r, so=so_r,
    )


# ── Monte Carlo 시뮬레이션 ────────────────────────────────────────────────────

def _log5(b: float, p: float, lg: float) -> float:
    if lg <= 0 or lg >= 1:
        return b
    num = (b * p) / lg
    den = num + ((1 - b) * (1 - p)) / (1 - lg)
    return num / den if den > 0 else 0.0


def _matchup_probs(batter: dict, pitcher: dict, league: dict) -> list[float]:
    hr     = _log5(batter["hr"],     pitcher["hr"],     league["hr"])
    triple = _log5(batter["triple"], pitcher["triple"], league["triple"])
    dbl    = _log5(batter["dbl"],    pitcher["dbl"],    league["dbl"])
    single = _log5(batter["single"], pitcher["single"], league["single"])
    bb     = _log5(batter["bb"],     pitcher["bb"],     league["bb"])
    so     = _log5(batter["so"],     pitcher["so"],     league["so"])
    total_e = hr + triple + dbl + single + bb + so
    out = max(0.0, 1.0 - total_e)
    total = total_e + out
    if total <= 0:
        return [0, 0, 0, 0, 0, 0, 1.0]
    return [hr/total, triple/total, dbl/total, single/total, bb/total, so/total, out/total]


def _sample(probs: list[float], rng: random.Random) -> int:
    r, cum = rng.random(), 0.0
    for i, p in enumerate(probs):
        cum += p
        if r <= cum:
            return i
    return 6


def _advance(bases: list[bool], event: int, rng: random.Random) -> tuple[list[bool], int]:
    r1, r2, r3 = bases
    runs = 0
    if event == 0:   # HR
        runs = sum([r1, r2, r3]) + 1
        return [False, False, False], runs
    if event == 1:   # 3B
        runs = sum([r1, r2, r3])
        return [False, False, True], runs
    if event == 2:   # 2B
        runs += int(r3) + int(r2)
        new_r3 = r1 and rng.random() < 0.4
        runs += int(r1 and not new_r3)
        return [False, True, new_r3], runs
    if event == 3:   # 1B
        runs += int(r3)
        new_r3 = r2 and rng.random() < 0.4
        runs += int(r2 and not new_r3)
        return [True, r1, new_r3], runs
    if event == 4:   # BB/HBP
        if r1 and r2 and r3:
            return [True, True, True], 1
        return [True, r2 or r1, r3 or (r1 and r2)], 0
    return bases, 0  # SO / out


def _half_inning(lineup, pitcher, league, start, rng) -> tuple[int, int]:
    outs = runs = 0
    bases = [False, False, False]
    idx = start
    n = len(lineup)
    while outs < 3:
        probs = _matchup_probs(lineup[idx % n], pitcher, league)
        e = _sample(probs, rng)
        if e >= 5:
            outs += 1
        else:
            bases, scored = _advance(bases, e, rng)
            runs += scored
        idx += 1
    return runs, idx % n


def _game(home_lu, away_lu, home_p, away_p, league, rng) -> tuple[int, int]:
    hs = aws = hb = ab = 0
    for _ in range(9):
        r, ab = _half_inning(away_lu, home_p, league, ab, rng)
        aws += r
        r, hb = _half_inning(home_lu, away_p, league, hb, rng)
        hs += r
    return hs, aws


def run_simulation(home_lineup, away_lineup, home_pitcher, away_pitcher,
                   league, iterations: int = 10_000) -> dict:
    rng = random.Random()
    hw = aw = ties = 0
    ht = at = 0.0
    for _ in range(iterations):
        hs, aws = _game(home_lineup, away_lineup, home_pitcher, away_pitcher, league, rng)
        ht += hs; at += aws
        if hs > aws:   hw += 1
        elif aws > hs: aw += 1
        else:          ties += 1
    return dict(
        home_win_prob=hw / iterations,
        away_win_prob=aw / iterations,
        home_avg_score=ht / iterations,
        away_avg_score=at / iterations,
    )


# ── 팀 품질 / Log-5 조정 ─────────────────────────────────────────────────────

def _pythagorean(code: str, rs_map: dict, ra_map: dict) -> float:
    rs = float(rs_map.get(code, 0))
    ra = float(ra_map.get(code, 0))
    if rs <= 0 or ra <= 0:
        return 0.5
    return rs * rs / (rs * rs + ra * ra)


def _last10(code: str, standings: list[dict]) -> float:
    for s in standings:
        if s.get("team") == code:
            text = s.get("last10", "")
            wm = re.search(r"(\d+)승", text)
            lm = re.search(r"(\d+)패", text)
            w = int(wm.group(1)) if wm else 0
            l = int(lm.group(1)) if lm else 0
            return w / (w + l) if w + l > 0 else 0.5
    return 0.5


def _split_bias(st: Optional[dict], is_home: bool) -> float:
    if st is None:
        return 1.08 if is_home else 0.92
    total = st.get("wins", 0) + st.get("losses", 0)
    if total == 0:
        return 1.08 if is_home else 0.92
    overall = st["wins"] / total
    sw = st.get("home_w", 0) if is_home else st.get("away_w", 0)
    sg = (st.get("home_w", 0) + st.get("home_l", 0)) if is_home else (st.get("away_w", 0) + st.get("away_l", 0))
    if sg == 0:
        return 1.08 if is_home else 0.92
    return (sw / sg) / max(0.01, min(0.99, overall))


def _log5_team_prob(home_code: str, away_code: str,
                    standings: list[dict], rs_map: dict, ra_map: dict) -> float:
    home_st = next((s for s in standings if s.get("team") == home_code), None)
    away_st = next((s for s in standings if s.get("team") == away_code), None)

    hq = 0.70 * _pythagorean(home_code, rs_map, ra_map) + 0.30 * _last10(home_code, standings)
    aq = 0.70 * _pythagorean(away_code, rs_map, ra_map) + 0.30 * _last10(away_code, standings)

    pA = max(0.1, min(0.9, hq * _split_bias(home_st, True)))
    pB = max(0.1, min(0.9, aq * _split_bias(away_st, False)))

    num = pA * (1 - pB)
    den = num + pB * (1 - pA)
    return num / den if den > 0 else 0.54


def _h2h_adj(home_code: str, away_code: str, h2h_data: list[dict]) -> float:
    home_h2h = next((h for h in h2h_data if h.get("team") == home_code), None)
    if home_h2h is None:
        return 0.0
    rec = (home_h2h.get("matchups") or {}).get(away_code)
    if not rec:
        return 0.0
    w, l, t = rec.get("w", 0), rec.get("l", 0), rec.get("t", 0)
    total = w + l + t
    if total < 5:
        return 0.0
    return max(-0.05, min(0.05, w / total - 0.5))


def _calc_fip(p: dict) -> float:
    ip = float(p.get("ip", 0))
    if ip <= 0:
        return 4.20
    hr = float(p.get("hr", 0))
    bb = float(p.get("bb", 0)) + float(p.get("hbp", 0))
    so = float(p.get("so", 0))
    return (13 * hr + 3 * bb - 2 * so) / ip + 3.20


# ── 메인 예측 함수 ────────────────────────────────────────────────────────────

def predict_game(home_team_name: str, away_team_name: str,
                 home_starter_name: str = "", away_starter_name: str = "",
                 season: int = 2025) -> dict:
    """
    home_team_name / away_team_name: Naver API 전체 팀명 (예: "NC 다이노스")
    반환: 예측 결과 dict
    """
    home_code = home_team_name.split()[0]
    away_code = away_team_name.split()[0]

    hitters  = get_hitters(season)
    pitchers = get_pitchers(season)
    standings = get_standings(season)
    h2h_data  = get_h2h(season)
    t_hitters = get_team_hitters(season)
    t_pitchers = get_team_pitchers(season)

    league = _league_avg(hitters)

    # 라인업: 팀별 OPS 상위 9명
    def build_lineup(code: str) -> list[dict]:
        team_h = sorted(
            [h for h in hitters if h.get("team") == code],
            key=lambda h: h.get("ops", 0), reverse=True
        )
        lineup = [_batter_profile(h) for h in team_h[:9]]
        if not lineup:
            lineup = [_batter_profile(h) for h in hitters[:9]]
        return lineup

    # 선발 투수 탐색: 이름+팀 → 이름만 → 팀 최다이닝 순
    def find_pitcher(name: str, code: str) -> Optional[dict]:
        if name:
            for p in pitchers:
                if p.get("name") == name and p.get("team") == code:
                    return p
            for p in pitchers:
                if p.get("name") == name:
                    return p
        by_ip = sorted(
            [p for p in pitchers if p.get("team") == code],
            key=lambda p: p.get("ip", 0), reverse=True
        )
        return by_ip[0] if by_ip else None

    home_p_data = find_pitcher(home_starter_name, home_code)
    away_p_data = find_pitcher(away_starter_name, away_code)

    if not home_p_data or not away_p_data:
        raise ValueError(f"투수 데이터 없음 — 홈:{home_code}, 원정:{away_code}")

    home_lineup = build_lineup(home_code)
    away_lineup = build_lineup(away_code)
    home_pitcher = _pitcher_profile(home_p_data, league)
    away_pitcher = _pitcher_profile(away_p_data, league)

    # 몬테카를로 시뮬레이션 (CPU-bound, bot에서 executor로 실행됨)
    sim = run_simulation(home_lineup, away_lineup, home_pitcher, away_pitcher, league)

    # 팀 득점/실점 맵
    rs_map = {h.get("team", ""): h.get("runs", 0) for h in t_hitters}
    ra_map = {p.get("team", ""): p.get("er", 0)   for p in t_pitchers}

    # 최종 확률 조합
    log5_base = _log5_team_prob(home_code, away_code, standings, rs_map, ra_map)
    fip_diff  = max(-3.0, min(3.0, _calc_fip(away_p_data) - _calc_fip(home_p_data)))
    fip_adj   = fip_diff * 0.04
    h2h       = _h2h_adj(home_code, away_code, h2h_data)
    sim_sig   = (sim["home_win_prob"] - 0.5) * 0.20

    adj_home = max(0.1, min(0.9, log5_base + fip_adj + h2h + sim_sig))

    return dict(
        home_team=home_team_name,
        away_team=away_team_name,
        home_starter=home_p_data.get("name", "미정"),
        away_starter=away_p_data.get("name", "미정"),
        home_win_prob=adj_home,
        away_win_prob=1.0 - adj_home,
        home_avg_score=sim["home_avg_score"],
        away_avg_score=sim["away_avg_score"],
        home_fip=_calc_fip(home_p_data),
        away_fip=_calc_fip(away_p_data),
    )
