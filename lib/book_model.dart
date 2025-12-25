class Book {
  final String id;
  final String title;
  final String authorName;
  final String description;
  final String? coverUrl;

  Book({
    required this.id,
    required this.title,
    required this.authorName,
    required this.description,
    this.coverUrl,
  });

  // Converts Database (Map) data into a Book object
  factory Book.fromMap(Map<String, dynamic> map) {
    return Book(
      id: map['id'],
      title: map['title'],
      authorName: map['author_name'] ?? 'Unknown Author',
      description: map['description'] ?? '',
      coverUrl: map['cover_url'],
    );
  }
}
