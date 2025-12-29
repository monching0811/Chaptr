import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'book_model.dart';
import 'reader_screen.dart';
import 'animations.dart';

class BookstoreScreen extends StatefulWidget {
  const BookstoreScreen({super.key});

  @override
  State<BookstoreScreen> createState() => _BookstoreScreenState();
}

class _BookstoreScreenState extends State<BookstoreScreen> {
  String _searchQuery = "";

  Future<List<Book>> _fetchBooks() async {
    final supabase = Supabase.instance.client;
    var query = supabase.from('books').select().eq('status', 'Published');

    if (_searchQuery.isNotEmpty) {
      query = query.ilike('title', '%$_searchQuery%');
    }

    final response = await query.order('created_at', ascending: false);
    return (response as List).map((data) => Book.fromMap(data)).toList();
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
                fillColor: Colors.grey[100],
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
            child: FutureBuilder<List<Book>>(
              future: _fetchBooks(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(child: Text("No books found."));
                }

                final books = snapshot.data!;
                // Pick top 5 books for the featured carousel
                final featuredBooks = books.take(5).toList();

                return SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // --- SECTION 1: THE CAROUSEL ---
                      const Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 15,
                          vertical: 10,
                        ),
                        child: Text(
                          "Featured Stories",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      CarouselSlider(
                        options: CarouselOptions(
                          height: 220.0,
                          enlargeCenterPage: true,
                          autoPlay: true,
                          aspectRatio: 16 / 9,
                          autoPlayCurve: Curves.fastOutSlowIn,
                          enableInfiniteScroll: true,
                          viewportFraction: 0.8,
                        ),
                        items: featuredBooks.map((book) {
                          return GestureDetector(
                            onTap: () => Navigator.push(
                              context,
                              createSlideRoute(ReaderScreen(book: book)),
                            ),
                            child: Container(
                              width: MediaQuery.of(context).size.width,
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFF59D),
                                borderRadius: BorderRadius.circular(15),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Colors.black12,
                                    blurRadius: 4,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(15),
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    book.coverUrl != null
                                        ? Image.network(
                                            book.coverUrl!,
                                            fit: BoxFit.cover,
                                          )
                                        : const Icon(
                                            Icons.menu_book,
                                            size: 80,
                                            color: Colors.black26,
                                          ),
                                    // Title Overlay
                                    Positioned(
                                      bottom: 0,
                                      left: 0,
                                      right: 0,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 10,
                                          horizontal: 15,
                                        ),
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            begin: Alignment.bottomCenter,
                                            end: Alignment.topCenter,
                                            colors: [
                                              Colors.black.withOpacity(0.8),
                                              Colors.transparent,
                                            ],
                                          ),
                                        ),
                                        child: Text(
                                          book.title,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),

                      // --- SECTION 2: THE GRID ---
                      const Padding(
                        padding: EdgeInsets.fromLTRB(15, 25, 15, 10),
                        child: Text(
                          "Explore All",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      GridView.builder(
                        shrinkWrap: true, // Required for nested scrolling
                        physics:
                            const NeverScrollableScrollPhysics(), // Scroll handled by SingleChildScrollView
                        padding: const EdgeInsets.symmetric(horizontal: 15),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              childAspectRatio: 0.7,
                              crossAxisSpacing: 15,
                              mainAxisSpacing: 15,
                            ),
                        itemCount: books.length,
                        itemBuilder: (context, index) {
                          final book = books[index];
                          return GestureDetector(
                            onTap: () => Navigator.push(
                              context,
                              createSlideRoute(ReaderScreen(book: book)),
                            ),
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Colors.black12,
                                    blurRadius: 4,
                                  ),
                                ],
                              ),
                              child: Column(
                                children: [
                                  Expanded(
                                    child: Container(
                                      width: double.infinity,
                                      decoration: const BoxDecoration(
                                        color: Color(0xFFFFF59D),
                                        borderRadius: BorderRadius.vertical(
                                          top: Radius.circular(12),
                                        ),
                                      ),
                                      child:
                                          (book.coverUrl != null &&
                                              book.coverUrl!.isNotEmpty)
                                          ? ClipRRect(
                                              borderRadius:
                                                  const BorderRadius.vertical(
                                                    top: Radius.circular(12),
                                                  ),
                                              child: Image.network(
                                                book.coverUrl!,
                                                fit: BoxFit.cover,
                                              ),
                                            )
                                          : const Center(
                                              child: Icon(
                                                Icons.menu_book,
                                                size: 50,
                                                color: Colors.black26,
                                              ),
                                            ),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Column(
                                      children: [
                                        Text(
                                          book.title,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        Text(
                                          book.authorName,
                                          style: const TextStyle(fontSize: 12),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
