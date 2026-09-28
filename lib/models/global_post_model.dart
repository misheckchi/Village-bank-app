class GlobalReplyModel {
  final String authorName;
  final String authorOrg;
  final String content;
  final DateTime timestamp;

  GlobalReplyModel({
    required this.authorName,
    required this.authorOrg,
    required this.content,
    required this.timestamp,
  });

  factory GlobalReplyModel.fromJson(Map<String, dynamic> json) {
    return GlobalReplyModel(
      authorName: json['authorName'] ?? 'Member',
      authorOrg: json['authorOrg'] ?? 'Village Bank',
      content: json['content'] ?? '',
      timestamp: json['timestamp'] != null ? DateTime.parse(json['timestamp']) : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'authorName': authorName,
    'authorOrg': authorOrg,
    'content': content,
    'timestamp': timestamp.toIso8601String(),
  };
}

class GlobalPostModel {
  final String id;
  final String title;
  final String content;
  final String authorName;
  final String authorOrg;
  final String authorPhone;
  final List<String> likes;
  final List<GlobalReplyModel> replies;
  final DateTime timestamp;

  GlobalPostModel({
    required this.id,
    required this.title,
    required this.content,
    required this.authorName,
    required this.authorOrg,
    required this.authorPhone,
    required this.likes,
    required this.replies,
    required this.timestamp,
  });

  factory GlobalPostModel.fromJson(Map<String, dynamic> json) {
    var likesList = json['likes'];
    List<String> parsedLikes = [];
    if (likesList is List) {
      parsedLikes = likesList.map((e) => e.toString()).toList();
    }

    var repliesList = json['replies'];
    List<GlobalReplyModel> parsedReplies = [];
    if (repliesList is List) {
      parsedReplies = repliesList.map((r) => GlobalReplyModel.fromJson(r)).toList();
    }

    return GlobalPostModel(
      id: json['_id'] ?? json['id'] ?? '',
      title: json['title'] ?? '',
      content: json['content'] ?? '',
      authorName: json['authorName'] ?? 'Anonymous',
      authorOrg: json['authorOrg'] ?? 'Village Bank',
      authorPhone: json['authorPhone'] ?? '',
      likes: parsedLikes,
      replies: parsedReplies,
      timestamp: json['timestamp'] != null ? DateTime.parse(json['timestamp']) : DateTime.now(),
    );
  }
}
