import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:provider/provider.dart';
import 'dart:math';
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

  int currentHighlightStart = -1;
  int currentHighlightEnd = -1;
  List<int> chapterStarts = [];
  
  // Reading progress tracking
  ScrollController? _scrollController;
  double _readingProgress = 0.0;
  
  // Save reading progress periodically
  Future<void> _saveReadingProgress() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    
    try {
      // Calculate progress percentage based on scroll position
      if (_scrollController != null && _scrollController!.hasClients) {
        final maxScroll = _scrollController!.position.maxScrollExtent;
        final currentScroll = _scrollController!.offset;
        if (maxScroll > 0) {
          _readingProgress = (currentScroll / maxScroll * 100).clamp(0.0, 100.0);
        }
      }
      
      // Get total content length
      final totalLength = _publishedChapters
          .map((ch) => (ch['content'] ?? '').toString().length)
          .fold<int>(0, (sum, length) => sum + length);
      
      // Save to database
      await Supabase.instance.client.from('reading_progress').upsert({
        'user_id': user.id,
        'book_id': widget.book.id,
        'progress_percentage': _readingProgress,
        'last_read_at': DateTime.now().toIso8601String(),
        'total_length': totalLength,
      });
    } catch (e) {
      debugPrint('Error saving reading progress: $e');
    }
  }
  
  // Load reading progress
  Future<void> _loadReadingProgress() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    
    try {
      final response = await Supabase.instance.client
          .from('reading_progress')
          .select()
          .eq('user_id', user.id)
          .eq('book_id', widget.book.id)
          .maybeSingle();
      
      if (response != null && mounted) {
        setState(() {
          _readingProgress = (response['progress_percentage'] ?? 0.0).toDouble();
        });
        
        // Scroll to saved position if available
        if (_scrollController != null && 
            _scrollController!.hasClients && 
            _readingProgress > 0) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_scrollController != null && _scrollController!.hasClients) {
              final maxScroll = _scrollController!.position.maxScrollExtent;
              _scrollController!.jumpTo(maxScroll * (_readingProgress / 100));
            }
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading reading progress: $e');
    }
  }

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
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController!.addListener(() {
      // Save progress periodically while scrolling
      _saveReadingProgress();
    });
    
    int offset = 0;
    for (var ch in _publishedChapters) {
      chapterStarts.add(offset);
      String content = (ch['content'] ?? '').toString();
      offset += content.length + 1;
    }
    
    // Load saved progress
    _loadReadingProgress();
  }

  @override
  void dispose() {
    _flutterTts.stop();
    // Save progress one last time
    _saveReadingProgress();
    _scrollController?.dispose();
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
      if (mounted) {
        setState(() {
          _isPlaying = false;
          currentHighlightStart = -1;
          currentHighlightEnd = -1;
        });
      }
    } else {
      if (mounted) setState(() => _isPlaying = true);
      await _flutterTts.setLanguage("en-US");
      await _flutterTts.setSpeechRate(_speechRate);
      await _flutterTts.setPitch(_pitch);

      _flutterTts.setProgressHandler((
        String text,
        int start,
        int end,
        String word,
      ) {
        if (mounted) {
          setState(() {
            currentHighlightStart = start;
            currentHighlightEnd = end;
          });
        }
      });

      // Extract the 'content' string from each published chapter map (defensive)
      String fullContent = _publishedChapters
          .map((ch) => (ch['content'] ?? '').toString())
          .join(' ');

      await _flutterTts.speak(fullContent);

      _flutterTts.setCompletionHandler(() {
        if (mounted) {
          setState(() {
            _isPlaying = false;
            currentHighlightStart = -1;
            currentHighlightEnd = -1;
          });
        }
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

  List<TextSpan> _buildTextSpans(String text, int globalStart) {
    List<TextSpan> spans = [];
    
    // If TTS is playing and we have highlight positions
    if (_isPlaying && currentHighlightStart >= 0 && currentHighlightEnd > currentHighlightStart) {
      int highlightStart = max(0, currentHighlightStart - globalStart);
      int highlightEnd = min(text.length, currentHighlightEnd - globalStart);
      if (highlightStart < 0) highlightStart = 0;
      if (highlightEnd < 0) highlightEnd = 0;
      if (highlightStart > text.length) highlightStart = text.length;
      if (highlightEnd > text.length) highlightEnd = text.length;
      
      if (highlightStart >= highlightEnd || highlightStart >= text.length) {
        spans.add(TextSpan(text: text));
      } else {
        // Before highlight
        if (highlightStart > 0) {
          spans.add(TextSpan(text: text.substring(0, highlightStart)));
        }
        // Highlighted text (current word being read)
        spans.add(
          TextSpan(
            text: text.substring(highlightStart, highlightEnd),
            style: TextStyle(
              backgroundColor: const Color(0xFFFFEB3B),
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        );
        // After highlight
        if (highlightEnd < text.length) {
          spans.add(TextSpan(text: text.substring(highlightEnd)));
        }
      }
    } else {
      // No highlighting when TTS is not playing
      spans.add(TextSpan(text: text));
    }
    return spans;
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
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.book.title,
              style: const TextStyle(fontSize: 16),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (_readingProgress > 0)
              Text(
                '${_readingProgress.toStringAsFixed(0)}% read',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
              ),
          ],
        ),
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
        bottom: _readingProgress > 0
            ? PreferredSize(
                preferredSize: const Size.fromHeight(4),
                child: LinearProgressIndicator(
                  value: _readingProgress / 100,
                  backgroundColor: Colors.grey[300],
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.black87),
                ),
              )
            : null,
      ),
      body: SingleChildScrollView(
        controller: _scrollController,
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

            // --- Iterate over published chapters, showing all planned chapters ---
            ..._publishedChapters.asMap().entries.map((entry) {
              int index = entry.key;
              var chapter = entry.value;
              int chNumber = chapter['chapter_number'] ?? 1;
              String title = chapter['title'] ?? '';
              String content = chapter['content'] ?? '';
              final hasContent = content.trim().isNotEmpty;

              return Padding(
                padding: const EdgeInsets.only(bottom: 25.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title.isNotEmpty ? title : "Chapter $chNumber",
                            style: TextStyle(
                              fontSize: effectiveFontSize + 2,
                              fontWeight: FontWeight.bold,
                              color: textColor.withAlpha((0.9 * 255).round()),
                            ),
                          ),
                        ),
                        if (!hasContent)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.orange.withAlpha((0.2 * 255).round()),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.orange,
                                width: 1,
                              ),
                            ),
                            child: Text(
                              'Coming Soon',
                              style: TextStyle(
                                fontSize: effectiveFontSize - 4,
                                color: Colors.orange[700],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (hasContent)
                      RichText(
                        text: TextSpan(
                          children: _buildTextSpans(
                            content,
                            chapterStarts[index],
                          ),
                          style: TextStyle(
                            fontSize: effectiveFontSize,
                            height: 1.7,
                            fontFamily: 'Serif',
                            color: textColor,
                          ),
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey.withAlpha((0.1 * 255).round()),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.schedule,
                              color: Colors.grey[600],
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'This chapter is coming soon. The author is still working on it.',
                              style: TextStyle(
                                fontSize: effectiveFontSize - 2,
                                fontStyle: FontStyle.italic,
                                color: textColor.withAlpha((0.6 * 255).round()),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
