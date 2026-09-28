class UserProfile {
  final String name;
  final String role;
  final String token;
  final String organizationId;
  final String organizationName;

  String get accountNumber => token;

  UserProfile({
    required this.name,
    required this.role,
    required this.token,
    this.organizationId = 'default_org',
    this.organizationName = 'Village Bank',
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      name: json['name'] ?? '',
      role: json['role'] ?? 'member',
      token: json['token'] ?? json['phoneNumber'] ?? '',
      organizationId: json['organizationId'] ?? 'default_org',
      organizationName: json['organizationName'] ?? 'Village Bank',
    );
  }
}

class UserInfo {
  final String name;
  final String phoneNumber;
  final String role;
  final double savings;
  final double loan;
  final double interest;
  final String organizationId;

  UserInfo({
    required this.name,
    required this.phoneNumber,
    required this.role,
    required this.savings,
    required this.loan,
    required this.interest,
    this.organizationId = 'default_org',
  });

  factory UserInfo.fromJson(Map<String, dynamic> json) {
    return UserInfo(
      name: json['name'] ?? '',
      phoneNumber: json['phoneNumber'] ?? '',
      role: json['role'] ?? 'member',
      savings: (json['savings'] as num?)?.toDouble() ?? 0.0,
      loan: (json['loan'] as num?)?.toDouble() ?? 0.0,
      interest: (json['interest'] as num?)?.toDouble() ?? 0.0,
      organizationId: json['organizationId'] ?? 'default_org',
    );
  }
}

class MemberStats {
  final double savings;
  final double loan;
  final double unwithdrawnLoan;
  final double accruedInterest;
  final double totalToRepay;
  final double interestRate;
  final int pendingLoanCount;

  MemberStats({
    required this.savings,
    required this.loan,
    this.unwithdrawnLoan = 0.0,
    required this.accruedInterest,
    required this.totalToRepay,
    required this.interestRate,
    this.pendingLoanCount = 0,
  });

  factory MemberStats.fromJson(Map<String, dynamic> json) {
    return MemberStats(
      savings: (json['savings'] as num?)?.toDouble() ?? 0.0,
      loan: (json['loan'] as num?)?.toDouble() ?? 0.0,
      unwithdrawnLoan: (json['unwithdrawnLoan'] as num?)?.toDouble() ?? 0.0,
      accruedInterest: (json['accruedInterest'] as num?)?.toDouble() ?? 0.0,
      totalToRepay: (json['totalToRepay'] as num?)?.toDouble() ?? 0.0,
      interestRate: (json['interestRate'] as num?)?.toDouble() ?? 35.0,
      pendingLoanCount: json['pendingLoanCount'] ?? 0,
    );
  }
}

class AdminStats {
  final int totalMembers;
  final double groupFund;
  final int pendingApprovals;
  final double totalLoans;
  final double highestNet;
  final double bankCommission;

  AdminStats({
    required this.totalMembers,
    required this.groupFund,
    required this.pendingApprovals,
    required this.totalLoans,
    required this.highestNet,
    required this.bankCommission,
  });

  factory AdminStats.fromJson(Map<String, dynamic> json) {
    return AdminStats(
      totalMembers: json['totalMembers'] ?? 0,
      groupFund: (json['groupFund'] as num?)?.toDouble() ?? 0.0,
      pendingApprovals: json['pendingApprovals'] ?? 0,
      totalLoans: (json['totalLoans'] as num?)?.toDouble() ?? 0.0,
      highestNet: (json['highestNet'] as num?)?.toDouble() ?? 0.0,
      bankCommission: (json['bankCommission'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class PendingLoan {
  final String id;
  final double amount;
  final double interest;
  final String requestedBy;
  final String date;
  final String receivingAccount;

  PendingLoan({
    required this.id,
    required this.amount,
    required this.interest,
    required this.requestedBy,
    required this.date,
    required this.receivingAccount,
  });

  factory PendingLoan.fromJson(Map<String, dynamic> json) {
    return PendingLoan(
      id: json['id'] ?? json['_id'] ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      interest: (json['interest'] as num?)?.toDouble() ?? 0.0,
      requestedBy: json['requestedBy'] ?? '',
      date: json['date'] ?? '',
      receivingAccount: json['receivingAccount'] ?? '',
    );
  }
}

class SystemLog {
  final String id;
  final String title;
  final String desc;
  final String time;
  final String type;

  SystemLog({required this.id, required this.title, required this.desc, required this.time, required this.type});

  factory SystemLog.fromJson(Map<String, dynamic> json) {
    return SystemLog(
      id: json['id'] ?? json['_id'] ?? '',
      title: json['title'] ?? '',
      desc: json['desc'] ?? '',
      time: json['time'] ?? '',
      type: json['type'] ?? 'info',
    );
  }
}
