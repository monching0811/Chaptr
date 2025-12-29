import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'book_model.dart';
import 'reader_screen.dart';
import 'add_book_screen.dart';
import 'animations.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

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
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: libraryStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
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
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                  const Text('Go to the Store to add some books!'),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(10),
            itemCount: libraryData.length,
            itemBuilder: (context, index) {
              final bookId = libraryData[index]['book_id'];

              return FutureBuilder(
                future: supabase
                    .from('books')
                    .select()
                    .eq('id', bookId)
                    .single(),
                builder: (context, bookSnapshot) {
                  if (!bookSnapshot.hasData) return const SizedBox();

                  final book = Book.fromMap(
                    bookSnapshot.data as Map<String, dynamic>,
                  );

                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ListTile(
                      leading: const Icon(Icons.book, color: Color(0xFFFFEB3B)),
                      title: Text(
                        book.title,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(book.authorName),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: () => Navigator.push(
                        context,
                        createSlideRoute(ReaderScreen(book: book)),
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
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
