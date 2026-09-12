import 'dart:io';
import 'package:flutter/material.dart';
import '../models/transaction.dart';
import '../models/user_model.dart';
import '../models/chat_message.dart';
import '../models/release_record.dart';
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
  List<ReleaseRecord> _releases = [];
  final Map<String, List<ChatMessage>> _chatCache = {};
  String? _activeChatPhone;
  bool _isLoading = false;
  String? _errorMessage;
  ThemeMode _themeMode = ThemeMode.dark; // Default to dark

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
  List<ReleaseRecord> get releases => _releases;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  ThemeMode get themeMode => _themeMode;

  void toggleTheme() {
    _themeMode = _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    notifyListeners();
  }

  Future<bool> login(String phoneNumber, String password) async {
    // Clear any stale data before logging in
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
    }
    
    _isLoading = false;
    notifyListeners();
    return _user != null;
  }

  Future<bool> register(String phoneNumber, String password, String fullName, {String role = 'member'}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final result = await _apiService.register(phoneNumber, password, fullName, role: role);

    // Only log in automatically if we were not already logged in (Self-Registration)
    if (_user == null && result != null) {
      _user = result;
    }

    if (result == null) {
      _errorMessage = "Registration failed.";
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

    final result = await _apiService.register(phoneNumber, password, fullName, role: role);

    if (result != null) {
      await refreshAdminData();
      NotificationService.showNotification(
        title: 'User Added',
        body: '$fullName has been successfully registered.',
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
      final stats = await _apiService.fetchAdminStats();
      final pLoans = await _apiService.fetchPendingLoans();
      final pPayouts = await _apiService.fetchPendingPayouts();
      final pDeposits = await _apiService.fetchPendingDeposits();
      final pRepayments = await _apiService.fetchPendingRepayments();
      final uList = await _apiService.fetchUsers();
      
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

  Future<bool> processLoan(String loanId, bool approve) async {
    final success = await _apiService.approveLoan(loanId, approve);
    if (success) {
      NotificationService.playTransactionSound();
      await refreshAdminData();
    }
    return success;
  }

  Future<bool> processPayout(String payoutId, bool confirm) async {
    final success = await _apiService.processPayout(payoutId, confirm);
    if (success) {
      NotificationService.playTransactionSound();
      await refreshAdminData();
    }
    return success;
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

  Future<bool> makeLoanRequest(double amount) async {
    if (_user == null) return false;
    final success = await _apiService.requestLoan(amount, _user!.token);
    if (success) {
      NotificationService.playTransactionSound();
      await refreshMemberData();
    }
    return success;
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

  Future<bool> requestPayout(double amount) async {
    if (_user == null) return false;
    final success = await _apiService.requestPayout(amount, _user!.token);
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

  Future<void> refreshReleases() async {
    _isLoading = true;
    notifyListeners();
    try {
      _releases = await _apiService.fetchReleases();
    } catch (e) {
      print('Refresh Releases Error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> logNewRelease({
    required String version,
    required String buildNumber,
    required String downloadUrl,
    required String notes,
  }) async {
    final success = await _apiService.logRelease(
      version: version,
      buildNumber: buildNumber,
      downloadUrl: downloadUrl,
      notes: notes,
    );
    if (success) {
      await refreshReleases();
    }
    return success;
  }
}
