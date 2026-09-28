class OrganizationModel {
  final String id;
  final String code;
  final String name;
  final String description;
  final int expectedMembers;
  final String contactPerson;
  final String contactPhone;
  final String contactEmail;
  final String adminName;
  final String adminPhone;
  final String status;
  final int memberCount;
  final double totalSavings;
  final double totalLoans;
  final double sharePercentage;
  final double organizationFund;
  final int fundUtilization;
  final int healthScore;

  OrganizationModel({
    required this.id,
    required this.code,
    required this.name,
    required this.description,
    required this.expectedMembers,
    required this.contactPerson,
    required this.contactPhone,
    required this.contactEmail,
    required this.adminName,
    required this.adminPhone,
    required this.status,
    required this.memberCount,
    required this.totalSavings,
    required this.totalLoans,
    this.sharePercentage = 25.0,
    this.organizationFund = 0.0,
    this.fundUtilization = 0,
    this.healthScore = 100,
  });

  factory OrganizationModel.fromJson(Map<String, dynamic> json) {
    return OrganizationModel(
      id: json['id'] ?? json['_id'] ?? '',
      code: json['code'] ?? '',
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      expectedMembers: json['expectedMembers'] ?? 0,
      contactPerson: json['contactPerson'] ?? '',
      contactPhone: json['contactPhone'] ?? '',
      contactEmail: json['contactEmail'] ?? '',
      adminName: json['adminName'] ?? '',
      adminPhone: json['adminPhone'] ?? '',
      status: json['status'] ?? 'pending',
      memberCount: json['memberCount'] ?? 0,
      totalSavings: (json['totalSavings'] as num?)?.toDouble() ?? 0.0,
      totalLoans: (json['totalLoans'] as num?)?.toDouble() ?? 0.0,
      sharePercentage: (json['sharePercentage'] as num?)?.toDouble() ?? 25.0,
      organizationFund: (json['organizationFund'] as num?)?.toDouble() ?? 0.0,
      fundUtilization: json['fundUtilization'] ?? 0,
      healthScore: json['healthScore'] ?? 100,
    );
  }
}
