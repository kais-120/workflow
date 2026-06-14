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
  const CheckinScreen({super.key, this.standalone = true});

  @override
  State<CheckinScreen> createState() => _CheckinScreenState();
}

class _CheckinScreenState extends State<CheckinScreen> {
  DateTime _selectedDate      = DateTime.now();
  JobModel? _selectedJob;
  bool _saving                = false;
  bool _loaded                = true;
  bool _loadingAttendance     = false;

  // workerId → _WorkerEntry
  final Map<String, _WorkerEntry> _entries = {};

  Future<void> _loadExistingAttendance() async {
    if (_selectedJob == null || _loadingAttendance) return;
    _loadingAttendance = true;
    if (mounted) setState(() { _loaded = false; _entries.clear(); });

    try {
      final fs       = context.read<FirestoreService>();
      final existing = await fs.getAttendanceForJobOnDate(
          _selectedJob!.id, _selectedDate);

      final map = { for (var a in existing) a.workerId: a };
      for (final wId in _selectedJob!.workerIds) {
        final rec = map[wId];
        _entries[wId] = _WorkerEntry(
          present: rec?.present ?? true,
          dayType: rec?.dayType ?? DayType.fullDay,
        );
      }
    } catch (e) {
      debugPrint('loadAttendance error: $e');
      if (_selectedJob != null) {
        for (final wId in _selectedJob!.workerIds) {
          _entries[wId] = const _WorkerEntry(
            present: true,
            dayType: DayType.fullDay,
          );
        }
      }
    } finally {
      _loadingAttendance = false;
      if (mounted) setState(() => _loaded = true);
    }
  }

  Future<void> _saveAttendance() async {
    if (_selectedJob == null) return;
    setState(() => _saving = true);

    final fs      = context.read<FirestoreService>();
    final records = _entries.entries.map((e) => AttendanceModel(
      id:       const Uuid().v4(),
      jobId:    _selectedJob!.id,
      workerId: e.key,
      date:     _selectedDate,
      dayType:  e.value.dayType,
      present:  e.value.present,
    )).toList();

    await fs.saveAttendanceBatch(records);

    if (mounted) {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('✓  Attendance saved'),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12)),
      ));
    }
  }

  int    get _presentCount => _entries.values.where((e) => e.present).length;
  int    get _absentCount  => _entries.values.where((e) => !e.present).length;
  double get _totalDays    => _entries.values
      .where((e) => e.present)
      .fold(0.0, (s, e) => s + e.dayType.multiplier);

  @override
  Widget build(BuildContext context) {
    final fs = context.read<FirestoreService>();

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Stack(children: [
        Positioned(top: -40, right: -30,
            child: _orb(170, AppColors.success, 0.12)),
        Positioned(bottom: 80, left: -20,
            child: _orb(120, AppColors.primary, 0.10)),
        Positioned.fill(child: CustomPaint(painter: _DotGridPainter())),

        SafeArea(child: Column(children: [

          // ── Top bar ──────────────────────────
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

          // ── Date card ────────────────────────
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

          // ── Job selector ─────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: StreamBuilder<List<JobModel>>(
              stream: fs.watchActiveJobs(),
              builder: (_, snap) {
                final jobs = snap.data ?? [];
                if (jobs.isEmpty) {
                  return Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(13),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: const Text('No active jobs',
                        style: TextStyle(
                            color: AppColors.textMuted, fontSize: 12)),
                  );
                }

                if (_selectedJob == null) {
                  _selectedJob = jobs.first;
                  Future.microtask(_loadExistingAttendance);
                } else {
                  final match =
                      jobs.where((j) => j.id == _selectedJob!.id);
                  if (match.isNotEmpty &&
                      !identical(match.first, _selectedJob)) {
                    _selectedJob = match.first;
                  }
                }

                final dropdownValue =
                    jobs.any((j) => j.id == _selectedJob?.id)
                        ? jobs.firstWhere(
                            (j) => j.id == _selectedJob!.id)
                        : null;

                return _JobDropdown(
                  jobs: jobs,
                  selected: dropdownValue,
                  onChanged: (job) {
                    setState(() => _selectedJob = job);
                    _loadExistingAttendance();
                  },
                );
              },
            ),
          ),

          const SizedBox(height: 12),

          // ── Worker list ──────────────────────
          Expanded(
            child: _selectedJob == null
                ? const EmptyState(
                    icon: '📋',
                    title: 'Select a job',
                    subtitle: 'Choose a job above to mark attendance',
                  )
                : !_loaded
                    ? const Center(
                        child: CircularProgressIndicator(
                            color: AppColors.primary, strokeWidth: 2))
                    : StreamBuilder<List<WorkerModel>>(
                        stream: fs.watchWorkers(),
                        builder: (_, snap) {
                          final workers = (snap.data ?? [])
                              .where((w) => _selectedJob!.workerIds
                                  .contains(w.id))
                              .toList();

                          if (workers.isEmpty) {
                            return const EmptyState(
                              icon: '👷',
                              title: 'No workers assigned',
                              subtitle:
                                  'Assign workers to this job first',
                            );
                          }

                          return ListView.separated(
                            padding: const EdgeInsets.fromLTRB(
                                20, 0, 20, 120),
                            itemCount: workers.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 10),
                            itemBuilder: (_, i) {
                              final w = workers[i];
                              final entry = _entries[w.id] ??
                                  const _WorkerEntry(
                                    present: true,
                                    dayType: DayType.fullDay,
                                  );

                              return _WorkerDayRow(
                                worker: w,
                                entry: entry,
                                onPresentChanged: (v) => setState(() =>
                                    _entries[w.id] =
                                        entry.copyWith(present: v)),
                                onDayTypeChanged: (t) => setState(() =>
                                    _entries[w.id] =
                                        entry.copyWith(dayType: t)),
                              )
                                  .animate()
                                  .fadeIn(
                                      delay: (i * 50).ms,
                                      duration: 300.ms)
                                  .slideX(begin: 0.04, end: 0);
                            },
                          );
                        },
                      ),
          ),
        ])),

        // ── Save button ───────────────────────
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
      _loadExistingAttendance();
    }
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
            _StatPill('${totalDays.toStringAsFixed(1)}', 'Days', AppColors.primary),
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
                fontSize: 16, fontWeight: FontWeight.w800, color: color)),
        Text(label,
            style: const TextStyle(fontSize: 8, color: AppColors.textMuted)),
      ]);
}

// ─────────────────────────────────────────────
//  Job dropdown — shows clientName + date
// ─────────────────────────────────────────────
class _JobDropdown extends StatelessWidget {
  final List<JobModel> jobs;
  final JobModel? selected;
  final ValueChanged<JobModel?> onChanged;

  const _JobDropdown(
      {required this.jobs, required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: AppColors.primary.withOpacity(0.3)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<JobModel>(
          value: selected,
          isExpanded: true,
          dropdownColor: AppColors.surface,
          icon: const Icon(Icons.keyboard_arrow_down_rounded,
              color: AppColors.textMuted),
          items: jobs
              .map((j) => DropdownMenuItem(
                    value: j,
                    // ✅ Shows "ClientName · dd/MM/yyyy"
                    child: Text(j.displayLabel,
                        style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 12)),
                  ))
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Worker day row — present toggle + day type selector
// ─────────────────────────────────────────────
class _WorkerDayRow extends StatelessWidget {
  final WorkerModel worker;
  final _WorkerEntry entry;
  final ValueChanged<bool> onPresentChanged;
  final ValueChanged<DayType> onDayTypeChanged;

  const _WorkerDayRow({
    required this.worker,
    required this.entry,
    required this.onPresentChanged,
    required this.onDayTypeChanged,
  });

  @override
  Widget build(BuildContext context) {
    final fmt     = NumberFormat('#,##0.00', 'fr_TN');
    final earned  = entry.present
        ? entry.dayType.multiplier * worker.dailyRate
        : 0.0;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: entry.present
            ? AppColors.success.withOpacity(0.05)
            : Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: entry.present
              ? AppColors.success.withOpacity(0.2)
              : AppColors.border,
        ),
      ),
      child: Column(children: [

        // ── Top: avatar + name + present toggle ──
        Row(children: [
          GradientAvatar(
            label: worker.name,
            colors: entry.present
                ? [AppColors.success, const Color(0xFF00A86B)]
                : [Colors.white24, Colors.white12],
            size: 38,
            fontSize: 15,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(worker.name,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: entry.present
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
          Switch(
            value: entry.present,
            onChanged: onPresentChanged,
            activeColor: AppColors.success,
            inactiveThumbColor: Colors.white30,
            inactiveTrackColor: Colors.white10,
          ),
        ]),

        // ── Day type chips (only when present) ──
        if (entry.present) ...[
          const SizedBox(height: 10),
          Row(children: [
            ...DayType.values.map((t) {
              final selected = entry.dayType == t;
              return Expanded(
                child: GestureDetector(
                  onTap: () => onDayTypeChanged(t),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    margin: EdgeInsets.only(
                        right: t != DayType.values.last ? 6 : 0),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: selected
                          ? AppColors.primary.withOpacity(0.18)
                          : Colors.white.withOpacity(0.04),
                      borderRadius: BorderRadius.circular(10),
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
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: selected
                                ? AppColors.primary
                                : AppColors.textMuted,
                          )),
                      Text(
                        '${fmt.format(t.multiplier * worker.dailyRate)} DT',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 9,
                          color: selected
                              ? AppColors.primary.withOpacity(0.8)
                              : AppColors.textMuted,
                        ),
                      ),
                    ]),
                  ),
                ),
              );
            }),
            const SizedBox(width: 8),
            // Earned badge
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.success.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: AppColors.success.withOpacity(0.25)),
              ),
              child: Column(children: [
                Text(
                  '${fmt.format(earned)} DT',
                  style: GoogleFonts.syne(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.success),
                ),
                const Text('earned',
                    style: TextStyle(
                        fontSize: 8, color: AppColors.textMuted)),
              ]),
            ),
          ]),
        ],
      ]),
    );
  }
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
  @override bool shouldRepaint(_) => false;
}
