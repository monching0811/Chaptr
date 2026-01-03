import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import 'book_model.dart';
import 'comment_model.dart';
import 'reader_screen.dart';
import 'animations.dart';
import 'settings_provider.dart';

class BookDetailScreen extends StatefulWidget {
  final Book book;

  const BookDetailScreen({Key? key, required this.book}) : super(key: key);

  @override
  State<BookDetailScreen> createState() => _BookDetailScreenState();

  // Prefer super parameter for concision (if supported by SDK):
  // const BookDetailScreen({super.key, required this.book});
}

class _BookDetailScreenState extends State<BookDetailScreen> {
  late int reads;
  late int votes;
  bool _incrementing = false;
  List<Comment> _comments = [];
  final TextEditingController _commentController = TextEditingController();
  bool _postingComment = false;
  bool _isFollowing = false;

  @override
  void initState() {
    super.initState();
    reads = widget.book.reads;
    votes = widget.book.votes;
    _fetchMetrics();
    _fetchComments();
    _checkFollow();
  }

  Future<void> _fetchMetrics() async {
    try {
      final supabase = Supabase.instance.client;
      final row = await supabase
          .from('book_metrics')
          .select()
          .eq('book_id', widget.book.id)
          .maybeSingle();

      if (row != null) {
        setState(() {
          reads = (row['reads'] ?? reads) as int;
          votes = (row['votes'] ?? votes) as int;
        });
      }
    } catch (e) {
      // If the table doesn't exist or query fails, silently fallback to book values
    }
  }

  Future<void> _incrementReads() async {
    if (_incrementing) return;
    setState(() => _incrementing = true);

    try {
      final supabase = Supabase.instance.client;
      final row = await supabase
          .from('book_metrics')
          .select()
          .eq('book_id', widget.book.id)
          .maybeSingle();

      if (row != null) {
        final newReads = ((row['reads'] ?? 0) as int) + 1;
        await supabase
            .from('book_metrics')
            .update({'reads': newReads})
            .eq('book_id', widget.book.id);
        setState(() => reads = newReads);
      } else {
        // Insert a new metrics row
        await supabase.from('book_metrics').insert({
          'book_id': widget.book.id,
          'reads': 1,
          'votes': widget.book.votes,
        });
        setState(() => reads = reads + 1);
      }

      // Also update the books table reads column for compatibility (best-effort)
      try {
        await supabase
            .from('books')
            .update({'reads': reads})
            .eq('id', widget.book.id);
      } catch (_) {}
    } catch (e) {
      // ignore errors - metrics are best-effort
    } finally {
      setState(() => _incrementing = false);
    }
  }

  Future<void> _fetchComments() async {
    final supabase = Supabase.instance.client;
    final response = await supabase
        .from('comments')
        .select()
        .eq('book_id', widget.book.id)
        .order('created_at', ascending: false);
    setState(() {
      _comments = (response as List)
          .map((data) => Comment.fromMap(data))
          .toList();
    });
  }

  Future<void> _postComment() async {
    if (_commentController.text.trim().isEmpty) return;
    setState(() => _postingComment = true);
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    if (user == null) return;
    await supabase.from('comments').insert({
      'book_id': widget.book.id,
      'user_id': user.id,
      'comment': _commentController.text.trim(),
    });
    _commentController.clear();
    setState(() => _postingComment = false);
    _fetchComments();
  }

  Future<void> _checkFollow() async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    if (user == null || widget.book.authorId == null) return;
    final response = await supabase
        .from('follows')
        .select()
        .eq('follower_id', user.id)
        .eq('following_id', widget.book.authorId!)
        .maybeSingle();
    setState(() => _isFollowing = response != null);
  }

  Future<void> _toggleFollow() async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    if (user == null || widget.book.authorId == null) return;
    if (_isFollowing) {
      await supabase
          .from('follows')
          .delete()
          .eq('follower_id', user.id)
          .eq('following_id', widget.book.authorId!);
      setState(() => _isFollowing = false);
    } else {
      await supabase.from('follows').insert({
        'follower_id': user.id,
        'following_id': widget.book.authorId!,
      });
      setState(() => _isFollowing = true);
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${date.month}/${date.day}/${date.year}';
    }
  }

  String formatCount(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(n >= 10000 ? 0 : 1)}K';
    return n.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 300.0,
            floating: false,
            pinned: true,
            backgroundColor: const Color(0xFFFFEB3B),
            foregroundColor: Colors.black,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                widget.book.title,
                style: const TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                  shadows: [Shadow(color: Colors.white, blurRadius: 2)],
                ),
              ),
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Hero(
                    tag: 'cover-${widget.book.id}',
                    child: widget.book.coverUrl != null
                        ? Image.network(
                            widget.book.coverUrl!,
                            fit: BoxFit.cover,
                          )
                        : Container(
                            color: const Color(0xFFFFF59D),
                            child: const Icon(
                              Icons.menu_book,
                              size: 100,
                              color: Colors.black26,
                            ),
                          ),
                  ),
                  // Overlay for better text readability
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          Colors.black.withAlpha((0.7 * 255).round()),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                  // Author name at bottom
                  Positioned(
                    bottom: 60,
                    left: 16,
                    right: 16,
                    child: Consumer<SettingsProvider>(
                      builder: (context, settings, child) => Text(
                        'by ${widget.book.authorName}',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16 * settings.fontSize,
                          shadows: const [
                            Shadow(color: Colors.black, blurRadius: 2),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Metadata
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Consumer<SettingsProvider>(
                        builder: (context, settings, child) => _buildStat(
                          'Reads',
                          formatCount(reads),
                          fontScale: settings.fontSize,
                        ),
                      ),
                      Consumer<SettingsProvider>(
                        builder: (context, settings, child) => _buildStat(
                          'Votes',
                          formatCount(votes),
                          fontScale: settings.fontSize,
                        ),
                      ),
                      Consumer<SettingsProvider>(
                        builder: (context, settings, child) => _buildStat(
                          'Parts',
                          '${widget.book.chapters.length}',
                          fontScale: settings.fontSize,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // Genre
                  Consumer<SettingsProvider>(
                    builder: (context, settings, child) => Text(
                      'Genre: ${widget.book.genre}',
                      style: TextStyle(
                        fontSize: 16 * settings.fontSize,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Start Reading Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        await _incrementReads();
                        if (!mounted) return;
                        Navigator.push(
                          context,
                          createSlideRoute(ReaderScreen(book: widget.book)),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFFEB3B),
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _incrementing
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Consumer<SettingsProvider>(
                              builder: (context, settings, child) => Text(
                                'Start Reading',
                                style: TextStyle(
                                  fontSize: 18 * settings.fontSize,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Synopsis
                  Consumer<SettingsProvider>(
                    builder: (context, settings, child) => Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Synopsis',
                          style: TextStyle(
                            fontSize: 20 * settings.fontSize,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          widget.book.description.isNotEmpty
                              ? widget.book.description
                              : 'No description available.',
                          style: TextStyle(
                            fontSize: 16 * settings.fontSize,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Follow Button
                  if (widget.book.authorId != null &&
                      widget.book.authorId!.isNotEmpty &&
                      widget.book.authorId !=
                          Supabase.instance.client.auth.currentUser?.id)
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 16),
                      child: ElevatedButton.icon(
                        onPressed: _toggleFollow,
                        icon: Icon(
                          _isFollowing ? Icons.person_remove : Icons.person_add,
                        ),
                        label: Text(
                          _isFollowing ? 'Unfollow Author' : 'Follow Author',
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _isFollowing
                              ? Colors.grey
                              : const Color(0xFFFFEB3B),
                          foregroundColor: _isFollowing
                              ? Colors.white
                              : Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  // Comments Section
                  Container(
                    margin: const EdgeInsets.only(top: 24),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.surface.withAlpha((0.05 * 255).round()),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.comment, color: Color(0xFFFFEB3B)),
                            const SizedBox(width: 8),
                            Text(
                              'Comments',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        // Add Comment
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _commentController,
                                decoration: InputDecoration(
                                  hintText: 'Share your thoughts...',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  filled: true,
                                  fillColor: Theme.of(
                                    context,
                                  ).colorScheme.surface,
                                ),
                                maxLines: 3,
                                minLines: 1,
                              ),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              onPressed: _postingComment ? null : _postComment,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFFFEB3B),
                                foregroundColor: Colors.black,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: _postingComment
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Text('Post'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        // Comments List
                        _comments.isEmpty
                            ? Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Text(
                                    'No comments yet. Be the first to share your thoughts!',
                                    style: TextStyle(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface
                                          .withAlpha((0.6 * 255).round()),
                                      fontStyle: FontStyle.italic,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              )
                            : ListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: _comments.length,
                                itemBuilder: (context, index) {
                                  final comment = _comments[index];
                                  return Card(
                                    margin: const EdgeInsets.symmetric(
                                      vertical: 4,
                                    ),
                                    elevation: 0,
                                    color: Theme.of(context).colorScheme.surface
                                        .withAlpha((0.1 * 255).round()),
                                    child: Padding(
                                      padding: const EdgeInsets.all(12),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              CircleAvatar(
                                                radius: 16,
                                                backgroundColor: const Color(
                                                  0xFFFFEB3B,
                                                ),
                                                child: Text(
                                                  comment.username.isNotEmpty
                                                      ? comment.username[0]
                                                            .toUpperCase()
                                                      : '?',
                                                  style: const TextStyle(
                                                    color: Colors.black,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                comment.username,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 8),
                                          Text(comment.comment),
                                          const SizedBox(height: 4),
                                          Text(
                                            _formatDate(comment.createdAt),
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .onSurface
                                                  .withAlpha(
                                                    (0.6 * 255).round(),
                                                  ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStat(String label, String value, {double fontScale = 1.0}) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 18 * fontScale,
            fontWeight: FontWeight.bold,
            color: const Color(0xFFFFEB3B),
          ),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 14 * fontScale, color: Colors.grey[600]),
        ),
      ],
    );
  }
}
