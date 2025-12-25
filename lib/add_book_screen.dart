import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AddBookScreen extends StatefulWidget {
  const AddBookScreen({super.key});

  @override
  State<AddBookScreen> createState() => _AddBookScreenState();
}

// Fixed the class name here to match the createState above
class _AddBookScreenState extends State<AddBookScreen> {
  final _titleController = TextEditingController();
  final _genreController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _contentController = TextEditingController();

  Future<void> _saveBook() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    if (_titleController.text.isEmpty || _contentController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Title and Content are required")),
      );
      return;
    }

    try {
      await Supabase.instance.client.from('books').insert({
        'title': _titleController.text,
        'genre': _genreController.text,
        'description': _descriptionController.text,
        'content': _contentController.text,
        'author_id': user.id,
      });

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Story Published!")));
        _titleController.clear();
        _genreController.clear();
        _descriptionController.clear();
        _contentController.clear();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Write Your Story"),
        backgroundColor: const Color(
          0xFFFFEB3B,
        ), // Theme from proposal [cite: 57]
        foregroundColor: Colors.black,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: "Book Title",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _genreController,
              decoration: const InputDecoration(
                labelText: "Genre (Poetry, Fiction, etc.)",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: "Short Description",
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _contentController,
              decoration: const InputDecoration(
                labelText: "Start Writing...",
                alignLabelWithHint: true,
                border: OutlineInputBorder(),
              ),
              maxLines: 15,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(
                  0xFFFFEB3B,
                ), // Yellow Palette [cite: 57]
                foregroundColor: Colors.black,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ), // Round Corner [cite: 59]
              ),
              onPressed: _saveBook,
              child: const Text("Publish to Chaptr"),
            ),
          ],
        ),
      ),
    );
  }
}
