// lib/screens/checkin/checkin_list_screen.dart
import 'package:elecpro/screens/checkin/checkin_screen_2.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import '../../theme/app_theme.dart';
import '../../services/firestore_service.dart';
import '../../models/models.dart';
import '../../widgets/shared_widgets.dart';

class CheckinListScreen extends StatefulWidget {
  final bool standalone;
  const CheckinListScreen({super.key,this.standalone = true});

  @override
  State<CheckinListScreen> createState() => _CheckinListScreenState();
}

class _CheckinListScreenState extends State<CheckinListScreen> {

  // Returns distinct dates that have attendance records, sorted descending
  Stream<List<DateTime>> _watchCheckinDates(FirestoreService fs) {
    return fs.watchAllAttendance().map((records) {
      final seen = <String>{};
      final dates = <DateTime>[];
      for (final r in records) {
        final key = DateFormat('yyyy-MM-dd').format(r.date);
        if (seen.add(key)) {
          dates.add(DateTime(r.date.year, r.date.month, r.date.day));
        }
      }
      dates.sort((a, b) => b.compareTo(a)); // newest first
      return dates;
    });
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  bool _isToday(DateTime d) => _isSameDay(d, DateTime.now());

  Future<void> _openCheckin(DateTime date, {required bool isNew}) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CheckinScreen(
          standalone: true,
          initialDate: date,
          readOnly: false,
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final fs      = context.read<FirestoreService>();
    final today   = DateTime.now();
    final todayKey = DateFormat('yyyy-MM-dd').format(today);

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Stack(children: [
        Positioned(top: -40, right: -30,
            child: _orb(170, AppColors.success, 0.10)),
        Positioned(bottom: 80, left: -20,
            child: _orb(120, AppColors.primary, 0.08)),
        Positioned.fill(child: CustomPaint(painter: _DotGridPainter())),

        SafeArea(child: Column(children: [

          // ── Top bar ──────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Row(children: [
              Expanded(
                  child: Text('Check-in', style: AppText.heading(20))),
            ]),
          ),

          const SizedBox(height: 16),

          // ── Today banner ─────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: StreamBuilder<List<DateTime>>(
              stream: _watchCheckinDates(fs),
              builder: (_, snap) {
                final dates     = snap.data ?? [];
                final doneToday = dates.any((d) =>
                    DateFormat('yyyy-MM-dd').format(d) == todayKey);

                return _TodayBanner(
                  date: today,
                  isDone: doneToday,
                  onTap: doneToday
                      ? null
                      : () => _openCheckin(today, isNew: true),
                );
              },
            ),
          ),

          const SizedBox(height: 20),

          // ── Section label ─────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(children: [
              Text('HISTORY', style: AppText.label),
            ]),
          ),
          const SizedBox(height: 10),

          // ── Past check-ins list ───────────────────────────────────
          Expanded(
            child: StreamBuilder<List<DateTime>>(
              stream: _watchCheckinDates(fs),
              builder: (_, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(
                      child: CircularProgressIndicator(
                          color: AppColors.primary, strokeWidth: 2));
                }

                // Exclude today from history list
                final dates = (snap.data ?? [])
                    .where((d) =>
                        DateFormat('yyyy-MM-dd').format(d) != todayKey)
                    .toList();

                if (dates.isEmpty) {
                  return const EmptyState(
                    icon: '📋',
                    title: 'No past check-ins',
                    subtitle: 'Your daily attendance history will appear here',
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
                  itemCount: dates.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final date = dates[i];
                    return _CheckinHistoryRow(
                      date: date,
                      onTap: () => _openCheckin(date, isNew: false),
                    )
                        .animate()
                        .fadeIn(delay: (i * 40).ms, duration: 250.ms)
                        .slideX(begin: 0.03, end: 0);
                  },
                );
              },
            ),
          ),
        ])),
      ]),
    );
  }

  Widget _orb(double size, Color color, double opacity) => Container(
      width: size, height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
            colors: [color.withOpacity(opacity), Colors.transparent]),
      ));
}

// ─────────────────────────────────────────────
//  Today banner — green if not done, grey if done
// ─────────────────────────────────────────────
class _TodayBanner extends StatelessWidget {
  final DateTime date;
  final bool isDone;
  final VoidCallback? onTap;

  const _TodayBanner({
    required this.date,
    required this.isDone,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDone
                ? [const Color(0xFF0D1F12), const Color(0xFF091408)]
                : [
                    AppColors.success.withOpacity(0.18),
                    AppColors.success.withOpacity(0.08),
                  ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDone
                ? AppColors.success.withOpacity(0.15)
                : AppColors.success.withOpacity(0.5),
          ),
        ),
        child: Row(children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isDone
                  ? AppColors.success.withOpacity(0.15)
                  : AppColors.success.withOpacity(0.2),
            ),
            child: Icon(
              isDone
                  ? Icons.check_circle_rounded
                  : Icons.add_circle_outline_rounded,
              color: AppColors.success,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Today — ${DateFormat('EEEE dd MMM').format(date)}',
                  style: GoogleFonts.syne(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.white),
                ),
                const SizedBox(height: 3),
                Text(
                  isDone
                      ? 'Attendance already recorded'
                      : 'Tap to record today\'s attendance',
                  style: TextStyle(
                      fontSize: 11,
                      color: isDone
                          ? AppColors.textMuted
                          : AppColors.success.withOpacity(0.8)),
                ),
              ],
            ),
          ),
          if (isDone)
            // View today button
            GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CheckinScreen(
                    standalone: true,
                    initialDate: date,
                    readOnly: false,
                  ),
                ),
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: AppColors.success.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(
                      color: AppColors.success.withOpacity(0.3)),
                ),
                child: Text('Edit',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.success)),
              ),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: AppColors.success,
                borderRadius: BorderRadius.circular(9),
              ),
              child: Text('Start',
                  style: GoogleFonts.syne(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Colors.black)),
            ),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  History row — one per past check-in date
// ─────────────────────────────────────────────
class _CheckinHistoryRow extends StatelessWidget {
  final DateTime date;
  final VoidCallback onTap;

  const _CheckinHistoryRow({
    required this.date,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isYesterday = _isYesterday(date);
    final label = isYesterday
        ? 'Yesterday'
        : DateFormat('EEEE').format(date);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(children: [
          // Day icon
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: AppColors.primary.withOpacity(0.2)),
            ),
            child: Center(
              child: Text(
                date.day.toString(),
                style: GoogleFonts.syne(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary)),
                const SizedBox(height: 2),
                Text(
                  DateFormat('dd MMMM yyyy').format(date),
                  style: const TextStyle(
                      fontSize: 10, color: AppColors.textMuted),
                ),
              ],
            ),
          ),
          // Done badge
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.success.withOpacity(0.10),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: AppColors.success.withOpacity(0.25)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.check_rounded,
                  color: AppColors.success, size: 11),
              const SizedBox(width: 4),
              const Text('Done',
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: AppColors.success)),
            ]),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.chevron_right_rounded,
              color: AppColors.textMuted, size: 18),
        ]),
      ),
    );
  }

  bool _isYesterday(DateTime d) {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    return d.year == yesterday.year &&
        d.month == yesterday.month &&
        d.day == yesterday.day;
  }
}

class _DotGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = Colors.white.withOpacity(0.04)
      ..style = PaintingStyle.fill;
    const s = 26.0;
    for (double x = 0; x < size.width; x += s)
      for (double y = 0; y < size.height; y += s)
        canvas.drawCircle(Offset(x, y), 1.2, p);
  }

  @override
  bool shouldRepaint(_) => false;
}