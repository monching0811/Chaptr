import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:provider/provider.dart';
import 'book_model.dart';
import 'settings_provider.dart';

class ReaderScreen extends StatefulWidget {
  final Book book;
  const ReaderScreen({super.key, required this.book});

  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen> {
  final FlutterTts _flutterTts = FlutterTts();
  bool _isPlaying = false;

  double _fontSize = 18.0;
  Color _backgroundColor = Colors.white;
  Color _textColor = Colors.black87;

  // Local overrides (if user modifies appearance in the reader UI)
  bool _appearanceOverride =
      false; // if true, local theme choice wins over global setting
  bool _fontOverride =
      false; // if true, local font size wins over global setting

  double _speechRate = 0.5;
  double _pitch = 1.0;

  // Helper to get only the chapters that are marked as published, sorted by chapter_number
  List<Map<String, dynamic>> get _publishedChapters {
    return widget.book.chapters
        .where((ch) => ch['is_published'] == true)
        .toList()
      ..sort(
        (a, b) =>
            (a['chapter_number'] ?? 0).compareTo(b['chapter_number'] ?? 0),
      );
  }

  @override
  void dispose() {
    _flutterTts.stop();
    super.dispose();
  }

  void _setTheme(String theme) {
    setState(() {
      _appearanceOverride = true;
      if (theme == 'sepia') {
        _backgroundColor = const Color(0xFFF4ECD8);
        _textColor = const Color(0xFF5B4636);
      } else if (theme == 'dark') {
        _backgroundColor = const Color(0xFF1A1A1A);
        _textColor = Colors.white70;
      } else {
        _backgroundColor = Colors.white;
        _textColor = Colors.black87;
      }
    });
  }

  void _showAppearanceSettings() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: const EdgeInsets.all(20),
              height: 400,
              child: Column(
                children: [
                  const Text(
                    "Appearance",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _themeCircle(
                        "Light",
                        Colors.white,
                        Colors.black,
                        () => _setTheme('light'),
                      ),
                      _themeCircle(
                        "Sepia",
                        const Color(0xFFF4ECD8),
                        Colors.brown,
                        () => _setTheme('sepia'),
                      ),
                      _themeCircle(
                        "Dark",
                        const Color(0xFF1A1A1A),
                        Colors.white,
                        () => _setTheme('dark'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      const Icon(Icons.text_fields, size: 15),
                      Expanded(
                        child: Slider(
                          value: _fontSize,
                          min: 14,
                          max: 32,
                          activeColor: const Color(0xFFFFEB3B),
                          onChanged: (val) {
                            setModalState(() => _fontSize = val);
                            setState(() {
                              _fontSize = val;
                              _fontOverride = true;
                            });
                          },
                        ),
                      ),
                      const Icon(Icons.text_fields, size: 30),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    "TTS Settings",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(Icons.speed, size: 15),
                      Expanded(
                        child: Slider(
                          value: _speechRate,
                          min: 0.1,
                          max: 1.0,
                          activeColor: const Color(0xFFFFEB3B),
                          onChanged: (val) {
                            setModalState(() => _speechRate = val);
                            setState(() => _speechRate = val);
                          },
                        ),
                      ),
                      const Icon(Icons.speed, size: 30),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(Icons.tune, size: 15),
                      Expanded(
                        child: Slider(
                          value: _pitch,
                          min: 0.5,
                          max: 2.0,
                          activeColor: const Color(0xFFFFEB3B),
                          onChanged: (val) {
                            setModalState(() => _pitch = val);
                            setState(() => _pitch = val);
                          },
                        ),
                      ),
                      const Icon(Icons.tune, size: 30),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _themeCircle(
    String label,
    Color bg,
    Color border,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          CircleAvatar(
            backgroundColor: border,
            radius: 22,
            child: CircleAvatar(backgroundColor: bg, radius: 20),
          ),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  // --- FIXED: TTS Logic extracts string from Map ---
  Future<void> _speak() async {
    if (_isPlaying) {
      await _flutterTts.stop();
      if (mounted) setState(() => _isPlaying = false);
    } else {
      if (mounted) setState(() => _isPlaying = true);
      await _flutterTts.setLanguage("en-US");
      await _flutterTts.setSpeechRate(_speechRate);
      await _flutterTts.setPitch(_pitch);

      // Extract the 'content' string from each published chapter map (defensive)
      String fullContent = _publishedChapters
          .map((ch) => (ch['content'] ?? '').toString())
          .join(' ');

      await _flutterTts.speak(fullContent);

      _flutterTts.setCompletionHandler(() {
        if (mounted) setState(() => _isPlaying = false);
      });
    }
  }

  Future<void> _saveToLibrary() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    try {
      await Supabase.instance.client.from('library').insert({
        'user_id': user.id,
        'book_id': widget.book.id,
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Added to your Library!")));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Already in library.")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();

    // Apply global reading settings unless the reader has locally overridden them
    final effectiveFontSize = _fontOverride
        ? _fontSize
        : (18 * settings.fontSize);

    // Determine background / text color from settings unless locally overridden
    Color background = _backgroundColor;
    Color textColor = _textColor;
    if (!_appearanceOverride) {
      switch (settings.readingBackground) {
        case ReadingBackground.sepia:
          background = const Color(0xFFF4ECD8);
          textColor = const Color(0xFF5B4636);
          break;
        case ReadingBackground.black:
          background = const Color(0xFF1A1A1A);
          textColor = Colors.white70;
          break;
        case ReadingBackground.white:
          background = Colors.white;
          textColor = Colors.black87;
          break;
      }
    }

    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        title: Text(widget.book.title),
        backgroundColor: const Color(0xFFFFEB3B),
        foregroundColor: Colors.black,
        actions: [
          IconButton(
            icon: const Icon(Icons.text_fields),
            onPressed: _showAppearanceSettings,
          ),
          IconButton(
            icon: Icon(_isPlaying ? Icons.stop : Icons.volume_up),
            onPressed: _speak,
          ),
          IconButton(
            icon: const Icon(Icons.library_add),
            onPressed: _saveToLibrary,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.book.title,
              style: TextStyle(
                fontSize: effectiveFontSize + 8,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            Text(
              "by ${widget.book.authorName}",
              style: TextStyle(
                fontSize: 16,
                fontStyle: FontStyle.italic,
                color: textColor.withAlpha((0.7 * 255).round()),
              ),
            ),
            const Divider(height: 30),

            // --- FIXED: Iterate over published chapters only ---
            ..._publishedChapters.map((chapter) {
              int chNumber = chapter['chapter_number'] ?? 1;
              String title = chapter['title'] ?? '';
              String content = chapter['content'] ?? '';

              return Padding(
                padding: const EdgeInsets.only(bottom: 25.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title.isNotEmpty ? title : "Chapter $chNumber",
                      style: TextStyle(
                        fontSize: effectiveFontSize + 2,
                        fontWeight: FontWeight.bold,
                        color: textColor.withAlpha((0.9 * 255).round()),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      content,
                      style: TextStyle(
                        fontSize: effectiveFontSize,
                        height: 1.7,
                        fontFamily: 'Serif',
                        color: textColor,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }
}
