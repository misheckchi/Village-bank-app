import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/organization_model.dart';
import '../services/bank_provider.dart';
import '../utils/theme.dart';
import '../widgets/glass_container.dart';
import '../widgets/bank_bar_chart.dart';

class GlobalAnalyticsScreen extends StatefulWidget {
  const GlobalAnalyticsScreen({super.key});

  @override
  State<GlobalAnalyticsScreen> createState() => _GlobalAnalyticsScreenState();
}

class _GlobalAnalyticsScreenState extends State<GlobalAnalyticsScreen> {
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<BankProvider>(context, listen: false).refreshGlobalAnalytics();
    });
  }

  void _showAdjustShareDialog(OrganizationModel org) {
    final provider = Provider.of<BankProvider>(context, listen: false);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    double currentShare = org.sharePercentage;
    final TextEditingController shareController = TextEditingController(text: currentShare.toStringAsFixed(1));

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: theme.colorScheme.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Row(
            children: [
              const Icon(Icons.settings_suggest_rounded, color: BankTheme.accentPurple),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'CONFIGURE BANK SHARE %',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : BankTheme.lightTextPrimary,
                  ),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  org.name,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: BankTheme.accentPurple),
                ),
                const SizedBox(height: 12),
                Text(
                  'Define how loan interest returns are allocated when members repay loans:',
                  style: TextStyle(fontSize: 12, color: isDark ? BankTheme.textMuted : BankTheme.lightTextSecondary),
                ),
                const SizedBox(height: 16),

                // Fixed Allocations Info
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: BankTheme.accentPurple.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: BankTheme.accentPurple.withOpacity(0.2)),
                  ),
                  child: Column(
                    children: [
                      _buildShareRow('Main Management Portal Cut:', '5.0%', Colors.amberAccent, isDark),
                      const SizedBox(height: 6),
                      _buildShareRow('${org.name} Reserve:', '5.0%', Colors.cyanAccent, isDark),
                      const SizedBox(height: 6),
                      _buildShareRow('Member Savings Yield:', '${currentShare.toStringAsFixed(1)}%', Colors.greenAccent, isDark),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                Text(
                  'MEMBER SHARE PERCENTAGE (0% - 50%)',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isDark ? BankTheme.textMuted : BankTheme.lightTextSecondary),
                ),
                const SizedBox(height: 8),
                Slider(
                  value: currentShare,
                  min: 5.0,
                  max: 45.0,
                  divisions: 40,
                  activeColor: BankTheme.accentPurple,
                  label: '${currentShare.toStringAsFixed(1)}%',
                  onChanged: (val) {
                    setDialogState(() {
                      currentShare = val;
                      shareController.text = val.toStringAsFixed(1);
                    });
                  },
                ),
                TextField(
                  controller: shareController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: TextStyle(color: isDark ? Colors.white : BankTheme.lightTextPrimary, fontWeight: FontWeight.bold),
                  decoration: const InputDecoration(
                    suffixText: '%',
                    labelText: 'CUSTOM PERCENTAGE',
                  ),
                  onChanged: (val) {
                    final parsed = double.tryParse(val);
                    if (parsed != null && parsed >= 0 && parsed <= 50) {
                      setDialogState(() {
                        currentShare = parsed;
                      });
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('CANCEL', style: TextStyle(color: isDark ? BankTheme.textMuted : BankTheme.lightTextSecondary)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: BankTheme.accentPurple),
              onPressed: () async {
                final success = await provider.updateOrganizationSharePercentage(org.code, currentShare);
                if (!mounted) return;
                Navigator.pop(context);
                if (success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Share percentage for ${org.name} updated to ${currentShare.toStringAsFixed(1)}%!'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              },
              child: const Text('SAVE SHARE CONFIG'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShareRow(String label, String value, Color color, bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: 11, color: isDark ? Colors.white70 : BankTheme.lightTextSecondary)),
        Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.hub_rounded, color: BankTheme.accentPurple, size: 20),
            SizedBox(width: 8),
            Text('Global Analytics', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
      ),
      body: Consumer<BankProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading && provider.globalSummary == null) {
            return const Center(child: CircularProgressIndicator(color: BankTheme.accentPurple));
          }

          final summary = provider.globalSummary;
          final orgs = provider.globalOrganizations.where((org) {
            if (_searchQuery.isEmpty) return true;
            final query = _searchQuery.toLowerCase();
            return org.name.toLowerCase().contains(query) || org.code.toLowerCase().contains(query);
          }).toList();

          final isSuperAdminOrAdmin = provider.user?.role == 'super_admin' || provider.user?.role == 'admin';

          return RefreshIndicator(
            onRefresh: provider.refreshGlobalAnalytics,
            color: BankTheme.accentPurple,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title & Subtitle
                  Text(
                    'Village Bank Ecosystem Comparison',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : BankTheme.lightTextPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Real-time comparative performance analysis across all village bank organizations.',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? BankTheme.textMuted : BankTheme.lightTextSecondary,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Platform Stats Cards
                  if (summary != null) ...[
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        _buildPlatformStatCard('Active Banks', '${summary['totalOrganizations'] ?? 0}', Icons.account_balance_rounded, Colors.purpleAccent, isDark),
                        _buildPlatformStatCard('Total Members', '${summary['totalMembers'] ?? 0}', Icons.people_rounded, Colors.blueAccent, isDark),
                        _buildPlatformStatCard('Total Savings', 'MK ${(summary['platformTotalSavings'] as num?)?.toStringAsFixed(0) ?? '0'}', Icons.savings_rounded, Colors.greenAccent, isDark),
                        _buildPlatformStatCard('Total Loans', 'MK ${(summary['platformTotalLoans'] as num?)?.toStringAsFixed(0) ?? '0'}', Icons.account_balance_wallet_rounded, Colors.orangeAccent, isDark),
                        _buildPlatformStatCard('Management Share (5%)', 'MK ${(summary['platformManagementFund'] as num?)?.toStringAsFixed(0) ?? '0'}', Icons.admin_panel_settings_rounded, Colors.amberAccent, isDark),
                      ],
                    ),
                    const SizedBox(height: 32),
                  ],

                  // Visual Bar Chart comparing Village Banks
                  if (orgs.isNotEmpty) ...[
                    GlassContainer(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('SAVINGS COMPARISON BY BANK', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: BankTheme.accentPurple, letterSpacing: 1.5)),
                          const SizedBox(height: 16),
                          BankBarChart(
                            data: orgs.map((org) => BarData(
                              name: org.name.length > 8 ? '${org.name.substring(0, 8)}...' : org.name,
                              value: org.totalSavings,
                              color: BankTheme.accentPurple,
                            )).toList(),
                            title: 'Total Savings per Bank',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],

                  // Search Box
                  TextField(
                    onChanged: (val) => setState(() => _searchQuery = val),
                    style: TextStyle(color: isDark ? Colors.white : BankTheme.lightTextPrimary),
                    decoration: InputDecoration(
                      hintText: 'Search organization by name or code...',
                      prefixIcon: const Icon(Icons.search_rounded, color: BankTheme.accentPurple),
                      filled: true,
                      fillColor: theme.colorScheme.surface,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Organization List Table / Cards
                  Text(
                    'ORGANIZATION LEADERBOARD',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                      color: isDark ? BankTheme.textMuted : BankTheme.lightTextSecondary,
                    ),
                  ),
                  const SizedBox(height: 12),

                  if (orgs.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(40),
                        child: Text(
                          'No registered organizations found.',
                          style: TextStyle(color: isDark ? BankTheme.textMuted : BankTheme.lightTextSecondary),
                        ),
                      ),
                    )
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: orgs.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 16),
                      itemBuilder: (context, index) {
                        final org = orgs[index];
                        final isUserOrg = provider.user?.organizationId == org.code;

                        return GlassContainer(
                          hasPurpleTopBorder: isUserOrg,
                          padding: const EdgeInsets.all(18),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 20,
                                    backgroundColor: isUserOrg ? BankTheme.accentPurple : Colors.blue.withOpacity(0.2),
                                    child: Text(
                                      '#${index + 1}',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Text(
                                              org.name,
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16,
                                                color: isDark ? Colors.white : BankTheme.lightTextPrimary,
                                              ),
                                            ),
                                            if (isUserOrg) ...[
                                              const SizedBox(width: 6),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: BankTheme.accentPurple.withOpacity(0.2),
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                                child: const Text('YOUR BANK', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: BankTheme.accentPurple)),
                                              ),
                                            ],
                                          ],
                                        ),
                                        Text(
                                          'Code: ${org.code} • Contact: ${org.contactPerson}',
                                          style: TextStyle(fontSize: 11, color: isDark ? BankTheme.textMuted : BankTheme.lightTextSecondary),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (isSuperAdminOrAdmin && isUserOrg)
                                    IconButton(
                                      icon: const Icon(Icons.settings_rounded, color: BankTheme.accentPurple),
                                      tooltip: 'Configure Bank Share %',
                                      onPressed: () => _showAdjustShareDialog(org),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 16),

                              // Metrics Grid
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  _buildOrgMetricTile('Members', '${org.memberCount}', isDark),
                                  _buildOrgMetricTile('Savings', 'MK ${org.totalSavings.toStringAsFixed(0)}', isDark, color: Colors.greenAccent),
                                  _buildOrgMetricTile('Loans', 'MK ${org.totalLoans.toStringAsFixed(0)}', isDark, color: Colors.orangeAccent),
                                  _buildOrgMetricTile('5% Reserve', 'MK ${org.organizationFund.toStringAsFixed(0)}', isDark, color: Colors.cyanAccent),
                                ],
                              ),
                              const SizedBox(height: 14),

                              // Share Breakdown Bar
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: isDark ? Colors.white.withOpacity(0.03) : Colors.black.withOpacity(0.03),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Interest Distribution:',
                                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isDark ? Colors.white70 : BankTheme.lightTextSecondary),
                                    ),
                                    Text(
                                      'Member: ${org.sharePercentage.toStringAsFixed(0)}% | Org 5% | Portal 5%',
                                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: BankTheme.accentPurple),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPlatformStatCard(String label, String value, IconData icon, Color color, bool isDark) {
    return Container(
      width: (MediaQuery.of(context).size.width - 52) / 2,
      constraints: const BoxConstraints(minWidth: 150),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.04),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isDark ? Colors.white10 : Colors.black.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: color, size: 20),
              Text(
                'Global',
                style: TextStyle(fontSize: 10, color: isDark ? BankTheme.textMuted : BankTheme.lightTextSecondary),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : BankTheme.lightTextPrimary),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(fontSize: 11, color: isDark ? BankTheme.textMuted : BankTheme.lightTextSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildOrgMetricTile(String label, String value, bool isDark, {Color? color}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 10, color: isDark ? BankTheme.textMuted : BankTheme.lightTextSecondary),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: color ?? (isDark ? Colors.white : BankTheme.lightTextPrimary),
          ),
        ),
      ],
    );
  }
}
