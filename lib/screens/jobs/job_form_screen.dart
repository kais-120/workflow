// lib/screens/jobs/job_form_screen.dart
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

class JobFormScreen extends StatefulWidget {
  final ClientModel client;
  final JobModel? existingJob;

  const JobFormScreen({
    super.key,
    required this.client,
    this.existingJob,
  });

  @override
  State<JobFormScreen> createState() => _JobFormScreenState();
}

class _JobFormScreenState extends State<JobFormScreen> {
  final _titleCtrl   = TextEditingController();
  final _addressCtrl = TextEditingController();

  DateTime _startDate = DateTime.now();
  final Set<String> _selectedWorkerIds = {};
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    final j = widget.existingJob;
    if (j != null) {
      _titleCtrl.text   = j.title;
      _addressCtrl.text = j.address;
      _startDate        = j.startDate;
      _selectedWorkerIds.addAll(j.workerIds);
    } else {
      _addressCtrl.text = widget.client.address;
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_titleCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Please enter a job title'),
        backgroundColor: AppColors.danger,
      ));
      return;
    }
    setState(() => _loading = true);

    final fs  = context.read<FirestoreService>();
    final job = JobModel(
      id:         widget.existingJob?.id ?? const Uuid().v4(),
      title:      _titleCtrl.text.trim(),
      clientId:   widget.client.id,
      clientName: widget.client.name,
      address:    _addressCtrl.text.trim(),
      status:     JobStatus.active,
      workerIds:  _selectedWorkerIds.toList(),
      startDate:  _startDate,
    );

    if (widget.existingJob != null) {
      await fs.updateJob(job);
    } else {
      await fs.addJob(job);
    }

    if (mounted) {
      setState(() => _loading = false);
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(widget.existingJob != null
            ? '✓  Job updated'
            : '✓  Job created'),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12)),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existingJob != null;
    final fs     = context.read<FirestoreService>();

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Stack(children: [
        Positioned(top: -40, right: -30,
            child: _orb(160, AppColors.primary, 0.10)),
        Positioned(bottom: 100, left: -20,
            child: _orb(120, AppColors.success, 0.08)),
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
                child: Text(isEdit ? 'Edit Job' : 'New Job',
                    style: AppText.heading(20)),
              ),
            ]),
          ),

          const SizedBox(height: 8),

          // Client badge
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.info.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: AppColors.info.withOpacity(0.25)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.person_outline_rounded,
                      color: AppColors.info, size: 12),
                  const SizedBox(width: 5),
                  Text(widget.client.name,
                      style: const TextStyle(
                          color: AppColors.info,
                          fontSize: 11,
                          fontWeight: FontWeight.w500)),
                ]),
              ),
            ]),
          ),

          const SizedBox(height: 16),

          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
              children: [

                // ── Title ─────────────────────
                Text('JOB TITLE', style: AppText.label),
                const SizedBox(height: 8),
                TextField(
                  controller: _titleCtrl,
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: const InputDecoration(
                    hintText: 'Full electrical wiring',
                    prefixIcon: Icon(Icons.bolt_rounded,
                        color: Colors.white30, size: 18),
                  ),
                ),

                const SizedBox(height: 16),

                // ── Address ───────────────────
                Text('SITE ADDRESS', style: AppText.label),
                const SizedBox(height: 8),
                TextField(
                  controller: _addressCtrl,
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: const InputDecoration(
                    hintText: 'La Marsa, Tunis',
                    prefixIcon: Icon(Icons.location_on_outlined,
                        color: Colors.white30, size: 18),
                  ),
                ),

                const SizedBox(height: 16),

                // ── Start date ────────────────
                Text('START DATE', style: AppText.label),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: _pickStartDate,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 14),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(children: [
                      const Icon(Icons.event_rounded,
                          color: Colors.white30, size: 18),
                      const SizedBox(width: 10),
                      Text(
                        DateFormat('dd MMMM yyyy').format(_startDate),
                        style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 13),
                      ),
                      const Spacer(),
                      const Icon(Icons.keyboard_arrow_down_rounded,
                          color: Colors.white30, size: 18),
                    ]),
                  ),
                ),

                const SizedBox(height: 24),

                // ── Info banner ───────────────
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.info.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: AppColors.info.withOpacity(0.2)),
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline_rounded,
                          color: AppColors.info, size: 16),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Attendance is recorded daily in the Check-in screen. '
                          'Pay is calculated from days worked × daily rate.',
                          style: TextStyle(
                              fontSize: 11,
                              color: AppColors.info,
                              height: 1.5),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // ── Assign workers ────────────
                SectionHeader(
                  title: 'Assign Workers',
                  actionLabel: _selectedWorkerIds.isEmpty
                      ? null
                      : '${_selectedWorkerIds.length} selected',
                ),
                const SizedBox(height: 10),

                StreamBuilder<List<WorkerModel>>(
                  stream: fs.watchWorkers(),
                  builder: (_, snap) {
                    final workers = snap.data ?? [];
                    if (workers.isEmpty) {
                      return const EmptyState(
                        icon: '👷',
                        title: 'No workers yet',
                        subtitle: 'Add workers first from the Workers tab',
                      );
                    }
                    return Column(
                      children: workers
                          .asMap()
                          .entries
                          .map((e) => _WorkerSelectRow(
                                worker: e.value,
                                selected: _selectedWorkerIds
                                    .contains(e.value.id),
                                onToggle: (v) => setState(() {
                                  if (v) {
                                    _selectedWorkerIds.add(e.value.id);
                                  } else {
                                    _selectedWorkerIds.remove(e.value.id);
                                  }
                                }),
                              )
                                  .animate()
                                  .fadeIn(
                                      delay: (e.key * 50).ms,
                                      duration: 250.ms))
                          .toList(),
                    );
                  },
                ),
              ],
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
                colors: [
                  AppColors.bg.withOpacity(0),
                  AppColors.bg,
                ],
              ),
            ),
            child: ElevatedButton.icon(
              onPressed: _loading ? null : _save,
              icon: _loading
                  ? const SizedBox(
                      width: 16, height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.black))
                  : const Icon(Icons.check_rounded, size: 18),
              label: Text(isEdit ? 'Save Changes' : 'Create Job'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.black,
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

  Future<void> _pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
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
      setState(() => _startDate = picked);
    }
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
//  Worker select row — ✅ uses dailyRate
// ─────────────────────────────────────────────
class _WorkerSelectRow extends StatelessWidget {
  final WorkerModel worker;
  final bool selected;
  final ValueChanged<bool> onToggle;

  const _WorkerSelectRow({
    required this.worker,
    required this.selected,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onToggle(!selected),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withOpacity(0.08)
              : Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(13),
          border: Border.all(
            color: selected
                ? AppColors.primary.withOpacity(0.4)
                : AppColors.border,
          ),
        ),
        child: Row(children: [
          GradientAvatar(
            label: worker.name,
            colors: selected
                ? [AppColors.primary, AppColors.secondary]
                : [Colors.white24, Colors.white12],
            size: 34,
            fontSize: 13,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(worker.name,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: selected
                          ? AppColors.textPrimary
                          : AppColors.textSecondary,
                    )),
                const SizedBox(height: 2),
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
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 22, height: 22,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: selected
                  ? AppColors.primary
                  : Colors.white.withOpacity(0.08),
              border: Border.all(
                color: selected
                    ? AppColors.primary
                    : Colors.white.withOpacity(0.15),
              ),
            ),
            child: selected
                ? const Icon(Icons.check_rounded,
                    color: Colors.black, size: 14)
                : null,
          ),
        ]),
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
