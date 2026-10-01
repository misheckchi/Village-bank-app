import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:telephony/telephony.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import '../models/transaction.dart';
import '../services/bank_provider.dart';
import '../services/notification_service.dart';
import '../utils/theme.dart';
import '../widgets/glass_container.dart';
import '../widgets/bank_bar_chart.dart';
import 'auth_screen.dart';
import 'chat_screen.dart';

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
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
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

    final adminPhone = Provider.of<BankProvider>(context, listen: false).memberStats?.adminPhone ?? "0881689220";

    String fullCode = baseCode;
    if (_selectedPaymentMethod == 'Airtel Money') {
      fullCode = "*211*3*$adminPhone*$amount#";
    } else if (_selectedPaymentMethod == 'TNM Mpamba') {
      fullCode = "*444*3*1*$adminPhone*$amount#";
    } else if (_selectedPaymentMethod == 'National Bank (626)') {
      fullCode = "*626*5*1*$adminPhone*$amount#";
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
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final provider = Provider.of<BankProvider>(context, listen: false);
      provider.refreshMemberData();

      final prompted = await NotificationService.hasPromptedPermission();
      if (!prompted && mounted) {
        final choice = await NotificationService.showPermissionDialog(context);
        if (choice == true) {
          provider.toggleNotifications(true);
        }
      }
    });
  }

  void _callAdmin() async {
    final adminPhone = Provider.of<BankProvider>(context, listen: false).memberStats?.adminPhone ?? "0881689220";
    final Uri telUri = Uri.parse("tel:$adminPhone");
    if (await canLaunchUrl(telUri)) {
      await launchUrl(telUri);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not launch phone dialer for $adminPhone')),
        );
      }
    }
  }

  void _showLoanDialog() {
    final TextEditingController amountController = TextEditingController();
    final TextEditingController accountController = TextEditingController();
    final provider = Provider.of<BankProvider>(context, listen: false);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final int pendingCount = provider.memberStats?.pendingLoanCount ?? 0;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text('REQUEST LOAN', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.5, color: isDark ? Colors.white : BankTheme.lightTextPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Request a loan from the community pool.', style: TextStyle(color: isDark ? BankTheme.textMuted : BankTheme.lightTextSecondary, fontSize: 12)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: pendingCount >= 3 ? Colors.redAccent.withOpacity(0.1) : BankTheme.accentPurple.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: pendingCount >= 3 ? Colors.redAccent : BankTheme.accentPurple.withOpacity(0.3)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Active Loan Requests Limit:', style: TextStyle(fontSize: 11, color: isDark ? Colors.white70 : BankTheme.lightTextSecondary)),
                  Text(
                    '$pendingCount / 3',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: pendingCount >= 3 ? Colors.redAccent : BankTheme.accentPurple,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
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
              if (pendingCount >= 3) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Maximum loan request limit (3) reached. Please wait for previous requests to be processed.'))
                );
                return;
              }
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
    final String userPhone = provider.user?.token ?? '';

    final TextEditingController amountController = TextEditingController();
    final TextEditingController phoneController = TextEditingController(text: userPhone);
    final TextEditingController pinController = TextEditingController();
    bool isProcessing = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: theme.colorScheme.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: BankTheme.accentPurple.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.payment_rounded, color: BankTheme.accentPurple, size: 22),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'INSTANT MOBILE DEPOSIT',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    letterSpacing: 1,
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
                Text('SELECT PAYMENT METHOD', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isDark ? BankTheme.textMuted : BankTheme.lightTextSecondary)),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  value: _selectedPaymentMethod,
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
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
                          Text(value, style: TextStyle(fontSize: 14, color: isDark ? Colors.white : BankTheme.lightTextPrimary)),
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
                const SizedBox(height: 16),
                TextField(
                  controller: phoneController,
                  keyboardType: TextInputType.phone,
                  style: TextStyle(fontSize: 15, color: isDark ? Colors.white : BankTheme.lightTextPrimary),
                  decoration: const InputDecoration(
                    labelText: 'MOBILE MONEY NUMBER',
                    hintText: 'e.g. 088xxxxxxx or 099xxxxxxx',
                    prefixIcon: Icon(Icons.phone_android_rounded),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: amountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: isDark ? Colors.white : BankTheme.lightTextPrimary),
                  decoration: const InputDecoration(
                    prefixText: 'MK ',
                    labelText: 'DEPOSIT AMOUNT',
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: pinController,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  style: TextStyle(fontSize: 15, color: isDark ? Colors.white : BankTheme.lightTextPrimary),
                  decoration: const InputDecoration(
                    labelText: 'MOBILE MONEY PIN',
                    hintText: 'Enter PIN to authorize payment',
                    prefixIcon: Icon(Icons.lock_outline_rounded),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Secure Mobile Money Gateway. No USSD or manual verification required.',
                  style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: isDark ? BankTheme.textMuted : BankTheme.lightTextSecondary),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isProcessing ? null : () => Navigator.pop(context),
              child: Text('CANCEL', style: TextStyle(color: isDark ? BankTheme.textMuted : BankTheme.lightTextSecondary, fontWeight: FontWeight.bold)),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(140, 45),
                backgroundColor: BankTheme.accentPurple,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              icon: isProcessing
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.flash_on_rounded, size: 18),
              label: Text(isProcessing ? 'PROCESSING...' : 'PAY NOW'),
              onPressed: isProcessing ? null : () async {
                final amount = double.tryParse(amountController.text);
                final phone = phoneController.text.trim();
                final pin = pinController.text.trim();

                if (amount == null || amount <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a valid amount')));
                  return;
                }
                if (phone.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a valid mobile money phone number')));
                  return;
                }

                setDialogState(() => isProcessing = true);
                NotificationService.playClickSound();

                final res = await provider.payChanguCharge(
                  amount: amount,
                  paymentMethod: _selectedPaymentMethod,
                  type: 'deposit',
                  phone: phone,
                  pin: pin.isNotEmpty ? pin : null,
                );

                if (!context.mounted) return;
                setDialogState(() => isProcessing = false);
                Navigator.pop(context);

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: res['success'] == true ? Colors.green : Colors.red,
                    content: Text(res['message'] ?? 'Transaction complete', style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                );
              },
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
    final String userPhone = provider.user?.token ?? '';

    final TextEditingController amountController = TextEditingController(text: stats?.totalToRepay.toStringAsFixed(2) ?? '0.00');
    final TextEditingController phoneController = TextEditingController(text: userPhone);
    final TextEditingController pinController = TextEditingController();
    bool isProcessing = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: theme.colorScheme.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.greenAccent.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.assignment_turned_in_rounded, color: Colors.greenAccent, size: 22),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'INSTANT LOAN REPAYMENT',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    letterSpacing: 1,
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
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.greenAccent.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Total Loan Due:', style: TextStyle(fontSize: 12, color: isDark ? BankTheme.textMuted : BankTheme.lightTextSecondary)),
                      Text('MK ${stats?.totalToRepay.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.greenAccent, fontSize: 14)),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text('SELECT PAYMENT METHOD', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isDark ? BankTheme.textMuted : BankTheme.lightTextSecondary)),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  value: _selectedPaymentMethod,
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
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
                          Text(value, style: TextStyle(fontSize: 14, color: isDark ? Colors.white : BankTheme.lightTextPrimary)),
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
                const SizedBox(height: 16),
                TextField(
                  controller: phoneController,
                  keyboardType: TextInputType.phone,
                  style: TextStyle(fontSize: 15, color: isDark ? Colors.white : BankTheme.lightTextPrimary),
                  decoration: const InputDecoration(
                    labelText: 'MOBILE MONEY NUMBER',
                    hintText: 'e.g. 088xxxxxxx or 099xxxxxxx',
                    prefixIcon: Icon(Icons.phone_android_rounded),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: amountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: isDark ? Colors.white : BankTheme.lightTextPrimary),
                  decoration: const InputDecoration(
                    prefixText: 'MK ',
                    labelText: 'REPAYMENT AMOUNT',
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: pinController,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  style: TextStyle(fontSize: 15, color: isDark ? Colors.white : BankTheme.lightTextPrimary),
                  decoration: const InputDecoration(
                    labelText: 'MOBILE MONEY PIN',
                    hintText: 'Enter PIN to authorize repayment',
                    prefixIcon: Icon(Icons.lock_outline_rounded),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isProcessing ? null : () => Navigator.pop(context),
              child: Text('CANCEL', style: TextStyle(color: isDark ? BankTheme.textMuted : BankTheme.lightTextSecondary, fontWeight: FontWeight.bold)),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(140, 45),
                backgroundColor: Colors.greenAccent,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              icon: isProcessing
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                : const Icon(Icons.check_circle_rounded, size: 18),
              label: Text(isProcessing ? 'PROCESSING...' : 'REPAY NOW'),
              onPressed: isProcessing ? null : () async {
                final amount = double.tryParse(amountController.text);
                final phone = phoneController.text.trim();
                final pin = pinController.text.trim();

                if (amount == null || amount <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a valid amount')));
                  return;
                }
                if (phone.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter mobile money phone number')));
                  return;
                }

                setDialogState(() => isProcessing = true);
                NotificationService.playClickSound();

                final res = await provider.payChanguCharge(
                  amount: amount,
                  paymentMethod: _selectedPaymentMethod,
                  type: 'repayment',
                  phone: phone,
                  pin: pin.isNotEmpty ? pin : null,
                );

                if (!context.mounted) return;
                setDialogState(() => isProcessing = false);
                Navigator.pop(context);

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: res['success'] == true ? Colors.green : Colors.red,
                    content: Text(res['message'] ?? 'Repayment complete', style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                );
              },
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
    final String userPhone = provider.user?.token ?? '';

    final TextEditingController amountController = TextEditingController(text: totalSavings > 0 ? totalSavings.toStringAsFixed(2) : '');
    final TextEditingController accountController = TextEditingController(text: userPhone);
    String selectedMethod = _selectedPaymentMethod;
    bool isProcessing = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: theme.colorScheme.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orangeAccent.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.outbox_rounded, color: Colors.orangeAccent, size: 22),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'INSTANT SAVINGS WITHDRAWAL',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    letterSpacing: 1,
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
                Text('Instant payout directly to your mobile money account.', style: TextStyle(color: isDark ? BankTheme.textMuted : BankTheme.lightTextSecondary, fontSize: 12)),
                const SizedBox(height: 16),
                Text('WITHDRAWAL METHOD', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isDark ? BankTheme.textMuted : BankTheme.lightTextSecondary)),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  value: selectedMethod,
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
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
                          Text(value, style: TextStyle(fontSize: 14, color: isDark ? Colors.white : BankTheme.lightTextPrimary)),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (newValue) {
                    if (newValue != null) {
                      setDialogState(() {
                        selectedMethod = newValue;
                      });
                    }
                  },
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: amountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: isDark ? Colors.white : BankTheme.lightTextPrimary),
                  decoration: const InputDecoration(
                    prefixText: 'MK ',
                    labelText: 'AMOUNT',
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: accountController,
                  style: TextStyle(fontSize: 14, color: isDark ? Colors.white : BankTheme.lightTextPrimary),
                  decoration: const InputDecoration(
                    labelText: 'RECEIVING PHONE NUMBER',
                    hintText: 'e.g. 088xxxxxxx or 099xxxxxxx',
                    prefixIcon: Icon(Icons.phone_android_rounded),
                  ),
                ),
                const SizedBox(height: 8),
                Text('Max Available Savings: MK ${totalSavings.toStringAsFixed(2)}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: BankTheme.statusYellow)),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isProcessing ? null : () => Navigator.pop(context),
              child: Text('CANCEL', style: TextStyle(color: isDark ? BankTheme.textMuted : BankTheme.lightTextSecondary, fontWeight: FontWeight.bold)),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(140, 45),
                backgroundColor: Colors.orangeAccent,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              icon: isProcessing
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                : const Icon(Icons.send_rounded, size: 18),
              label: Text(isProcessing ? 'DISBURSING...' : 'WITHDRAW NOW'),
              onPressed: isProcessing ? null : () async {
                final amount = double.tryParse(amountController.text);
                final receivingAcc = accountController.text.trim();

                if (amount == null || amount <= 0 || amount > totalSavings) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Please enter a valid amount up to MK ${totalSavings.toStringAsFixed(2)}')));
                  return;
                }
                if (receivingAcc.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter receiving phone number')));
                  return;
                }

                setDialogState(() => isProcessing = true);
                NotificationService.playClickSound();

                final res = await provider.payChanguPayout(
                  amount: amount,
                  recipientPhone: receivingAcc,
                  paymentMethod: selectedMethod,
                  type: 'payout',
                );

                if (!context.mounted) return;
                setDialogState(() => isProcessing = false);
                Navigator.pop(context);

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: res['success'] == true ? Colors.orangeAccent : Colors.red,
                    content: Text(res['message'] ?? 'Payout complete', style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showInstantWithdrawDialog() {
    final provider = Provider.of<BankProvider>(context, listen: false);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final double unwithdrawn = provider.memberStats?.unwithdrawnLoan ?? 0.0;
    final String defaultPhone = provider.user?.token ?? '';

    final TextEditingController amountController = TextEditingController(text: unwithdrawn > 0 ? unwithdrawn.toStringAsFixed(2) : '');
    final TextEditingController phoneController = TextEditingController(text: defaultPhone);
    String selectedMethod = 'TNM Mpamba';
    bool isProcessing = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: theme.colorScheme.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.flash_on_rounded, color: Colors.greenAccent),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'INSTANT LOAN WITHDRAWAL',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    letterSpacing: 1,
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
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.greenAccent.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.greenAccent.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.verified_user_rounded, color: Colors.greenAccent, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Instant Mobile Disbursement! Available Loaned Cash: MK ${unwithdrawn.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white70 : BankTheme.lightTextSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text('WITHDRAWAL METHOD', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isDark ? BankTheme.textMuted : BankTheme.lightTextSecondary)),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  value: selectedMethod,
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  dropdownColor: theme.colorScheme.surface,
                  items: ['TNM Mpamba', 'Airtel Money', 'National Bank (626)'].map((String value) {
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
                          Text(value, style: TextStyle(fontSize: 14, color: isDark ? Colors.white : BankTheme.lightTextPrimary)),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (newValue) {
                    if (newValue != null) {
                      setDialogState(() {
                        selectedMethod = newValue;
                      });
                    }
                  },
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: amountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: isDark ? Colors.white : BankTheme.lightTextPrimary),
                  decoration: const InputDecoration(
                    prefixText: 'MK ',
                    labelText: 'WITHDRAWAL AMOUNT',
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: phoneController,
                  keyboardType: TextInputType.phone,
                  style: TextStyle(fontSize: 14, color: isDark ? Colors.white : BankTheme.lightTextPrimary),
                  decoration: const InputDecoration(
                    labelText: 'RECEIVING TNM / AIRTEL NUMBER',
                    hintText: 'e.g. 088xxxxxxx or 099xxxxxxx',
                    prefixIcon: Icon(Icons.phone_android_rounded),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '* Money will be sent directly to this number via Direct Mobile Money Gateway.',
                  style: TextStyle(fontSize: 10, fontStyle: FontStyle.italic, color: isDark ? BankTheme.textMuted : BankTheme.lightTextSecondary),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isProcessing ? null : () => Navigator.pop(context),
              child: Text('CANCEL', style: TextStyle(color: isDark ? BankTheme.textMuted : BankTheme.lightTextSecondary, fontWeight: FontWeight.bold)),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(140, 45),
                backgroundColor: Colors.greenAccent,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              icon: isProcessing
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                : const Icon(Icons.flash_on_rounded, size: 18),
              label: Text(isProcessing ? 'DISBURSING...' : 'WITHDRAW NOW'),
              onPressed: isProcessing ? null : () async {
                final amount = double.tryParse(amountController.text);
                final receivingPhone = phoneController.text.trim();

                if (amount == null || amount <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a valid amount.')));
                  return;
                }

                if (amount > unwithdrawn) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Amount exceeds available borrowed cash (MK ${unwithdrawn.toStringAsFixed(2)})')));
                  return;
                }

                if (receivingPhone.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please specify receiving phone number.')));
                  return;
                }

                setDialogState(() => isProcessing = true);
                NotificationService.playClickSound();

                final res = await provider.payChanguPayout(
                  amount: amount,
                  recipientPhone: receivingPhone,
                  paymentMethod: selectedMethod,
                  type: 'instant-loan',
                );

                if (!context.mounted) return;
                setDialogState(() => isProcessing = false);
                Navigator.pop(context);

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: res['success'] == true ? Colors.greenAccent : Colors.red,
                    content: Text(res['message'] ?? 'Withdrawal complete', style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                  ),
                );
              },
            ),
          ],
        ),
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
        title: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Row(
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
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.phone_rounded, size: 20, color: Colors.greenAccent),
            tooltip: 'Call Admin Direct',
            onPressed: _callAdmin,
          ),
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
              } else if (value == 'logout') {
                Provider.of<BankProvider>(context, listen: false).logout();
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (context) => const AuthScreen()),
                  (route) => false,
                );
              }
            },
            itemBuilder: (context) {
              final user = Provider.of<BankProvider>(context, listen: false).user;
              return [
                PopupMenuItem(
                  enabled: false,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user?.name ?? 'User',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : BankTheme.lightTextPrimary,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        'Account: ${user?.token ?? ""}',
                        style: const TextStyle(fontSize: 10, color: BankTheme.statusYellow),
                      ),
                      Text(
                        'Org: ${user?.organizationName ?? "Village Bank"}',
                        style: const TextStyle(fontSize: 10, color: BankTheme.accentPurple, fontWeight: FontWeight.bold),
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
                  value: 'logout',
                  child: Row(
                    children: [
                      Icon(Icons.logout_rounded, size: 18, color: Colors.redAccent),
                      const SizedBox(width: 12),
                      Text('Logout', style: TextStyle(color: Colors.redAccent)),
                    ],
                  ),
                ),
              ];
            },
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
                      _buildStatCard('Borrowed Cash (In Acct)', 'MK ${stats?.unwithdrawnLoan.toStringAsFixed(2) ?? '0.00'}', isHighlight: (stats?.unwithdrawnLoan ?? 0) > 0),
                    ],
                  ),
                  if (stats != null && stats.unwithdrawnLoan > 0) ...[
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.greenAccent.withOpacity(0.15),
                            BankTheme.accentPurple.withOpacity(0.15),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.greenAccent.withOpacity(0.5), width: 1.5),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: Colors.greenAccent.withOpacity(0.2),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.account_balance_wallet_rounded, color: Colors.greenAccent, size: 20),
                                  ),
                                  const SizedBox(width: 10),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('LOANED CASH AVAILABLE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.greenAccent, letterSpacing: 1.5)),
                                      Text('Not Yet Withdrawn', style: TextStyle(fontSize: 11, color: isDark ? Colors.white70 : BankTheme.lightTextSecondary)),
                                    ],
                                  ),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.greenAccent,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Row(
                                  children: [
                                    Icon(Icons.bolt_rounded, size: 12, color: Colors.black),
                                    SizedBox(width: 2),
                                    Text('INSTANT', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.black)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'MK ${stats.unwithdrawnLoan.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              letterSpacing: -0.5,
                              color: isDark ? Colors.white : BankTheme.lightTextPrimary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Your approved loan is stored in your account. You can instantly withdraw this money to TNM Mpamba or Airtel Money without needing admin approval or changing SIM cards.',
                            style: TextStyle(fontSize: 12, height: 1.4, color: isDark ? BankTheme.textMuted : BankTheme.lightTextSecondary),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.greenAccent,
                                foregroundColor: Colors.black,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              icon: const Icon(Icons.flash_on_rounded, color: Colors.black),
                              label: const Text('INSTANT WITHDRAW CASH (TNM / AIRTEL)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 0.5)),
                              onPressed: _showInstantWithdrawDialog,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 32),
                  _buildAdminBankDetails(provider),
                  const SizedBox(height: 32),
                  GlassContainer(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Quick Overview', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 12),
                        const Text('Your financial summary is shown above. Use the tabs to manage your community interactions.', style: TextStyle(color: BankTheme.textMuted, fontSize: 14)),
                        if (stats != null && stats.unwithdrawnLoan > 0) ...[
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.greenAccent,
                                foregroundColor: Colors.black,
                              ),
                              icon: const Icon(Icons.flash_on_rounded, size: 18),
                              label: Text('Instant Withdraw Borrowed Cash (MK ${stats.unwithdrawnLoan.toStringAsFixed(2)})'),
                              onPressed: _showInstantWithdrawDialog,
                            ),
                          ),
                        ],
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
                            Expanded(child: OutlinedButton(
                              onPressed: _showLoanDialog,
                              child: Text(
                                stats != null && stats.loan > 0 
                                  ? 'Request Loan (${stats.pendingLoanCount}/3)' 
                                  : 'Request Loan',
                              ),
                            )),
                          ],
                        ),
                        if (stats != null && stats.loan > 0) ...[
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.greenAccent, foregroundColor: Colors.black),
                              onPressed: _showRepayDialog, 
                              child: const Text('Repay Active Loan'),
                            ),
                          ),
                        ],
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

    final double memberShare = stats.sharePercentage;
    final double orgReserve = 5.0;
    final double managementCut = 5.0;

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
              const Text('PROFIT DISTRIBUTION YIELD', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: BankTheme.accentPurple, letterSpacing: 2)),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildCircularProgressIndicator('Member (${memberShare.toStringAsFixed(0)}%)', memberShare / 100, Colors.greenAccent),
                  _buildCircularProgressIndicator('Reserve (5%)', orgReserve / 100, Colors.orangeAccent),
                  _buildCircularProgressIndicator('Portal (5%)', managementCut / 100, Colors.redAccent),
                ],
              ),
              const SizedBox(height: 32),
              Text(
                'Your organization (${provider.user?.organizationName ?? 'Village Bank'}) distributes ${memberShare.toStringAsFixed(0)}% profit back to your member savings pool upon loan repayment, while 5% supports the local group reserve and 5% platform management.',
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

  Widget _buildAdminBankDetails(BankProvider provider) {
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
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.greenAccent,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              icon: const Icon(Icons.phone_rounded, color: Colors.black, size: 20),
              label: Text('CALL ADMIN DIRECTLY (${provider.memberStats?.adminPhone ?? "0881689220"})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              onPressed: _callAdmin,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'For Airtel Money & TNM Mpamba, contact support or call directly.',
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

  Widget _buildStatCard(String label, String value, {bool isHighlight = false}) {
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
            Text(
              label,
              style: TextStyle(
                color: isHighlight ? Colors.greenAccent : (isDark ? BankTheme.textMuted : BankTheme.lightTextSecondary),
                fontSize: 12,
                fontWeight: isHighlight ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                letterSpacing: -0.5,
                color: isHighlight ? Colors.greenAccent : (isDark ? Colors.white : BankTheme.lightTextPrimary),
              ),
            ),
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
