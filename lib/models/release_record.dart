class ReleaseRecord {
  final String id;
  final String version;
  final String buildNumber;
  final String downloadUrl;
  final String notes;
  final DateTime timestamp;

  ReleaseRecord({
    required this.id,
    required this.version,
    required this.buildNumber,
    required this.downloadUrl,
    required this.notes,
    required this.timestamp,
  });

  factory ReleaseRecord.fromJson(Map<String, dynamic> json) {
    return ReleaseRecord(
      id: json['id'] ?? '',
      version: json['version'] ?? '',
      buildNumber: json['buildNumber'] ?? '',
      downloadUrl: json['downloadUrl'] ?? '',
      notes: json['notes'] ?? '',
      timestamp: DateTime.parse(json['timestamp'] ?? DateTime.now().toIso8601String()),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'version': version,
      'buildNumber': buildNumber,
      'downloadUrl': downloadUrl,
      'notes': notes,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}
