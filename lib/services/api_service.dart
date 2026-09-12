import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import '../models/transaction.dart';
import '../models/user_model.dart';
import '../models/chat_message.dart';
import '../models/release_record.dart';

class ApiService {
  static const String _pcIp = "172.20.10.12";
  static const String _productionUrl = "https://village-bank-app-api.onrender.com/api";
  static const bool _isProduction = true; // Set to true when you deploy!

  static String get baseUrl {
    if (_isProduction) return _productionUrl;
    if (kIsWeb) return "http://localhost:3000/api";
    try {
      if (Platform.isAndroid) return "http://$_pcIp:3000/api";
    } catch (e) {}
    return "http://localhost:3000/api";
  }

  Future<UserProfile?> login(String phoneNumber, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'phoneNumber': phoneNumber, 'password': password}),
      ).timeout(const Duration(seconds: 5));

      final data = json.decode(response.body);
      if (response.statusCode == 200 && data['success']) {
        return UserProfile.fromJson(data);
      }
    } catch (e) {
      print('Login Error: $e');
    }
    return null;
  }

  Future<UserProfile?> register(String phoneNumber, String password, String fullName, {String role = 'member'}) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/register'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'phoneNumber': phoneNumber,
          'password': password,
          'fullName': fullName,
          'role': role,
        }),
      ).timeout(const Duration(seconds: 5));

      final data = json.decode(response.body);
      if (response.statusCode == 200 && data['success']) {
        return UserProfile.fromJson(data);
      }
    } catch (e) {
      print('Registration Error: $e');
    }
    return null;
  }

  Future<MemberStats?> fetchMemberStats(String token) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/member/summary?phone=$token'));
      if (response.statusCode == 200) {
        return MemberStats.fromJson(json.decode(response.body));
      }
    } catch (e) {
      print('Fetch Stats Error: $e');
    }
    return null;
  }

  Future<List<Transaction>> fetchTransactions(String token) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/member/transactions?phone=$token'));
      if (response.statusCode == 200) {
        List data = json.decode(response.body);
        return data.map((item) => Transaction.fromJson(item)).toList();
      }
    } catch (e) {
      print('Fetch Transactions Error: $e');
    }
    return [];
  }

  Future<AdminStats?> fetchAdminStats() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/admin/overview'));
      if (response.statusCode == 200) {
        return AdminStats.fromJson(json.decode(response.body));
      }
    } catch (e) {
      print('Fetch Admin Stats Error: $e');
    }
    return null;
  }

  Future<List<UserInfo>> fetchUsers() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/admin/users'));
      if (response.statusCode == 200) {
        List data = json.decode(response.body);
        return data.map((item) => UserInfo.fromJson(item)).toList();
      }
    } catch (e) {
      print('Fetch Users Error: $e');
    }
    return [];
  }

  Future<List<PendingLoan>> fetchPendingLoans() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/admin/pending-loans'));
      if (response.statusCode == 200) {
        List data = json.decode(response.body);
        return data.map((item) => PendingLoan.fromJson(item)).toList();
      }
    } catch (e) {
      print('Fetch Pending Loans Error: $e');
    }
    return [];
  }

  Future<List<dynamic>> fetchPendingPayouts() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/admin/pending-payouts'));
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
    } catch (e) {
      print('Fetch Pending Payouts Error: $e');
    }
    return [];
  }

  Future<List<dynamic>> fetchPendingDeposits() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/admin/pending-deposits'));
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
    } catch (e) {
      print('Fetch Pending Deposits Error: $e');
    }
    return [];
  }

  Future<List<dynamic>> fetchPendingRepayments() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/admin/pending-repayments'));
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
    } catch (e) {
      print('Fetch Pending Repayments Error: $e');
    }
    return [];
  }

  Future<Map<String, dynamic>?> approveLoan(String loanId, bool approve) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/admin/approve-loan'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'loanId': loanId, 'approve': approve}),
      );
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
    } catch (e) {}
    return null;
  }

  Future<Map<String, dynamic>?> processPayout(String payoutId, bool confirm) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/admin/process-payout'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'payoutId': payoutId, 'confirm': confirm}),
      );
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
    } catch (e) {}
    return null;
  }

  Future<bool> approveDeposit(String depositId, bool approve) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/admin/approve-deposit'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'depositId': depositId, 'approve': approve}),
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  Future<bool> approveRepayment(String repaymentId, bool approve) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/admin/approve-repayment'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'repaymentId': repaymentId, 'approve': approve}),
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  Future<bool> deposit(double amount, String token, String transactionId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/member/deposit'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'amount': amount,
          'phone': token,
          'transactionId': transactionId,
        }),
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  Future<bool> requestLoan(double amount, String token, String receivingAccount) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/member/loan'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'amount': amount, 'phone': token, 'receivingAccount': receivingAccount}),
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  Future<bool> repayLoan(double amount, String token, String transactionId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/member/repay'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'amount': amount,
          'phone': token,
          'transactionId': transactionId,
        }),
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  Future<bool> requestPayout(double amount, String token, String receivingAccount) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/member/request-payout'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'amount': amount, 'phone': token, 'receivingAccount': receivingAccount}),
        body: json.encode({'amount': amount, 'phone': token}),
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  Future<bool> resetSystem() async {
    try {
      final response = await http.post(Uri.parse('$baseUrl/admin/reset'));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // Chat APIs
  Future<List<ChatMessage>> fetchMessages(String otherPhone, String myPhone) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/chat?other=$otherPhone&me=$myPhone'));
      if (response.statusCode == 200) {
        List data = json.decode(response.body);
        return data.map((item) => ChatMessage.fromJson(item)).toList();
      }
    } catch (e) {
      print('Fetch Messages Error: $e');
    }
    return [];
  }

  Future<ChatMessage?> sendMessage({
    required String sender,
    required String receiver,
    required String text,
    String? transactionId,
    String? imageUrl,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/chat/send'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'sender': sender,
          'receiver': receiver,
          'text': text,
          'transactionId': transactionId,
          'imageUrl': imageUrl,
        }),
      );
      if (response.statusCode == 200) {
        return ChatMessage.fromJson(json.decode(response.body));
      }
    } catch (e) {
      print('Send Message Error: $e');
    }
    return null;
  }

  Future<String?> uploadImage(File file) async {
    try {
      final bytes = await file.readAsBytes();
      final base64Image = base64Encode(bytes);
      final fileName = '${DateTime.now().millisecondsSinceEpoch}${p.extension(file.path)}';

      final response = await http.post(
        Uri.parse('$baseUrl/upload'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'image': base64Image,
          'fileName': fileName,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        String url = data['url'];
        
        // Only perform localhost replacement if NOT in production
        if (!_isProduction && !kIsWeb && Platform.isAndroid) {
          url = url.replaceAll('localhost', _pcIp);
        }
        return url;
      }
    } catch (e) {
      print('Upload Error: $e');
    }
    return null;
  }

  // Release Tracking APIs
  Future<List<ReleaseRecord>> fetchReleases() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/releases'));
      if (response.statusCode == 200) {
        List data = json.decode(response.body);
        return data.map((item) => ReleaseRecord.fromJson(item)).toList();
      }
    } catch (e) {
      print('Fetch Releases Error: $e');
    }
    return [];
  }

  Future<bool> logRelease({
    required String version,
    required String buildNumber,
    required String downloadUrl,
    required String notes,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/releases/log'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'version': version,
          'buildNumber': buildNumber,
          'downloadUrl': downloadUrl,
          'notes': notes,
        }),
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}
