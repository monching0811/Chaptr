class Book {
  final String id;
  final String title;
  final String authorName;
  final String? authorId;
  final List<String> genres;
  final String description;
  final List<Map<String, dynamic>> chapters; // Changed to handle status
  final String? coverUrl;
  final String status;
  final int reads;
  final int votes;

  Book({
    required this.id,
    required this.title,
    required this.authorName,
    this.authorId,
    required this.genres,
    required this.description,
    required this.chapters,
    this.coverUrl,
    required this.status,
    this.reads = 0,
    this.votes = 0,
  });

  String get genre => genres.join(', ');

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

    // Parse reads and votes safely (could be int, double or string)
    int parseInt(dynamic value) {
      if (value == null) return 0;
      if (value is int) return value;
      if (value is double) return value.round();
      if (value is String) {
        return int.tryParse(value) ?? 0;
      }
      return 0;
    }

    // Parse genres
    List<String> genresList = [];
    var rawGenres = map['genres'] ?? map['genre'];
    if (rawGenres is List) {
      genresList = rawGenres
          .map((e) => e.toString())
          .where((g) => g.trim().isNotEmpty)
          .toList();
    } else if (rawGenres is String) {
      // Split comma-separated genres and filter empty strings
      genresList = rawGenres
          .split(',')
          .map((g) => g.trim())
          .where((g) => g.isNotEmpty)
          .toList();
      // If splitting resulted in empty list, keep the original as single item
      if (genresList.isEmpty && rawGenres.trim().isNotEmpty) {
        genresList = [rawGenres.trim()];
      }
    }

    return Book(
      id: map['id'].toString(),
      title: map['title'] ?? 'Untitled',
      genres: genresList,
      authorName: map['author_name'] ?? 'Unknown Author',
      authorId: map['author_id']?.toString(),
      description: map['description'] ?? '',
      chapters: chapterList,
      coverUrl: map['cover_url'],
      status: map['status'] ?? 'Draft',
      reads: parseInt(map['reads'] ?? map['views'] ?? map['reads_count']),
      votes: parseInt(map['votes'] ?? map['likes'] ?? map['votes_count']),
    );
  }
}
