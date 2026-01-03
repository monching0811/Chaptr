import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'book_model.dart';
import 'book_detail_screen.dart';
import 'animations.dart';
import 'widgets/book_flip_loading.dart';

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
        _genres = booksList
            .map((b) => (b['genre'] ?? '').toString())
            .where((s) => s.isNotEmpty)
            .toSet()
            .toList();
      }
    } catch (e) {
      _genres = [];
    } finally {
      if (_genres.isEmpty) _genres = ['All'];
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
      return _allBooks
          .where((b) => b.genre.toLowerCase() == genre.toLowerCase())
          .toList();
    }

    // Apply search filtering across title, author, description
    if (genre == 'All' || genre.toLowerCase() == 'recommended') {
      return _allBooks.where((b) {
        return b.title.toLowerCase().contains(q) ||
            b.authorName.toLowerCase().contains(q) ||
            b.description.toLowerCase().contains(q);
      }).toList();
    }

    return _allBooks.where((b) {
      return b.genre.toLowerCase() == genre.toLowerCase() &&
          (b.title.toLowerCase().contains(q) ||
              b.authorName.toLowerCase().contains(q) ||
              b.description.toLowerCase().contains(q));
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _loadGenresAndBooks();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chaptr Bookstore'),
        backgroundColor: const Color(0xFFFFEB3B),
        foregroundColor: Colors.black,
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
                                final books = _booksForGenre(genre);
                                // Featured: top 5 by reads
                                final featured = List<Book>.from(
                                  books,
                                )..sort((a, b) => (b.reads).compareTo(a.reads));
                                final featuredBooks = featured.take(5).toList();

                                // Hottest Originals: top 10 by reads
                                final hottest = List<Book>.from(
                                  books,
                                )..sort((a, b) => (b.reads).compareTo(a.reads));
                                final hottestBooks = hottest.take(10).toList();

                                // Top Charts: ranked by reads
                                final ranked = List<Book>.from(
                                  books,
                                )..sort((a, b) => (b.reads).compareTo(a.reads));

                                return SingleChildScrollView(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 15.0,
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const SizedBox(height: 10),
                                        Text(
                                          'Featured in $genre',
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                          ),
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
                                                  createSlideRoute(
                                                    BookDetailScreen(
                                                      book: book,
                                                    ),
                                                  ),
                                                ),
                                                child: ClipRRect(
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                  child: Stack(
                                                    fit: StackFit.expand,
                                                    children: [
                                                      book.coverUrl != null
                                                          ? Image.network(
                                                              book.coverUrl!,
                                                              fit: BoxFit.cover,
                                                            )
                                                          : Container(
                                                              color:
                                                                  const Color(
                                                                    0xFFFFF59D,
                                                                  ),
                                                            ),
                                                      Positioned(
                                                        bottom: 0,
                                                        left: 0,
                                                        right: 0,
                                                        child: Container(
                                                          padding:
                                                              const EdgeInsets.all(
                                                                12,
                                                              ),
                                                          color: Colors.black54,
                                                          child: Text(
                                                            book.title,
                                                            style:
                                                                const TextStyle(
                                                                  color: Colors
                                                                      .white,
                                                                ),
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
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                          ),
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
                                                padding: const EdgeInsets.only(
                                                  right: 12.0,
                                                ),
                                                child: GestureDetector(
                                                  onTap: () => Navigator.push(
                                                    context,
                                                    createSlideRoute(
                                                      BookDetailScreen(
                                                        book: book,
                                                      ),
                                                    ),
                                                  ),
                                                  child: Column(
                                                    children: [
                                                      Container(
                                                        width: 100,
                                                        height: 120,
                                                        decoration: BoxDecoration(
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                8,
                                                              ),
                                                          color: const Color(
                                                            0xFFFFF59D,
                                                          ),
                                                        ),
                                                        child:
                                                            book.coverUrl !=
                                                                null
                                                            ? Image.network(
                                                                book.coverUrl!,
                                                                fit: BoxFit
                                                                    .cover,
                                                              )
                                                            : const Icon(
                                                                Icons.menu_book,
                                                              ),
                                                      ),
                                                      const SizedBox(height: 6),
                                                      SizedBox(
                                                        width: 100,
                                                        child: Text(
                                                          book.title,
                                                          maxLines: 1,
                                                          overflow: TextOverflow
                                                              .ellipsis,
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
                                        const Text(
                                          'Top Charts',
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 10),
                                        ListView.builder(
                                          shrinkWrap: true,
                                          physics:
                                              const NeverScrollableScrollPhysics(),
                                          itemCount: ranked.length,
                                          itemBuilder: (context, idx) {
                                            final book = ranked[idx];
                                            return ListTile(
                                              leading: Text('#${idx + 1}'),
                                              title: Text(book.title),
                                              subtitle: Text(
                                                '${book.authorName} • ${book.reads} reads',
                                              ),
                                              onTap: () => Navigator.push(
                                                context,
                                                createSlideRoute(
                                                  BookDetailScreen(book: book),
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                        const SizedBox(height: 30),
                                      ],
                                    ),
                                  ),
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
