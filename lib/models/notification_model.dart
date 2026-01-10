class NotificationModel {
  final String id;
  final String userId; // Recipient user ID
  final String type; // 'follow', 'comment', 'reply'
  final String? bookId;
  final String? commentId;
  final String? fromUserId; // User who triggered the notification
  final String? fromUsername;
  final String message;
  final bool isRead;
  final DateTime createdAt;

  NotificationModel({
    required this.id,
    required this.userId,
    required this.type,
    this.bookId,
    this.commentId,
    this.fromUserId,
    this.fromUsername,
    required this.message,
    this.isRead = false,
    required this.createdAt,
  });

  factory NotificationModel.fromMap(Map<String, dynamic> map) {
    return NotificationModel(
      id: map['id'].toString(),
      userId: map['user_id'].toString(),
      type: map['type'].toString(),
      bookId: map['book_id']?.toString(),
      commentId: map['comment_id']?.toString(),
      fromUserId: map['from_user_id']?.toString(),
      fromUsername: map['from_username']?.toString(),
      message: map['message'] ?? '',
      isRead: map['is_read'] ?? false,
      createdAt: map['created_at'] is String
          ? DateTime.parse(map['created_at'])
          : (map['created_at'] as DateTime? ?? DateTime.now()),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'type': type,
      'book_id': bookId,
      'comment_id': commentId,
      'from_user_id': fromUserId,
      'from_username': fromUsername,
      'message': message,
      'is_read': isRead,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
