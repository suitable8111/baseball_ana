"""
Firebase Firestore 업로더
크롤링 데이터를 Firestore에 저장
"""

import os
import firebase_admin
from firebase_admin import credentials, firestore
from dotenv import load_dotenv

load_dotenv()

_db = None


def init_firebase():
    global _db
    if _db is not None:
        return _db

    cred_path = os.getenv('FIREBASE_CREDENTIALS_PATH', './firebase-adminsdk.json')
    if not os.path.exists(cred_path):
        raise FileNotFoundError(
            f'Firebase 서비스 계정 키 파일을 찾을 수 없습니다: {cred_path}\n'
            'Firebase 콘솔에서 서비스 계정 키를 다운로드 후 경로를 .env에 설정하세요.'
        )

    if not firebase_admin._apps:
        cred = credentials.Certificate(cred_path)
        firebase_admin.initialize_app(cred)

    _db = firestore.client()
    return _db


def upload_player_hitters(data: list[dict], season: int):
    """선수 타자 데이터 업로드"""
    db = init_firebase()
    collection = db.collection('seasons').document(str(season)).collection('player_hitter')
    _batch_upload(db, collection, data, key_field='name')
    print(f'[Firebase] 타자 {len(data)}명 업로드 완료')


def upload_player_pitchers(data: list[dict], season: int):
    """선수 투수 데이터 업로드"""
    db = init_firebase()
    collection = db.collection('seasons').document(str(season)).collection('player_pitcher')
    _batch_upload(db, collection, data, key_field='name')
    print(f'[Firebase] 투수 {len(data)}명 업로드 완료')


def upload_player_defense(data: list[dict], season: int):
    """선수 수비 데이터 업로드"""
    db = init_firebase()
    collection = db.collection('seasons').document(str(season)).collection('player_defense')
    _batch_upload(db, collection, data, key_field='name')
    print(f'[Firebase] 수비 {len(data)}명 업로드 완료')


def upload_player_runners(data: list[dict], season: int):
    """선수 주루 데이터 업로드"""
    db = init_firebase()
    collection = db.collection('seasons').document(str(season)).collection('player_runner')
    _batch_upload(db, collection, data, key_field='name')
    print(f'[Firebase] 주루 {len(data)}명 업로드 완료')


def upload_team_hitters(data: list[dict], season: int):
    """팀 타자 데이터 업로드"""
    db = init_firebase()
    collection = db.collection('seasons').document(str(season)).collection('team_hitter')
    _batch_upload(db, collection, data, key_field='team')
    print(f'[Firebase] 팀 타자 {len(data)}팀 업로드 완료')


def upload_team_pitchers(data: list[dict], season: int):
    """팀 투수 데이터 업로드"""
    db = init_firebase()
    collection = db.collection('seasons').document(str(season)).collection('team_pitcher')
    _batch_upload(db, collection, data, key_field='team')
    print(f'[Firebase] 팀 투수 {len(data)}팀 업로드 완료')


def _batch_upload(db, collection, data: list[dict], key_field: str):
    """Firestore 배치 쓰기 (500개 제한)"""
    BATCH_SIZE = 400

    for i in range(0, len(data), BATCH_SIZE):
        batch = db.batch()
        chunk = data[i:i + BATCH_SIZE]
        for item in chunk:
            doc_id = item.get(key_field, str(i))
            # 팀명 포함 시 고유키로 사용
            if 'team' in item and key_field == 'name':
                doc_id = f"{item['team']}_{item['name']}"
            doc_ref = collection.document(doc_id)
            batch.set(doc_ref, item)
        batch.commit()
