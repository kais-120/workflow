// lib/screens/checkin/checkin_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../theme/app_theme.dart';
import '../../services/firestore_service.dart';
import '../../models/models.dart';
import '../../widgets/shared_widgets.dart';

class CheckinScreen extends StatefulWidget {
  final bool standalone;
  const CheckinScreen({super.key, this.standalone = true,initialDate,readOnly});

  @override
  State<CheckinScreen> createState() => _CheckinScreenState();
}

class _CheckinScreenState extends State<CheckinScreen> {
  DateTime _selectedDate  = DateTime.now();
  bool _saving            = false;
  bool _loaded            = false;

  // key: "$workerId|$jobId" → _WorkerEntry
  final Map<String, _WorkerEntry> _entries = {};

  // All active jobs + all workers, loaded once
  List<JobModel>    _jobs    = [];
  List<WorkerModel> _workers = [];

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  // ── Load jobs + workers + existing attendance ──────────────────────
  Future<void> _loadAll() async {
    if (!mounted) return;
    setState(() { _loaded = false; _entries.clear(); });

    final fs = context.read<FirestoreService>();

    try {
      // Fetch jobs & workers in parallel
      final results = await Future.wait([
        fs.watchActiveJobs().first,
        fs.watchWorkers().first,
      ]);

      _jobs    = results[0] as List<JobModel>;
      _workers = results[1] as List<WorkerModel>;

      // For every (worker, job) pair, pre-fill with defaults
      for (final job in _jobs) {
        for (final wId in job.workerIds) {
          final key = _key(wId, job.id);
          _entries[key] = const _WorkerEntry(
            present: true,
            dayType: DayType.fullDay,
          );
        }
      }

      // Load existing attendance for all jobs on selected date
      final allAttendance = await Future.wait(
        _jobs.map((j) => fs.getAttendanceForJobOnDate(j.id, _selectedDate)),
      );

      for (var i = 0; i < _jobs.length; i++) {
        for (final rec in allAttendance[i]) {
          final key = _key(rec.workerId, _jobs[i].id);
          if (_entries.containsKey(key)) {
            _entries[key] = _WorkerEntry(
              present: rec.present,
              dayType: rec.dayType,
            );
          }
        }
      }
    } catch (e) {
      debugPrint('loadAll error: $e');
    } finally {
      if (mounted) setState(() => _loaded = true);
    }
  }

  String _key(String workerId, String jobId) => '$workerId|$jobId';

  // ── Save all entries across all jobs ──────────────────────────────
  Future<void> _saveAttendance() async {
    setState(() => _saving = true);
    final fs = context.read<FirestoreService>();

    // Group entries by jobId and save as batches
    for (final job in _jobs) {
      final records = job.workerIds
          .where((wId) => _entries.containsKey(_key(wId, job.id)))
          .map((wId) {
            final entry = _entries[_key(wId, job.id)]!;
            return AttendanceModel(
              id:       const Uuid().v4(),
              jobId:    job.id,
              workerId: wId,
              date:     _selectedDate,
              dayType:  entry.dayType,
              present:  entry.present,
            );
          }).toList();

      if (records.isNotEmpty) {
        await fs.saveAttendanceBatch(records);
      }
    }

    if (mounted) {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('✓  Attendance saved'),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
    }
  }

  // ── Stats across all jobs ─────────────────────────────────────────
  int get _presentCount =>
      _entries.values.where((e) => e.present).length;
  int get _absentCount =>
      _entries.values.where((e) => !e.present).length;
  double get _totalDays =>
      _entries.values
          .where((e) => e.present)
          .fold(0.0, (s, e) => s + e.dayType.multiplier);

  // ── Build worker list: each worker + their jobs ───────────────────
  // Returns a list of workers that have at least one active job today
  List<WorkerModel> get _activeWorkers {
    final assignedIds = _jobs
        .expand((j) => j.workerIds)
        .toSet();
    return _workers.where((w) => assignedIds.contains(w.id)).toList();
  }

  List<JobModel> _jobsForWorker(String workerId) =>
      _jobs.where((j) => j.workerIds.contains(workerId)).toList();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Stack(children: [
        Positioned(top: -40, right: -30,
            child: _orb(170, AppColors.success, 0.12)),
        Positioned(bottom: 80, left: -20,
            child: _orb(120, AppColors.primary, 0.10)),
        Positioned.fill(child: CustomPaint(painter: _DotGridPainter())),

        SafeArea(child: Column(children: [

          // ── Top bar ────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Row(children: [
              if (widget.standalone)
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Icon(Icons.arrow_back_ios_new_rounded,
                      color: Colors.white54, size: 18),
                ),
              if (widget.standalone) const SizedBox(width: 12),
              Expanded(
                  child: Text('Check-in', style: AppText.heading(20))),
              GestureDetector(
                onTap: _pickDate,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: AppColors.primary.withOpacity(0.3)),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.calendar_today_rounded,
                        color: AppColors.primary, size: 13),
                    const SizedBox(width: 5),
                    Text(
                      DateFormat('dd MMM').format(_selectedDate),
                      style: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 11,
                          fontWeight: FontWeight.w600),
                    ),
                  ]),
                ),
              ),
            ]),
          ),

          const SizedBox(height: 14),

          // ── Date card ──────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _DateCard(
              date: _selectedDate,
              presentCount: _presentCount,
              absentCount: _absentCount,
              totalDays: _totalDays,
            ),
          ),

          const SizedBox(height: 12),

          // ── Worker list ────────────────────────────────────────────
          Expanded(
            child: !_loaded
                ? const Center(
                    child: CircularProgressIndicator(
                        color: AppColors.primary, strokeWidth: 2))
                : _activeWorkers.isEmpty
                    ? const EmptyState(
                        icon: '👷',
                        title: 'No workers assigned',
                        subtitle: 'Assign workers to active jobs first',
                      )
                    : ListView.separated(
                        padding:
                            const EdgeInsets.fromLTRB(20, 0, 20, 120),
                        itemCount: _activeWorkers.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 12),
                        itemBuilder: (_, i) {
                          final worker = _activeWorkers[i];
                          final jobs   = _jobsForWorker(worker.id);

                          return _WorkerCard(
                            worker: worker,
                            jobs: jobs,
                            entries: {
                              for (final j in jobs)
                                j.id: _entries[_key(worker.id, j.id)] ??
                                    const _WorkerEntry(
                                      present: true,
                                      dayType: DayType.fullDay,
                                    ),
                            },
                            onPresentChanged: (jobId, v) => setState(() {
                              final key = _key(worker.id, jobId);
                              _entries[key] =
                                  (_entries[key] ?? const _WorkerEntry(
                                    present: true,
                                    dayType: DayType.fullDay,
                                  )).copyWith(present: v);
                            }),
                            onDayTypeChanged: (jobId, t) => setState(() {
                              final key = _key(worker.id, jobId);
                              _entries[key] =
                                  (_entries[key] ?? const _WorkerEntry(
                                    present: true,
                                    dayType: DayType.fullDay,
                                  )).copyWith(dayType: t);
                            }),
                          )
                              .animate()
                              .fadeIn(
                                  delay: (i * 60).ms, duration: 300.ms)
                              .slideX(begin: 0.04, end: 0);
                        },
                      ),
          ),
        ])),

        // ── Save button ────────────────────────────────────────────
        Positioned(
          bottom: 0, left: 0, right: 0,
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 30),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [AppColors.bg.withOpacity(0), AppColors.bg],
              ),
            ),
            child: ElevatedButton.icon(
              onPressed: _saving ? null : _saveAttendance,
              icon: _saving
                  ? const SizedBox(
                      width: 16, height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.black))
                  : const Icon(Icons.check_rounded, size: 18),
              label: const Text('Save Attendance'),
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
        ),
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

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: AppColors.primary,
            surface: AppColors.surface,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null && mounted) {
      setState(() => _selectedDate = picked);
      _loadAll();
    }
  }
}

// ─────────────────────────────────────────────
//  Worker card — shows worker info + one job row per job
// ─────────────────────────────────────────────
class _WorkerCard extends StatelessWidget {
  final WorkerModel worker;
  final List<JobModel> jobs;
  final Map<String, _WorkerEntry> entries; // jobId → entry
  final void Function(String jobId, bool) onPresentChanged;
  final void Function(String jobId, DayType) onDayTypeChanged;

  const _WorkerCard({
    required this.worker,
    required this.jobs,
    required this.entries,
    required this.onPresentChanged,
    required this.onDayTypeChanged,
  });

  bool get _anyPresent => entries.values.any((e) => e.present);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _anyPresent
            ? AppColors.success.withOpacity(0.04)
            : Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _anyPresent
              ? AppColors.success.withOpacity(0.18)
              : AppColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          // ── Worker header ──────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: Row(children: [
              GradientAvatar(
                label: worker.name,
                colors: _anyPresent
                    ? [AppColors.success, const Color(0xFF00A86B)]
                    : [Colors.white24, Colors.white12],
                size: 40,
                fontSize: 15,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(worker.name,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: _anyPresent
                              ? AppColors.textPrimary
                              : AppColors.textMuted,
                        )),
                    Text(
                      '${worker.role}  ·  '
                      '${worker.dailyRate.toStringAsFixed(0)} DT/day',
                      style: const TextStyle(
                          fontSize: 10, color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
              // Total earned badge
              _TotalEarnedBadge(worker: worker, entries: entries),
            ]),
          ),

          // Divider
          Divider(
              height: 1,
              color: Colors.white.withOpacity(0.06),
              indent: 12,
              endIndent: 12),

          // ── One row per job ────────────────────────────────────
          ...jobs.map((job) {
            final entry = entries[job.id] ??
                const _WorkerEntry(present: true, dayType: DayType.fullDay);
            return _JobAttendanceRow(
              worker: worker,
              entry: entry,
              onPresentChanged: (v) => onPresentChanged(job.id, v),
              onDayTypeChanged: (t) => onDayTypeChanged(job.id, t),
            );
          }),

          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Total earned badge
// ─────────────────────────────────────────────
class _TotalEarnedBadge extends StatelessWidget {
  final WorkerModel worker;
  final Map<String, _WorkerEntry> entries;

  const _TotalEarnedBadge({required this.worker, required this.entries});

  @override
  Widget build(BuildContext context) {
    final total = entries.values
        .where((e) => e.present)
        .fold(0.0, (s, e) => s + e.dayType.multiplier * worker.dailyRate);

    final fmt = NumberFormat('#,##0.00', 'fr_TN');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.success.withOpacity(0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.success.withOpacity(0.25)),
      ),
      child: Column(children: [
        Text(
          '${fmt.format(total)} DT',
          style: GoogleFonts.syne(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.success),
        ),
        const Text('today',
            style: TextStyle(fontSize: 8, color: AppColors.textMuted)),
      ]),
    );
  }
}

// ─────────────────────────────────────────────
//  One job row inside a worker card
// ─────────────────────────────────────────────
class _JobAttendanceRow extends StatelessWidget {
  final WorkerModel worker;
  final _WorkerEntry entry;
  final ValueChanged<bool> onPresentChanged;
  final ValueChanged<DayType> onDayTypeChanged;

  const _JobAttendanceRow({
    required this.worker,
    required this.entry,
    required this.onPresentChanged,
    required this.onDayTypeChanged,
  });

  @override
  Widget build(BuildContext context) {
    final fmt    = NumberFormat('#,##0.00', 'fr_TN');
    final earned = entry.present
        ? entry.dayType.multiplier * worker.dailyRate
        : 0.0;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.fromLTRB(8, 6, 8, 0),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: entry.present
            ? AppColors.primary.withOpacity(0.05)
            : Colors.white.withOpacity(0.02),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: entry.present
              ? AppColors.primary.withOpacity(0.2)
              : Colors.white.withOpacity(0.06),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          // Job label + present switch
          Row(children: [
            const Icon(Icons.work_outline_rounded,
                color: AppColors.textMuted, size: 13),
            const SizedBox(width: 6),
            
            // Earned mini badge (when absent show 0)
            if (!entry.present)
              const Text('Absent',
                  style: TextStyle(
                      fontSize: 10,
                      color: AppColors.danger,
                      fontWeight: FontWeight.w600)),
            if (entry.present)
              Text(
                '${fmt.format(earned)} DT',
                style: GoogleFonts.syne(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary),
              ),
            const SizedBox(width: 6),
            Transform.scale(
              scale: 0.8,
              child: Switch(
                value: entry.present,
                onChanged: onPresentChanged,
                activeColor: AppColors.success,
                inactiveThumbColor: Colors.white30,
                inactiveTrackColor: Colors.white10,
              ),
            ),
          ]),

          // Day type chips (only when present)
          if (entry.present) ...[
            const SizedBox(height: 8),
            Row(
              children: DayType.values.map((t) {
                final selected = entry.dayType == t;
                final isLast   = t == DayType.values.last;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => onDayTypeChanged(t),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      margin: EdgeInsets.only(right: isLast ? 0 : 6),
                      padding: const EdgeInsets.symmetric(vertical: 7),
                      decoration: BoxDecoration(
                        color: selected
                            ? AppColors.primary.withOpacity(0.18)
                            : Colors.white.withOpacity(0.04),
                        borderRadius: BorderRadius.circular(9),
                        border: Border.all(
                          color: selected
                              ? AppColors.primary.withOpacity(0.6)
                              : Colors.white.withOpacity(0.08),
                        ),
                      ),
                      child: Column(children: [
                        Text(t.shortLabel,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: selected
                                  ? AppColors.primary
                                  : AppColors.textMuted,
                            )),
                        Text(
                          '${fmt.format(t.multiplier * worker.dailyRate)} DT',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 8,
                            color: selected
                                ? AppColors.primary.withOpacity(0.8)
                                : AppColors.textMuted,
                          ),
                        ),
                      ]),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Date card
// ─────────────────────────────────────────────
class _DateCard extends StatelessWidget {
  final DateTime date;
  final int presentCount, absentCount;
  final double totalDays;

  const _DateCard({
    required this.date,
    required this.presentCount,
    required this.absentCount,
    required this.totalDays,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
            colors: [Color(0xFF001A10), Color(0xFF00120B)]),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.success.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(DateFormat('EEEE').format(date),
                style: GoogleFonts.syne(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Colors.white)),
            const SizedBox(height: 2),
            Text(DateFormat('dd MMMM yyyy').format(date),
                style: const TextStyle(
                    fontSize: 11, color: AppColors.textMuted)),
          ]),
          Row(children: [
            _StatPill('$presentCount', 'Present', AppColors.success),
            const SizedBox(width: 10),
            _StatPill('$absentCount', 'Absent', AppColors.danger),
            const SizedBox(width: 10),
            _StatPill(totalDays.toStringAsFixed(1), 'Days',
                AppColors.primary),
          ]),
        ],
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  final String value, label;
  final Color color;
  const _StatPill(this.value, this.label, this.color);

  @override
  Widget build(BuildContext context) => Column(children: [
        Text(value,
            style: GoogleFonts.syne(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: color)),
        Text(label,
            style: const TextStyle(
                fontSize: 8, color: AppColors.textMuted)),
      ]);
}

// ─────────────────────────────────────────────
//  Worker entry state
// ─────────────────────────────────────────────
class _WorkerEntry {
  final bool present;
  final DayType dayType;

  const _WorkerEntry({required this.present, required this.dayType});

  _WorkerEntry copyWith({bool? present, DayType? dayType}) => _WorkerEntry(
        present: present ?? this.present,
        dayType: dayType ?? this.dayType,
      );
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