class Book {
  final String id;
  final String title;
  final String authorName;
  final String genre;
  final String description;
  final List<Map<String, dynamic>> chapters; // Changed to handle status
  final String? coverUrl;
  final String status;

  Book({
    required this.id,
    required this.title,
    required this.authorName,
    required this.genre,
    required this.description,
    required this.chapters,
    this.coverUrl,
    required this.status,
  });

  factory Book.fromMap(Map<String, dynamic> map) {
    var rawChapters = map['chapters'];
    List<Map<String, dynamic>> chapterList = [];

    if (rawChapters is List) {
      // Cast the incoming list to the correct format
      chapterList = rawChapters
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    } else if (rawChapters is String) {
      // Backward compatibility for old simple text books
      chapterList = [
        {'content': rawChapters, 'is_published': true},
      ];
    }

    return Book(
      id: map['id'].toString(),
      title: map['title'] ?? 'Untitled',
      genre: map['genre'] ?? 'Story',
      authorName: map['author_name'] ?? 'Unknown Author',
      description: map['description'] ?? '',
      chapters: chapterList,
      coverUrl: map['cover_url'],
      status: map['status'] ?? 'Draft',
    );
  }
}
