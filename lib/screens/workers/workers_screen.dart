// lib/screens/workers/workers_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:uuid/uuid.dart';
import '../../theme/app_theme.dart';
import '../../services/firestore_service.dart';
import '../../models/models.dart';
import '../../widgets/shared_widgets.dart';
import '../pay/pay_screen.dart';

class WorkersScreen extends StatefulWidget {
  final bool standalone;
  const WorkersScreen({super.key, this.standalone = true});

  @override
  State<WorkersScreen> createState() => _WorkersScreenState();
}

class _WorkersScreenState extends State<WorkersScreen> {
  final _searchCtrl = TextEditingController();
  String _filter    = 'All';
  String _query     = '';
  final _filters    = ['All', 'Active', 'Off'];

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<WorkerModel> _applyFilter(List<WorkerModel> all) {
    var list = all;
    if (_query.isNotEmpty) {
      list = list.where((w) =>
          w.name.toLowerCase().contains(_query.toLowerCase()) ||
          w.role.toLowerCase().contains(_query.toLowerCase())).toList();
    }
    if (_filter == 'Active') list = list.where((w) => w.isActive).toList();
    if (_filter == 'Off')    list = list.where((w) => !w.isActive).toList();
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final fs = context.read<FirestoreService>();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(children: [
        if (widget.standalone)
          Positioned.fill(child: Container(color: AppColors.bg)),

        SafeArea(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // ── Top bar ──────────────────────
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
                    child: Text('Workers', style: AppText.heading(20))),
                StreamBuilder<List<WorkerModel>>(
                  stream: fs.watchWorkers(),
                  builder: (_, snap) => Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: AppColors.primary.withOpacity(0.3)),
                    ),
                    child: Text('${snap.data?.length ?? 0}',
                        style: const TextStyle(
                            color: AppColors.primary,
                            fontSize: 12,
                            fontWeight: FontWeight.w700)),
                  ),
                ),
              ]),
            ),

            const SizedBox(height: 14),

            // ── Search ───────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border),
                ),
                child: TextField(
                  controller: _searchCtrl,
                  style: const TextStyle(
                      color: AppColors.textPrimary, fontSize: 13),
                  onChanged: (v) => setState(() => _query = v),
                  decoration: const InputDecoration(
                    hintText: 'Search worker…',
                    hintStyle: TextStyle(
                        color: AppColors.textMuted, fontSize: 13),
                    prefixIcon: Icon(Icons.search_rounded,
                        color: AppColors.textMuted, size: 18),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 12),

            // ── Filter chips ─────────────────
            SizedBox(
              height: 34,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: _filters.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final f      = _filters[i];
                  final active = _filter == f;
                  return GestureDetector(
                    onTap: () => setState(() => _filter = f),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: active
                            ? AppColors.primary.withOpacity(0.15)
                            : Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: active
                              ? AppColors.primary.withOpacity(0.5)
                              : Colors.white.withOpacity(0.1),
                        ),
                      ),
                      child: Text(f,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: active
                                ? AppColors.primary
                                : AppColors.textMuted,
                          )),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 12),

            // ── Worker list ──────────────────
            Expanded(
              child: StreamBuilder<List<WorkerModel>>(
                stream: fs.watchWorkers(),
                builder: (ctx, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(
                          color: AppColors.primary, strokeWidth: 2),
                    );
                  }
                  final filtered = _applyFilter(snap.data ?? []);
                  if (filtered.isEmpty) {
                    return const EmptyState(
                      icon: '👷',
                      title: 'No workers found',
                      subtitle: 'Tap + to add a new worker',
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: 8),
                    itemBuilder: (_, i) => _WorkerCard(
                      worker: filtered[i],
                      onTap: () {
                        // ✅ FIXED: tap opens worker pay detail
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => WorkerPayDetailScreen(
                              worker: filtered[i],
                              fs: context.read<FirestoreService>(),
                            ),
                          ),
                        );
                      },
                      onEdit: () =>
                          _showWorkerSheet(context, worker: filtered[i]),
                      onDelete: () =>
                          _confirmDelete(context, filtered[i].id),
                    )
                        .animate()
                        .fadeIn(delay: (i * 60).ms, duration: 300.ms)
                        .slideX(begin: 0.05, end: 0),
                  );
                },
              ),
            ),
          ],
        )),

        // ── FAB ──────────────────────────────
        Positioned(
          bottom: 80, right: 20,
          child: GestureDetector(
            onTap: () => _showWorkerSheet(context),
            child: Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.primary, AppColors.secondary],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.4),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: const Icon(Icons.add, color: Colors.white, size: 24),
            ),
          ),
        ),
      ]),
    );
  }

  void _showWorkerSheet(BuildContext context, {WorkerModel? worker}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _WorkerFormSheet(existingWorker: worker),
    );
  }

  void _confirmDelete(BuildContext context, String id) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: Text('Delete Worker', style: AppText.heading(16)),
        content: const Text(
          'This will remove the worker permanently.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel',
                style: TextStyle(color: AppColors.textMuted)),
          ),
          TextButton(
            onPressed: () {
              context.read<FirestoreService>().deleteWorker(id);
              Navigator.pop(context);
            },
            child: const Text('Delete',
                style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Worker card — tap opens profile, long press options
// ─────────────────────────────────────────────
class _WorkerCard extends StatelessWidget {
  final WorkerModel worker;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _WorkerCard({
    required this.worker,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  Color get _avatarColor {
    final colors = [
      AppColors.primary,
      AppColors.info,
      AppColors.success,
      AppColors.danger,
    ];
    return colors[worker.name.length % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,                          // ✅ tap → open profile
      onLongPress: () => _showOptions(context), // long press → edit/delete
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(children: [
          GradientAvatar(
            label: worker.name,
            colors: [_avatarColor, AppColors.secondary],
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
                      color: AppColors.textPrimary,
                    )),
                const SizedBox(height: 3),
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
              worker.isActive ? 'Active' : 'Off',
              style: TextStyle(
                fontSize: 10,
                color: worker.isActive
                    ? AppColors.success
                    : AppColors.textMuted,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            // ✅ Arrow hint that it's tappable
            const Icon(Icons.chevron_right_rounded,
                color: Colors.white30, size: 18),
          ]),
        ]),
      ),
    );
  }

  void _showOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 8),
          Container(
              width: 36, height: 4,
              decoration: BoxDecoration(
                  color: Colors.white12,
                  borderRadius: BorderRadius.circular(4))),
          const SizedBox(height: 16),
          ListTile(
            leading: const Icon(Icons.edit_outlined,
                color: AppColors.info),
            title: const Text('Edit Worker',
                style: TextStyle(color: AppColors.textPrimary)),
            onTap: () { Navigator.pop(context); onEdit(); },
          ),
          ListTile(
            leading: const Icon(Icons.delete_outline_rounded,
                color: AppColors.danger),
            title: const Text('Delete Worker',
                style: TextStyle(color: AppColors.danger)),
            onTap: () { Navigator.pop(context); onDelete(); },
          ),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Worker form sheet — dailyRate
// ─────────────────────────────────────────────
class _WorkerFormSheet extends StatefulWidget {
  final WorkerModel? existingWorker;
  const _WorkerFormSheet({this.existingWorker});

  @override
  State<_WorkerFormSheet> createState() => _WorkerFormSheetState();
}

class _WorkerFormSheetState extends State<_WorkerFormSheet> {
  final _nameCtrl = TextEditingController();
  final _rateCtrl = TextEditingController();
  String _role    = 'Electrician';
  bool _isActive  = true;
  bool _loading   = false;
  final _roles    = ['Electrician', 'Technician', 'Helper'];

  @override
  void initState() {
    super.initState();
    final w = widget.existingWorker;
    if (w != null) {
      _nameCtrl.text = w.name;
      _rateCtrl.text = w.dailyRate.toStringAsFixed(0);
      _role          = w.role;
      _isActive      = w.isActive;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _rateCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_nameCtrl.text.isEmpty || _rateCtrl.text.isEmpty) return;
    setState(() => _loading = true);

    final fs     = context.read<FirestoreService>();
    final worker = WorkerModel(
      id:        widget.existingWorker?.id ?? const Uuid().v4(),
      name:      _nameCtrl.text.trim(),
      role:      _role,
      dailyRate: double.tryParse(_rateCtrl.text) ?? 0,
      isActive:  _isActive,
      createdAt: widget.existingWorker?.createdAt ?? DateTime.now(),
    );

    if (widget.existingWorker != null) {
      await fs.updateWorker(worker);
    } else {
      await fs.addWorker(worker);
    }

    if (mounted) {
      setState(() => _loading = false);
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existingWorker != null;

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
          Text(isEdit ? 'Edit Worker' : 'Add Worker',
              style: AppText.heading(18)),
          const SizedBox(height: 20),

          Text('FULL NAME', style: AppText.label),
          const SizedBox(height: 8),
          TextField(
            controller: _nameCtrl,
            style: const TextStyle(color: AppColors.textPrimary),
            decoration: const InputDecoration(
              hintText: 'Mohamed Ali',
              prefixIcon: Icon(Icons.person_outline_rounded,
                  color: Colors.white30, size: 18),
            ),
          ),
          const SizedBox(height: 16),

          Text('ROLE', style: AppText.label),
          const SizedBox(height: 8),
          Row(
            children: _roles.map((r) => Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _role = r),
                child: Container(
                  margin: EdgeInsets.only(
                      right: r != _roles.last ? 8 : 0),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: _role == r
                        ? AppColors.primary.withOpacity(0.15)
                        : Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _role == r
                          ? AppColors.primary.withOpacity(0.5)
                          : Colors.white.withOpacity(0.1),
                    ),
                  ),
                  child: Text(r,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: _role == r
                            ? AppColors.primary
                            : AppColors.textMuted,
                      )),
                ),
              ),
            )).toList(),
          ),
          const SizedBox(height: 16),

          Text('DAILY RATE (DT/day)', style: AppText.label),
          const SizedBox(height: 8),
          TextField(
            controller: _rateCtrl,
            keyboardType: TextInputType.number,
            style: const TextStyle(color: AppColors.textPrimary),
            decoration: const InputDecoration(
              hintText: '65',
              prefixIcon: Icon(Icons.payments_outlined,
                  color: Colors.white30, size: 18),
              suffixText: 'DT/day',
              suffixStyle: TextStyle(color: AppColors.textMuted),
            ),
          ),
          const SizedBox(height: 16),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Active',
                  style: TextStyle(
                      color: AppColors.textPrimary, fontSize: 14)),
              Switch(
                value: _isActive,
                onChanged: (v) => setState(() => _isActive = v),
                activeColor: AppColors.primary,
              ),
            ],
          ),
          const SizedBox(height: 20),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _loading ? null : _save,
              child: _loading
                  ? const SizedBox(
                      width: 20, height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.black))
                  : Text(isEdit ? 'Save Changes' : 'Add Worker'),
            ),
          ),
        ],
      ),
    );
  }
}
