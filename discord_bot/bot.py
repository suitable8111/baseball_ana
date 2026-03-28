"""
KBO 야구 분석 Discord 봇

명령어 (자연어):
  오늘 경기          → 오늘 KBO 전체 경기 일정 + 선발 라인업 표시
  오늘 NC 삼성 승부 예측  → 두 팀 간 오늘 경기 승부 확률 예측
                      (오늘 경기 아닐 경우 오류 메시지)
"""

import os
import re
import asyncio
from datetime import datetime, timezone, timedelta
from typing import Optional

import discord
from discord.ext import commands
from dotenv import load_dotenv

from naver_service import fetch_schedule
from prediction import predict_game
from data_loader import preload_all

load_dotenv()

TOKEN = os.getenv("DISCORD_TOKEN")
if not TOKEN:
    raise SystemExit("❌ .env 파일에 DISCORD_TOKEN을 설정해주세요.")

KST = timezone(timedelta(hours=9))

# ── KBO 팀 이름 정규화 ────────────────────────────────────────────────────────
# 사용자 입력(소문자·공백 제거 후) → 팀 코드 (Naver API 팀명 첫 단어)
_ALIASES: dict[str, str] = {
    "lg": "LG", "lg트윈스": "LG",
    "두산": "두산", "두산베어스": "두산",
    "kt": "KT", "kt위즈": "KT",
    "ssg": "SSG", "ssg랜더스": "SSG",
    "nc": "NC", "nc다이노스": "NC",
    "kia": "KIA", "kia타이거즈": "KIA",
    "롯데": "롯데", "롯데자이언츠": "롯데",
    "삼성": "삼성", "삼성라이온즈": "삼성",
    "한화": "한화", "한화이글스": "한화",
    "키움": "키움", "키움히어로즈": "키움",
}
_KEYWORDS = {"오늘", "승부", "예측", "승부예측", "경기"}


def _normalize(raw: str) -> Optional[str]:
    key = raw.lower().replace(" ", "")
    return _ALIASES.get(key) or _ALIASES.get(raw)


def _extract_teams(text: str) -> list[str]:
    """텍스트에서 KBO 팀 코드를 순서대로 추출"""
    found: list[str] = []
    for word in re.split(r"[\s,]+", text):
        code = _normalize(word.strip())
        if code and code not in found:
            found.append(code)
    return found


# ── Discord 봇 설정 ───────────────────────────────────────────────────────────

intents = discord.Intents.default()
intents.message_content = True
bot = commands.Bot(command_prefix="!", intents=intents)


@bot.event
async def on_ready():
    print(f"✅ 봇 로그인 완료: {bot.user}")
    print("📦 데이터 사전 로드 중...")
    preload_all()
    print("🚀 준비 완료")


@bot.event
async def on_message(message: discord.Message):
    if message.author.bot:
        return

    text = message.content.strip()

    # ── 오늘 경기 ──────────────────────────────────────────────────────────────
    if text in ("오늘 경기", "오늘경기"):
        await _handle_today_games(message)
        return

    # ── 오늘 X Y 승부 예측 ─────────────────────────────────────────────────────
    if "오늘" in text and ("승부" in text or "예측" in text):
        teams = _extract_teams(text)
        if len(teams) == 2:
            await _handle_prediction(message, teams[0], teams[1])
            return
        if len(teams) > 2:
            await message.reply("❌ 두 팀만 입력해주세요. 예: `오늘 NC 삼성 승부 예측`")
            return

    await bot.process_commands(message)


# ── 오늘 경기 목록 ────────────────────────────────────────────────────────────

async def _handle_today_games(message: discord.Message):
    now = datetime.now(KST)
    try:
        games = await fetch_schedule(now)
    except Exception as e:
        await message.reply(f"❌ 경기 일정을 가져올 수 없습니다: {e}")
        return

    if not games:
        await message.reply(f"📅 {now.strftime('%Y-%m-%d')} KBO 경기가 없습니다.")
        return

    _STATUS_EMOJI = {
        "GAME_CANCEL": "🚫",
        "GAME_RESULT": "✅",
        "GAME_LIVE":   "🔴",
        "GAME_READY":  "⚾",
    }

    lines = [f"📅 **{now.strftime('%Y년 %m월 %d일')} KBO 경기**\n"]
    for g in games:
        home = g.get("homeTeamName", "")
        away = g.get("awayTeamName", "")
        home_s = g.get("homeStarterName") or "미정"
        away_s = g.get("awayStarterName") or "미정"
        status = g.get("statusCode", "")
        emoji = _STATUS_EMOJI.get(status, "⚾")

        # KST 시간 파싱
        time_str = ""
        scheduled = g.get("scheduledAt", "")
        if scheduled:
            try:
                dt = datetime.fromisoformat(scheduled.replace("Z", "+00:00")).astimezone(KST)
                time_str = dt.strftime("%H:%M")
            except Exception:
                pass

        lines.append(
            f"{emoji} **{away} @ {home}**  {time_str}\n"
            f"  └ 선발: {away_s} (원정) vs {home_s} (홈)"
        )

    await message.reply("\n".join(lines))


# ── 승부 예측 ─────────────────────────────────────────────────────────────────

async def _handle_prediction(message: discord.Message, team1_code: str, team2_code: str):
    now = datetime.now(KST)

    try:
        games = await fetch_schedule(now)
    except Exception as e:
        await message.reply(f"❌ 경기 일정을 가져올 수 없습니다: {e}")
        return

    # 두 팀 간 오늘 경기 탐색
    game: Optional[dict] = None
    for g in games:
        hc = g.get("homeTeamName", "").split()[0]
        ac = g.get("awayTeamName", "").split()[0]
        if {hc, ac} == {team1_code, team2_code}:
            game = g
            break

    if game is None:
        await message.reply(
            f"❌ 오늘({now.strftime('%m/%d')}) **{team1_code} vs {team2_code}** 경기가 없습니다.\n"
            "`오늘 경기`를 입력하면 오늘 전체 경기 목록을 확인할 수 있습니다."
        )
        return

    home_name  = game.get("homeTeamName", "")
    away_name  = game.get("awayTeamName", "")
    home_start = game.get("homeStarterName") or ""
    away_start = game.get("awayStarterName") or ""

    thinking = await message.reply("⏳ 10,000회 시뮬레이션 계산 중...")

    try:
        loop = asyncio.get_event_loop()
        result = await loop.run_in_executor(
            None, predict_game, home_name, away_name, home_start, away_start
        )
    except Exception as e:
        await thinking.edit(content=f"❌ 예측 실패: {e}")
        return

    hp = result["home_win_prob"]
    ap = result["away_win_prob"]
    winner = result["home_team"] if hp >= ap else result["away_team"]
    winner_prob = max(hp, ap)

    msg = (
        f"⚾ **{away_name} @ {home_name}** 승부 예측\n"
        f"선발: **{result['away_starter']}** (원정) vs **{result['home_starter']}** (홈)\n"
        f"FIP:  {result['away_fip']:.2f}  vs  {result['home_fip']:.2f}\n"
        f"\n"
        f"{away_name}  `{ap*100:.1f}%`  {_bar(ap)}\n"
        f"{home_name}  `{hp*100:.1f}%`  {_bar(hp)}\n"
        f"\n"
        f"예상 득점: {away_name} **{result['away_avg_score']:.1f}** — {home_name} **{result['home_avg_score']:.1f}**\n"
        f"\n"
        f"🏆 예측 승자: **{winner}** ({winner_prob*100:.1f}%)"
    )
    await thinking.edit(content=msg)


def _bar(prob: float, width: int = 12) -> str:
    filled = round(prob * width)
    return "█" * filled + "░" * (width - filled)


if __name__ == "__main__":
    bot.run(TOKEN)
