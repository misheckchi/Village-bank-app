import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:telephony/telephony.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show Platform;
import '../models/transaction.dart';
import '../services/bank_provider.dart';
import '../services/notification_service.dart';
import '../utils/theme.dart';
import '../widgets/glass_container.dart';
import '../widgets/bank_bar_chart.dart';
import 'auth_screen.dart';
import 'chat_screen.dart';
import 'release_history_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedTabIndex = 0;
  String _selectedPaymentMethod = 'National Bank (626)';

  final Map<String, String> _ussdCodes = {
    'Airtel Money': '*211#',
    'TNM Mpamba': '*444#',
    'National Bank (626)': '*626#',
  };

  final Map<String, Map<String, dynamic>> _paymentBranding = {
    'Airtel Money': {
      'color': const Color(0xFFFF0000),
      'logo': 'https://upload.wikimedia.org/wikipedia/commons/thumb/3/3a/Airtel_logo.svg/256px-Airtel_logo.svg.png',
    },
    'TNM Mpamba': {
      'color': const Color(0xFF00A651),
      'logo': 'https://www.tnm.co.mw/assets/images/logo.png',
    },
    'National Bank (626)': {
      'color': const Color(0xFF0033A0),
      'logo': 'https://www.natbank.co.mw/templates/natbank/images/logo.png',
    },
  };

  void _startSmsListener(TextEditingController controller) async {
    if (kIsWeb || !Platform.isAndroid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("SMS Fetching is only supported on Android devices.")),
      );
      return;
    }

    final Telephony telephony = Telephony.instance;
    bool? permissionsGranted = await telephony.requestSmsPermissions;

    if (permissionsGranted ?? false) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Listening for transaction SMS..."),
          duration: Duration(seconds: 30),
        ),
      );

      telephony.listenIncomingSms(
        onNewMessage: (SmsMessage message) {
          if (message.body != null) {
            String? tid = _extractTID(message.body!);
            if (tid != null) {
              controller.text = tid;
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text("Transaction ID Captured: $tid"),
                  backgroundColor: Colors.green,
                ),
              );
            }
          }
        },
        listenInBackground: false,
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("SMS permissions denied. Please enter ID manually.")),
      );
    }
  }

  String? _extractTID(String body) {
    // Standard patterns for Airtel Money and TNM Mpamba in Malawi
    // Airtel: e.g., PP240904.1234.H12345
    // Mpamba: Often contains a long alphanumeric string or "Ref: 12345678"
    
    // Pattern 1: Alphanumeric.Digits.Alphanumeric (Airtel Style)
    final airtelRegex = RegExp(r"([A-Z0-9]{5,}\.[0-9]{4,}\.[A-Z0-9]{5,})");
    // Pattern 2: Reference/Trans ID labels
    final refRegex = RegExp(r"(?:Ref|ID|Transaction ID|Txn ID)[:\s]+([A-Z0-9]{8,})", caseSensitive: false);
    
    final match1 = airtelRegex.firstMatch(body);
    if (match1 != null) return match1.group(1);
    
    final match2 = refRegex.firstMatch(body);
    if (match2 != null) return match2.group(1);

    return null;
  }

  void _launchUSSD(double amount, String transactionId, {bool isRepayment = false}) async {
    String? baseCode = _ussdCodes[_selectedPaymentMethod];
    if (baseCode == null) return;

    String fullCode = baseCode;
    if (_selectedPaymentMethod == 'Airtel Money') {
      fullCode = "*211*3*0881689220*$amount#";
    } else if (_selectedPaymentMethod == 'TNM Mpamba') {
      fullCode = "*444*3*1*0881689220*$amount#";
    } else if (_selectedPaymentMethod == 'National Bank (626)') {
      fullCode = "*626*5*1*0881689220*$amount#";
    }

    final Uri telUri = Uri.parse("tel:${fullCode.replaceAll('#', '%23')}");
    
    if (await canLaunchUrl(telUri)) {
      await launchUrl(telUri);
      
      // If TID is PENDING, we just wanted to launch the dialer.
      if (transactionId == "PENDING") return;

      if (!mounted) return;
      final provider = Provider.of<BankProvider>(context, listen: false);
      bool success = false;
      if (isRepayment) {
        success = await provider.repayLoan(amount, transactionId);
      } else {
        success = await provider.makeDeposit(amount, transactionId);
      }

      if (mounted && success) {
        provider.sendMessage(
          text: isRepayment ? 'Loan repayment submitted for verification.' : 'Deposit verification requested for MK ${amount.toStringAsFixed(2)}.',
          receiverPhone: 'admin-token',
          transactionId: transactionId,
        );

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.greenAccent,
            behavior: SnackBarBehavior.floating,
            content: Text(
              isRepayment ? 'Repayment Submitted! Please wait ~10 mins for verification.' : 'Deposit Submitted! Please wait ~10 mins for verification.',
              style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
            ),
            action: SnackBarAction(
              label: 'VIEW CHAT',
              textColor: Colors.black,
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (context) => const ChatScreen(otherUserPhone: 'admin-token', otherUserName: 'Village Bank Support'),
              )),
            ),
          ),
        );
      }
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<BankProvider>(context, listen: false).refreshMemberData();
    });
  }

  void _showLoanDialog() {
    final TextEditingController amountController = TextEditingController();
    final TextEditingController accountController = TextEditingController();
    final provider = Provider.of<BankProvider>(context, listen: false);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text('REQUEST LOAN', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.5, color: isDark ? Colors.white : BankTheme.lightTextPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Request a loan from the community pool.', style: TextStyle(color: isDark ? BankTheme.textMuted : BankTheme.lightTextSecondary, fontSize: 12)),
            const SizedBox(height: 20),
            TextField(
              controller: amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              autofocus: true,
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: isDark ? Colors.white : BankTheme.lightTextPrimary),
              decoration: const InputDecoration(
                prefixText: 'MK ',
                labelText: 'AMOUNT',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: accountController,
              style: TextStyle(fontSize: 14, color: isDark ? Colors.white : BankTheme.lightTextPrimary),
              decoration: const InputDecoration(
                labelText: 'RECEIVING ACCOUNT / PHONE NUMBER',
                hintText: 'e.g. National Bank No or Phone',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('CANCEL', style: TextStyle(color: isDark ? BankTheme.textMuted : BankTheme.lightTextSecondary, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(minimumSize: const Size(120, 45)),
            onPressed: () async {
              final amount = double.tryParse(amountController.text);
              final receivingAcc = accountController.text.trim();
              if (amount != null && amount > 0 && receivingAcc.isNotEmpty) {
                final success = await provider.makeLoanRequest(amount, receivingAcc);
                if (!mounted) return;
                Navigator.pop(context);
                if (!success) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(provider.errorMessage ?? 'Loan request failed')));
                }
              } else {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please specify receiving account/phone number')));
              }
            },
            child: const Text('REQUEST'),
          ),
        ],
      ),
    );
  }

  void _showDepositDialog() {
    final provider = Provider.of<BankProvider>(context, listen: false);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final TextEditingController amountController = TextEditingController();
    final TextEditingController tidController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: theme.colorScheme.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Text('INITIATE DEPOSIT', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.5, color: isDark ? Colors.white : BankTheme.lightTextPrimary)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('PAYMENT METHOD', style: TextStyle(fontSize: 10, color: isDark ? BankTheme.textMuted : BankTheme.lightTextSecondary)),
                DropdownButton<String>(
                  value: _selectedPaymentMethod,
                  isExpanded: true,
                  dropdownColor: theme.colorScheme.surface,
                  items: _ussdCodes.keys.map((String value) {
                    final branding = _paymentBranding[value];
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Row(
                        children: [
                          Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: branding?['color']?.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            padding: const EdgeInsets.all(2),
                            child: branding != null
                              ? Image.network(
                                  branding['logo'],
                                  fit: BoxFit.contain,
                                  errorBuilder: (c, e, s) => Icon(Icons.account_balance_wallet, size: 12, color: branding['color']),
                                )
                              : const Icon(Icons.account_balance_wallet, size: 12),
                          ),
                          const SizedBox(width: 12),
                          Text(value, style: TextStyle(color: isDark ? Colors.white : BankTheme.lightTextPrimary)),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (newValue) {
                    if (newValue != null) {
                      setDialogState(() {
                        _selectedPaymentMethod = newValue;
                      });
                    }
                  },
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: amountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: isDark ? Colors.white : BankTheme.lightTextPrimary),
                  decoration: const InputDecoration(
                    prefixText: 'MK ',
                    labelText: 'AMOUNT',
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: tidController,
                        style: TextStyle(fontSize: 14, color: isDark ? Colors.white : BankTheme.lightTextPrimary),
                        decoration: const InputDecoration(
                          labelText: 'TRANSACTION ID (FROM SMS)',
                          hintText: 'e.g. PP240904.1234.H12345',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.sms_rounded, color: BankTheme.accentPurple),
                      onPressed: () => _startSmsListener(tidController),
                      tooltip: 'Fetch from SMS',
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('CANCEL', style: TextStyle(color: isDark ? BankTheme.textMuted : BankTheme.lightTextSecondary, fontWeight: FontWeight.bold)),
            ),
            Column(
              children: [
                ElevatedButton(
                  style: ElevatedButton.styleFrom(minimumSize: const Size(140, 40), backgroundColor: BankTheme.accentPurple.withOpacity(0.2)),
                  onPressed: () {
                    final amount = double.tryParse(amountController.text);
                    if (amount != null && amount > 0) {
                      _startSmsListener(tidController);
                      _launchUSSD(amount, "PENDING"); // Temporary TID
                    }
                  },
                  child: const Text('1. LAUNCH USSD'),
                ),
                const SizedBox(height: 8),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(minimumSize: const Size(140, 45)),
                  onPressed: () {
                    NotificationService.playClickSound();
                    final amount = double.tryParse(amountController.text);
                    final tid = tidController.text.trim();
                    if (amount != null && amount > 0 && tid.isNotEmpty && tid != "PENDING") {
                      _launchUSSD(amount, tid);
                      Navigator.pop(context);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter amount and valid Transaction ID')));
                    }
                  },
                  child: const Text('2. VERIFY DEPOSIT'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showRepayDialog() {
    final provider = Provider.of<BankProvider>(context, listen: false);
    final stats = provider.memberStats;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final TextEditingController amountController = TextEditingController(text: stats?.totalToRepay.toStringAsFixed(2) ?? '0.00');
    final TextEditingController tidController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: theme.colorScheme.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Text('REPAY LOAN', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.5, color: isDark ? Colors.white : BankTheme.lightTextPrimary)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Total Due: MK ${stats?.totalToRepay.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, color: BankTheme.accentPurple)),
                const SizedBox(height: 20),
                
                Text('PAYMENT METHOD', style: TextStyle(fontSize: 10, color: isDark ? BankTheme.textMuted : BankTheme.lightTextSecondary)),
                DropdownButton<String>(
                  value: _selectedPaymentMethod,
                  isExpanded: true,
                  dropdownColor: theme.colorScheme.surface,
                  items: _ussdCodes.keys.map((String value) {
                    final branding = _paymentBranding[value];
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Row(
                        children: [
                          Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: branding?['color']?.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            padding: const EdgeInsets.all(2),
                            child: branding != null
                              ? Image.network(
                                  branding['logo'],
                                  fit: BoxFit.contain,
                                  errorBuilder: (c, e, s) => Icon(Icons.account_balance_wallet, size: 12, color: branding['color']),
                                )
                              : const Icon(Icons.account_balance_wallet, size: 12),
                          ),
                          const SizedBox(width: 12),
                          Text(value, style: TextStyle(color: isDark ? Colors.white : BankTheme.lightTextPrimary)),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (newValue) {
                    if (newValue != null) {
                      setDialogState(() {
                        _selectedPaymentMethod = newValue;
                      });
                    }
                  },
                ),
                
                const SizedBox(height: 20),
                TextField(
                  controller: amountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    prefixText: 'MK ',
                    labelText: 'CONFIRM AMOUNT',
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: tidController,
                        style: TextStyle(fontSize: 14, color: isDark ? Colors.white : BankTheme.lightTextPrimary),
                        decoration: const InputDecoration(
                          labelText: 'TRANSACTION ID (FROM SMS)',
                          hintText: 'e.g. PP240904.1234.H12345',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.sms_rounded, color: BankTheme.accentPurple),
                      onPressed: () => _startSmsListener(tidController),
                      tooltip: 'Fetch from SMS',
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('CANCEL', style: TextStyle(color: isDark ? BankTheme.textMuted : BankTheme.lightTextSecondary, fontWeight: FontWeight.bold)),
            ),
            Column(
              children: [
                ElevatedButton(
                  style: ElevatedButton.styleFrom(minimumSize: const Size(140, 40), backgroundColor: Colors.greenAccent.withOpacity(0.2), foregroundColor: isDark ? Colors.greenAccent : Colors.black),
                  onPressed: () {
                    final amount = double.tryParse(amountController.text);
                    if (amount != null && amount > 0) {
                      _startSmsListener(tidController);
                      _launchUSSD(amount, "PENDING", isRepayment: true);
                    }
                  },
                  child: const Text('1. LAUNCH USSD'),
                ),
                const SizedBox(height: 8),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(minimumSize: const Size(140, 45), backgroundColor: Colors.greenAccent, foregroundColor: Colors.black),
                  onPressed: () {
                    NotificationService.playClickSound();
                    final amount = double.tryParse(amountController.text);
                    final tid = tidController.text.trim();
                    if (amount != null && amount > 0 && tid.isNotEmpty && tid != "PENDING") {
                      _launchUSSD(amount, tid, isRepayment: true);
                      Navigator.pop(context);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter amount and valid Transaction ID')));
                    }
                  },
                  child: const Text('2. VERIFY REPAYMENT'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showPayoutDialog() {
    final provider = Provider.of<BankProvider>(context, listen: false);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final double totalSavings = provider.memberStats?.savings ?? 0.0;
    final TextEditingController amountController = TextEditingController(text: totalSavings.toStringAsFixed(2));
    final TextEditingController accountController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text('REQUEST PAYOUT', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.5, color: isDark ? Colors.white : BankTheme.lightTextPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Request your savings to be sent to your choice account.', style: TextStyle(color: isDark ? BankTheme.textMuted : BankTheme.lightTextSecondary, fontSize: 12)),
            const SizedBox(height: 20),
            TextField(
              controller: amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              autofocus: true,
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: isDark ? Colors.white : BankTheme.lightTextPrimary),
              decoration: const InputDecoration(
                prefixText: 'MK ',
                labelText: 'AMOUNT',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: accountController,
              style: TextStyle(fontSize: 14, color: isDark ? Colors.white : BankTheme.lightTextPrimary),
              decoration: const InputDecoration(
                labelText: 'RECEIVING ACCOUNT / PHONE NUMBER',
                hintText: 'e.g. National Bank No or Phone',
              ),
            ),
            const SizedBox(height: 12),
            Text('Max Available: MK ${totalSavings.toStringAsFixed(2)}', style: TextStyle(fontSize: 11, color: BankTheme.statusYellow)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('CANCEL', style: TextStyle(color: isDark ? BankTheme.textMuted : BankTheme.lightTextSecondary, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(minimumSize: const Size(120, 45), backgroundColor: Colors.orangeAccent, foregroundColor: Colors.black),
            onPressed: () async {
              final amount = double.tryParse(amountController.text);
              final receivingAcc = accountController.text.trim();
              if (amount != null && amount > 0 && amount <= totalSavings && receivingAcc.isNotEmpty) {
                final success = await provider.requestPayout(amount, receivingAcc);
                if (!mounted) return;
                Navigator.pop(context);
                if (success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      backgroundColor: Colors.orangeAccent,
                      behavior: SnackBarBehavior.floating,
                      content: Text('Payout request sent to Treasurer!', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                    ),
                  );
                }
              } else {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please verify fields and ensure details are specified.')));
              }
            },
            child: const Text('REQUEST'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(width: 16),
            // Mini Brand Icon - Simplified for space
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
            icon: Icon(Icons.group_rounded, size: 20, color: isDark ? BankTheme.textMuted : BankTheme.lightTextSecondary),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (context) => const ChatScreen(otherUserPhone: 'group', otherUserName: 'Community Group Chat'),
            )),
          ),
          IconButton(
            icon: Icon(Icons.chat_bubble_outline_rounded, size: 20, color: isDark ? BankTheme.textMuted : BankTheme.lightTextSecondary),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (context) => const ChatScreen(otherUserPhone: 'admin-token', otherUserName: 'Village Bank Support'),
            )),
          ),
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert_rounded, color: isDark ? BankTheme.textMuted : BankTheme.lightTextSecondary),
            onSelected: (value) {
              if (value == 'theme') {
                Provider.of<BankProvider>(context, listen: false).toggleTheme();
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
              PopupMenuItem(
                enabled: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      Provider.of<BankProvider>(context, listen: false).user?.name ?? 'User',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : BankTheme.lightTextPrimary,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      'Account: ${Provider.of<BankProvider>(context, listen: false).user?.token ?? ""}',
                      style: const TextStyle(fontSize: 10, color: BankTheme.statusYellow),
                    ),
                    const Divider(),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'theme',
                child: Row(
                  children: [
                    Icon(isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded, size: 18),
                    const SizedBox(width: 12),
                    Text(isDark ? 'Light Mode' : 'Dark Mode'),
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
                    Icon(Icons.logout_rounded, size: 18, color: Colors.redAccent),
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
          if (provider.isLoading && provider.memberStats == null) {
            return const Center(child: CircularProgressIndicator(color: BankTheme.accentPurple));
          }
          final stats = provider.memberStats;
          final transactions = provider.transactions.where((tx) {
            if (_selectedTabIndex == 1) return tx.isDeposit;
            if (_selectedTabIndex == 2) return !tx.isDeposit;
            return true;
          }).toList();

          return RefreshIndicator(
            onRefresh: provider.refreshMemberData,
            color: BankTheme.accentPurple,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildTab('Dashboard', 0),
                        _buildTab('Savings', 1),
                        _buildTab('Loans', 2),
                        _buildTab('Analytics', 3),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  if (_selectedTabIndex == 3) _buildAnalyticsView(provider) else ...[
                  Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    children: [
                      _buildStatCard('Total Savings', 'MK ${stats?.savings.toStringAsFixed(2) ?? '0.00'}'),
                      _buildStatCard('Active Loans', 'MK ${stats?.loan.toStringAsFixed(2) ?? '0.00'}'),
                    ],
                  ),
                  const SizedBox(height: 32),
                  _buildAdminBankDetails(),
                  const SizedBox(height: 32),
                  GlassContainer(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Quick Overview', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 12),
                        const Text('Your financial summary is shown above. Use the tabs to manage your community interactions.', style: TextStyle(color: BankTheme.textMuted, fontSize: 14)),
                        if (stats != null && stats.loan > 0) ...[
                          const SizedBox(height: 24),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: BankTheme.accentPurple.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: BankTheme.accentPurple.withOpacity(0.2)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text('Loan Interest (35%)', style: TextStyle(color: BankTheme.textMuted, fontSize: 12)),
                                    Text('Split: 30% Member / 5% Bank', style: const TextStyle(color: BankTheme.statusYellow, fontSize: 10, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'MK ${stats.accruedInterest.toStringAsFixed(2)}',
                                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: isDark ? Colors.white : BankTheme.lightTextPrimary),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text('Member Share (30%):', style: TextStyle(color: isDark ? Colors.white70 : BankTheme.lightTextSecondary, fontSize: 11)),
                                    Text('MK ${(stats.loan * 0.30).toStringAsFixed(2)}', style: const TextStyle(color: Colors.greenAccent, fontSize: 11, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text('Bank Cut (5%):', style: TextStyle(color: isDark ? Colors.white70 : BankTheme.lightTextSecondary, fontSize: 11)),
                                    Text('MK ${(stats.loan * 0.05).toStringAsFixed(2)}', style: const TextStyle(color: Colors.redAccent, fontSize: 11, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                                const Divider(height: 16, color: Colors.white10),
                                Text('Total to Repay: MK ${stats.totalToRepay.toStringAsFixed(2)}', style: TextStyle(color: isDark ? Colors.white70 : BankTheme.lightTextSecondary, fontSize: 12, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            Expanded(child: ElevatedButton(onPressed: _showDepositDialog, child: const Text('Deposit Funds'))),
                            const SizedBox(width: 12),
                            if (stats != null && stats.loan > 0)
                              Expanded(child: ElevatedButton(
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.greenAccent, foregroundColor: Colors.black),
                                onPressed: _showRepayDialog, 
                                child: const Text('Repay Loan')
                              ))
                            else
                              Expanded(child: OutlinedButton(onPressed: _showLoanDialog, child: const Text('Request Loan'))),
                          ],
                        ),
                        if (stats != null && stats.savings > 0) ...[
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.orangeAccent,
                                foregroundColor: Colors.black,
                              ),
                              onPressed: _showPayoutDialog,
                              child: const Text('Request Payout to SIM'),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  Text('Recent Activity', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1, color: isDark ? Colors.white : BankTheme.lightTextPrimary)),
                  const SizedBox(height: 16),
                  ...transactions.map((tx) => _buildTxTile(tx)).toList(),
                  if (transactions.isEmpty && _selectedTabIndex != 3)
                    Center(child: Padding(padding: const EdgeInsets.all(40), child: Text('NO DATA FOUND', style: TextStyle(color: isDark ? Colors.white10 : Colors.black.withOpacity(0.1), letterSpacing: 2)))),
                  ],
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
    final stats = provider.memberStats;
    
    if (stats == null) return const Center(child: CircularProgressIndicator());

    final List<BarData> chartData = [
      BarData(name: 'Total Savings', value: stats.savings, color: Colors.greenAccent),
      BarData(name: 'Loan Balance', value: stats.loan, color: Colors.orangeAccent),
      BarData(name: 'Accrued Int.', value: stats.accruedInterest, color: Colors.redAccent),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Financial Analytics',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: isDark ? Colors.white : BankTheme.lightTextPrimary),
        ),
        const SizedBox(height: 24),
        GlassContainer(
          padding: const EdgeInsets.all(24),
          child: BankBarChart(data: chartData, title: 'BALANCE BREAKDOWN'),
        ),
        const SizedBox(height: 24),
        GlassContainer(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('PROFIT DISTRIBUTION', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: BankTheme.accentPurple, letterSpacing: 2)),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildCircularProgressIndicator('Member (30%)', 0.30, Colors.greenAccent),
                  _buildCircularProgressIndicator('Bank (5%)', 0.05, Colors.redAccent),
                ],
              ),
              const SizedBox(height: 32),
              Text(
                'Your current loan structure yields 30% profit back to your savings pool, while 5% supports the village bank administration.',
                style: TextStyle(color: isDark ? BankTheme.textMuted : BankTheme.lightTextSecondary, fontSize: 13, height: 1.5),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCircularProgressIndicator(String label, double percent, Color color) {
    return Column(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              height: 80,
              width: 80,
              child: CircularProgressIndicator(
                value: percent / 0.35,
                strokeWidth: 8,
                backgroundColor: Colors.white10,
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
            Text('${(percent * 100).toInt()}%', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        const SizedBox(height: 12),
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildAdminBankDetails() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return GlassContainer(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ADMIN BANK DETAILS',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              color: isDark ? BankTheme.textMuted : BankTheme.lightTextSecondary,
              letterSpacing: 2
            ),
          ),
          const SizedBox(height: 16),
          _buildBankItem('National Bank', '10023456789', 'Village Bank Group'),
          const Divider(height: 24, color: Colors.white10),
          Text(
            'For Airtel Money & TNM Mpamba, contact support.',
            style: TextStyle(
              fontSize: 10,
              color: isDark ? BankTheme.textMuted.withOpacity(0.7) : BankTheme.lightTextSecondary.withOpacity(0.7),
              fontStyle: FontStyle.italic
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBankItem(String method, String number, String name) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(method, style: const TextStyle(color: BankTheme.accentPurple, fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 2),
              Text(number, style: TextStyle(color: isDark ? Colors.white : BankTheme.lightTextPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
              Text(name, style: TextStyle(color: isDark ? BankTheme.textMuted : BankTheme.lightTextSecondary, fontSize: 11)),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.copy_rounded, size: 20, color: BankTheme.accentPurple),
          onPressed: () {
            Clipboard.setData(ClipboardData(text: number));
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$method number copied!')));
          },
        ),
      ],
    );
  }

  Widget _buildTab(String label, int index) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bool isActive = _selectedTabIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedTabIndex = index),
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
    return Container(
      width: (MediaQuery.of(context).size.width - 56) / 2,
      constraints: const BoxConstraints(minWidth: 160),
      child: GlassContainer(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8), // Padding for top border
            Text(label, style: TextStyle(color: isDark ? BankTheme.textMuted : BankTheme.lightTextSecondary, fontSize: 12)),
            const SizedBox(height: 8),
            Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: -0.5, color: isDark ? Colors.white : BankTheme.lightTextPrimary)),
          ],
        ),
      ),
    );
  }

  Widget _buildTxTile(Transaction tx) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border.all(color: isDark ? const Color(0xFF2E2E32) : const Color(0xFFE2E8F0)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(tx.isDeposit ? Icons.arrow_downward : Icons.arrow_upward, color: tx.isDeposit ? Colors.greenAccent : Colors.redAccent, size: 16),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tx.title, style: TextStyle(color: isDark ? Colors.white : BankTheme.lightTextPrimary, fontWeight: FontWeight.w600, fontSize: 14)),
                Text(tx.date, style: TextStyle(color: isDark ? BankTheme.textMuted : BankTheme.lightTextSecondary, fontSize: 11)),
              ],
            ),
          ),
          Text(
            'MK ${tx.amount.toStringAsFixed(2)}',
            style: TextStyle(color: isDark ? Colors.white : BankTheme.lightTextPrimary, fontWeight: FontWeight.bold, fontSize: 14),
          ),
        ],
      ),
    );
  }
}
