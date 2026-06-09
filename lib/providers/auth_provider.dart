// lib/providers/auth_provider.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';

enum AuthStatus { initial, loading, authenticated, unauthenticated, error }

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();

  AuthStatus _status = AuthStatus.initial;
  String? _errorMessage;
  User? _user;

  AuthStatus get status       => _status;
  String?    get errorMessage => _errorMessage;
  User?      get user         => _user;
  bool       get isLoggedIn   => _user != null;

  AuthProvider() {
    _authService.authStateChanges.listen((user) {
      _user = user;
      _status = user != null
          ? AuthStatus.authenticated
          : AuthStatus.unauthenticated;
      notifyListeners();
    });
  }

  // ── Biometric login ──────────────────────────
  Future<bool> loginWithBiometric() async {
    _setLoading();
    final success = await _authService.authenticateWithBiometric();
    if (!success) {
      _setError('Biometric authentication failed. Try PIN.');
    }
    return success;
  }

  Future<bool> isBiometricAvailable() =>
      _authService.isBiometricAvailable();

  // ── Email login ──────────────────────────────
  Future<bool> loginWithEmail(String email, String password) async {
    _setLoading();
    try {
      await _authService.signInWithEmail(email, password);
      _clearError();
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    }
  }

  // ── Register ─────────────────────────────────
  Future<bool> register(String email, String password) async {
    _setLoading();
    try {
      await _authService.registerWithEmail(email, password);
      _clearError();
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    }
  }

  // ── Sign out ─────────────────────────────────
  Future<void> signOut() async {
    await _authService.signOut();
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

  void _clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
