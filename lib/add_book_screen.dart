import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'book_model.dart';
import 'image_utils.dart';
import 'widgets/book_flip_loading.dart';

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
  final _chapterController = TextEditingController();

  int _chapterCount = 0;
  final List<TextEditingController> _chapterNumberControllers = [];
  final List<TextEditingController> _chapterTitleControllers = [];
  final List<TextEditingController> _chapterContentControllers = [];
  final List<bool> _chapterDone = [];

  File? _selectedImage;
  bool _isLoading = false;
  bool _isUploading = false; // true while uploading cover to storage

  @override
  void initState() {
    super.initState();
    if (widget.book != null) {
      _loadBookData();
    }
    // Load cached genres first, then refresh from backend
    _loadCachedGenres().then((_) => _fetchGenres());
  }

  // Common genre options for writers (fallback)
  static const List<String> _kGenres = [
    'Fantasy',
    'Romance',
    'Sci-Fi',
    'Mystery',
    'Thriller',
    'Non-fiction',
    'Horror',
    'Historical',
    'Young Adult',
    'Children',
    'Poetry',
    'Other',
  ];

  // Loaded from backend (falls back to _kGenres when empty)
  List<String> _genres = [];
  bool _isLoadingGenres = true;

  List<String> _selectedGenres = [];
  String? _genreError;
  String? _selectedGenre; // For dropdown
  bool _isOtherGenre = false; // For custom genre input

  // Load book data into the form (existing book editing)
  void _loadBookData() {
    _titleController.text = widget.book!.title;
    // Load genres - filter out empty strings
    _selectedGenres = widget.book!.genres
        .where((g) => g.trim().isNotEmpty)
        .toList();
    _descriptionController.text = widget.book!.description;
    _chapterCount = widget.book!.chapters.length;
    _chapterController.text = _chapterCount.toString();
    _chapterNumberControllers.clear();
    _chapterTitleControllers.clear();
    _chapterContentControllers.clear();
    _chapterDone.clear();
    for (var ch in widget.book!.chapters) {
      _chapterNumberControllers.add(
        TextEditingController(text: (ch['chapter_number'] ?? 1).toString()),
      );
      _chapterTitleControllers.add(
        TextEditingController(text: ch['title'] ?? ''),
      );
      _chapterContentControllers.add(
        TextEditingController(text: ch['content'] ?? ''),
      );
      _chapterDone.add(ch['is_done'] ?? false);
    }
    // Note: Image loading not implemented for simplicity
  }

  // Fetch genres from backend, fallback to distinct genres from books table, then to _kGenres
  Future<void> _fetchGenres() async {
    setState(() => _isLoadingGenres = true);
    try {
      final client = Supabase.instance.client;

      // Try a dedicated 'genres' table first
      final genresTable = await client.from('genres').select('name');
      final List<dynamic> genresList = genresTable as List<dynamic>? ?? [];
      if (genresList.isNotEmpty) {
        _genres = genresList
            .map((r) => (r['name'] ?? '').toString())
            .where((s) => s.isNotEmpty)
            .toSet()
            .toList();
      } else {
        // Fallback: collect distinct genres from books
        final books = await client.from('books').select('genre');
        final List<dynamic> booksList = books as List<dynamic>? ?? [];
        if (booksList.isNotEmpty) {
          _genres = booksList
              .map((b) => (b['genre'] ?? '').toString())
              .where((s) => s.isNotEmpty)
              .toSet()
              .toList();
        }
      }
    } catch (e) {
      // If the query fails, we'll fallback to the static list below
    } finally {
      if (_genres.isEmpty) _genres = _kGenres.toList();
      try {
        SharedPreferences.getInstance().then(
          (prefs) => prefs.setString('cached_genres', jsonEncode(_genres)),
        );
      } catch (_) {}
      setState(() => _isLoadingGenres = false);

      // If new book and nothing selected, don't auto-select
      setState(() {
        // Don't auto-select genres - let user choose
      });
    }
  }

  // Load cached genres from SharedPreferences (fast startup)
  Future<void> _loadCachedGenres() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final s = prefs.getString('cached_genres');
      if (s != null) {
        final List<dynamic> list = jsonDecode(s) as List<dynamic>;
        if (list.isNotEmpty) {
          setState(() => _genres = list.map((e) => e.toString()).toList());
        }
      }
    } catch (_) {}
  }

  // Allow the writer to suggest a new genre (try to insert into 'genres' table)
  Future<void> _suggestGenre(String genre) async {
    final g = genre.trim();
    if (g.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter a genre to suggest')),
        );
      }
      return;
    }

    try {
      final client = Supabase.instance.client;
      await client.from('genres').insert({'name': g});
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Thanks — "$g" was suggested')));
        // Refresh the list so the new suggestion is available immediately
        _fetchGenres();
        // Auto-select the new genre if it was successfully stored
        setState(() {
          if (!_selectedGenres.contains(g)) {
            _selectedGenres.add(g);
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not submit suggestion')),
        );
      }
    }
  }

  void _updateChapterCount(int count) {
    setState(() {
      _chapterCount = count;
      if (count > 0) {
        _chapterController.text = count.toString();
      } else {
        _chapterController.text = '';
      }
      while (_chapterNumberControllers.length < count) {
        _chapterNumberControllers.add(
          TextEditingController(
            text: (_chapterNumberControllers.length + 1).toString(),
          ),
        );
        _chapterTitleControllers.add(TextEditingController());
        _chapterContentControllers.add(TextEditingController());
        _chapterDone.add(false);
      }
      // If the user reduces the chapter count, remove and dispose extra controllers
      while (_chapterNumberControllers.length > count) {
        _chapterNumberControllers.removeLast().dispose();
        _chapterTitleControllers.removeLast().dispose();
        _chapterContentControllers.removeLast().dispose();
        _chapterDone.removeLast();
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

      final List<Map<String, dynamic>> chapterData = _chapterContentControllers
          .asMap()
          .entries
          .map(
            (e) => {
              'chapter_number':
                  int.tryParse(_chapterNumberControllers[e.key].text) ??
                  (e.key + 1),
              'title': _chapterTitleControllers[e.key].text,
              'content': e.value.text,
              'is_done': _chapterDone[e.key],
              // If published and has title/number, mark as published even without content
              // This allows showing planned chapters
              'is_published': !isDraft && (
                e.value.text.isNotEmpty || 
                _chapterTitleControllers[e.key].text.trim().isNotEmpty
              ),
            },
          )
          .toList();

      debugPrint('Data prep done');

      debugPrint('Starting save');

      // 3. Insert or Update
      // Preserve existing cover URL if editing and no new image selected
      String? coverUrl = widget.book?.coverUrl;

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

      // Validate genre selection - filter out empty strings
      final validGenres = _selectedGenres.where((g) => g.trim().isNotEmpty).toList();
      if (validGenres.isEmpty) {
        if (mounted) {
          setState(() => _genreError = 'Please select at least one genre');
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please select at least one genre')),
          );
        }
        setState(() => _isLoading = false);
        return;
      }

      // Convert genres list to a single string (database uses 'genre' column, not 'genres')
      // Join multiple genres with comma and space
      final genreString = validGenres.join(', ');

      final payload = {
        'title': title,
        'genre': genreString, // Use singular 'genre' to match database schema
        'description': _descriptionController.text,
        'chapters': chapterData,
        'author_id': user.id,
        'author_name': user.email ?? user.userMetadata?['name'] ?? 'Unknown Author',
        'status': isDraft ? 'Draft' : 'Published',
        // Always include cover_url - either new or existing
        'cover_url': coverUrl ?? widget.book?.coverUrl,
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
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isDraft ? "✓ Saved as Draft successfully!" : "✓ Published successfully!",
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                ],
              ),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
            ),
          );
          // Give the UI a brief moment to show the SnackBar before popping
          await Future.delayed(const Duration(milliseconds: 500));
          if (mounted) Navigator.pop(context);
        }
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
    _chapterController.dispose();
    for (final c in _chapterNumberControllers) {
      c.dispose();
    }
    for (final c in _chapterTitleControllers) {
      c.dispose();
    }
    for (final c in _chapterContentControllers) {
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
          ? const Center(child: LogoLoading())
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
                          : widget.book?.coverUrl != null
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.network(
                                    widget.book!.coverUrl!,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      return Icon(
                                        Icons.add_a_photo,
                                        color: Theme.of(context).colorScheme.onSurface
                                            .withAlpha((0.5 * 255).round()),
                                      );
                                    },
                                  ),
                                )
                              : Icon(
                                  Icons.add_a_photo,
                                  color: Theme.of(context).colorScheme.onSurface
                                      .withAlpha((0.5 * 255).round()),
                                ),
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
                        child: SizedBox(
                          width: 80,
                          child: TextField(
                            controller: _chapterController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: "Chapters",
                              border: OutlineInputBorder(),
                            ),
                            onChanged: (value) {
                              final count = value.isEmpty
                                  ? 0
                                  : (int.tryParse(value) ?? 0);
                              if (count >= 0 && count <= 100) {
                                _updateChapterCount(count);
                              } else {
                                // Reset to valid value if invalid
                                _chapterController.text = _chapterCount
                                    .toString();
                              }
                            },
                          ),
                        ),
                      ),
                    ],
                  ),

                  // If user chose "Other", show an autocomplete text field to type the custom genre
                  if (_isOtherGenre) ...[
                    const SizedBox(height: 10),
                    TextField(
                      controller: _genreController,
                      decoration: const InputDecoration(
                        labelText: "Custom Genre",
                        border: OutlineInputBorder(),
                        hintText: "Enter a custom genre",
                      ),
                      onChanged: (value) {
                        if (value.trim().isNotEmpty && !_selectedGenres.contains(value.trim())) {
                          setState(() {
                            _selectedGenres = [value.trim()];
                          });
                        }
                      },
                    ),
                  ],
                  // Multi-genre selection chips
                  const SizedBox(height: 10),
                  if (!_isLoadingGenres && _genres.isNotEmpty)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Select Genres (Multiple):",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _genres.map((genre) {
                            final isSelected = _selectedGenres.contains(genre);
                            return FilterChip(
                              label: Text(genre),
                              selected: isSelected,
                              onSelected: (selected) {
                                setState(() {
                                  if (selected) {
                                    if (!_selectedGenres.contains(genre)) {
                                      _selectedGenres.add(genre);
                                    }
                                  } else {
                                    _selectedGenres.remove(genre);
                                  }
                                  _genreError = null;
                                });
                              },
                              selectedColor: const Color(0xFFFFEB3B),
                              checkmarkColor: Colors.black,
                            );
                          }).toList(),
                        ),
                        if (_genreError != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              _genreError!,
                              style: const TextStyle(color: Colors.red, fontSize: 12),
                            ),
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
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _chapterNumberControllers[index],
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    labelText: "Chapter Number",
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: TextField(
                                  controller: _chapterTitleControllers[index],
                                  decoration: const InputDecoration(
                                    labelText: "Chapter Title",
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Text("Done:"),
                              Checkbox(
                                value: _chapterDone[index],
                                onChanged: (value) {
                                  setState(() {
                                    _chapterDone[index] = value ?? false;
                                  });
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _chapterContentControllers[index],
                            decoration: const InputDecoration(
                              labelText: "Chapter Content",
                              border: OutlineInputBorder(),
                            ),
                            maxLines: 5,
                          ),
                        ],
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
