import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/organization_model.dart';
import '../models/user_model.dart';
import '../services/bank_provider.dart';
import '../utils/theme.dart';
import '../widgets/glass_container.dart';
import '../widgets/bank_bar_chart.dart';
import 'auth_screen.dart';
import 'chat_screen.dart';
import 'release_history_screen.dart';
import 'global_analytics_screen.dart';
import 'global_community_thread_screen.dart';

class SuperAdminDashboardScreen extends StatefulWidget {
  const SuperAdminDashboardScreen({super.key});

  @override
  State<SuperAdminDashboardScreen> createState() => _SuperAdminDashboardScreenState();
}

class _SuperAdminDashboardScreenState extends State<SuperAdminDashboardScreen> {
  int _activeTabIndex = 0;
  final _phoneController = TextEditingController(text: 'owner');
  final _passwordController = TextEditingController(text: 'password');
  bool _obscurePassword = true;
  String _selectedOrgFilter = 'all';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<BankProvider>(context, listen: false);
      if (provider.user?.role == 'super_admin') {
        provider.refreshManagementData();
      }
    });
  }

  void _loginAsSuperAdmin() async {
    final provider = Provider.of<BankProvider>(context, listen: false);
    final success = await provider.login(
      _phoneController.text.trim(),
      _passwordController.text,
    );

    if (!mounted) return;
    if (success && provider.user?.role == 'super_admin') {
      provider.refreshManagementData();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Welcome, Site Owner / Super Admin')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(provider.errorMessage ?? 'Invalid Super Admin credentials')),
      );
    }
  }

  void _showOrgMembersDialog(OrganizationModel org) async {
    final provider = Provider.of<BankProvider>(context, listen: false);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final members = await provider.fetchOrgMembers(org.code);

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.colorScheme.surface,
        title: Row(
          children: [
            const Icon(Icons.apartment_rounded, color: BankTheme.accentPurple),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    org.name,
                    style: TextStyle(
                      color: isDark ? Colors.white : BankTheme.lightTextPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Code: ${org.code} • ${members.length} Members',
                    style: const TextStyle(fontSize: 11, color: BankTheme.textMuted),
                  ),
                ],
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: members.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Text(
                    'No members registered in this organization yet.',
                    style: TextStyle(color: isDark ? BankTheme.textMuted : BankTheme.lightTextSecondary),
                  ),
                )
              : ListView.separated(
                  shrinkWrap: true,
                  itemCount: members.length,
                  separatorBuilder: (context, index) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final member = members[index];
                    return ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        member.name,
                        style: TextStyle(
                          color: isDark ? Colors.white : BankTheme.lightTextPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      subtitle: Text(
                        '${member.phoneNumber} • ${member.role.toUpperCase()}',
                        style: TextStyle(
                          color: isDark ? BankTheme.textMuted : BankTheme.lightTextSecondary,
                          fontSize: 11,
                        ),
                      ),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'Savings: MK ${member.savings.toStringAsFixed(0)}',
                            style: const TextStyle(color: Colors.greenAccent, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            'Loan: MK ${member.loan.toStringAsFixed(0)}',
                            style: const TextStyle(color: Colors.orangeAccent, fontSize: 10),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CLOSE', style: TextStyle(color: BankTheme.accentPurple)),
          ),
        ],
      ),
    );
  }

  void _showSetShareDialog(OrganizationModel org) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    double currentShare = org.sharePercentage;
    final controller = TextEditingController(text: currentShare.toStringAsFixed(1));

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: theme.colorScheme.surface,
            title: Text(
              'MEMBER SHARE RATE',
              style: TextStyle(
                color: isDark ? Colors.white : BankTheme.lightTextPrimary,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Set member yield share percentage for ${org.name}.',
                  style: TextStyle(
                    color: isDark ? BankTheme.textMuted : BankTheme.lightTextSecondary,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: controller,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: TextStyle(color: isDark ? Colors.white : BankTheme.lightTextPrimary),
                  decoration: const InputDecoration(
                    labelText: 'Member Share (%)',
                    suffixText: '%',
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Note: Platform automatically reserves 5% for Organization Pool and 5% for Management Portal.',
                  style: TextStyle(color: Colors.amberAccent, fontSize: 10, height: 1.3),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('CANCEL', style: TextStyle(color: BankTheme.textMuted)),
              ),
              ElevatedButton(
                onPressed: () async {
                  final val = double.tryParse(controller.text);
                  if (val != null) {
                    final success = await Provider.of<BankProvider>(context, listen: false)
                        .updateOrganizationSharePercentage(org.code, val);
                    if (mounted) {
                      Navigator.pop(context);
                      if (success) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Updated share rate to $val% for ${org.name}')),
                        );
                      }
                    }
                  }
                },
                child: const Text('SAVE'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showResetConfirmation() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.colorScheme.surface,
        title: const Text('HARD SYSTEM RESET?', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
        content: Text(
          'WARNING: This will permanently wipe all organizations, users, transactions, and stats from the system. Proceed only if intended.',
          style: TextStyle(color: isDark ? Colors.white70 : BankTheme.lightTextSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('CANCEL', style: TextStyle(color: isDark ? BankTheme.textMuted : BankTheme.lightTextSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () async {
              final success = await Provider.of<BankProvider>(context, listen: false).resetSystem();
              if (!mounted) return;
              Navigator.pop(context);
              if (success) {
                Provider.of<BankProvider>(context, listen: false).refreshManagementData();
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('System has been completely reset.')));
              }
            },
            child: const Text('RESET SYSTEM', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final provider = Provider.of<BankProvider>(context);

    // Guard: Prompt for login if not Super Admin
    if (provider.user?.role != 'super_admin') {
      return _buildSuperAdminLoginForm(provider, theme, isDark);
    }

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        titleSpacing: 0,
        backgroundColor: theme.appBarTheme.backgroundColor,
        title: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(width: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Colors.amberAccent, BankTheme.accentPurple],
                  ),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'SUPER ADMIN',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: Colors.black,
                    letterSpacing: 1,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text('Management ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: theme.textTheme.titleLarge?.color)),
              const Text('Portal', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.amberAccent)),
            ],
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, size: 20, color: BankTheme.accentPurple),
            tooltip: 'Refresh Portal',
            onPressed: provider.refreshManagementData,
          ),
          IconButton(
            icon: const Icon(Icons.hub_rounded, size: 20, color: BankTheme.accentPurple),
            tooltip: 'Global Analytics',
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (context) => const GlobalAnalyticsScreen(),
            )),
          ),
          IconButton(
            icon: const Icon(Icons.forum_rounded, size: 20, color: Colors.amberAccent),
            tooltip: 'Global Community Forum',
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (context) => const GlobalCommunityThreadScreen(),
            )),
          ),
          IconButton(
            icon: Icon(
              provider.themeMode == ThemeMode.dark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
              color: BankTheme.textMuted,
            ),
            onPressed: provider.toggleTheme,
          ),
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert_rounded, color: BankTheme.textMuted),
            onSelected: (value) {
              if (value == 'analytics') {
                Navigator.of(context).push(MaterialPageRoute(builder: (context) => const GlobalAnalyticsScreen()));
              } else if (value == 'forum') {
                Navigator.of(context).push(MaterialPageRoute(builder: (context) => const GlobalCommunityThreadScreen()));
              } else if (value == 'releases') {
                Navigator.of(context).push(MaterialPageRoute(builder: (context) => const ReleaseHistoryScreen()));
              } else if (value == 'logout') {
                provider.logout();
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (context) => const AuthScreen()),
                  (route) => false,
                );
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                enabled: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Site Owner / Super Admin',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.amberAccent),
                    ),
                    Text(
                      'Role: Master Administrator',
                      style: TextStyle(fontSize: 10, color: BankTheme.statusYellow),
                    ),
                    Divider(),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'analytics',
                child: Row(
                  children: [
                    Icon(Icons.hub_rounded, size: 18, color: BankTheme.accentPurple),
                    SizedBox(width: 12),
                    Text('Global Analytics'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'forum',
                child: Row(
                  children: [
                    Icon(Icons.forum_rounded, size: 18, color: Colors.amberAccent),
                    SizedBox(width: 12),
                    Text('Community Forum'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'releases',
                child: Row(
                  children: [
                    Icon(Icons.cloud_done_rounded, size: 18),
                    SizedBox(width: 12),
                    Text('Releases'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.power_settings_new_rounded, size: 18, color: Colors.redAccent),
                    SizedBox(width: 12),
                    Text('Logout', style: TextStyle(color: Colors.redAccent)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Consumer<BankProvider>(
        builder: (context, provider, child) {
          return RefreshIndicator(
            onRefresh: provider.refreshManagementData,
            color: Colors.amberAccent,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Tab Navigation Bar
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildTab('Organizations & Approvals', 0),
                        _buildTab('Platform Analytics', 1),
                        _buildTab('Platform Members', 2),
                        _buildTab('System Maintenance', 3),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  if (_activeTabIndex == 0) _buildOrganizationsView(provider),
                  if (_activeTabIndex == 1) _buildAnalyticsView(provider),
                  if (_activeTabIndex == 2) _buildMembersView(provider),
                  if (_activeTabIndex == 3) _buildSystemMaintenanceView(provider),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSuperAdminLoginForm(BankProvider provider, ThemeData theme, bool isDark) {
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.amberAccent.withOpacity(0.1),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.amberAccent, width: 2),
                ),
                child: const Icon(Icons.admin_panel_settings_rounded, size: 48, color: Colors.amberAccent),
              ),
              const SizedBox(height: 20),
              Text(
                'Super Admin Management Portal',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : BankTheme.lightTextPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Exclusively for Site Owner & Master Administrators',
                style: TextStyle(color: isDark ? BankTheme.textMuted : BankTheme.lightTextSecondary, fontSize: 13),
              ),
              const SizedBox(height: 32),
              GlassContainer(
                padding: const EdgeInsets.all(28),
                child: Column(
                  children: [
                    TextFormField(
                      controller: _phoneController,
                      style: TextStyle(color: isDark ? Colors.white : BankTheme.lightTextPrimary),
                      decoration: const InputDecoration(
                        labelText: 'Super Admin Username / Phone',
                        hintText: 'e.g. owner or superadmin',
                        prefixIcon: Icon(Icons.person_rounded, color: Colors.amberAccent),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      style: TextStyle(color: isDark ? Colors.white : BankTheme.lightTextPrimary),
                      decoration: InputDecoration(
                        labelText: 'Password',
                        prefixIcon: const Icon(Icons.lock_rounded, color: Colors.amberAccent),
                        suffixIcon: IconButton(
                          icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, color: BankTheme.textMuted),
                          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.amberAccent,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        onPressed: provider.isLoading ? null : _loginAsSuperAdmin,
                        child: provider.isLoading
                            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                            : const Text('ACCESS MANAGEMENT PORTAL', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOrganizationsView(BankProvider provider) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final overview = provider.managementOverview;
    final orgs = provider.managementOrganizations;

    final pendingOrgs = orgs.where((o) => o.status == 'pending').toList();
    final approvedOrgs = orgs.where((o) => o.status == 'approved').toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Top Overview Metrics Row
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _buildStatCard('Total Orgs', '${overview?['totalOrganizations'] ?? approvedOrgs.length}', Colors.amberAccent),
            _buildStatCard('Pending Reviews', '${overview?['pendingOrganizationsCount'] ?? pendingOrgs.length}', Colors.orangeAccent),
            _buildStatCard('Total Members', '${overview?['totalMembers'] ?? 0}', BankTheme.accentPurple),
            _buildStatCard('Platform Savings', 'MK ${(overview?['totalSavings'] as num?)?.toStringAsFixed(0) ?? '0'}', Colors.greenAccent),
          ],
        ),
        const SizedBox(height: 28),

        // PENDING ORGANIZATIONS REVIEW SECTION
        if (pendingOrgs.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orangeAccent.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orangeAccent.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.notifications_active_rounded, color: Colors.orangeAccent, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '${pendingOrgs.length} New Organization Registration Request(s) Pending Approval',
                    style: const TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: pendingOrgs.length,
            itemBuilder: (context, index) {
              final org = pendingOrgs[index];
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                child: GlassContainer(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              org.name,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : BankTheme.lightTextPrimary,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.orangeAccent.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text('PENDING APPROVAL', style: TextStyle(color: Colors.orangeAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text('Code: ${org.code} • Expected Members: ${org.expectedMembers}', style: TextStyle(color: isDark ? BankTheme.textMuted : BankTheme.lightTextSecondary, fontSize: 12)),
                      Text('Contact Person: ${org.contactPerson} (${org.contactPhone})', style: TextStyle(color: isDark ? BankTheme.textMuted : BankTheme.lightTextSecondary, fontSize: 12)),
                      if (org.contactEmail.isNotEmpty)
                        Text('Email: ${org.contactEmail}', style: TextStyle(color: isDark ? BankTheme.textMuted : BankTheme.lightTextSecondary, fontSize: 12)),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                              icon: const Icon(Icons.check_circle_rounded, size: 18),
                              label: const Text('APPROVE & ACTIVATE'),
                              onPressed: () => provider.approveOrganization(org.id, true),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(foregroundColor: Colors.redAccent, side: const BorderSide(color: Colors.redAccent)),
                              icon: const Icon(Icons.cancel_rounded, size: 18),
                              label: const Text('REJECT'),
                              onPressed: () => provider.approveOrganization(org.id, false),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 28),
        ],

        // REGISTERED ORGANIZATIONS SECTION
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Active Organizations (${approvedOrgs.length})',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : BankTheme.lightTextPrimary),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (approvedOrgs.isEmpty)
          GlassContainer(
            padding: const EdgeInsets.all(32),
            child: Center(
              child: Text(
                'No active organizations registered yet.',
                style: TextStyle(color: isDark ? BankTheme.textMuted : BankTheme.lightTextSecondary),
              ),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: approvedOrgs.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final org = approvedOrgs[index];
              return GlassContainer(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: Colors.amberAccent.withOpacity(0.2),
                          child: Text(org.name[0].toUpperCase(), style: const TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                org.name,
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? Colors.white : BankTheme.lightTextPrimary),
                              ),
                              Text(
                                'Code: ${org.code} • Contact: ${org.contactPerson} (${org.contactPhone})',
                                style: TextStyle(color: isDark ? BankTheme.textMuted : BankTheme.lightTextSecondary, fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text('ACTIVE', style: TextStyle(color: Colors.greenAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    const Divider(height: 1),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildOrgMiniStat('Members', '${org.memberCount}'),
                        _buildOrgMiniStat('Savings', 'MK ${org.totalSavings.toStringAsFixed(0)}'),
                        _buildOrgMiniStat('Loans', 'MK ${org.totalLoans.toStringAsFixed(0)}'),
                        _buildOrgMiniStat('Member Share', '${org.sharePercentage.toStringAsFixed(1)}%'),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton.icon(
                          icon: const Icon(Icons.people_alt_rounded, size: 16, color: BankTheme.accentPurple),
                          label: const Text('View Members', style: TextStyle(fontSize: 12, color: BankTheme.accentPurple)),
                          onPressed: () => _showOrgMembersDialog(org),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          icon: const Icon(Icons.tune_rounded, size: 16, color: Colors.amberAccent),
                          label: const Text('Set Share %', style: TextStyle(fontSize: 12, color: Colors.amberAccent)),
                          style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.amberAccent)),
                          onPressed: () => _showSetShareDialog(org),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _buildAnalyticsView(BankProvider provider) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final summary = provider.globalSummary ?? provider.managementOverview;
    final orgs = provider.globalOrganizations;

    final List<Color> chartColors = [
      Colors.amberAccent,
      const Color(0xFF33FF99),
      const Color(0xFF33CCFF),
      const Color(0xFFFF3366),
      const Color(0xFFCC66FF),
    ];

    final List<BarData> chartData = orgs.asMap().entries.map((entry) {
      final index = entry.key;
      final org = entry.value;
      return BarData(
        name: org.name,
        value: org.totalSavings,
        color: chartColors[index % chartColors.length],
      );
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Platform Financial Analytics',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: isDark ? Colors.white : BankTheme.lightTextPrimary),
        ),
        const SizedBox(height: 8),
        Text(
          'System-wide metrics across all village bank organizations.',
          style: TextStyle(color: isDark ? BankTheme.textMuted : BankTheme.lightTextSecondary, fontSize: 13),
        ),
        const SizedBox(height: 24),

        // Management Share Card
        GlassContainer(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('MANAGEMENT PORTAL POOL (5% SHARE)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.amberAccent, letterSpacing: 1)),
                  const Icon(Icons.savings_rounded, color: Colors.amberAccent, size: 20),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'MK ${(summary?['platformManagementFund'] as num?)?.toStringAsFixed(2) ?? '0.00'}',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: isDark ? Colors.white : BankTheme.lightTextPrimary),
              ),
              const SizedBox(height: 4),
              const Text(
                'Accumulated platform management cuts from loan interest repayments across all village banks.',
                style: TextStyle(color: BankTheme.textMuted, fontSize: 11),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        GlassContainer(
          padding: const EdgeInsets.all(24),
          child: chartData.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(20),
                  child: Center(
                    child: Text('No organization data for comparison', style: TextStyle(color: isDark ? BankTheme.textMuted : BankTheme.lightTextSecondary)),
                  ),
                )
              : BankBarChart(data: chartData, title: 'ORGANIZATION SAVINGS RANKING'),
        ),
      ],
    );
  }

  Widget _buildMembersView(BankProvider provider) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final orgs = provider.managementOrganizations;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'All Registered Members',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: isDark ? Colors.white : BankTheme.lightTextPrimary),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // Filter Dropdown
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: isDark ? Colors.white10 : Colors.black.withOpacity(0.1)),
          ),
          child: DropdownButton<String>(
            value: _selectedOrgFilter,
            isExpanded: true,
            underline: const SizedBox(),
            dropdownColor: theme.colorScheme.surface,
            style: TextStyle(color: isDark ? Colors.white : BankTheme.lightTextPrimary),
            items: [
              const DropdownMenuItem(value: 'all', child: Text('Filter by Organization: All Organizations')),
              ...orgs.map((o) => DropdownMenuItem(value: o.code, child: Text(o.name))),
            ],
            onChanged: (val) {
              if (val != null) {
                setState(() => _selectedOrgFilter = val);
              }
            },
          ),
        ),
        const SizedBox(height: 20),

        FutureBuilder<List<UserInfo>>(
          future: provider.fetchOrgMembers(_selectedOrgFilter),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.all(40),
                child: Center(child: CircularProgressIndicator(color: Colors.amberAccent)),
              );
            }

            final members = snapshot.data ?? [];

            if (members.isEmpty) {
              return GlassContainer(
                padding: const EdgeInsets.all(32),
                child: Center(
                  child: Text('No members found in this selection.', style: TextStyle(color: isDark ? BankTheme.textMuted : BankTheme.lightTextSecondary)),
                ),
              );
            }

            return ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: members.length,
              separatorBuilder: (context, index) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final member = members[index];
                return GlassContainer(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: BankTheme.accentPurple.withOpacity(0.2),
                        child: Text(member.name[0].toUpperCase(), style: const TextStyle(color: BankTheme.accentPurple, fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(member.name, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: isDark ? Colors.white : BankTheme.lightTextPrimary)),
                            Text('${member.phoneNumber} • ${member.organizationId}', style: TextStyle(color: isDark ? BankTheme.textMuted : BankTheme.lightTextSecondary, fontSize: 12)),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('MK ${member.savings.toStringAsFixed(0)}', style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 13)),
                          Text('Loan: MK ${member.loan.toStringAsFixed(0)}', style: const TextStyle(color: Colors.orangeAccent, fontSize: 11)),
                        ],
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildSystemMaintenanceView(BankProvider provider) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Super Admin System Control',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: isDark ? Colors.white : BankTheme.lightTextPrimary),
        ),
        const SizedBox(height: 16),
        GlassContainer(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Master System Reset',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.redAccent),
              ),
              const SizedBox(height: 12),
              Text(
                'A master hard reset will erase all registered organizations, users, deposits, loans, and transaction history. Use with extreme caution.',
                style: TextStyle(color: isDark ? Colors.white70 : BankTheme.lightTextSecondary, height: 1.5),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent.withOpacity(0.15),
                    side: const BorderSide(color: Colors.redAccent),
                    foregroundColor: Colors.redAccent,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  icon: const Icon(Icons.delete_forever_rounded),
                  label: const Text('PERFORM MASTER HARD RESET', style: TextStyle(fontWeight: FontWeight.bold)),
                  onPressed: _showResetConfirmation,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTab(String label, int index) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    bool isActive = _activeTabIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _activeTabIndex = index),
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? Colors.amberAccent.withOpacity(0.2) : (isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05)),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isActive ? Colors.amberAccent : (isDark ? Colors.white10 : Colors.black.withOpacity(0.1))),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isActive ? Colors.amberAccent : (isDark ? BankTheme.textMuted : BankTheme.lightTextSecondary),
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(String label, String value, Color accentColor) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      width: (MediaQuery.of(context).size.width - 56) / 2,
      constraints: const BoxConstraints(minWidth: 150),
      child: GlassContainer(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(color: isDark ? BankTheme.textMuted : BankTheme.lightTextSecondary, fontSize: 11)),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: accentColor),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrgMiniStat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: BankTheme.textMuted, fontSize: 10)),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
      ],
    );
  }
}
