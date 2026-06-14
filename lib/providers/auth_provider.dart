// lib/providers/auth_provider.dart
import 'package:flutter/material.dart';
import '../services/auth_service.dart';

enum AuthStatus { initial, loading, authenticated, unauthenticated, error }

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();

  AuthStatus _status = AuthStatus.unauthenticated;
  String?    _errorMessage;

  AuthStatus get status       => _status;
  String?    get errorMessage => _errorMessage;
  bool       get isLoggedIn   => _status == AuthStatus.authenticated;

  // ── Biometric login ──────────────────────────
  Future<bool> loginWithBiometric() async {
    _setLoading();

    final success = await _authService.authenticateWithBiometric();

    if (success) {
      _status = AuthStatus.authenticated;
      _errorMessage = null;
      notifyListeners();
    } else {
      _setError('Biometric authentication failed. Try PIN.');
    }

    return success;
  }

  Future<bool> isBiometricAvailable() =>
      _authService.isBiometricAvailable();

  // ── Sign out ─────────────────────────────────
  Future<void> signOut() async {
    _status = AuthStatus.unauthenticated;
    _errorMessage = null;
    notifyListeners();
  }

  // ── Helpers ──────────────────────────────────
  void _setLoading() {
    _status = AuthStatus.loading;
    _errorMessage = null;
    notifyListeners();
  }

  void _setError(String msg) {
    _status = AuthStatus.error;
    _errorMessage = msg;
    notifyListeners();
  }
}
