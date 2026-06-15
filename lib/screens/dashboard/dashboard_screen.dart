// lib/screens/dashboard/dashboard_screen.dart
import 'package:elecpro/screens/checkin/checkin_list_screen.dart';
import 'package:elecpro/screens/checkin/checkin_screen_2.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import '../../theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../services/firestore_service.dart';
import '../../models/models.dart';
import '../../widgets/shared_widgets.dart';
import '../workers/workers_screen.dart';
import '../clients/clients_screen.dart';
import '../pay/pay_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _navIndex = 0;
  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      const _HomeTab(),
      const WorkersScreen(standalone: false),
      const ClientsScreen(standalone: false),
      const CheckinListScreen(standalone: false),
      const PayScreen(standalone: false),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: IndexedStack(index: _navIndex, children: _pages),
      bottomNavigationBar: ElecBottomNav(
        currentIndex: _navIndex,
        onTap: (i) => setState(() => _navIndex = i),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Home Tab
// ─────────────────────────────────────────────
class _HomeTab extends StatelessWidget {
  const _HomeTab();

  @override
  Widget build(BuildContext context) {
    final fs = context.read<FirestoreService>();

    return ElecBackground(
      orbs: const [
        OrbConfig(size: 220, color: AppColors.primary, opacity: 0.12,
            top: -60, right: -40),
        OrbConfig(size: 160, color: AppColors.secondary, opacity: 0.10,
            bottom: 120, left: -30),
      ],
      child: SafeArea(
        child: RefreshIndicator(
          color: AppColors.primary,
          backgroundColor: AppColors.surface,
          onRefresh: () async {},
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            children: [
              _buildTopBar(context),
              const SizedBox(height: 20),

              // Stats
              FutureBuilder<Map<String, dynamic>>(
                future: fs.getDashboardStats(),
                builder: (ctx, snap) {
                  final data = snap.data;
                  return Row(children: [
                    StatCard(
                      value: '${data?['activeJobs'] ?? '-'}',
                      label: 'Active Jobs',
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 8),
                    StatCard(
                      value: '${data?['totalWorkers'] ?? '-'}',
                      label: 'Workers',
                      color: AppColors.info,
                    ),
                    const SizedBox(width: 8),
                    StatCard(
                      value: '${data?['totalClients'] ?? '-'}',
                      label: 'Clients',
                      color: AppColors.success,
                    ),
                  ]);
                },
              ),

              const SizedBox(height: 14),

              // Earnings
              FutureBuilder<Map<String, dynamic>>(
                future: fs.getDashboardStats(),
                builder: (ctx, snap) =>
                    _EarningsCard(data: snap.data),
              ),

              const SizedBox(height: 18),

              SectionHeader(
                title: 'Active Jobs',
                actionLabel: 'See all',
                onAction: () {},
              ),
              const SizedBox(height: 10),

              StreamBuilder<List<JobModel>>(
                stream: fs.watchActiveJobs(),
                builder: (ctx, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(20),
                        child: CircularProgressIndicator(
                            color: AppColors.primary, strokeWidth: 2),
                      ),
                    );
                  }
                  final jobs = snap.data ?? [];
                  if (jobs.isEmpty) {
                    return const EmptyState(
                      icon: '⚡',
                      title: 'No active jobs',
                      subtitle: 'Add a job from the Clients screen',
                    );
                  }
                  return Column(
                    children: jobs
                        .take(5)
                        .map((j) => _JobCard(job: j)
                            .animate()
                            .fadeIn(duration: 400.ms)
                            .slideX(begin: 0.05, end: 0))
                        .toList(),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    // ✅ Option B: no Firebase user — use static avatar label
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(_greeting(),
              style: const TextStyle(
                  fontSize: 12, color: AppColors.textMuted)),
          const SizedBox(height: 2),
          Text('Manager', style: AppText.heading(18)),
        ]),
        GestureDetector(
          onTap: () => _showProfileMenu(context),
          child: const GradientAvatar(
            label: 'M',
            colors: [AppColors.primary, AppColors.secondary],
            size: 38,
            fontSize: 16,
          ),
        ),
      ],
    );
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning 👋';
    if (h < 18) return 'Good afternoon 👋';
    return 'Good evening 👋';
  }

  void _showProfileMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
              width: 36, height: 4,
              decoration: BoxDecoration(
                  color: Colors.white12,
                  borderRadius: BorderRadius.circular(4))),
          const SizedBox(height: 20),
          Text('Account', style: AppText.heading(16)),
          const SizedBox(height: 20),
          ListTile(
            leading: const Icon(Icons.logout_rounded,
                color: AppColors.danger),
            title: const Text('Sign Out',
                style: TextStyle(color: AppColors.danger)),
            onTap: () {
              Navigator.pop(context);
              context.read<AuthProvider>().signOut();
            },
          ),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Earnings card
// ─────────────────────────────────────────────
class _EarningsCard extends StatelessWidget {
  final Map<String, dynamic>? data;
  const _EarningsCard({this.data});

  @override
  Widget build(BuildContext context) {
    final fmt     = NumberFormat('#,##0.00', 'fr_TN');
    final total   = data?['totalEarnings'] as double? ?? 0;
    final paid    = data?['totalPaid']     as double? ?? 0;
    final pending = data?['totalPending']  as double? ?? 0;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1C1200), Color(0xFF1A0800)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withOpacity(0.2)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('This Month — Earnings',
              style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.success.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text('↑ +12%',
                style: TextStyle(
                    fontSize: 9,
                    color: AppColors.success,
                    fontWeight: FontWeight.w600)),
          ),
        ]),
        const SizedBox(height: 6),
        Text('${fmt.format(total)} DT',
            style: GoogleFonts.syne(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: AppColors.primary)),
        const SizedBox(height: 10),
        const Divider(color: Color(0x14FFFFFF)),
        const SizedBox(height: 8),
        Row(children: [
          _EarnStat(label: 'Paid',
              value: '${fmt.format(paid)} DT',
              color: AppColors.success),
          const SizedBox(width: 20),
          _EarnStat(label: 'Pending',
              value: '${fmt.format(pending)} DT',
              color: AppColors.danger),
        ]),
      ]),
    );
  }
}

class _EarnStat extends StatelessWidget {
  final String label, value;
  final Color color;
  const _EarnStat(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value,
              style: GoogleFonts.syne(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: color)),
          Text(label,
              style: const TextStyle(
                  fontSize: 9, color: AppColors.textMuted)),
        ],
      );
}

// ─────────────────────────────────────────────
//  Job card
// ─────────────────────────────────────────────
class _JobCard extends StatelessWidget {
  final JobModel job;
  const _JobCard({required this.job});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(children: [
        Container(
          width: 36, height: 36,
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
              Text(job.title,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
              const SizedBox(height: 3),
              Text(
                '${job.workerIds.length} workers · ${job.address}',
                style: const TextStyle(
                    fontSize: 10, color: AppColors.textMuted),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
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
    );
  }
}
