class Comment {
  final String id;
  final String bookId;
  final String userId;
  final String username;
  final String comment;
  final DateTime createdAt;
  final String? parentCommentId; // For replies
  final List<Comment> replies; // Nested replies

  Comment({
    required this.id,
    required this.bookId,
    required this.userId,
    required this.username,
    required this.comment,
    required this.createdAt,
    this.parentCommentId,
    this.replies = const [],
  });

  factory Comment.fromMap(Map<String, dynamic> map) {
    // Handle both joined profile and direct username field
    String username = 'Anonymous';
    if (map['profiles'] != null && map['profiles'] is Map) {
      username = map['profiles']?['username'] ?? 'Anonymous';
    } else if (map['username'] != null) {
      username = map['username'].toString();
    }
    
    return Comment(
      id: map['id'].toString(),
      bookId: map['book_id'].toString(),
      userId: map['user_id'].toString(),
      username: username,
      comment: map['comment'] ?? '',
      createdAt: map['created_at'] is String 
          ? DateTime.parse(map['created_at'])
          : (map['created_at'] as DateTime? ?? DateTime.now()),
      parentCommentId: map['parent_comment_id']?.toString(),
      replies: map['replies'] != null 
          ? (map['replies'] as List).map((r) => Comment.fromMap(r)).toList()
          : [],
    );
  }
}
