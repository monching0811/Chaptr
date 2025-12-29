import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'book_model.dart';
import 'image_utils.dart';

class AddBookScreen extends StatefulWidget {
  final Book? book;
  const AddBookScreen({super.key, this.book});

  @override
  State<AddBookScreen> createState() => _AddBookScreenState();
}

class _AddBookScreenState extends State<AddBookScreen> {
  final _titleController = TextEditingController();
  final _genreController = TextEditingController();
  final _descriptionController = TextEditingController();

  int _chapterCount = 1;
  final List<TextEditingController> _chapterControllers = [
    TextEditingController(),
  ];

  File? _selectedImage;
  bool _isLoading = false;
  bool _isUploading = false; // true while uploading cover to storage

  @override
  void initState() {
    super.initState();
    if (widget.book != null) {
      _loadBookData();
    }
  }

  void _loadBookData() {
    _titleController.text = widget.book!.title;
    _genreController.text = widget.book!.genre;
    _descriptionController.text = widget.book!.description;
    _chapterCount = widget.book!.chapters.length;
    _chapterControllers.clear();
    for (var ch in widget.book!.chapters) {
      _chapterControllers.add(TextEditingController(text: ch['content'] ?? ''));
    }
    // Note: Image loading not implemented for simplicity
  }

  void _updateChapterCount(int count) {
    setState(() {
      _chapterCount = count;
      while (_chapterControllers.length < count) {
        _chapterControllers.add(TextEditingController());
      }
      // If the user reduces the chapter count, remove and dispose extra controllers
      while (_chapterControllers.length > count) {
        _chapterControllers.removeLast().dispose();
      }
    });
  }

  Future<void> _pickImage() async {
    // Prevent picking a new image while a save/publish is in progress
    if (_isLoading) return;

    final picker = ImagePicker();
    try {
      final pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 50,
        // Resize at pick time to avoid large memory / GPU usage on device
        maxWidth: 1200,
        maxHeight: 1200,
      );

      if (pickedFile != null) {
        debugPrint('Picked image: ${pickedFile.path}');
        final file = File(pickedFile.path);

        // Further compress in background to be safe on older devices
        try {
          final compressed = await compressImage(
            file,
            quality: 85,
            width: 800,
            height: 800,
          );
          if (mounted) setState(() => _selectedImage = compressed);
        } catch (e, st) {
          debugPrint('Compression after pick failed: $e\n$st');
          if (mounted) setState(() => _selectedImage = file);
        }
      }
    } catch (e, st) {
      debugPrint('Image pick failed: $e\n$st');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to pick image. Try a smaller photo.'),
          ),
        );
      }
    }
  }

  // THIS IS THE UPDATED STABILITY VERSION
  Future<void> _handleSave({required bool isDraft}) async {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;

    if (user == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("User not logged in")));
      return;
    }

    // 1. Clear UI focus immediately to prevent keyboard-related crashes
    FocusManager.instance.primaryFocus?.unfocus();

    setState(() => _isLoading = true);

    try {
      debugPrint('Starting save process');
      // 2. Data Prep
      final String title = _titleController.text.trim();
      if (title.isEmpty) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Title is required")));
        setState(() => _isLoading = false);
        return;
      }

      final List<Map<String, dynamic>> chapterData = _chapterControllers
          .asMap()
          .entries
          .map(
            (e) => {
              'chapter_number': e.key + 1,
              'content': e.value.text,
              'is_published': !isDraft && e.value.text.isNotEmpty,
            },
          )
          .toList();

      debugPrint('Data prep done');

      debugPrint('Starting save');

      // 3. Insert or Update
      String? coverUrl;

      // If there's a selected image, compress (again for safety) and upload it to storage.
      if (_selectedImage != null) {
        debugPrint('Starting compression');
        setState(() => _isUploading = true);
        try {
          final toUpload = await compressImage(
            _selectedImage!,
            quality: 85,
            width: 800,
            height: 800,
          );
          debugPrint('Compression done');
          debugPrint('Uploading cover: ${toUpload.path}');
          final uploadedUrl = await uploadCoverFile(toUpload);
          debugPrint('Upload done: $uploadedUrl');
          if (uploadedUrl == null) {
            // Upload failed — surface to the user and abort save to allow retry
            if (mounted) {
              setState(() => _isLoading = false);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Cover upload failed. Please try again.'),
                ),
              );
            }
            return;
          }
          coverUrl = uploadedUrl;
        } catch (e, st) {
          debugPrint('Cover upload failed: $e\n$st');
          if (mounted) {
            setState(() => _isLoading = false);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Cover upload failed. Please try again.'),
              ),
            );
          }
          return;
        } finally {
          if (mounted) setState(() => _isUploading = false);
        }
      }

      final payload = {
        'title': title,
        'genre': _genreController.text,
        'description': _descriptionController.text,
        'chapters': chapterData,
        'author_id': user.id,
        'author_name': user.email,
        'status': isDraft ? 'Draft' : 'Published',
        if (coverUrl != null) 'cover_url': coverUrl,
      };

      debugPrint('Payload: $payload');

      final isNew = widget.book == null;
      final response = isNew
          ? await client
                .from('books')
                .insert(payload)
                .select()
                .timeout(const Duration(seconds: 15))
          : await client
                .from('books')
                .update(payload)
                .eq('id', widget.book!.id)
                .select()
                .timeout(const Duration(seconds: 15));

      debugPrint("Save Successful! Response: $response");

      if (mounted) {
        setState(() => _isLoading = false);
        debugPrint('UI updated after save');
        // Temporarily commented out to test if causing crash
        // ScaffoldMessenger.of(context).showSnackBar(
        //   SnackBar(
        //     content: Text(isDraft ? "Saved as Draft" : "Published!"),
        //     backgroundColor: Colors.green,
        //   ),
        // );
        // // Give the UI a brief moment to show the SnackBar before popping
        // await Future.delayed(const Duration(milliseconds: 200));
        // if (mounted) Navigator.pop(context);
      }
    } catch (e, st) {
      debugPrint("CATCHED ERROR: $e\n$st");
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Critical Failure: $e"),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 8),
          ),
        );
      }
    }
  }

  // Confirmation Dialog before publishing
  void _confirmPublish() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Publish Story?"),
        content: const Text(
          "Once published, your story will be visible to all users. Are you sure?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _handleSave(isDraft: false);
            },
            child: const Text("Publish"),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _genreController.dispose();
    _descriptionController.dispose();
    for (final c in _chapterControllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: widget.book == null
            ? const Text("Write Your Story")
            : const Text("Edit Book"),
        backgroundColor: const Color(0xFFFFEB3B),
        foregroundColor: Colors.black,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  GestureDetector(
                    onTap: _isLoading ? null : _pickImage,
                    child: Container(
                      height: 150,
                      width: 100,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey[400]!),
                      ),
                      child: _selectedImage != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.file(
                                _selectedImage!,
                                fit: BoxFit.cover,
                              ),
                            )
                          : const Icon(Icons.add_a_photo, color: Colors.grey),
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _titleController,
                    decoration: const InputDecoration(
                      labelText: "Book Title",
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Temporarily commented out to test if causing crash
                  // if (_isUploading)
                  //   Padding(
                  //     padding: const EdgeInsets.only(bottom: 12.0),
                  //     child: Row(
                  //       children: const [
                  //         Expanded(child: LinearProgressIndicator()),
                  //       ],
                  //     ),
                  //   ),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _genreController,
                          decoration: const InputDecoration(
                            labelText: "Genre",
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      DropdownButton<int>(
                        value: _chapterCount,
                        items: [1, 2, 3, 5, 10]
                            .map(
                              (int v) => DropdownMenuItem(
                                value: v,
                                child: Text("$v Chaps"),
                              ),
                            )
                            .toList(),
                        onChanged: (val) => _updateChapterCount(val!),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _descriptionController,
                    decoration: const InputDecoration(
                      labelText: "Description",
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 20),
                  ...List.generate(_chapterCount, (index) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 15.0),
                      child: TextField(
                        controller: _chapterControllers[index],
                        decoration: InputDecoration(
                          labelText: "Chapter ${index + 1}",
                          border: const OutlineInputBorder(),
                        ),
                        maxLines: 5,
                      ),
                    );
                  }),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: (_isLoading || _isUploading)
                              ? null
                              : () => _handleSave(isDraft: true),
                          child: const Text("Save Draft"),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: (_isLoading || _isUploading)
                              ? null
                              : () => _confirmPublish(),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFFEB3B),
                            foregroundColor: Colors.black,
                          ),
                          child: const Text("Publish Now"),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
    );
  }
}
