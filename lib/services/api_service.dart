import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import '../models/organization_model.dart';
import '../models/transaction.dart';
import '../models/user_model.dart';
import '../models/chat_message.dart';
import '../models/release_record.dart';
import '../models/global_post_model.dart';

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

  // ==================== ORGANIZATION APIS ====================

  Future<List<Map<String, dynamic>>> fetchActiveOrganizations() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/organizations/active'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return List<Map<String, dynamic>>.from(data['organizations']);
        }
      }
    } catch (e) {
      print('Fetch Active Orgs Error: $e');
    }
    return [];
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
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/organizations/register'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'name': name,
          'expectedMembers': expectedMembers,
          'contactPerson': contactPerson,
          'contactPhone': contactPhone,
          'contactEmail': contactEmail,
          'description': description,
          'adminName': adminName,
          'adminPhone': adminPhone,
          'adminPassword': adminPassword,
        }),
      );
      final data = json.decode(response.body);
      return response.statusCode == 200 && data['success'] == true;
    } catch (e) {
      print('Register Org Error: $e');
      return false;
    }
  }

  // ==================== MANAGEMENT PORTAL APIS ====================

  Future<Map<String, dynamic>?> fetchManagementOverview() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/management/overview'));
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
    } catch (e) {
      print('Fetch Management Overview Error: $e');
    }
    return null;
  }

  Future<List<OrganizationModel>> fetchManagementOrganizations() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/management/organizations'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          List orgs = data['organizations'];
          return orgs.map((item) => OrganizationModel.fromJson(item)).toList();
        }
      }
    } catch (e) {
      print('Fetch Management Organizations Error: $e');
    }
    return [];
  }

  Future<bool> approveOrganization(String orgId, bool approve) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/management/approve-organization'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'orgId': orgId, 'approve': approve}),
      );
      return response.statusCode == 200;
    } catch (e) {
      print('Approve Org Error: $e');
      return false;
    }
  }

  Future<List<UserInfo>> fetchOrganizationMembers(String orgCode) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/management/organization-members?orgCode=$orgCode'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          List members = data['members'];
          return members.map((item) => UserInfo.fromJson(item)).toList();
        }
      }
    } catch (e) {
      print('Fetch Org Members Error: $e');
    }
    return [];
  }

  // ==================== AUTH APIS ====================

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

  Future<UserProfile?> register(String phoneNumber, String password, String fullName, {String role = 'member', String organizationId = 'default_org'}) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/register'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'phoneNumber': phoneNumber,
          'password': password,
          'fullName': fullName,
          'role': role,
          'organizationId': organizationId,
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

  // ==================== MEMBER APIS ====================

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

  Future<AdminStats?> fetchAdminStats([String orgCode = 'default_org']) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/admin/overview?orgCode=$orgCode'));
      if (response.statusCode == 200) {
        return AdminStats.fromJson(json.decode(response.body));
      }
    } catch (e) {
      print('Fetch Admin Stats Error: $e');
    }
    return null;
  }

  Future<List<UserInfo>> fetchUsers([String orgCode = 'default_org']) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/admin/users?orgCode=$orgCode'));
      if (response.statusCode == 200) {
        List data = json.decode(response.body);
        return data.map((item) => UserInfo.fromJson(item)).toList();
      }
    } catch (e) {
      print('Fetch Users Error: $e');
    }
    return [];
  }

  Future<List<PendingLoan>> fetchPendingLoans([String orgCode = 'default_org']) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/admin/pending-loans?orgCode=$orgCode'));
      if (response.statusCode == 200) {
        List data = json.decode(response.body);
        return data.map((item) => PendingLoan.fromJson(item)).toList();
      }
    } catch (e) {
      print('Fetch Pending Loans Error: $e');
    }
    return [];
  }

  Future<List<dynamic>> fetchPendingPayouts([String orgCode = 'default_org']) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/admin/pending-payouts?orgCode=$orgCode'));
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
    } catch (e) {
      print('Fetch Pending Payouts Error: $e');
    }
    return [];
  }

  Future<List<dynamic>> fetchPendingDeposits([String orgCode = 'default_org']) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/admin/pending-deposits?orgCode=$orgCode'));
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
    } catch (e) {
      print('Fetch Pending Deposits Error: $e');
    }
    return [];
  }

  Future<List<dynamic>> fetchPendingRepayments([String orgCode = 'default_org']) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/admin/pending-repayments?orgCode=$orgCode'));
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

  Future<Map<String, dynamic>> requestLoan(double amount, String token, String receivingAccount) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/member/loan'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'amount': amount, 'phone': token, 'receivingAccount': receivingAccount}),
      );
      final data = json.decode(response.body);
      if (response.statusCode == 200 && data['success'] == true) {
        return {'success': true, 'message': data['message'] ?? 'Loan requested successfully'};
      } else {
        return {'success': false, 'message': data['message'] ?? 'Failed to request loan'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Network error. Please try again.'};
    }
  }

  Future<Map<String, dynamic>> instantWithdrawLoan({
    required String token,
    required double amount,
    required String paymentMethod,
    required String receivingPhone,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/member/instant-withdraw-loan'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'phone': token,
          'amount': amount,
          'paymentMethod': paymentMethod,
          'receivingPhone': receivingPhone,
        }),
      );
      final data = json.decode(response.body);
      if (response.statusCode == 200 && data['success'] == true) {
        return {'success': true, 'message': data['message'] ?? 'Withdrawal successful'};
      } else {
        return {'success': false, 'message': data['message'] ?? 'Withdrawal failed'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Network error. Please try again.'};
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

  // ==================== GLOBAL ANALYTICS & COMMUNITY THREAD APIS ====================

  Future<Map<String, dynamic>?> fetchGlobalAnalytics() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/analytics/global'));
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
    } catch (e) {
      print('Fetch Global Analytics Error: $e');
    }
    return null;
  }

  Future<bool> updateOrganizationSharePercentage(String orgCode, double sharePercentage) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/organizations/set-share-percentage'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'orgCode': orgCode,
          'sharePercentage': sharePercentage,
        }),
      );
      final data = json.decode(response.body);
      return response.statusCode == 200 && data['success'] == true;
    } catch (e) {
      print('Update Share Percentage Error: $e');
      return false;
    }
  }

  Future<List<GlobalPostModel>> fetchGlobalCommunityPosts() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/community/posts'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          List posts = data['posts'];
          return posts.map((p) => GlobalPostModel.fromJson(p)).toList();
        }
      }
    } catch (e) {
      print('Fetch Community Posts Error: $e');
    }
    return [];
  }

  Future<bool> createGlobalCommunityPost({
    required String title,
    required String content,
    required String authorName,
    required String authorOrg,
    required String authorPhone,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/community/posts'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'title': title,
          'content': content,
          'authorName': authorName,
          'authorOrg': authorOrg,
          'authorPhone': authorPhone,
        }),
      );
      final data = json.decode(response.body);
      return response.statusCode == 200 && data['success'] == true;
    } catch (e) {
      print('Create Community Post Error: $e');
      return false;
    }
  }

  Future<bool> replyGlobalCommunityPost({
    required String postId,
    required String authorName,
    required String authorOrg,
    required String content,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/community/posts/$postId/reply'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'authorName': authorName,
          'authorOrg': authorOrg,
          'content': content,
        }),
      );
      final data = json.decode(response.body);
      return response.statusCode == 200 && data['success'] == true;
    } catch (e) {
      print('Reply Community Post Error: $e');
      return false;
    }
  }

  Future<bool> likeGlobalCommunityPost(String postId, String userPhone) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/community/posts/$postId/like'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'userPhone': userPhone}),
      );
      final data = json.decode(response.body);
      return response.statusCode == 200 && data['success'] == true;
    } catch (e) {
      print('Like Post Error: $e');
      return false;
    }
  }
}
