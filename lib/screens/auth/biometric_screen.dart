// lib/screens/auth/biometric_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import 'pin_screen.dart';

class BiometricScreen extends StatefulWidget {
  const BiometricScreen({super.key});

  @override
  State<BiometricScreen> createState() => _BiometricScreenState();
}

class _BiometricScreenState extends State<BiometricScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulseAnim;

  _FpState _fpState = _FpState.idle;
  bool _biometricAvailable = false;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _pulseAnim = Tween<double>(begin: 0.92, end: 1.08).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final auth = context.read<AuthProvider>();
      final available = await auth.isBiometricAvailable();
      setState(() => _biometricAvailable = available);
    });
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleBiometric() async {
    if (_fpState == _FpState.scanning) return;

    setState(() => _fpState = _FpState.scanning);

    final auth = context.read<AuthProvider>();
    final success = await auth.loginWithBiometric();

    if (!mounted) return;

    if (success) {
      setState(() => _fpState = _FpState.success);
      await Future.delayed(const Duration(milliseconds: 800));
      // Navigation handled by auth state listener in main.dart
    } else {
      setState(() => _fpState = _FpState.error);
      await Future.delayed(const Duration(milliseconds: 1500));
      if (mounted) setState(() => _fpState = _FpState.idle);
    }
  }

  Color get _accentColor {
    switch (_fpState) {
      case _FpState.scanning: return AppColors.info;
      case _FpState.success:  return AppColors.success;
      case _FpState.error:    return AppColors.danger;
      default:                return AppColors.primary;
    }
  }

  String get _statusText {
    switch (_fpState) {
      case _FpState.scanning: return 'Scanning…';
      case _FpState.success:  return 'Identity Verified';
      case _FpState.error:    return 'Try Again';
      default:                return 'Touch to Unlock';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background
          _buildBackground(),
          SafeArea(
            child: Column(
              children: [
                // Status bar row
                _buildTopBar(),
                const Spacer(flex: 2),
                // Brand
                _buildBrand()
                    .animate()
                    .fadeIn(duration: 700.ms)
                    .slideY(begin: -0.1, end: 0),
                const Spacer(flex: 3),
                // Fingerprint
                _buildFingerprintSensor()
                    .animate()
                    .fadeIn(delay: 300.ms, duration: 600.ms)
                    .scale(begin: const Offset(0.8, 0.8)),
                const SizedBox(height: 20),
                // Status text
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: Text(
                    _statusText,
                    key: ValueKey(_fpState),
                    style: TextStyle(
                      color: _accentColor,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const Spacer(flex: 2),
                // PIN fallback
                _buildPinFallback()
                    .animate()
                    .fadeIn(delay: 600.ms, duration: 500.ms),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Background ────────────────────────────────
  Widget _buildBackground() {
    return Container(
      decoration: const BoxDecoration(color: AppColors.bg),
      child: Stack(
        children: [
          // Top-left orb
          Positioned(
            top: -60, left: -50,
            child: Container(
              width: 260, height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.primary.withOpacity(0.18),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          // Bottom-right orb
          Positioned(
            bottom: -40, right: -40,
            child: Container(
              width: 220, height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.secondary.withOpacity(0.15),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          // Dot grid
          Positioned.fill(
            child: CustomPaint(painter: _DotGridPainter()),
          ),
        ],
      ),
    );
  }

  // ── Top bar ───────────────────────────────────
  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.06),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.08)),
            ),
            child: Row(
              children: [
                Container(
                  width: 6, height: 6,
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  'Secure',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.55),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Brand ─────────────────────────────────────
  Widget _buildBrand() {
    return Column(
      children: [
        // Logo
        Container(
          width: 60, height: 60,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.primary, AppColors.secondary],
            ),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withOpacity(0.35),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: const Center(
            child: Text('⚡', style: TextStyle(fontSize: 28)),
          ),
        ),
        const SizedBox(height: 14),
        Text('ElecPro', style: AppText.heading(28)),
        const SizedBox(height: 6),
        Text(
          'Electric Work Manager',
          style: TextStyle(
            color: Colors.white.withOpacity(0.4),
            fontSize: 13,
          ),
        ),
      ],
    );
  }

  // ── Fingerprint sensor ────────────────────────
  Widget _buildFingerprintSensor() {
    return GestureDetector(
      onTap: _biometricAvailable ? _handleBiometric : null,
      child: SizedBox(
        width: 150, height: 150,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Pulse ring
            if (_fpState == _FpState.idle)
              AnimatedBuilder(
                animation: _pulseAnim,
                builder: (_, __) => Transform.scale(
                  scale: _pulseAnim.value,
                  child: Container(
                    width: 150, height: 150,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _accentColor.withOpacity(0.15),
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
              ),

            // Ring 2
            Container(
              width: 120, height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: _accentColor.withOpacity(0.2),
                  width: 1,
                ),
              ),
            ),

            // Core
            Container(
              width: 88, height: 88,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _accentColor.withOpacity(0.08),
                border: Border.all(
                  color: _accentColor.withOpacity(0.5),
                  width: 1.5,
                ),
                boxShadow: _fpState == _FpState.success
                    ? [
                        BoxShadow(
                          color: _accentColor.withOpacity(0.3),
                          blurRadius: 20,
                        )
                      ]
                    : null,
              ),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: _fpState == _FpState.success
                    ? Icon(Icons.check_rounded,
                        key: const ValueKey('check'),
                        color: _accentColor,
                        size: 36)
                    : _fpState == _FpState.error
                        ? Icon(Icons.close_rounded,
                            key: const ValueKey('err'),
                            color: _accentColor,
                            size: 36)
                        : Icon(Icons.fingerprint_rounded,
                            key: const ValueKey('fp'),
                            color: _accentColor,
                            size: 44),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── PIN fallback ──────────────────────────────
  Widget _buildPinFallback() {
    return Column(
      children: [
        Row(
          children: [
            const Expanded(child: Divider(color: Color(0x12FFFFFF))),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                'OR',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.2),
                  fontSize: 10,
                  letterSpacing: 1,
                ),
              ),
            ),
            const Expanded(child: Divider(color: Color(0x12FFFFFF))),
          ],
        ),
        const SizedBox(height: 16),
        TextButton(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const PinScreen()),
          ),
          style: TextButton.styleFrom(
            foregroundColor: Colors.white38,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            side: const BorderSide(color: Color(0x10FFFFFF)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.grid_view_rounded, size: 14),
              SizedBox(width: 7),
              Text('Use PIN instead', style: TextStyle(fontSize: 13)),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Enum ──────────────────────────────────────
enum _FpState { idle, scanning, success, error }

// ── Dot grid painter ──────────────────────────
class _DotGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.04)
      ..style = PaintingStyle.fill;
    const spacing = 26.0;
    for (double x = 0; x < size.width; x += spacing) {
      for (double y = 0; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), 1.2, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}
