class Comment {
  final String id;
  final String bookId;
  final String userId;
  final String username;
  final String comment;
  final DateTime createdAt;

  Comment({
    required this.id,
    required this.bookId,
    required this.userId,
    required this.username,
    required this.comment,
    required this.createdAt,
  });

  factory Comment.fromMap(Map<String, dynamic> map) {
    return Comment(
      id: map['id'].toString(),
      bookId: map['book_id'].toString(),
      userId: map['user_id'].toString(),
      username: map['profiles']?['username'] ?? 'Anonymous',
      comment: map['comment'] ?? '',
      createdAt: DateTime.parse(map['created_at']),
    );
  }
}
