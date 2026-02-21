import 'package:flutter/material.dart';

// Firebase Auth 연동 전 임시 구현
// Firebase 세팅 후 실제 auth 로직 추가
class AuthProvider extends ChangeNotifier {
  // 임시: 항상 로그인 상태로 처리 (개발 중)
  bool _isLoggedIn = true;

  // TODO: Firebase User 객체로 교체
  dynamic get user => _isLoggedIn ? {'uid': 'dev_user'} : null;

  Future<void> signOut() async {
    _isLoggedIn = false;
    notifyListeners();
  }

  Future<void> signInAnonymously() async {
    _isLoggedIn = true;
    notifyListeners();
  }
}
