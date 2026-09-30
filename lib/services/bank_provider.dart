import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import '../models/transaction.dart';
import '../models/user_model.dart';
import '../models/chat_message.dart';
import '../models/organization_model.dart';
import 'api_service.dart';
import 'notification_service.dart';

class BankProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();
  
  UserProfile? _user;
  MemberStats? _memberStats;
  AdminStats? _adminStats;
  List<Transaction> _transactions = [];
  List<PendingLoan> _pendingLoans = [];
  List<dynamic> _pendingPayouts = [];
  List<dynamic> _pendingDeposits = [];
  List<dynamic> _pendingRepayments = [];
  List<SystemLog> _logs = [];
  List<UserInfo> _users = [];
  List<ChatMessage> _messages = [];
  List<OrganizationModel> _globalOrganizations = [];
  Map<String, dynamic>? _globalSummary;
  List<OrganizationModel> _managementOrganizations = [];
  Map<String, dynamic>? _managementOverview;
  List<UserInfo> _orgMembers = [];
  List<Map<String, dynamic>> _activeOrganizations = [];

  final Map<String, List<ChatMessage>> _chatCache = {};
  String? _activeChatPhone;
  bool _isLoading = false;
  String? _errorMessage;
  ThemeMode _themeMode = ThemeMode.dark; // Default to dark

  Timer? _realtimeSyncTimer;
  bool _isPolling = false;
  final Set<String> _seenNotificationIds = {};

  UserProfile? get user => _user;
  MemberStats? get memberStats => _memberStats;
  AdminStats? get adminStats => _adminStats;
  List<Transaction> get transactions => _transactions;
  List<PendingLoan> get pendingLoans => _pendingLoans;
  List<dynamic> get pendingPayouts => _pendingPayouts;
  List<dynamic> get pendingDeposits => _pendingDeposits;
  List<dynamic> get pendingRepayments => _pendingRepayments;
  List<SystemLog> get logs => _logs;
  List<UserInfo> get users => _users;
  List<ChatMessage> get messages => _messages;
  List<OrganizationModel> get globalOrganizations => _globalOrganizations;
  Map<String, dynamic>? get globalSummary => _globalSummary;
  List<OrganizationModel> get managementOrganizations => _managementOrganizations;
  Map<String, dynamic>? get managementOverview => _managementOverview;
  List<UserInfo> get orgMembers => _orgMembers;
  List<Map<String, dynamic>> get activeOrganizations => _activeOrganizations;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  ThemeMode get themeMode => _themeMode;

  @override
  void dispose() {
    stopRealtimeSync();
    super.dispose();
  }

  void toggleTheme() {
    _themeMode = _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    notifyListeners();
  }

  // ==================== REAL-TIME NOTIFICATION POLLING ====================

  void startRealtimeSync() {
    _realtimeSyncTimer?.cancel();
    pollRealtimeNotifications();
    _realtimeSyncTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (_user != null) {
        pollRealtimeNotifications();
      } else {
        stopRealtimeSync();
      }
    });
  }

  void stopRealtimeSync() {
    _realtimeSyncTimer?.cancel();
    _realtimeSyncTimer = null;
  }

  Future<void> pollRealtimeNotifications() async {
    final enabled = await NotificationService.isNotificationEnabled();
    if (!enabled || _user == null || _isPolling) return;
    _isPolling = true;

    try {
      final phone = _user!.token;
      final role = _user!.role;
      final orgCode = _user!.organizationId ?? 'default_org';

      final unreadNotifs = await _apiService.fetchRealtimeNotifications(
        phone: phone,
        role: role,
        orgCode: orgCode,
      );

      final newNotifs = unreadNotifs.where((notif) {
        final id = notif['_id']?.toString();
        if (id == null) return false;
        if (_seenNotificationIds.contains(id)) return false;
        _seenNotificationIds.add(id);
        return true;
      }).toList();

      if (newNotifs.isNotEmpty) {
        List<String> idsToMarkRead = [];

        for (var notif in newNotifs) {
          final id = notif['_id']?.toString();
          final title = notif['title'] ?? 'Notification';
          final body = notif['body'] ?? '';
          final type = notif['type'] ?? 'info';
          final isError = type == 'danger' || type == 'error';

          if (id != null) {
            idsToMarkRead.add(id);
          }

          // Push native system notification and floating in-app snackbar
          await NotificationService.showSystemNotification(
            title: title,
            body: body,
            isError: isError,
          );
        }

        if (idsToMarkRead.isNotEmpty) {
          await _apiService.markNotificationsRead(idsToMarkRead);
        }

        // Refresh internal state according to user role
        if (role == 'admin') {
          await refreshAdminData();
        } else if (role == 'member') {
          await refreshMemberData();
        } else if (role == 'super_admin') {
          await refreshManagementData();
        }
      }
    } catch (e) {
      debugPrint('Poll Notifications Error: $e');
    } finally {
      _isPolling = false;
    }
  }

  Future<void> toggleNotifications(bool enable) async {
    await NotificationService.setNotificationEnabled(enable);
    if (enable) {
      await NotificationService.requestOSPermission();
      startRealtimeSync();
    } else {
      stopRealtimeSync();
    }
    notifyListeners();
  }

  Future<bool> login(String phoneNumber, String password) async {
    // Clear any stale data before logging in
    stopRealtimeSync();
    _user = null;
    _memberStats = null;
    _adminStats = null;
    _transactions = [];
    _pendingLoans = [];
    _pendingPayouts = [];
    _pendingDeposits = [];
    _pendingRepayments = [];
    _users = [];
    _messages = [];
    _releases = [];

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    
    final result = await _apiService.login(phoneNumber, password);
    _user = result;
    
    if (_user == null) {
      _errorMessage = "Login failed. Please check your credentials.";
    } else {
      startRealtimeSync();
    }
    
    _isLoading = false;
    notifyListeners();
    return _user != null;
  }

  Future<void> refreshActiveOrganizations() async {
    try {
      final orgs = await _apiService.fetchActiveOrganizations();
      _activeOrganizations = orgs;
      notifyListeners();
    } catch (e) {
      print('Refresh Active Orgs Error: $e');
    }
  }

  Future<bool> registerOrganization({
    required String name,
    required int expectedMembers,
    required String contactPerson,
    required String contactPhone,
    required String contactEmail,
    required String description,
    required String adminName,
    required String adminPhone,
    required String adminPassword,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final success = await _apiService.registerOrganization(
      name: name,
      expectedMembers: expectedMembers,
      contactPerson: contactPerson,
      contactPhone: contactPhone,
      contactEmail: contactEmail,
      description: description,
      adminName: adminName,
      adminPhone: adminPhone,
      adminPassword: adminPassword,
    );

    _isLoading = false;
    notifyListeners();
    return success;
  }

  Future<bool> register(
    String phoneNumber,
    String password,
    String fullName, {
    String role = 'member',
    String organizationId = 'default_org',
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final result = await _apiService.register(
      phoneNumber,
      password,
      fullName,
      role: role,
      organizationId: organizationId,
    );

    // Only log in automatically if we were not already logged in (Self-Registration)
    if (_user == null && result != null) {
      _user = result;
      startRealtimeSync();
    }

    if (result == null) {
      _errorMessage = "Registration failed. Phone number may already be registered.";
    }

    _isLoading = false;
    notifyListeners();
    return result != null;
  }

  // Admin specific registration to avoid state confusion
  Future<bool> adminAddUser({
    required String phoneNumber,
    required String password,
    required String fullName,
    String role = 'member',
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final orgCode = _user?.organizationId ?? 'default_org';
    final result = await _apiService.register(
      phoneNumber,
      password,
      fullName,
      role: role,
      organizationId: orgCode,
    );

    if (result != null) {
      await refreshAdminData();
      NotificationService.showNotification(
        title: 'User Added',
        body: '$fullName has been successfully registered to your organization.',
      );
      NotificationService.playTransactionSound();
    } else {
      _errorMessage = "Failed to add user.";
    }

    _isLoading = false;
    notifyListeners();
    return result != null;
  }

  Future<void> refreshMemberData() async {
    if (_user == null) return;
    _isLoading = true;
    notifyListeners();
    
    try {
      final stats = await _apiService.fetchMemberStats(_user!.token);
      final txs = await _apiService.fetchTransactions(_user!.token);
      
      if (stats != null) {
        // Notify if a new transaction was verified
        if (_transactions.isNotEmpty && txs.length > _transactions.length) {
          NotificationService.showNotification(
            title: 'Transaction Updated',
            body: 'A new activity has been recorded on your account.',
          );
        }
        _memberStats = stats;
        _transactions = txs;
      }
    } catch (e) {} finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refreshAdminData() async {
    _isLoading = true;
    notifyListeners();
    
    try {
      final orgCode = _user?.organizationId ?? 'default_org';
      final stats = await _apiService.fetchAdminStats(orgCode);
      final pLoans = await _apiService.fetchPendingLoans(orgCode);
      final pPayouts = await _apiService.fetchPendingPayouts(orgCode);
      final pDeposits = await _apiService.fetchPendingDeposits(orgCode);
      final pRepayments = await _apiService.fetchPendingRepayments(orgCode);
      final uList = await _apiService.fetchUsers(orgCode);
      
      if (stats != null) {
        // Notify Admin of new requests
        if (_pendingLoans.isNotEmpty && pLoans.length > _pendingLoans.length) {
          NotificationService.showNotification(
            title: 'New Loan Request',
            body: 'A member has requested a new loan.',
          );
        }

        if (_pendingDeposits.isNotEmpty && pDeposits.length > _pendingDeposits.length) {
          NotificationService.showNotification(
            title: 'New Deposit',
            body: 'A new deposit is waiting for verification.',
          );
        }

        if (_pendingRepayments.isNotEmpty && pRepayments.length > _pendingRepayments.length) {
          NotificationService.showNotification(
            title: 'New Repayment',
            body: 'A new repayment is waiting for verification.',
          );
        }

        _adminStats = stats;
        _pendingLoans = pLoans;
        _pendingPayouts = pPayouts;
        _pendingDeposits = pDeposits;
        _pendingRepayments = pRepayments;

        // Only update users if we actually got a list back
        if (uList.isNotEmpty || _users.isEmpty) {
          _users = uList;
        }
      }
    } catch (e) {
      print('Admin Refresh Error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>?> processLoan(String loanId, bool approve) async {
    final res = await _apiService.approveLoan(loanId, approve);
    if (res != null && res['success'] == true) {
      NotificationService.playTransactionSound();
      await refreshAdminData();
      return res;
    }
    return null;
  }

  Future<Map<String, dynamic>?> processPayout(String payoutId, bool confirm) async {
    final res = await _apiService.processPayout(payoutId, confirm);
    if (res != null && res['success'] == true) {
      NotificationService.playTransactionSound();
      await refreshAdminData();
      return res;
    }
    return null;
  }

  Future<bool> processDeposit(String depositId, bool approve) async {
    final success = await _apiService.approveDeposit(depositId, approve);
    if (success) {
      NotificationService.playTransactionSound();
      await refreshAdminData();
    }
    return success;
  }

  Future<bool> processRepayment(String repaymentId, bool approve) async {
    final success = await _apiService.approveRepayment(repaymentId, approve);
    if (success) {
      NotificationService.playTransactionSound();
      await refreshAdminData();
    }
    return success;
  }

  Future<bool> makeDeposit(double amount, String transactionId) async {
    if (_user == null) return false;
    final success = await _apiService.deposit(amount, _user!.token, transactionId);
    if (success) {
      NotificationService.playTransactionSound();
      await refreshMemberData();
    }
    return success;
  }

  Future<bool> makeLoanRequest(double amount, String receivingAccount) async {
    if (_user == null) return false;
    final res = await _apiService.requestLoan(amount, _user!.token, receivingAccount);
    if (res['success'] == true) {
      NotificationService.playTransactionSound();
      await refreshMemberData();
      return true;
    } else {
      _errorMessage = res['message'];
      notifyListeners();
      return false;
    }
  }

  Future<bool> instantWithdrawLoan({
    required double amount,
    required String paymentMethod,
    required String receivingPhone,
  }) async {
    if (_user == null) return false;
    final res = await _apiService.instantWithdrawLoan(
      token: _user!.token,
      amount: amount,
      paymentMethod: paymentMethod,
      receivingPhone: receivingPhone,
    );
    if (res['success'] == true) {
      NotificationService.playTransactionSound();
      await refreshMemberData();
      return true;
    } else {
      _errorMessage = res['message'];
      notifyListeners();
      return false;
    }
  }

  Future<bool> repayLoan(double amount, String transactionId) async {
    if (_user == null) return false;
    final success = await _apiService.repayLoan(amount, _user!.token, transactionId);
    if (success) {
      NotificationService.playTransactionSound();
      await refreshMemberData();
    }
    return success;
  }

  Future<bool> requestPayout(double amount, String receivingAccount) async {
    if (_user == null) return false;
    final success = await _apiService.requestPayout(amount, _user!.token, receivingAccount);
    if (success) {
      NotificationService.playTransactionSound();
      await refreshMemberData();
    }
    return success;
  }

  Future<bool> resetSystem() async {
    final success = await _apiService.resetSystem();
    if (success) await refreshAdminData();
    return success;
  }

  void logout() {
    stopRealtimeSync();
    _user = null;
    _memberStats = null;
    _adminStats = null;
    _transactions = [];
    _pendingLoans = [];
    _pendingPayouts = [];
    _pendingDeposits = [];
    _pendingRepayments = [];
    _users = [];
    _messages = [];
    _chatCache.clear();
    _activeChatPhone = null;
    _errorMessage = null;
    notifyListeners();
  }

  void setActiveChat(String? phone) {
    _activeChatPhone = phone;
    if (phone != null) {
      _messages = _chatCache[phone] ?? [];
    } else {
      _messages = [];
    }
    notifyListeners();
  }

  Future<void> refreshMessages(String otherPhone) async {
    if (_user == null) return;
    final newMsgs = await _apiService.fetchMessages(otherPhone, _user!.token);

    final int oldLen = _chatCache[otherPhone]?.length ?? 0;

    if (newMsgs.length > oldLen) {
      final lastMsg = newMsgs.last;
      // Only show notification if it's from the other person AND we aren't looking at the chat
      if (lastMsg.sender != _user?.token && _activeChatPhone != otherPhone) {
        NotificationService.showNotification(
          title: 'New Message',
          body: lastMsg.text,
        );
      }

      _chatCache[otherPhone] = newMsgs;

      // Only update the active UI list if this is the thread we are looking at
      if (_activeChatPhone == otherPhone) {
        _messages = List.from(newMsgs);
        notifyListeners();
      }
    } else if (newMsgs.length < oldLen || (_activeChatPhone == otherPhone && _messages.isEmpty && newMsgs.isNotEmpty)) {
      _chatCache[otherPhone] = newMsgs;
      if (_activeChatPhone == otherPhone) {
        _messages = List.from(newMsgs);
        notifyListeners();
      }
    } else if (_activeChatPhone == otherPhone && _messages.isEmpty && oldLen > 0) {
      // Force update if we just entered an already cached chat
      _messages = List.from(_chatCache[otherPhone]!);
      notifyListeners();
    }
  }

  Future<bool> sendMessage({
    required String text,
    required String receiverPhone,
    String? transactionId,
    String? imageUrl,
  }) async {
    if (_user == null) return false;
    
    final sender = _user!.token;
    final receiver = receiverPhone;
    
    final msg = await _apiService.sendMessage(
      sender: sender,
      receiver: receiver,
      text: text,
      transactionId: transactionId,
      imageUrl: imageUrl,
    );
    
    if (msg != null) {
      NotificationService.playTransactionSound();

      // Update cache for this thread
      if (!_chatCache.containsKey(receiver)) _chatCache[receiver] = [];
      _chatCache[receiver]!.add(msg);

      // Update active messages if viewing this thread
      if (_activeChatPhone == receiver) {
        _messages = List.from(_chatCache[receiver]!);
        notifyListeners();
      }
      return true;
    }
    return false;
  }

  Future<String?> uploadImage(File file) async {
    return await _apiService.uploadImage(file);
  }

  // ==================== GLOBAL ANALYTICS & SHARE MANAGEMENT ====================

  Future<void> refreshGlobalAnalytics() async {
    _isLoading = true;
    notifyListeners();
    try {
      final data = await _apiService.fetchGlobalAnalytics();
      if (data != null && data['success'] == true) {
        _globalSummary = data['summary'];
        List orgs = data['organizations'] ?? [];
        _globalOrganizations = orgs.map((o) => OrganizationModel.fromJson(o)).toList();
      }
    } catch (e) {
      print('Refresh Global Analytics Error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> updateOrganizationSharePercentage(String orgCode, double sharePercentage) async {
    final success = await _apiService.updateOrganizationSharePercentage(orgCode, sharePercentage);
    if (success) {
      await refreshGlobalAnalytics();
      await refreshAdminData();
    }
    return success;
  }

  // ==================== SUPER ADMIN / MANAGEMENT PORTAL ====================

  Future<void> refreshManagementData() async {
    _isLoading = true;
    notifyListeners();
    try {
      _managementOverview = await _apiService.fetchManagementOverview();
      _managementOrganizations = await _apiService.fetchManagementOrganizations();
      await refreshGlobalAnalytics();
    } catch (e) {
      print('Refresh Management Data Error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> approveOrganization(String orgId, bool approve) async {
    final success = await _apiService.approveOrganization(orgId, approve);
    if (success) {
      NotificationService.playTransactionSound();
      await refreshManagementData();
    }
    return success;
  }

  Future<List<UserInfo>> fetchOrgMembers(String orgCode) async {
    final members = await _apiService.fetchOrganizationMembers(orgCode);
    _orgMembers = members;
    notifyListeners();
    return members;
  }

  Future<bool> updateAdminAccountNumber(String adminPhone) async {
    if (_user == null) return false;
    final orgCode = _user!.organizationId;
    final success = await _apiService.updateAdminAccountNumber(orgCode, adminPhone);
    if (success) {
      await refreshAdminData();
    }
    return success;
  }
}
