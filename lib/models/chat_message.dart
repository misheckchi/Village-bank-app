class ChatMessage {
  final String id;
  final String sender;
  final String receiver;
  final String text;
  final String timestamp;
  final String? transactionId;
  final String? imageUrl;

  ChatMessage({
    required this.id,
    required this.sender,
    required this.receiver,
    required this.text,
    required this.timestamp,
    this.transactionId,
    this.imageUrl,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] ?? json['_id'] ?? '',
      sender: json['sender'] ?? '',
      receiver: json['receiver'] ?? '',
      text: json['text'] ?? '',
      timestamp: json['timestamp']?.toString() ?? '',
      transactionId: json['transactionId'],
      imageUrl: json['imageUrl'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'sender': sender,
      'receiver': receiver,
      'text': text,
      'transactionId': transactionId,
      'imageUrl': imageUrl,
    };
  }
}
