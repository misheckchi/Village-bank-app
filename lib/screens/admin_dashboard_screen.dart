import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/user_model.dart';
import '../services/bank_provider.dart';
import '../utils/theme.dart';
import '../widgets/glass_container.dart';
import '../widgets/bank_bar_chart.dart';
import 'auth_screen.dart';
import 'chat_screen.dart';
import 'release_history_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  int _activeTabIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<BankProvider>(context, listen: false).refreshAdminData();
    });
  }

  void _showApprovalsDialog() {
    final provider = Provider.of<BankProvider>(context, listen: false);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (context) => Consumer<BankProvider>(
        builder: (context, provider, child) => AlertDialog(
          backgroundColor: theme.colorScheme.surface,
          title: Text('PENDING APPROVALS', style: TextStyle(color: isDark ? Colors.white : BankTheme.lightTextPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
          content: SizedBox(
            width: double.maxFinite,
            child: provider.pendingLoans.isEmpty
                ? Text('No pending requests', style: TextStyle(color: isDark ? BankTheme.textMuted : BankTheme.lightTextSecondary))
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: provider.pendingLoans.length,
                    itemBuilder: (context, index) {
                      final loan = provider.pendingLoans[index];
                      return ListTile(
                        title: Text('MK ${loan.amount.toStringAsFixed(2)}', style: TextStyle(color: isDark ? Colors.white : BankTheme.lightTextPrimary, fontWeight: FontWeight.bold)),
                        subtitle: Text('Interest: MK ${loan.interest.toStringAsFixed(2)} • By ${loan.requestedBy} on ${loan.date}', style: TextStyle(color: isDark ? BankTheme.textMuted : BankTheme.lightTextSecondary)),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.check_circle, color: Colors.greenAccent),
                              onPressed: () async {
                                final res = await provider.processLoan(loan.id, true);
                                if (res != null && res['phone'] != null) {
                                  final targetAccount = res['phone'];
                                  final amount = res['amount'];
                                  // National Bank of Malawi default bank transaction transfer USSD template
                                  final ussdCode = "*626*5*1*$targetAccount*$amount#";
                                  final Uri telUri = Uri.parse("tel:${ussdCode.replaceAll('#', '%23')}");
                                  
                                  if (await canLaunchUrl(telUri)) {
                                    await launchUrl(telUri);
                                  }
                                }
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.cancel, color: Colors.redAccent),
                              onPressed: () => provider.processLoan(loan.id, false),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('CLOSE', style: TextStyle(color: BankTheme.accentPurple))),
          ],
        ),
      ),
    );
  }

  void _showPayoutRequestsDialog() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (context) => Consumer<BankProvider>(
        builder: (context, provider, child) => AlertDialog(
          backgroundColor: theme.colorScheme.surface,
          title: Text('PAYOUT REQUESTS', style: TextStyle(color: isDark ? Colors.white : BankTheme.lightTextPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
          content: SizedBox(
            width: double.maxFinite,
            child: provider.pendingPayouts.isEmpty
                ? Text('No pending payout requests', style: TextStyle(color: isDark ? BankTheme.textMuted : BankTheme.lightTextSecondary))
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: provider.pendingPayouts.length,
                    itemBuilder: (context, index) {
                      final payout = provider.pendingPayouts[index];
                      return ListTile(
                        title: Text('MK ${payout['amount'].toStringAsFixed(2)}', style: TextStyle(color: isDark ? Colors.white : BankTheme.lightTextPrimary, fontWeight: FontWeight.bold)),
                        subtitle: Text('To: ${payout['requestedBy']} (${payout['requestedByPhone']})', style: TextStyle(color: isDark ? BankTheme.textMuted : BankTheme.lightTextSecondary, fontSize: 12)),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.send_rounded, color: Colors.orangeAccent),
                              tooltip: 'Process Payout (USSD)',
                              onPressed: () async {
                                final phone = payout['requestedByPhone'];
                                final amount = payout['amount'];
                                
                                final res = await provider.processPayout(payout['id'] ?? payout['_id'] ?? '', true);
                                if (res != null && res['phone'] != null) {
                                  final targetAccount = res['phone'];
                                  // National Bank of Malawi default bank transaction transfer USSD template
                                  final ussdCode = "*626*5*1*$targetAccount*$amount#";
                                  final Uri telUri = Uri.parse("tel:${ussdCode.replaceAll('#', '%23')}");
                                  
                                  if (await canLaunchUrl(telUri)) {
                                    await launchUrl(telUri);
                                  }
                                }
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.cancel, color: Colors.redAccent),
                              onPressed: () => provider.processPayout(payout['id'] ?? payout['_id'] ?? '', false),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('CLOSE', style: TextStyle(color: BankTheme.accentPurple))),
          ],
        ),
      ),
    );
  }

  void _showDepositRequestsDialog() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (context) => Consumer<BankProvider>(
        builder: (context, provider, child) => AlertDialog(
          backgroundColor: theme.colorScheme.surface,
          title: Text('PENDING DEPOSITS', style: TextStyle(color: isDark ? Colors.white : BankTheme.lightTextPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
          content: SizedBox(
            width: double.maxFinite,
            child: provider.pendingDeposits.isEmpty
                ? Text('No pending deposits', style: TextStyle(color: isDark ? BankTheme.textMuted : BankTheme.lightTextSecondary))
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: provider.pendingDeposits.length,
                    itemBuilder: (context, index) {
                      final deposit = provider.pendingDeposits[index];
                      return ListTile(
                        title: Text('MK ${deposit['amount'].toStringAsFixed(2)}', style: TextStyle(color: isDark ? Colors.white : BankTheme.lightTextPrimary, fontWeight: FontWeight.bold)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('By: ${deposit['ownerName']} (${deposit['owner']})', style: TextStyle(color: isDark ? BankTheme.textMuted : BankTheme.lightTextSecondary, fontSize: 11)),
                            GestureDetector(
                              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                                builder: (context) => ChatScreen(otherUserPhone: deposit['owner'] ?? '', otherUserName: deposit['ownerName'] ?? ''),
                              )),
                              child: const Padding(
                                padding: EdgeInsets.only(top: 4.0),
                                child: Text('View Proof in Chat', style: TextStyle(color: BankTheme.accentPurple, fontSize: 10, fontWeight: FontWeight.bold, decoration: TextDecoration.underline)),
                              ),
                            ),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.verified_rounded, color: Colors.greenAccent),
                              onPressed: () => provider.processDeposit(deposit['id'] ?? deposit['_id'] ?? '', true),
                            ),
                            IconButton(
                              icon: const Icon(Icons.cancel, color: Colors.redAccent),
                              onPressed: () => provider.processDeposit(deposit['id'] ?? deposit['_id'] ?? '', false),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('CLOSE', style: TextStyle(color: BankTheme.accentPurple))),
          ],
        ),
      ),
    );
  }

  void _showRepaymentRequestsDialog() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (context) => Consumer<BankProvider>(
        builder: (context, provider, child) => AlertDialog(
          backgroundColor: theme.colorScheme.surface,
          title: Text('PENDING REPAYMENTS', style: TextStyle(color: isDark ? Colors.white : BankTheme.lightTextPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
          content: SizedBox(
            width: double.maxFinite,
            child: provider.pendingRepayments.isEmpty
                ? Text('No pending repayments', style: TextStyle(color: isDark ? BankTheme.textMuted : BankTheme.lightTextSecondary))
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: provider.pendingRepayments.length,
                    itemBuilder: (context, index) {
                      final repayment = provider.pendingRepayments[index];
                      return ListTile(
                        title: Text('MK ${repayment['amount'].toStringAsFixed(2)}', style: TextStyle(color: isDark ? Colors.white : BankTheme.lightTextPrimary, fontWeight: FontWeight.bold)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('By: ${repayment['ownerName']} (${repayment['owner']})', style: TextStyle(color: isDark ? BankTheme.textMuted : BankTheme.lightTextSecondary, fontSize: 11)),
                            Text('TID: ${repayment['transactionId']}', style: const TextStyle(color: BankTheme.accentPurple, fontSize: 11)),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.verified_rounded, color: Colors.greenAccent),
                              onPressed: () => provider.processRepayment(repayment['id'] ?? repayment['_id'], true),
                            ),
                            IconButton(
                              icon: const Icon(Icons.cancel, color: Colors.redAccent),
                              onPressed: () => provider.processRepayment(repayment['id'] ?? repayment['_id'], false),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('CLOSE', style: TextStyle(color: BankTheme.accentPurple))),
          ],
        ),
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
        title: const Text('HARD RESET SYSTEM?', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
        content: Text('This will wipe all users, transactions, and stats. This action cannot be undone.', style: TextStyle(color: isDark ? Colors.white70 : BankTheme.lightTextSecondary)),
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
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('System has been reset.')));
              }
            },
            child: const Text('RESET EVERYTHING', style: TextStyle(color: Colors.white)),
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
    
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        titleSpacing: 0,
        backgroundColor: theme.appBarTheme.backgroundColor,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(width: 16),
            // Mini Brand Icon
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                border: Border.all(color: BankTheme.accentPurple, width: 1.5),
                borderRadius: BorderRadius.circular(4),
              ),
              child: RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: 'V',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        color: isDark ? Colors.white : BankTheme.lightTextPrimary,
                      ),
                    ),
                    const TextSpan(
                      text: 'B',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        color: BankTheme.accentPurple,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text('Village ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: theme.textTheme.titleLarge?.color)),
            const Text('Bank', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: BankTheme.accentPurple)),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.group_rounded, size: 20, color: BankTheme.textMuted),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (context) => const ChatScreen(otherUserPhone: 'group', otherUserName: 'Community Group Chat'),
            )),
          ),
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert_rounded, color: BankTheme.textMuted),
            onSelected: (value) {
              if (value == 'theme') {
                provider.toggleTheme();
              } else if (value == 'releases') {
                Navigator.of(context).push(MaterialPageRoute(builder: (context) => const ReleaseHistoryScreen()));
              } else if (value == 'logout') {
                Provider.of<BankProvider>(context, listen: false).logout();
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
                      'Administrator',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    Text(
                      'Status: Active',
                      style: TextStyle(fontSize: 10, color: BankTheme.statusYellow),
                    ),
                    Divider(),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'theme',
                child: Row(
                  children: [
                    Icon(provider.themeMode == ThemeMode.dark ? Icons.light_mode_rounded : Icons.dark_mode_rounded, size: 18),
                    const SizedBox(width: 12),
                    Text(provider.themeMode == ThemeMode.dark ? 'Light Mode' : 'Dark Mode'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'releases',
                child: Row(
                  children: [
                    Icon(Icons.cloud_done_rounded, size: 18),
                    const SizedBox(width: 12),
                    Text('Releases'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.power_settings_new_rounded, size: 18, color: Colors.redAccent),
                    const SizedBox(width: 12),
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
            onRefresh: provider.refreshAdminData,
            color: BankTheme.accentPurple,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Tabs Section - ONLY Dashboard, User Database, Add User
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildTab('Dashboard', 0),
                        _buildTab('User Database', 1),
                        _buildTab('Analytics', 4),
                        _buildTab('Add User', 2),
                        _buildTab('Reset System', 3),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  if (_activeTabIndex == 0) _buildDashboardView(provider),
                  if (_activeTabIndex == 1) _buildUserDatabaseView(provider),
                  if (_activeTabIndex == 2) _buildAddUserView(provider),
                  if (_activeTabIndex == 3) _buildResetSystemView(provider),
                  if (_activeTabIndex == 4) _buildAnalyticsView(provider),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildAnalyticsView(BankProvider provider) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    final List<Color> chartColors = [
      const Color(0xFFFF3366),
      const Color(0xFF33FF99),
      const Color(0xFF33CCFF),
      const Color(0xFFFFCC33),
      const Color(0xFFCC66FF),
      const Color(0xFFFF6633),
    ];

    final members = provider.users.where((u) => u.role == 'member').toList();
    final List<BarData> chartData = members.asMap().entries.map((entry) {
      final index = entry.key;
      final user = entry.value;
      return BarData(
        name: user.name,
        value: user.savings,
        color: chartColors[index % chartColors.length],
      );
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Wealth Distribution',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: isDark ? Colors.white : BankTheme.lightTextPrimary),
        ),
        const SizedBox(height: 8),
        Text(
          'Comparison of member savings within the community pool.',
          style: TextStyle(color: isDark ? BankTheme.textMuted : BankTheme.lightTextSecondary, fontSize: 14),
        ),
        const SizedBox(height: 32),
        GlassContainer(
          padding: const EdgeInsets.all(24),
          child: chartData.isEmpty
              ? Text('No member data available', style: TextStyle(color: isDark ? BankTheme.textMuted : BankTheme.lightTextSecondary))
              : BankBarChart(data: chartData, title: 'TOP SAVERS'),
        ),
        const SizedBox(height: 32),
        Text(
          'Financial Insights',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : BankTheme.lightTextPrimary),
        ),
        const SizedBox(height: 16),
        _buildInsightTile(
          'Top Contributor',
          members.isEmpty ? 'N/A' : members.reduce((a, b) => a.savings > b.savings ? a : b).name,
          Icons.star_rounded,
        ),
        const SizedBox(height: 12),
        _buildInsightTile(
          'Loan Utilization',
          '${((provider.adminStats?.totalLoans ?? 0) / (provider.adminStats?.groupFund ?? 1) * 100).toStringAsFixed(1)}% of fund is currently lent out',
          Icons.account_balance_wallet_rounded,
        ),
      ],
    );
  }

  Widget _buildInsightTile(String title, String value, IconData icon) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.03) : Colors.black.withOpacity(0.03),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isDark ? Colors.white10 : Colors.black.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          Icon(icon, color: BankTheme.accentPurple, size: 20),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(color: isDark ? BankTheme.textMuted : BankTheme.lightTextSecondary, fontSize: 12)),
                Text(value, style: TextStyle(color: isDark ? Colors.white : BankTheme.lightTextPrimary, fontWeight: FontWeight.bold, fontSize: 14)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResetSystemView(BankProvider provider) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'System Maintenance',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: isDark ? Colors.white : BankTheme.lightTextPrimary),
        ),
        const SizedBox(height: 24),
        GlassContainer(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Danger Zone',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.redAccent),
              ),
              const SizedBox(height: 12),
              Text(
                'Executing a hard reset will immediately wipe all member accounts, transaction history, and group statistics. This is intended for development testing only.',
                style: TextStyle(color: isDark ? Colors.white70 : BankTheme.lightTextSecondary, height: 1.5),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent.withOpacity(0.1),
                    side: const BorderSide(color: Colors.redAccent),
                    foregroundColor: Colors.redAccent,
                  ),
                  onPressed: _showResetConfirmation,
                  child: const Text('PERFORM HARD RESET'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDashboardView(BankProvider provider) {
    final stats = provider.adminStats;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Stats Cards Wrap
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            _buildStatCard('Total Users', stats?.totalMembers.toString() ?? '0'),
            _buildStatCard('Total Savings', 'MK ${stats?.groupFund.toStringAsFixed(2) ?? '0.00'}'),
            _buildStatCard('Total Loans', 'MK ${stats?.totalLoans.toStringAsFixed(2) ?? '0.00'}'),
            _buildStatCard('Bank Earnings (5%)', 'MK ${stats?.bankCommission.toStringAsFixed(2) ?? '0.00'}'),
          ],
        ),
        const SizedBox(height: 32),

        // Quick Overview Section
        GlassContainer(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Quick Overview',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : BankTheme.lightTextPrimary),
              ),
              const SizedBox(height: 16),
              Text(
                'The frontend dashboard shows a summary of the current user database. Manage your village bank ecosystem efficiently.',
                style: TextStyle(color: isDark ? Colors.white70 : BankTheme.lightTextSecondary, fontSize: 14, height: 1.5),
              ),
              const SizedBox(height: 40),
              
              Text(
                'CRITICAL MODULES',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: isDark ? BankTheme.textMuted : BankTheme.lightTextSecondary, letterSpacing: 2),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  _buildActionTile(
                    Icons.verified_user, 
                    'APPROVALS', 
                    '${stats?.pendingApprovals ?? 0} PENDING',
                    onTap: _showApprovalsDialog,
                  ),
                  const SizedBox(width: 16),
                  _buildActionTile(
                    Icons.add_task_rounded,
                    'DEPOSITS',
                    '${provider.pendingDeposits.length} PENDING',
                    onTap: _showDepositRequestsDialog,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  _buildActionTile(
                    Icons.account_balance_wallet, 
                    'PAYOUTS', 
                    '${provider.pendingPayouts.length} REQUESTS',
                    onTap: _showPayoutRequestsDialog,
                  ),
                  const SizedBox(width: 16),
                  _buildActionTile(
                    Icons.price_check_rounded, 
                    'REPAYMENTS', 
                    '${provider.pendingRepayments.length} PENDING',
                    onTap: _showRepaymentRequestsDialog,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  _buildActionTile(
                    Icons.bar_chart, 
                    'ANALYTICS', 
                    'REAL-TIME',
                    onTap: () => setState(() => _activeTabIndex = 4),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(child: SizedBox()),
                ],
              ),
              const SizedBox(height: 32),
              
              // New Bar Chart Preview on Main Dashboard
              Text(
                'TOP SAVERS',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: isDark ? BankTheme.textMuted : BankTheme.lightTextSecondary, letterSpacing: 2),
              ),
              const SizedBox(height: 16),
              _buildBarChartPreview(provider),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBarChartPreview(BankProvider provider) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final List<Color> chartColors = [
      const Color(0xFFFF3366),
      const Color(0xFF33FF99),
      const Color(0xFF33CCFF),
      const Color(0xFFFFCC33),
      const Color(0xFFCC66FF),
    ];

    final members = provider.users.where((u) => u.role == 'member').toList();
    final List<BarData> chartData = members.asMap().entries.map((entry) {
      final index = entry.key;
      final user = entry.value;
      return BarData(
        name: user.name,
        value: user.savings,
        color: chartColors[index % chartColors.length],
      );
    }).toList();

    if (chartData.isEmpty) return Text('No data', style: TextStyle(color: isDark ? BankTheme.textMuted : BankTheme.lightTextSecondary));

    return BankBarChart(data: chartData, title: 'Contribution Ranking');
  }

  Widget _buildUserDatabaseView(BankProvider provider) {
    final users = provider.users;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'User Database',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: isDark ? Colors.white : BankTheme.lightTextPrimary),
        ),
        const SizedBox(height: 16),
        if (users.isEmpty)
          Center(child: Padding(padding: const EdgeInsets.all(40), child: Text('No users found.', style: TextStyle(color: isDark ? BankTheme.textMuted : BankTheme.lightTextSecondary))))
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: users.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final user = users[index];
              return GlassContainer(
                hasPurpleTopBorder: false,
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: BankTheme.accentPurple.withOpacity(0.2),
                      child: Text(user.name[0].toUpperCase(), style: const TextStyle(color: BankTheme.accentPurple, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(user.name, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? Colors.white : BankTheme.lightTextPrimary)),
                          Text(user.phoneNumber, style: TextStyle(color: isDark ? BankTheme.textMuted : BankTheme.lightTextSecondary, fontSize: 13)),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              _buildMiniIndividualStat('Savings', 'MK ${user.savings.toStringAsFixed(0)}', BankTheme.accentPurple),
                              const SizedBox(width: 12),
                              _buildMiniIndividualStat('Principal', 'MK ${user.loan.toStringAsFixed(0)}', Colors.orangeAccent),
                              const SizedBox(width: 12),
                              _buildMiniIndividualStat('Interest', 'MK ${user.interest.toStringAsFixed(0)}', Colors.redAccent),
                            ],
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.chat_bubble_outline_rounded, color: BankTheme.accentPurple, size: 20),
                      onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (context) => ChatScreen(otherUserPhone: user.phoneNumber, otherUserName: user.name),
                      )),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: user.role == 'admin' ? BankTheme.statusYellow.withOpacity(0.1) : Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        user.role.toUpperCase(),
                        style: TextStyle(
                          color: user.role == 'admin' ? BankTheme.statusYellow : Colors.blue,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _buildAddUserView(BankProvider provider) {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final passwordController = TextEditingController();
    bool isAdmin = false;

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return StatefulBuilder(
      builder: (context, setLocalState) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Add New User',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: isDark ? Colors.white : BankTheme.lightTextPrimary),
            ),
            const SizedBox(height: 24),
            GlassContainer(
              hasPurpleTopBorder: true,
              padding: const EdgeInsets.all(24),
              child: Form(
                key: formKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: nameController,
                      style: TextStyle(color: isDark ? Colors.white : BankTheme.lightTextPrimary),
                      decoration: const InputDecoration(hintText: 'Full Name'),
                      validator: (v) => v!.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: phoneController,
                      style: TextStyle(color: isDark ? Colors.white : BankTheme.lightTextPrimary),
                      decoration: const InputDecoration(hintText: 'Phone Number'),
                      validator: (v) => v!.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: passwordController,
                      obscureText: true,
                      style: TextStyle(color: isDark ? Colors.white : BankTheme.lightTextPrimary),
                      decoration: const InputDecoration(hintText: 'Initial Password'),
                      validator: (v) => v!.length < 6 ? 'Min 6 characters' : null,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Checkbox(
                          value: isAdmin,
                          onChanged: (v) => setLocalState(() => isAdmin = v!),
                          activeColor: BankTheme.accentPurple,
                          side: BorderSide(color: isDark ? Colors.white24 : Colors.black26),
                        ),
                        Text('Register as Administrator', style: TextStyle(color: isDark ? BankTheme.textMuted : BankTheme.lightTextSecondary)),
                      ],
                    ),
                    const SizedBox(height: 32),
                    ElevatedButton(
                      onPressed: provider.isLoading ? null : () async {
                        if (formKey.currentState!.validate()) {
                          final success = await provider.adminAddUser(
                            phoneNumber: phoneController.text.trim(),
                            password: passwordController.text,
                            fullName: nameController.text.trim(),
                            role: isAdmin ? 'admin' : 'member',
                          );
                          if (success) {
                            if (!mounted) return;
                            setState(() => _activeTabIndex = 1); // Switch back to User Database
                          }
                        }
                      },
                      child: provider.isLoading 
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Add User'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      }
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
          color: isActive ? Colors.transparent : (isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05)),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isActive ? BankTheme.accentPurple : (isDark ? Colors.white10 : Colors.black.withOpacity(0.1))),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isActive ? (isDark ? Colors.white : BankTheme.lightTextPrimary) : (isDark ? BankTheme.textMuted : BankTheme.lightTextSecondary),
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(String label, String value) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final provider = Provider.of<BankProvider>(context, listen: false);

    return Container(
      width: (MediaQuery.of(context).size.width - 56) / 2,
      constraints: const BoxConstraints(minWidth: 160),
      child: GlassContainer(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(label, style: TextStyle(color: isDark ? BankTheme.textMuted : BankTheme.lightTextSecondary, fontSize: 12)),
                if (provider.isLoading)
                  const SizedBox(height: 10, width: 10, child: CircularProgressIndicator(strokeWidth: 1.5, color: BankTheme.accentPurple)),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: isDark ? Colors.white : BankTheme.lightTextPrimary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionTile(IconData icon, String title, String status, {VoidCallback? onTap}) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withOpacity(0.03) : Colors.black.withOpacity(0.03),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: isDark ? Colors.white10 : Colors.black.withOpacity(0.1)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: BankTheme.accentPurple, size: 24),
              const SizedBox(height: 12),
              Text(title, style: TextStyle(color: isDark ? Colors.white : BankTheme.lightTextPrimary, fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 4),
              Text(status, style: TextStyle(color: isDark ? Colors.white70 : BankTheme.lightTextSecondary, fontSize: 11)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMiniIndividualStat(String label, String value, Color color) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: isDark ? BankTheme.textMuted : BankTheme.lightTextSecondary, fontSize: 9, fontWeight: FontWeight.bold)),
        Text(value, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
      ],
    );
  }
}
