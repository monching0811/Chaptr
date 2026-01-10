import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'book_model.dart';
import 'book_detail_screen.dart';
import 'animations.dart';
import 'widgets/book_flip_loading.dart';
import 'widgets/pagination_widget.dart';
import 'notifications_screen.dart';

class BookstoreScreen extends StatefulWidget {
  const BookstoreScreen({super.key});

  @override
  State<BookstoreScreen> createState() => _BookstoreScreenState();
}

class _BookstoreScreenState extends State<BookstoreScreen> {
  String _searchQuery = "";

  // Genre + books state for discovery
  List<String> _genres = [];
  bool _loadingGenres = true;
  List<Book> _allBooks = [];
  bool _loadingBooks = true;
  int _unreadNotifications = 0;

  Future<void> _loadUnreadNotifications() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    try {
      final response = await Supabase.instance.client
          .from('notifications')
          .select('id')
          .eq('user_id', user.id)
          .eq('is_read', false)
          .count();

      if (mounted) {
        setState(() {
          _unreadNotifications = response.count ?? 0;
        });
      }
    } catch (e) {
      // Notifications table might not exist yet
    }
  }

  Future<void> _loadGenresAndBooks() async {
    setState(() {
      _loadingGenres = true;
      _loadingBooks = true;
    });

    final supabase = Supabase.instance.client;

    // Load genres (try dedicated table, then distinct book genres, else fallback)
    try {
      final genresRes = await supabase
          .from('genres')
          .select('name')
          .order('name');
      final List<dynamic> genresList = genresRes as List<dynamic>? ?? [];
      if (genresList.isNotEmpty) {
        _genres = genresList
            .map((r) => (r['name'] ?? '').toString())
            .where((s) => s.isNotEmpty)
            .toList();
      } else {
        final booksRes = await supabase.from('books').select('genre');
        final List<dynamic> booksList = booksRes as List<dynamic>? ?? [];
        final genreSet = booksList
            .map((b) => (b['genre'] ?? '').toString())
            .where((s) => s.isNotEmpty)
            .toSet();

        // Split comma-separated genres
        final allGenres = <String>{};
        for (final genreStr in genreSet) {
          final splitGenres = genreStr
              .split(',')
              .map((g) => g.trim())
              .where((g) => g.isNotEmpty);
          allGenres.addAll(splitGenres);
        }

        _genres = allGenres.toList()..sort();
      }
    } catch (e) {
      _genres = [];
    } finally {
      // Add "All" as first option, then list individual genres
      if (_genres.isEmpty) {
        _genres = ['All'];
      } else {
        // Ensure "All" is first, then individual genres
        _genres = ['All', ..._genres.where((g) => g != 'All').toList()];
      }
      setState(() => _loadingGenres = false);
    }

    // Load books
    try {
      final response = await supabase
          .from('books')
          .select()
          .eq('status', 'Published')
          .order('created_at', ascending: false);
      final List<dynamic> respData = response as List<dynamic>? ?? [];
      _allBooks = respData.map((data) => Book.fromMap(data)).toList();
    } catch (e) {
      debugPrint('Error loading books: $e');
      _allBooks = [];
    } finally {
      setState(() => _loadingBooks = false);
    }
  }

  List<Book> _booksForGenre(String genre) {
    final q = _searchQuery.toLowerCase().trim();

    // If the user hasn't searched, return all books for the genre
    if (q.isEmpty) {
      if (genre == 'All' || genre.toLowerCase() == 'recommended') {
        return _allBooks;
      }
      // Filter by genre - check if genre string contains the selected genre (comma-separated)
      return _allBooks.where((b) {
        final bookGenres = b.genres.map((g) => g.toLowerCase()).toList();
        return bookGenres.contains(genre.toLowerCase());
      }).toList();
    }

    // Apply search filtering across title, author, description
    if (genre == 'All' || genre.toLowerCase() == 'recommended') {
      return _allBooks.where((b) {
        return b.title.toLowerCase().contains(q) ||
            b.authorName.toLowerCase().contains(q) ||
            b.description.toLowerCase().contains(q);
      }).toList();
    }

    // Filter by genre and search query
    return _allBooks.where((b) {
      final bookGenres = b.genres.map((g) => g.toLowerCase()).toList();
      final matchesGenre = bookGenres.contains(genre.toLowerCase());
      final matchesSearch =
          b.title.toLowerCase().contains(q) ||
          b.authorName.toLowerCase().contains(q) ||
          b.description.toLowerCase().contains(q);
      return matchesGenre && matchesSearch;
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _loadGenresAndBooks();
    _loadUnreadNotifications();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Image.asset(
              'logo/chaptrLOGO.png',
              width: 32,
              height: 32,
              fit: BoxFit.contain,
            ),
            const SizedBox(width: 8),
            const Text('Book'),
          ],
        ),
        backgroundColor: const Color(0xFFFFEB3B),
        foregroundColor: Colors.black,
        actions: [
          // Notification bell
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const NotificationsScreen(),
                    ),
                  ).then((_) => _loadUnreadNotifications());
                },
              ),
              if (_unreadNotifications > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    child: Text(
                      _unreadNotifications > 9 ? '9+' : '$_unreadNotifications',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // --- Search Field ---
          Padding(
            padding: const EdgeInsets.all(15.0),
            child: TextField(
              decoration: InputDecoration(
                hintText: "Search stories...",
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Theme.of(
                  context,
                ).colorScheme.surface.withAlpha((0.1 * 255).round()),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
          ),

          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                await _loadGenresAndBooks();
              },
              child: _loadingGenres || _loadingBooks
                  ? const Center(child: LogoLoading())
                  : DefaultTabController(
                      length: _genres.length,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // --- Genre Tab Bar (Scrollable) ---
                          SizedBox(
                            height: 50,
                            child: TabBar(
                              isScrollable: true,
                              labelColor: Colors.black,
                              indicatorColor: const Color(0xFFFFEB3B),
                              tabs: _genres.map((g) => Tab(text: g)).toList(),
                            ),
                          ),

                          // Tab views per genre
                          Expanded(
                            child: TabBarView(
                              children: _genres.map((genre) {
                                return _GenreTabView(
                                  genre: genre,
                                  books: _booksForGenre(genre),
                                  searchQuery: _searchQuery,
                                );
                              }).toList(),
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

// Separate widget for genre tab view with pagination
class _GenreTabView extends StatefulWidget {
  final String genre;
  final List<Book> books;
  final String searchQuery;

  const _GenreTabView({
    required this.genre,
    required this.books,
    required this.searchQuery,
  });

  @override
  State<_GenreTabView> createState() => _GenreTabViewState();
}

class _GenreTabViewState extends State<_GenreTabView> {
  int _topChartsPage = 1;
  static const int _itemsPerPage = 20;

  @override
  Widget build(BuildContext context) {
    // Featured: top 5 by reads
    final featured = List<Book>.from(widget.books)
      ..sort((a, b) => (b.reads).compareTo(a.reads));
    final featuredBooks = featured.take(5).toList();

    // Hottest Originals: top 10 by reads
    final hottest = List<Book>.from(widget.books)
      ..sort((a, b) => (b.reads).compareTo(a.reads));
    final hottestBooks = hottest.take(10).toList();

    // Top Charts: ranked by reads with pagination
    final ranked = List<Book>.from(widget.books)
      ..sort((a, b) => (b.reads).compareTo(a.reads));

    final totalPages = (ranked.length / _itemsPerPage).ceil();
    final startIndex = (_topChartsPage - 1) * _itemsPerPage;
    final endIndex = (startIndex + _itemsPerPage).clamp(0, ranked.length);
    final paginatedRanked = ranked.sublist(startIndex, endIndex);

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 15.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 10),
            Text(
              'Featured in ${widget.genre}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            if (featuredBooks.isNotEmpty)
              CarouselSlider(
                options: CarouselOptions(
                  height: 200,
                  enlargeCenterPage: true,
                  autoPlay: true,
                  viewportFraction: 0.8,
                ),
                items: featuredBooks.map((book) {
                  return GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      createSlideRoute(BookDetailScreen(book: book)),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          book.coverUrl != null
                              ? Image.network(book.coverUrl!, fit: BoxFit.cover)
                              : Container(color: const Color(0xFFFFF59D)),
                          Positioned(
                            bottom: 0,
                            left: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              color: Colors.black54,
                              child: Text(
                                book.title,
                                style: const TextStyle(color: Colors.white),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),

            const SizedBox(height: 20),
            const Text(
              'Hottest Originals',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 160,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: hottestBooks.length,
                itemBuilder: (context, i) {
                  final book = hottestBooks[i];
                  return Padding(
                    padding: const EdgeInsets.only(right: 12.0),
                    child: GestureDetector(
                      onTap: () => Navigator.push(
                        context,
                        createSlideRoute(BookDetailScreen(book: book)),
                      ),
                      child: Column(
                        children: [
                          Container(
                            width: 100,
                            height: 120,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              color: const Color(0xFFFFF59D),
                            ),
                            child: book.coverUrl != null
                                ? Image.network(
                                    book.coverUrl!,
                                    fit: BoxFit.cover,
                                  )
                                : const Icon(Icons.menu_book),
                          ),
                          const SizedBox(height: 6),
                          SizedBox(
                            width: 100,
                            child: Text(
                              book.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Top Charts',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                if (ranked.isNotEmpty)
                  Text(
                    'Showing ${startIndex + 1}-${endIndex} of ${ranked.length}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            if (paginatedRanked.isEmpty)
              const Padding(
                padding: EdgeInsets.all(20.0),
                child: Center(child: Text('No books found')),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: paginatedRanked.length,
                itemBuilder: (context, idx) {
                  final book = paginatedRanked[idx];
                  final globalIndex = startIndex + idx + 1;
                  return ListTile(
                    leading: Text('#$globalIndex'),
                    title: Text(book.title),
                    subtitle: Text(
                      '${book.authorName} • ${book.reads} reads • ${book.votes} votes',
                    ),
                    onTap: () => Navigator.push(
                      context,
                      createSlideRoute(BookDetailScreen(book: book)),
                    ),
                  );
                },
              ),

            // Pagination widget
            if (totalPages > 1)
              PaginationWidget(
                currentPage: _topChartsPage,
                totalPages: totalPages,
                onPageChanged: (page) {
                  setState(() {
                    _topChartsPage = page;
                  });
                  // Scroll to top of charts section
                  Scrollable.ensureVisible(
                    context,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                  );
                },
              ),

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}
