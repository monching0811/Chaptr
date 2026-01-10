import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'book_model.dart';
import 'book_detail_screen.dart';
import 'add_book_screen.dart';
import 'animations.dart';
import 'widgets/book_flip_loading.dart';
import 'widgets/pagination_widget.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _libraryPage = 1;
  static const int _libraryItemsPerPage = 15;

  @override
  Widget build(BuildContext context) {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;

    final libraryStream = supabase
        .from('library')
        .stream(primaryKey: ['id'])
        .eq('user_id', user?.id ?? '');

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Library'),
        backgroundColor: const Color(0xFFFFEB3B),
        foregroundColor: Colors.black,
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          // Since it's a stream, data updates automatically
          // Just show a brief feedback
          await Future.delayed(const Duration(milliseconds: 500));
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Library is up to date')),
            );
          }
        },
        child: StreamBuilder<List<Map<String, dynamic>>>(
          stream: libraryStream,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: LogoLoading());
            }

            final libraryData = snapshot.data ?? [];

            if (libraryData.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.menu_book,
                      size: 100,
                      color: Color(0xFFFFEB3B),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Your library is currently empty.',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const Text('Go to the Store to add some books!'),
                  ],
                ),
              );
            }

            // Calculate pagination
            final totalPages = (libraryData.length / _libraryItemsPerPage).ceil();
            final startIndex = (_libraryPage - 1) * _libraryItemsPerPage;
            final endIndex = (startIndex + _libraryItemsPerPage).clamp(0, libraryData.length);
            final paginatedLibraryData = libraryData.sublist(startIndex, endIndex);

            return Column(
              children: [
                // Page info header
                if (libraryData.length > _libraryItemsPerPage)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${libraryData.length} ${libraryData.length == 1 ? 'book' : 'books'} in library',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          'Page $_libraryPage of $totalPages • Showing ${startIndex + 1}-${endIndex}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                
                // Paginated list
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(10),
                    itemCount: paginatedLibraryData.length,
                    itemBuilder: (context, index) {
                      final bookId = paginatedLibraryData[index]['book_id'];

                return FutureBuilder(
                  future: Future.wait([
                    supabase
                        .from('books')
                        .select()
                        .eq('id', bookId)
                        .single(),
                    // Get reading progress
                    supabase
                        .from('reading_progress')
                        .select('progress_percentage')
                        .eq('user_id', user?.id ?? '')
                        .eq('book_id', bookId)
                        .maybeSingle()
                        .catchError((_) => null),
                  ]),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData || snapshot.data == null) {
                      return const SizedBox();
                    }
                    
                    final bookData = snapshot.data![0] as Map<String, dynamic>;
                    final progressData = snapshot.data![1] as Map<String, dynamic>?;
                    final book = Book.fromMap(bookData);
                    final progress = progressData?['progress_percentage'] ?? 0.0;

                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: InkWell(
                        onTap: () => Navigator.push(
                          context,
                          createSlideRoute(BookDetailScreen(book: book)),
                        ),
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Row(
                            children: [
                              // Book cover
                              Container(
                                width: 60,
                                height: 90,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  color: Colors.grey[200],
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withAlpha((0.1 * 255).round()),
                                      blurRadius: 4,
                                      offset: const Offset(2, 2),
                                    ),
                                  ],
                                ),
                                child: book.coverUrl != null
                                    ? ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: Image.network(
                                          book.coverUrl!,
                                          fit: BoxFit.cover,
                                          errorBuilder: (context, error, stackTrace) {
                                            return const Icon(
                                              Icons.book,
                                              color: Color(0xFFFFEB3B),
                                              size: 30,
                                            );
                                          },
                                        ),
                                      )
                                    : const Icon(
                                        Icons.book,
                                        color: Color(0xFFFFEB3B),
                                        size: 30,
                                      ),
                              ),
                              const SizedBox(width: 12),
                              // Book details
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      book.title,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      book.authorName,
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 14,
                                      ),
                                    ),
                                    if (book.genres.isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        book.genre,
                                        style: TextStyle(
                                          color: Colors.grey[500],
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                    if (progress > 0) ...[
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: LinearProgressIndicator(
                                              value: (progress as num).toDouble() / 100,
                                              backgroundColor: Colors.grey[300],
                                              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFFFEB3B)),
                                              minHeight: 6,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            '${(progress as num).toDouble().toStringAsFixed(0)}%',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.grey[700],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              const Icon(Icons.arrow_forward_ios, size: 16),
                            ],
                          ),
                        ),
                      ),
                    );
                    },
                  );
                },
              ),
            ),
            
            // Pagination widget
            if (totalPages > 1)
              PaginationWidget(
                currentPage: _libraryPage,
                totalPages: totalPages,
                onPageChanged: (page) {
                  setState(() {
                    _libraryPage = page;
                  });
                },
              ),
              ],
            );
          },
        ),
      ),
      // FAB updated to open the Write Screen
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFFFFEB3B),
        tooltip: "Write a Story",
        onPressed: () {
          Navigator.push(context, createSlideRoute(const AddBookScreen()));
        },
        child: const Icon(Icons.edit_note, color: Colors.black),
      ),
    );
  }
}
