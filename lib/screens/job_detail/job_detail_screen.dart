// lib/screens/job_detail/job_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import '../../theme/app_theme.dart';
import '../../services/firestore_service.dart';
import '../../models/models.dart';
import '../../widgets/shared_widgets.dart';
import '../checkin/checkin_screen.dart';

class JobDetailScreen extends StatelessWidget {
  final JobModel job;
  const JobDetailScreen({super.key, required this.job});

  @override
  Widget build(BuildContext context) {
    final fs  = context.read<FirestoreService>();
    final fmt = NumberFormat('#,##0.00', 'fr_TN');

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Stack(children: [
        Positioned(top: -50, right: -40,
            child: _orb(200, AppColors.primary, 0.10)),
        Positioned(bottom: 100, left: -20,
            child: _orb(140, AppColors.info, 0.08)),
        Positioned.fill(child: CustomPaint(painter: _DotGridPainter())),

        SafeArea(child: Column(children: [

          // ── Top bar ──────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Row(children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: const Icon(Icons.arrow_back_ios_new_rounded,
                    color: Colors.white54, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                  child: Text('Job Detail',
                      style: AppText.heading(20))),
              GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const CheckinScreen()),
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.success.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: AppColors.success.withOpacity(0.3)),
                  ),
                  child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                    Icon(Icons.how_to_reg_rounded,
                        color: AppColors.success, size: 13),
                    SizedBox(width: 5),
                    Text('Check-in',
                        style: TextStyle(
                            color: AppColors.success,
                            fontSize: 11,
                            fontWeight: FontWeight.w600)),
                  ]),
                ),
              ),
            ]),
          ),

          const SizedBox(height: 14),

          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
              children: [

                // ── Job hero card ─────────────
                _JobHeroCard(job: job)
                    .animate()
                    .fadeIn(duration: 400.ms)
                    .slideY(begin: 0.05, end: 0),

                const SizedBox(height: 16),

                SectionHeader(
                  title: 'Workers on this Job',
                  actionLabel: '+ Add',
                  onAction: () {},
                ),
                const SizedBox(height: 10),

                // ── Workers with days + pay ───
                StreamBuilder<List<WorkerModel>>(
                  stream: fs.watchWorkers(),
                  builder: (_, snap) {
                    final workers = (snap.data ?? [])
                        .where((w) => job.workerIds.contains(w.id))
                        .toList();

                    if (workers.isEmpty) {
                      return const EmptyState(
                        icon: '👷',
                        title: 'No workers assigned',
                        subtitle: 'Tap "+ Add" to assign workers',
                      );
                    }

                    return Column(
                      children: workers
                          .asMap()
                          .entries
                          .map((e) => _WorkerDayCard(
                                worker: e.value,
                                job: job,
                                fmt: fmt,
                              )
                                  .animate()
                                  .fadeIn(
                                      delay: (e.key * 80).ms,
                                      duration: 350.ms)
                                  .slideX(begin: 0.04, end: 0))
                          .toList(),
                    );
                  },
                ),

                const SizedBox(height: 16),

                // ── Total card ────────────────
                StreamBuilder<List<WorkerModel>>(
                  stream: fs.watchWorkers(),
                  builder: (_, snap) {
                    final workers = (snap.data ?? [])
                        .where((w) => job.workerIds.contains(w.id))
                        .toList();
                    return _TotalCard(
                        workers: workers, job: job, fmt: fmt);
                  },
                ),
              ],
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
//  Job hero card — ✅ uses displayLabel (ClientName · date)
// ─────────────────────────────────────────────
class _JobHeroCard extends StatelessWidget {
  final JobModel job;
  const _JobHeroCard({required this.job});

  @override
  Widget build(BuildContext context) {
    final elapsed    = DateTime.now().difference(job.startDate).inDays + 1;
    final startLabel = DateFormat('dd MMM yyyy').format(job.startDate);
    final endLabel   = job.endDate != null
        ? DateFormat('dd MMM yyyy').format(job.endDate!)
        : 'Ongoing';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1C1200), Color(0xFF1A0800)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.primary.withOpacity(0.2)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start,
          children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ✅ Shows "ClientName · dd/MM/yyyy"
                Text(
                  job.displayLabel,
                  style: GoogleFonts.syne(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.white),
                ),
                const SizedBox(height: 4),
                // Internal title shown smaller
                Text(job.title,
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textMuted)),
              ],
            ),
          ),
          StatusBadge(
            label: job.status == JobStatus.active ? 'Active' : 'Done',
            color: job.status == JobStatus.active
                ? AppColors.primary
                : AppColors.success,
          ),
        ]),

        const SizedBox(height: 8),
        Text('📍 ${job.address}',
            style: const TextStyle(
                fontSize: 10, color: AppColors.textMuted)),
        const SizedBox(height: 12),

        // Stats
        Row(children: [
          _Stat('Day $elapsed',  'Elapsed'),
          const SizedBox(width: 16),
          _Stat(startLabel,      'Started'),
          const SizedBox(width: 16),
          _Stat(endLabel,        'End'),
          const SizedBox(width: 16),
          _Stat('${job.workerIds.length}', 'Workers'),
        ]),
      ]),
    );
  }
}

class _Stat extends StatelessWidget {
  final String value, label;
  const _Stat(this.value, this.label);

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value,
              style: GoogleFonts.syne(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary)),
          Text(label,
              style: const TextStyle(
                  fontSize: 8, color: AppColors.textMuted)),
        ],
      );
}

// ─────────────────────────────────────────────
//  Worker day card — ✅ uses daysWorked × dailyRate
// ─────────────────────────────────────────────
class _WorkerDayCard extends StatelessWidget {
  final WorkerModel worker;
  final JobModel job;
  final NumberFormat fmt;

  const _WorkerDayCard({
    required this.worker,
    required this.job,
    required this.fmt,
  });

  @override
  Widget build(BuildContext context) {
    final fs = context.read<FirestoreService>();

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: FutureBuilder<double>(
        // ✅ FIXED: getTotalDaysWorked (not getHoursWorked)
        future: fs.getTotalDaysWorked(worker.id, job.id),
        builder: (_, snap) {
          final days  = snap.data ?? 0.0;
          // ✅ FIXED: dailyRate (not hourlyRate)
          final total = days * worker.dailyRate;

          return Row(children: [
            GradientAvatar(
              label: worker.name,
              colors: const [AppColors.primary, AppColors.secondary],
              size: 38,
              fontSize: 15,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(worker.name,
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary)),
                  const SizedBox(height: 3),
                  // ✅ FIXED: dailyRate
                  Text(
                    '${worker.role}  ·  '
                    '${worker.dailyRate.toStringAsFixed(0)} DT/day',
                    style: const TextStyle(
                        fontSize: 10, color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(
                '${days.toStringAsFixed(1)} j',
                style: GoogleFonts.syne(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary),
              ),
              Text(
                '= ${fmt.format(total)} DT',
                style: const TextStyle(
                    fontSize: 10, color: AppColors.textMuted),
              ),
            ]),
          ]);
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Total card — ✅ sums days × dailyRate
// ─────────────────────────────────────────────
class _TotalCard extends StatefulWidget {
  final List<WorkerModel> workers;
  final JobModel job;
  final NumberFormat fmt;

  const _TotalCard({
    required this.workers,
    required this.job,
    required this.fmt,
  });

  @override
  State<_TotalCard> createState() => _TotalCardState();
}

class _TotalCardState extends State<_TotalCard> {
  double _total = 0;

  @override
  void initState() {
    super.initState();
    _calc();
  }

  @override
  void didUpdateWidget(_TotalCard old) {
    super.didUpdateWidget(old);
    if (old.workers.length != widget.workers.length) _calc();
  }

  Future<void> _calc() async {
    final fs  = context.read<FirestoreService>();
    double sum = 0;
    for (final w in widget.workers) {
      // ✅ FIXED: getTotalDaysWorked × dailyRate
      final days = await fs.getTotalDaysWorked(w.id, widget.job.id);
      sum += days * w.dailyRate;
    }
    if (mounted) setState(() => _total = sum);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: AppColors.primary.withOpacity(0.25)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Total Cost This Job',
            style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500),
          ),
          Text(
            '${widget.fmt.format(_total)} DT',
            style: GoogleFonts.syne(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.primary),
          ),
        ],
      ),
    );
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
  @override bool shouldRepaint(_) => false;
}
