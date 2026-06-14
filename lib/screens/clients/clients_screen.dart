// lib/screens/clients/clients_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:uuid/uuid.dart';
import '../../theme/app_theme.dart';
import '../../services/firestore_service.dart';
import '../../models/models.dart';
import '../../widgets/shared_widgets.dart';
import '../jobs/job_form_screen.dart';
import '../job_detail/job_detail_screen.dart';


class ClientsScreen extends StatefulWidget {
  final bool standalone;
  const ClientsScreen({super.key, this.standalone = true});

  @override
  State<ClientsScreen> createState() => _ClientsScreenState();
}

class _ClientsScreenState extends State<ClientsScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<ClientModel> _applySearch(List<ClientModel> all) {
    if (_query.isEmpty) return all;
    return all.where((c) =>
        c.name.toLowerCase().contains(_query.toLowerCase()) ||
        c.address.toLowerCase().contains(_query.toLowerCase())).toList();
  }

  @override
  Widget build(BuildContext context) {
    final fs = context.read<FirestoreService>();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(children: [
        Positioned(bottom: -40, right: -40,
            child: _orb(180, AppColors.success, 0.10)),
        Positioned(top: -30, left: -30,
            child: _orb(140, AppColors.info, 0.08)),
        Positioned.fill(child: CustomPaint(painter: _DotGridPainter())),

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
                    child: Text('Clients', style: AppText.heading(20))),
                GestureDetector(
                  onTap: () => _showClientSheet(context),
                  child: Container(
                    width: 32, height: 32,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppColors.primary, AppColors.secondary],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
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
                    child: const Icon(Icons.add,
                        color: Colors.white, size: 18),
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
                    hintText: 'Search client…',
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

            // ── Client list ──────────────────
            Expanded(
              child: StreamBuilder<List<ClientModel>>(
                stream: fs.watchClients(),
                builder: (_, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(
                          color: AppColors.primary, strokeWidth: 2),
                    );
                  }
                  final clients = _applySearch(snap.data ?? []);
                  if (clients.isEmpty) {
                    return const EmptyState(
                      icon: '👥',
                      title: 'No clients yet',
                      subtitle: 'Tap + to add your first client',
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
                    itemCount: clients.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: 10),
                    itemBuilder: (_, i) => _ClientCard(
                      client: clients[i],
                      onEdit: () =>
                          _showClientSheet(context, client: clients[i]),
                      onDelete: () =>
                          _confirmDelete(context, clients[i].id),
                      onAddJob: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              JobFormScreen(client: clients[i]),
                        ),
                      ),
                    )
                        .animate()
                        .fadeIn(delay: (i * 60).ms, duration: 350.ms)
                        .slideX(begin: 0.05, end: 0),
                  );
                },
              ),
            ),
          ],
        )),
      ]),
    );
  }

  void _showClientSheet(BuildContext context, {ClientModel? client}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _ClientFormSheet(existing: client),
    );
  }

  void _confirmDelete(BuildContext context, String id) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: Text('Delete Client', style: AppText.heading(16)),
        content: const Text(
          'This will remove the client and all associated data.',
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
              context.read<FirestoreService>().deleteClient(id);
              Navigator.pop(context);
            },
            child: const Text('Delete',
                style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
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
//  Client card
// ─────────────────────────────────────────────
class _ClientCard extends StatefulWidget {
  final ClientModel client;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onAddJob;

  const _ClientCard({
    required this.client,
    required this.onEdit,
    required this.onDelete,
    required this.onAddJob,
  });

  @override
  State<_ClientCard> createState() => _ClientCardState();
}

class _ClientCardState extends State<_ClientCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final fs = context.read<FirestoreService>();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(children: [

        GestureDetector(
          onTap: () => setState(() => _expanded = !_expanded),
          onLongPress: () => _showOptions(context),
          child: Padding(
            padding: const EdgeInsets.all(13),
            child: Row(children: [
              Container(
                width: 38, height: 38,
                decoration: BoxDecoration(
                  color: AppColors.info.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(11),
                  border: Border.all(
                      color: AppColors.info.withOpacity(0.2)),
                ),
                child: const Center(
                    child: Text('🏠',
                        style: TextStyle(fontSize: 16))),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.client.name,
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary)),
                    const SizedBox(height: 3),
                    Text('📍 ${widget.client.address}',
                        style: const TextStyle(
                            fontSize: 10,
                            color: AppColors.textMuted)),
                  ],
                ),
              ),
              StreamBuilder<List<JobModel>>(
                stream: fs.watchJobs(),
                builder: (_, snap) {
                  final jobs = (snap.data ?? [])
                      .where((j) => j.clientId == widget.client.id)
                      .toList();
                  return Row(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text('${jobs.length} jobs',
                          style: const TextStyle(
                              fontSize: 9,
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600)),
                    ),
                    const SizedBox(width: 8),
                    AnimatedRotation(
                      turns: _expanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: Colors.white30,
                          size: 18),
                    ),
                  ]);
                },
              ),
            ]),
          ),
        ),

        if (_expanded)
          StreamBuilder<List<JobModel>>(
            stream: fs.watchJobs(),
            builder: (_, snap) {
              final jobs = (snap.data ?? [])
                  .where((j) => j.clientId == widget.client.id)
                  .toList();

              return Column(children: [
                const Divider(color: Color(0x0AFFFFFF), height: 1),
                Padding(
                  padding: const EdgeInsets.fromLTRB(13, 10, 13, 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Jobs',
                          style: GoogleFonts.syne(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Colors.white60)),
                      GestureDetector(
                        onTap: widget.onAddJob,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color:
                                AppColors.success.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color: AppColors.success
                                    .withOpacity(0.3)),
                          ),
                          child: const Text('+ New Job',
                              style: TextStyle(
                                  fontSize: 10,
                                  color: AppColors.success,
                                  fontWeight: FontWeight.w600)),
                        ),
                      ),
                    ],
                  ),
                ),
                if (jobs.isEmpty)
                  const Padding(
                    padding: EdgeInsets.fromLTRB(13, 4, 13, 14),
                    child: Text('No jobs yet for this client.',
                        style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textMuted)),
                  )
                else
                  ...jobs.map((j) => _JobMiniCard(job: j)),
                const SizedBox(height: 8),
              ]);
            },
          ),
      ]),
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
            title: const Text('Edit Client',
                style: TextStyle(color: AppColors.textPrimary)),
            onTap: () {
              Navigator.pop(context);
              widget.onEdit();
            },
          ),
          ListTile(
            leading: const Icon(Icons.work_outline_rounded,
                color: AppColors.success),
            title: const Text('Add Job',
                style: TextStyle(color: AppColors.textPrimary)),
            onTap: () {
              Navigator.pop(context);
              widget.onAddJob();
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete_outline_rounded,
                color: AppColors.danger),
            title: const Text('Delete Client',
                style: TextStyle(color: AppColors.danger)),
            onTap: () {
              Navigator.pop(context);
              widget.onDelete();
            },
          ),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Mini job card — no progressPercent
// ─────────────────────────────────────────────
class _JobMiniCard extends StatelessWidget {
  final JobModel job;
  const _JobMiniCard({required this.job});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(context,
          MaterialPageRoute(
              builder: (_) => JobDetailScreen(job: job))),
      child: Container(
        margin: const EdgeInsets.fromLTRB(13, 0, 13, 7),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.03),
          borderRadius: BorderRadius.circular(11),
          border:
              Border.all(color: Colors.white.withOpacity(0.06)),
        ),
        child: Row(children: [
          const Text('⚡', style: TextStyle(fontSize: 13)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(job.title,
                    style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w500),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 3),
                // ✅ FIXED: removed progressPercent bar, show address instead
                Text(job.address,
                    style: const TextStyle(
                        fontSize: 9, color: AppColors.textMuted),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          const SizedBox(width: 10),
          StatusBadge(
            label: job.status == JobStatus.active ? 'Active' : 'Done',
            color: job.status == JobStatus.active
                ? AppColors.primary
                : AppColors.success,
          ),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Client form sheet
// ─────────────────────────────────────────────
class _ClientFormSheet extends StatefulWidget {
  final ClientModel? existing;
  const _ClientFormSheet({this.existing});

  @override
  State<_ClientFormSheet> createState() => _ClientFormSheetState();
}

class _ClientFormSheetState extends State<_ClientFormSheet> {
  final _nameCtrl    = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _phoneCtrl   = TextEditingController();
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    final c = widget.existing;
    if (c != null) {
      _nameCtrl.text    = c.name;
      _addressCtrl.text = c.address;
      _phoneCtrl.text   = c.phone;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _addressCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_nameCtrl.text.isEmpty) return;
    setState(() => _loading = true);

    final fs     = context.read<FirestoreService>();
    final client = ClientModel(
      id:        widget.existing?.id ?? const Uuid().v4(),
      name:      _nameCtrl.text.trim(),
      address:   _addressCtrl.text.trim(),
      phone:     _phoneCtrl.text.trim(),
      createdAt: widget.existing?.createdAt ?? DateTime.now(),
    );

    if (widget.existing != null) {
      await fs.updateClient(client);
    } else {
      await fs.addClient(client);
    }

    if (mounted) {
      setState(() => _loading = false);
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
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
          Text(isEdit ? 'Edit Client' : 'Add Client',
              style: AppText.heading(18)),
          const SizedBox(height: 20),

          Text('CLIENT NAME', style: AppText.label),
          const SizedBox(height: 8),
          TextField(
            controller: _nameCtrl,
            style: const TextStyle(color: AppColors.textPrimary),
            decoration: const InputDecoration(
              hintText: 'Ben Salah Family',
              prefixIcon: Icon(Icons.person_outline_rounded,
                  color: Colors.white30, size: 18),
            ),
          ),
          const SizedBox(height: 14),

          Text('ADDRESS', style: AppText.label),
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
          const SizedBox(height: 14),

          Text('PHONE', style: AppText.label),
          const SizedBox(height: 8),
          TextField(
            controller: _phoneCtrl,
            keyboardType: TextInputType.phone,
            style: const TextStyle(color: AppColors.textPrimary),
            decoration: const InputDecoration(
              hintText: '+216 XX XXX XXX',
              prefixIcon: Icon(Icons.phone_outlined,
                  color: Colors.white30, size: 18),
            ),
          ),
          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _loading ? null : _save,
              child: _loading
                  ? const SizedBox(
                      width: 20, height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.black))
                  : Text(isEdit ? 'Save Changes' : 'Add Client'),
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