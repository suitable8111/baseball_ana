"""
고급 야구 지표 계산 모듈
크롤링한 기본 통계에서 sabermetric 지표를 계산
"""


def calc_babip(hits: int, hr: int, ab: int, so: int, sf: int = 0) -> float:
    """BABIP = (H - HR) / (AB - SO - HR + SF)"""
    denom = ab - so - hr + sf
    if denom <= 0:
        return 0.0
    return round((hits - hr) / denom, 3)


def calc_iso(slg: float, avg: float) -> float:
    """ISO = SLG - AVG"""
    return round(slg - avg, 3)


def calc_bb_pct(bb: int, pa: int) -> float:
    """BB% = BB / PA"""
    if pa <= 0:
        return 0.0
    return round(bb / pa, 3)


def calc_k_pct(so: int, pa: int) -> float:
    """K% = SO / PA"""
    if pa <= 0:
        return 0.0
    return round(so / pa, 3)


def calc_woba(singles: int, doubles: int, triples: int, hr: int,
              bb: int, hbp: int, pa: int,
              ibb: int = 0, sf: int = 0) -> float:
    """
    wOBA (Weighted On-Base Average)
    가중치는 KBO 근사값 사용 (MLB FanGraphs 기준 참고)
    """
    # KBO 근사 wOBA 가중치
    w_bb = 0.69
    w_hbp = 0.72
    w_1b = 0.88
    w_2b = 1.24
    w_3b = 1.56
    w_hr = 2.00

    numerator = (
        w_bb * (bb - ibb) +
        w_hbp * hbp +
        w_1b * singles +
        w_2b * doubles +
        w_3b * triples +
        w_hr * hr
    )
    denominator = pa - ibb - sf
    if denominator <= 0:
        return 0.0
    return round(numerator / denominator, 3)


def calc_fip(hr: int, bb: int, hbp: int, so: int, ip: float,
             fip_const: float = 3.20) -> float:
    """
    FIP = (13*HR + 3*(BB+HBP) - 2*K) / IP + FIP상수
    FIP 상수: 시즌 리그 평균 ERA - 리그 FIP 차이 (KBO 근사 3.20)
    """
    if ip <= 0:
        return 0.0
    return round((13 * hr + 3 * (bb + hbp) - 2 * so) / ip + fip_const, 2)


def calc_k9(so: int, ip: float) -> float:
    """K/9 = 9 * K / IP"""
    if ip <= 0:
        return 0.0
    return round(9 * so / ip, 2)


def calc_bb9(bb: int, ip: float) -> float:
    """BB/9 = 9 * BB / IP"""
    if ip <= 0:
        return 0.0
    return round(9 * bb / ip, 2)


def calc_hr9(hr: int, ip: float) -> float:
    """HR/9 = 9 * HR / IP"""
    if ip <= 0:
        return 0.0
    return round(9 * hr / ip, 2)


def enrich_hitter(record: dict) -> dict:
    """타자 기록에 고급 지표 추가"""
    hits = record.get('hits', 0)
    hr = record.get('hr', 0)
    ab = record.get('ab', 0)
    so = record.get('so', 0)
    doubles = record.get('doubles', 0)
    triples = record.get('triples', 0)
    bb = record.get('bb', 0)
    hbp = record.get('hbp', 0)
    pa = record.get('pa', 0)
    singles = hits - doubles - triples - hr
    slg = record.get('slg', 0.0)
    avg = record.get('avg', 0.0)

    record['babip'] = calc_babip(hits, hr, ab, so)
    record['iso'] = calc_iso(slg, avg)
    record['bb_pct'] = calc_bb_pct(bb, pa)
    record['k_pct'] = calc_k_pct(so, pa)
    record['woba'] = calc_woba(singles, doubles, triples, hr, bb, hbp, pa)
    return record


def enrich_pitcher(record: dict) -> dict:
    """투수 기록에 고급 지표 추가"""
    hr = record.get('hr', 0)
    bb = record.get('bb', 0)
    hbp = record.get('hbp', 0)
    so = record.get('so', 0)
    ip = record.get('ip', 0.0)

    record['fip'] = calc_fip(hr, bb, hbp, so, ip)
    record['k9'] = calc_k9(so, ip)
    record['bb9'] = calc_bb9(bb, ip)
    record['hr9'] = calc_hr9(hr, ip)
    return record
