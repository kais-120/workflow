// lib/screens/pay/pay_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../theme/app_theme.dart';
import '../../services/firestore_service.dart';
import '../../models/models.dart';
import '../../widgets/shared_widgets.dart';

// ─────────────────────────────────────────────
//  Manual payment model
// ─────────────────────────────────────────────
class ManualPayment {
  final String id;
  final String workerId;
  final double amount;
  final String note;
  final DateTime date;

  ManualPayment({
    required this.id,
    required this.workerId,
    required this.amount,
    required this.note,
    required this.date,
  });

  factory ManualPayment.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return ManualPayment(
      id:       doc.id,
      workerId: d['workerId'] ?? '',
      amount:   (d['amount'] ?? 0).toDouble(),
      note:     d['note']    ?? '',
      date:     (d['date'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() => {
    'workerId': workerId,
    'amount':   amount,
    'note':     note,
    'date':     Timestamp.fromDate(date),
  };
}

// ─────────────────────────────────────────────
//  Helper: stream that combines attendance +
//  manual_payments for one worker in real time
// ─────────────────────────────────────────────
class _WorkerSummary {
  final double totalDays, totalEarned, totalPaid, remaining;
  const _WorkerSummary({
    required this.totalDays,
    required this.totalEarned,
    required this.totalPaid,
    required this.remaining,
  });
}

Stream<_WorkerSummary> _workerSummaryStream(WorkerModel worker) {
  final attStream = FirebaseFirestore.instance
      .collection('attendance')
      .where('workerId', isEqualTo: worker.id)
      .where('present', isEqualTo: true)
      .snapshots();

  final payStream = FirebaseFirestore.instance
      .collection('manual_payments')
      .where('workerId', isEqualTo: worker.id)
      .snapshots();

  // Combine both streams into one summary
  return attStream.asyncMap((attSnap) async {
    double totalDays = 0;
    for (final doc in attSnap.docs) {
      final a = AttendanceModel.fromFirestore(doc);
      totalDays += a.daysValue;
    }

    final paySnap = await FirebaseFirestore.instance
        .collection('manual_payments')
        .where('workerId', isEqualTo: worker.id)
        .get();

    double totalPaid = 0;
    for (final doc in paySnap.docs) {
      totalPaid += ((doc.data())['amount'] ?? 0).toDouble();
    }

    final totalEarned = totalDays * worker.dailyRate;
    return _WorkerSummary(
      totalDays:   totalDays,
      totalEarned: totalEarned,
      totalPaid:   totalPaid,
      remaining:   totalEarned - totalPaid,
    );
  });
}

// We also need a combined stream that reacts to payment changes.
// Use a StreamBuilder for payments nested inside attendance stream.
Stream<_WorkerSummary> _workerSummaryStreamFull(WorkerModel worker) {
  // Listen to manual_payments changes → recompute everything
  return FirebaseFirestore.instance
      .collection('manual_payments')
      .where('workerId', isEqualTo: worker.id)
      .snapshots()
      .asyncMap((paySnap) async {
    double totalPaid = 0;
    for (final doc in paySnap.docs) {
      totalPaid += ((doc.data())['amount'] ?? 0).toDouble();
    }

    final attSnap = await FirebaseFirestore.instance
        .collection('attendance')
        .where('workerId', isEqualTo: worker.id)
        .where('present', isEqualTo: true)
        .get();

    double totalDays = 0;
    for (final doc in attSnap.docs) {
      final a = AttendanceModel.fromFirestore(doc);
      totalDays += a.daysValue;
    }

    final totalEarned = totalDays * worker.dailyRate;
    return _WorkerSummary(
      totalDays:   totalDays,
      totalEarned: totalEarned,
      totalPaid:   totalPaid,
      remaining:   totalEarned - totalPaid,
    );
  });
}

// ═════════════════════════════════════════════
//  PAY SCREEN — Worker list
// ═════════════════════════════════════════════
class PayScreen extends StatelessWidget {
  final bool standalone;
  const PayScreen({super.key, this.standalone = true});

  @override
  Widget build(BuildContext context) {
    final fs = context.read<FirestoreService>();

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Stack(children: [
        Positioned(top: -50, left: -40,
            child: _orb(200, AppColors.primary, 0.12)),
        Positioned(bottom: 80, right: -20,
            child: _orb(140, AppColors.secondary, 0.10)),
        Positioned.fill(child: CustomPaint(painter: _DotGridPainter())),

        SafeArea(child: Column(children: [

          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Row(children: [
              if (standalone)
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Icon(Icons.arrow_back_ios_new_rounded,
                      color: Colors.white54, size: 18),
                ),
              if (standalone) const SizedBox(width: 12),
              Expanded(child: Text('Pay', style: AppText.heading(20))),
            ]),
          ),

          const SizedBox(height: 16),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _GlobalSummaryCard(fs: fs),
          ),

          const SizedBox(height: 16),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('SELECT WORKER', style: AppText.label),
            ),
          ),
          const SizedBox(height: 10),

          Expanded(
            child: StreamBuilder<List<WorkerModel>>(
              stream: fs.watchWorkers(),
              builder: (_, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(
                        color: AppColors.primary, strokeWidth: 2),
                  );
                }
                final workers = snap.data ?? [];
                if (workers.isEmpty) {
                  return const EmptyState(
                    icon: '👷',
                    title: 'No workers yet',
                    subtitle: 'Add workers from the Workers tab',
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
                  itemCount: workers.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) => _WorkerPayRow(
                    worker: workers[i],
                    fs: fs,
                  )
                      .animate()
                      .fadeIn(delay: (i * 60).ms, duration: 300.ms)
                      .slideX(begin: 0.04, end: 0),
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
//  Global summary card
// ─────────────────────────────────────────────
class _GlobalSummaryCard extends StatelessWidget {
  final FirestoreService fs;
  const _GlobalSummaryCard({required this.fs});

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0.00', 'fr_TN');
    return FutureBuilder<Map<String, dynamic>>(
      future: fs.getDashboardStats(),
      builder: (_, snap) {
        final total   = snap.data?['totalEarnings'] as double? ?? 0;
        final paid    = snap.data?['totalPaid']     as double? ?? 0;
        final pending = snap.data?['totalPending']  as double? ?? 0;

        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1C1200), Color(0xFF1A0800)],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.primary.withOpacity(0.2)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _SumItem('Total',     '${fmt.format(total)} DT',   AppColors.primary),
              Container(width: 1, height: 36, color: Colors.white.withOpacity(0.08)),
              _SumItem('Paid',      '${fmt.format(paid)} DT',    AppColors.success),
              Container(width: 1, height: 36, color: Colors.white.withOpacity(0.08)),
              _SumItem('Remaining', '${fmt.format(pending)} DT', AppColors.danger),
            ],
          ),
        );
      },
    );
  }
}

class _SumItem extends StatelessWidget {
  final String label, value;
  final Color color;
  const _SumItem(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) => Column(children: [
        Text(value,
            style: GoogleFonts.syne(
                fontSize: 12, fontWeight: FontWeight.w700, color: color)),
        const SizedBox(height: 3),
        Text(label,
            style: const TextStyle(fontSize: 9, color: AppColors.textMuted)),
      ]);
}

// ─────────────────────────────────────────────
//  Worker pay row  ✅ StreamBuilder instead of FutureBuilder
// ─────────────────────────────────────────────
class _WorkerPayRow extends StatelessWidget {
  final WorkerModel worker;
  final FirestoreService fs;

  const _WorkerPayRow({required this.worker, required this.fs});

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0.00', 'fr_TN');

    // ✅ StreamBuilder — updates instantly when payments or attendance change
    return StreamBuilder<_WorkerSummary>(
      stream: _workerSummaryStreamFull(worker),
      builder: (_, snap) {
        final s = snap.data;
        return GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => WorkerPayDetailScreen(worker: worker, fs: fs),
            ),
          ),
          child: Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.04),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(children: [
              GradientAvatar(
                label: worker.name,
                colors: const [AppColors.primary, AppColors.secondary],
                size: 42,
                fontSize: 16,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(worker.name,
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary)),
                    const SizedBox(height: 3),
                    Text(
                      '${worker.role}  ·  ${worker.dailyRate.toStringAsFixed(0)} DT/day',
                      style: const TextStyle(
                          fontSize: 10, color: AppColors.textMuted),
                    ),
                    if (s != null) ...[
                      const SizedBox(height: 5),
                      Row(children: [
                        _MiniChip('${s.totalDays.toStringAsFixed(1)} days', AppColors.info),
                        const SizedBox(width: 6),
                        _MiniChip('Paid ${fmt.format(s.totalPaid)} DT', AppColors.success),
                      ]),
                    ],
                  ],
                ),
              ),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                if (s != null) ...[
                  Text(
                    '${fmt.format(s.remaining)} DT',
                    style: GoogleFonts.syne(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: s.remaining > 0 ? AppColors.danger : AppColors.success,
                    ),
                  ),
                  Text(
                    s.remaining > 0 ? 'remaining' : 'settled',
                    style: TextStyle(
                      fontSize: 9,
                      color: s.remaining > 0
                          ? AppColors.danger.withOpacity(0.7)
                          : AppColors.success.withOpacity(0.7),
                    ),
                  ),
                ],
                const SizedBox(height: 4),
                const Icon(Icons.chevron_right_rounded,
                    color: Colors.white24, size: 18),
              ]),
            ]),
          ),
        );
      },
    );
  }
}

class _MiniChip extends StatelessWidget {
  final String label;
  final Color color;
  const _MiniChip(this.label, this.color);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 9, color: color, fontWeight: FontWeight.w600)),
      );
}

// ═════════════════════════════════════════════
//  WORKER PAY DETAIL SCREEN
// ═════════════════════════════════════════════
class WorkerPayDetailScreen extends StatefulWidget {
  final WorkerModel worker;
  final FirestoreService fs;

  const WorkerPayDetailScreen({
    super.key,
    required this.worker,
    required this.fs,
  });

  @override
  State<WorkerPayDetailScreen> createState() =>
      _WorkerPayDetailScreenState();
}

class _WorkerPayDetailScreenState extends State<WorkerPayDetailScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;
  final fmt = NumberFormat('#,##0.00', 'fr_TN');

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Stack(children: [
        Positioned(top: -40, right: -30,
            child: _orb(180, AppColors.primary, 0.10)),
        Positioned.fill(child: CustomPaint(painter: _DotGridPainter())),

        SafeArea(child: Column(children: [

          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Row(children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: const Icon(Icons.arrow_back_ios_new_rounded,
                    color: Colors.white54, size: 18),
              ),
              const SizedBox(width: 12),
              GradientAvatar(
                label: widget.worker.name,
                colors: const [AppColors.primary, AppColors.secondary],
                size: 32,
                fontSize: 13,
              ),
              const SizedBox(width: 10),
              Expanded(
                  child: Text(widget.worker.name, style: AppText.heading(17))),
              GestureDetector(
                onTap: () => _showAddPaymentSheet(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.primary, AppColors.secondary],
                    ),
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.35),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.add, color: Colors.white, size: 14),
                    SizedBox(width: 4),
                    Text('Pay',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600)),
                  ]),
                ),
              ),
            ]),
          ),

          const SizedBox(height: 14),

          // ✅ StreamBuilder summary card — updates in real time
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: StreamBuilder<_WorkerSummary>(
              stream: _workerSummaryStreamFull(widget.worker),
              builder: (_, snap) => _WorkerSummaryCard(
                summary: snap.data,
                fmt: fmt,
                worker: widget.worker,
              ),
            ),
          ),

          const SizedBox(height: 14),

          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: TabBar(
              controller: _tabCtrl,
              indicator: BoxDecoration(
                color: AppColors.primary.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.primary.withOpacity(0.5)),
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              labelColor: AppColors.primary,
              unselectedLabelColor: AppColors.textMuted,
              labelStyle: GoogleFonts.syne(
                  fontSize: 11, fontWeight: FontWeight.w700),
              unselectedLabelStyle: const TextStyle(fontSize: 11),
              tabs: const [
                Tab(text: 'Payments'),
                Tab(text: 'Jobs'),
                Tab(text: 'Days'),
              ],
            ),
          ),

          const SizedBox(height: 12),

          Expanded(
            child: TabBarView(
              controller: _tabCtrl,
              children: [
                _PaymentHistoryTab(worker: widget.worker, fmt: fmt),
                _JobHistoryTab(worker: widget.worker, fs: widget.fs),
                _DaysWorkedTab(worker: widget.worker),
              ],
            ),
          ),
        ])),
      ]),
    );
  }

  void _showAddPaymentSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _AddPaymentSheet(worker: widget.worker),
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
//  Worker summary card  ✅ receives live data
// ─────────────────────────────────────────────
class _WorkerSummaryCard extends StatelessWidget {
  final _WorkerSummary? summary;
  final WorkerModel worker;
  final NumberFormat fmt;

  const _WorkerSummaryCard({
    required this.summary,
    required this.worker,
    required this.fmt,
  });

  @override
  Widget build(BuildContext context) {
    final totalDays   = summary?.totalDays   ?? 0;
    final totalEarned = summary?.totalEarned ?? 0;
    final totalPaid   = summary?.totalPaid   ?? 0;
    final remaining   = summary?.remaining   ?? 0;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
            colors: [Color(0xFF1C1200), Color(0xFF1A0800)]),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withOpacity(0.2)),
      ),
      child: Column(children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _Col('Days Worked', '${totalDays.toStringAsFixed(1)} j', AppColors.info),
            Container(width: 1, height: 40, color: Colors.white.withOpacity(0.08)),
            _Col('Total Earned', '${fmt.format(totalEarned)} DT', AppColors.primary),
            Container(width: 1, height: 40, color: Colors.white.withOpacity(0.08)),
            _Col('Paid', '${fmt.format(totalPaid)} DT', AppColors.success),
          ],
        ),
        const SizedBox(height: 10),
        const Divider(color: Color(0x12FFFFFF)),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Remaining Balance',
                style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500)),
            Text(
              '${fmt.format(remaining)} DT',
              style: GoogleFonts.syne(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: remaining > 0 ? AppColors.danger : AppColors.success,
              ),
            ),
          ],
        ),
      ]),
    );
  }
}

class _Col extends StatelessWidget {
  final String label, value;
  final Color color;
  const _Col(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) => Column(children: [
        Text(value,
            style: GoogleFonts.syne(
                fontSize: 13, fontWeight: FontWeight.w700, color: color)),
        const SizedBox(height: 3),
        Text(label,
            style: const TextStyle(fontSize: 9, color: AppColors.textMuted)),
      ]);
}

// ─────────────────────────────────────────────
//  Tab 1 — Payment history  ✅ StreamBuilder
// ─────────────────────────────────────────────
class _PaymentHistoryTab extends StatelessWidget {
  final WorkerModel worker;
  final NumberFormat fmt;

  const _PaymentHistoryTab({required this.worker, required this.fmt});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('manual_payments')
          .where('workerId', isEqualTo: worker.id)
          .snapshots(), // ✅ no orderBy — sort in Dart
      builder: (_, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
                color: AppColors.primary, strokeWidth: 2),
          );
        }
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) {
          return const EmptyState(
            icon: '💸',
            title: 'No payments yet',
            subtitle: 'Tap "+ Pay" to record a payment',
          );
        }

        // Sort by date descending in Dart
        final sorted = List.of(docs)
          ..sort((a, b) {
            final aDate = (a.data() as Map)['date'] as Timestamp;
            final bDate = (b.data() as Map)['date'] as Timestamp;
            return bDate.compareTo(aDate);
          });

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
          itemCount: sorted.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (_, i) {
            final p = ManualPayment.fromFirestore(sorted[i]);
            return _PaymentRow(payment: p, fmt: fmt)
                .animate()
                .fadeIn(delay: (i * 50).ms, duration: 250.ms);
          },
        );
      },
    );
  }
}

class _PaymentRow extends StatelessWidget {
  final ManualPayment payment;
  final NumberFormat fmt;
  const _PaymentRow({required this.payment, required this.fmt});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.success.withOpacity(0.05),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: AppColors.success.withOpacity(0.2)),
      ),
      child: Row(children: [
        Container(
          width: 38, height: 38,
          decoration: BoxDecoration(
            color: AppColors.success.withOpacity(0.12),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.payments_rounded,
              color: AppColors.success, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                payment.note.isNotEmpty ? payment.note : 'Payment',
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary),
              ),
              const SizedBox(height: 3),
              Text(
                DateFormat('dd MMM yyyy – HH:mm').format(payment.date),
                style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
              ),
            ],
          ),
        ),
        Text(
          '+${fmt.format(payment.amount)} DT',
          style: GoogleFonts.syne(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.success),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────
//  Tab 2 — Job history
// ─────────────────────────────────────────────
class _JobHistoryTab extends StatelessWidget {
  final WorkerModel worker;
  final FirestoreService fs;

  const _JobHistoryTab({required this.worker, required this.fs});

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0.00', 'fr_TN');
    return StreamBuilder<List<JobModel>>(
      stream: fs.watchJobs(),
      builder: (_, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
                color: AppColors.primary, strokeWidth: 2),
          );
        }
        final jobs = (snap.data ?? [])
            .where((j) => j.workerIds.contains(worker.id))
            .toList();

        if (jobs.isEmpty) {
          return const EmptyState(
            icon: '🔧',
            title: 'No jobs yet',
            subtitle: 'Worker has not been assigned to any job',
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
          itemCount: jobs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (_, i) => _JobRow(
            job: jobs[i],
            worker: worker,
            fmt: fmt,
          ).animate().fadeIn(delay: (i * 50).ms, duration: 250.ms),
        );
      },
    );
  }
}

class _JobRow extends StatelessWidget {
  final JobModel job;
  final WorkerModel worker;
  final NumberFormat fmt;

  const _JobRow({required this.job, required this.worker, required this.fmt});

  @override
  Widget build(BuildContext context) {
    // ✅ StreamBuilder for per-job days — updates when attendance changes
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('attendance')
          .where('workerId', isEqualTo: worker.id)
          .where('jobId',    isEqualTo: job.id)
          .where('present',  isEqualTo: true)
          .snapshots(),
      builder: (_, snap) {
        double days = 0;
        for (final doc in snap.data?.docs ?? []) {
          final a = AttendanceModel.fromFirestore(doc);
          days += a.daysValue;
        }
        final earned = days * worker.dailyRate;

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.04),
            borderRadius: BorderRadius.circular(13),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(children: [
            Container(
              width: 38, height: 38,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Center(
                  child: Text('⚡', style: TextStyle(fontSize: 16))),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(job.displayLabel,
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 3),
                  Text('📍 ${job.address}',
                      style: const TextStyle(
                          fontSize: 10, color: AppColors.textMuted)),
                ],
              ),
            ),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('${days.toStringAsFixed(1)} j',
                  style: GoogleFonts.syne(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.info)),
              Text('${fmt.format(earned)} DT',
                  style: const TextStyle(
                      fontSize: 10, color: AppColors.textMuted)),
              const SizedBox(height: 3),
              StatusBadge(
                label: job.status == JobStatus.active ? 'Active' : 'Done',
                color: job.status == JobStatus.active
                    ? AppColors.primary
                    : AppColors.success,
              ),
            ]),
          ]),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────
//  Tab 3 — Days worked log  ✅ StreamBuilder
// ─────────────────────────────────────────────
class _DaysWorkedTab extends StatelessWidget {
  final WorkerModel worker;
  const _DaysWorkedTab({required this.worker});

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0.00', 'fr_TN');

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('attendance')
          .where('workerId', isEqualTo: worker.id)
          .where('present',  isEqualTo: true)
          .snapshots(), // ✅ no orderBy — sort in Dart
      builder: (_, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
                color: AppColors.primary, strokeWidth: 2),
          );
        }
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) {
          return const EmptyState(
            icon: '📅',
            title: 'No days recorded yet',
            subtitle: 'Check-in days will appear here',
          );
        }

        // Sort by date descending in Dart
        final sorted = List.of(docs)
          ..sort((a, b) {
            final aDate = (a.data() as Map)['date'] as Timestamp;
            final bDate = (b.data() as Map)['date'] as Timestamp;
            return bDate.compareTo(aDate);
          });

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
          itemCount: sorted.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (_, i) {
            final a      = AttendanceModel.fromFirestore(sorted[i]);
            final earned = a.daysValue * worker.dailyRate;

            return Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.04),
                borderRadius: BorderRadius.circular(13),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(children: [
                Container(
                  width: 46, height: 46,
                  decoration: BoxDecoration(
                    color: AppColors.info.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(11),
                    border: Border.all(color: AppColors.info.withOpacity(0.2)),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        DateFormat('dd').format(a.date),
                        style: GoogleFonts.syne(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: AppColors.info),
                      ),
                      Text(
                        DateFormat('MMM').format(a.date).toUpperCase(),
                        style: const TextStyle(
                            fontSize: 8, color: AppColors.textMuted),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(DateFormat('EEEE').format(a.date),
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textPrimary)),
                      const SizedBox(height: 3),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(a.dayType.label,
                            style: const TextStyle(
                                fontSize: 9,
                                color: AppColors.primary,
                                fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                ),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text('${a.daysValue.toStringAsFixed(1)} j',
                      style: GoogleFonts.syne(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary)),
                  Text('${fmt.format(earned)} DT',
                      style: const TextStyle(
                          fontSize: 10, color: AppColors.textMuted)),
                ]),
              ]),
            ).animate().fadeIn(delay: (i * 40).ms, duration: 250.ms);
          },
        );
      },
    );
  }
}

// ─────────────────────────────────────────────
//  Add payment sheet
// ─────────────────────────────────────────────
class _AddPaymentSheet extends StatefulWidget {
  final WorkerModel worker;
  const _AddPaymentSheet({required this.worker});

  @override
  State<_AddPaymentSheet> createState() => _AddPaymentSheetState();
}

class _AddPaymentSheetState extends State<_AddPaymentSheet> {
  final _amountCtrl = TextEditingController();
  final _noteCtrl   = TextEditingController();
  bool _loading     = false;

  @override
  void dispose() {
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final amount = double.tryParse(_amountCtrl.text);
    if (amount == null || amount <= 0) return;
    setState(() => _loading = true);

    final payment = ManualPayment(
      id:       const Uuid().v4(),
      workerId: widget.worker.id,
      amount:   amount,
      note:     _noteCtrl.text.trim(),
      date:     DateTime.now(),
    );

    await FirebaseFirestore.instance
        .collection('manual_payments')
        .doc(payment.id)
        .set(payment.toMap());

    if (mounted) {
      setState(() => _loading = false);
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
            '✓  ${NumberFormat('#,##0.00', 'fr_TN').format(amount)} DT '
            'paid to ${widget.worker.name}'),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12)),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          24, 20, 24,
          MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
                width: 36, height: 4,
                decoration: BoxDecoration(
                    color: Colors.white12,
                    borderRadius: BorderRadius.circular(4))),
          ),
          const SizedBox(height: 20),

          Row(children: [
            GradientAvatar(
              label: widget.worker.name,
              colors: const [AppColors.primary, AppColors.secondary],
              size: 36,
              fontSize: 14,
            ),
            const SizedBox(width: 10),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Pay ${widget.worker.name}', style: AppText.heading(16)),
              Text(
                '${widget.worker.dailyRate.toStringAsFixed(0)} DT/day',
                style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
              ),
            ]),
          ]),

          const SizedBox(height: 20),

          Text('AMOUNT (DT)', style: AppText.label),
          const SizedBox(height: 8),
          TextField(
            controller: _amountCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            autofocus: true,
            style: GoogleFonts.syne(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: AppColors.primary),
            decoration: const InputDecoration(
              hintText: '0.00',
              hintStyle: TextStyle(color: AppColors.textMuted, fontSize: 28),
              suffixText: 'DT',
              suffixStyle: TextStyle(color: AppColors.textMuted, fontSize: 16),
              border: InputBorder.none,
            ),
          ),

          const Divider(color: Color(0x14FFFFFF)),
          const SizedBox(height: 12),

          Text('NOTE (optional)', style: AppText.label),
          const SizedBox(height: 8),
          TextField(
            controller: _noteCtrl,
            style: const TextStyle(color: AppColors.textPrimary),
            decoration: const InputDecoration(
              hintText: 'e.g. advance, week 1 pay…',
              prefixIcon: Icon(Icons.notes_rounded, color: Colors.white30, size: 18),
            ),
          ),

          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _loading ? null : _save,
              icon: _loading
                  ? const SizedBox(
                      width: 16, height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.black))
                  : const Icon(Icons.check_rounded, size: 18),
              label: const Text('Confirm Payment'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                textStyle: GoogleFonts.syne(
                    fontSize: 13, fontWeight: FontWeight.w700),
              ),
            ),
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