import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import 'book_model.dart';
import 'comment_model.dart';
import 'reader_screen.dart';
import 'animations.dart';
import 'settings_provider.dart';
import 'widgets/pagination_widget.dart';

class BookDetailScreen extends StatefulWidget {
  final Book book;

  const BookDetailScreen({super.key, required this.book});

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
  final Map<String, TextEditingController> _replyControllers = {};
  final Map<String, bool> _replyingTo = {}; // Track which comment is being replied to
  bool _postingComment = false;
  bool _isFollowing = false;
  int _commentsPage = 1;
  static const int _commentsPerPage = 10;

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
      
      // Try to fetch from book_metrics table first
      final metricsRow = await supabase
          .from('book_metrics')
          .select()
          .eq('book_id', widget.book.id)
          .maybeSingle();

      if (metricsRow != null) {
        setState(() {
          reads = (metricsRow['reads'] ?? reads) as int;
          votes = (metricsRow['votes'] ?? votes) as int;
        });
        return;
      }
      
      // If no metrics row, fetch from books table directly
      final bookRow = await supabase
          .from('books')
          .select('reads, votes, author_id')
          .eq('id', widget.book.id)
          .maybeSingle();
      
      if (bookRow != null && mounted) {
        setState(() {
          reads = (bookRow['reads'] ?? widget.book.reads) as int;
          votes = (bookRow['votes'] ?? widget.book.votes) as int;
          // Update author_id if missing
          if (widget.book.authorId == null && bookRow['author_id'] != null) {
            // Recreate book with updated author_id
            // Note: This is read-only, but ensures authorId is available for follow button
          }
        });
      }
    } catch (e) {
      debugPrint('Error fetching metrics: $e');
      // Fallback to book values already set
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
    try {
      final supabase = Supabase.instance.client;
      // Fetch all comments (including replies)
      final response = await supabase
          .from('comments')
          .select()
          .eq('book_id', widget.book.id)
          .order('created_at', ascending: false);
      
      if (mounted) {
        final allComments = (response as List)
            .map((data) => Comment.fromMap(data))
            .toList();
        
        // Separate parent comments and replies
        final parentComments = allComments
            .where((c) => c.parentCommentId == null)
            .toList();
        
        // Group replies by parent comment ID
        final repliesMap = <String, List<Comment>>{};
        for (final comment in allComments) {
          if (comment.parentCommentId != null) {
            repliesMap.putIfAbsent(comment.parentCommentId!, () => []);
            repliesMap[comment.parentCommentId]!.add(comment);
            // Sort replies by date (oldest first for conversation flow)
            repliesMap[comment.parentCommentId]!.sort((a, b) => 
              a.createdAt.compareTo(b.createdAt));
          }
        }
        
        // Attach replies to parent comments
        final commentsWithReplies = parentComments.map((parent) {
          final replies = repliesMap[parent.id] ?? [];
          return Comment(
            id: parent.id,
            bookId: parent.bookId,
            userId: parent.userId,
            username: parent.username,
            comment: parent.comment,
            createdAt: parent.createdAt,
            parentCommentId: parent.parentCommentId,
            replies: replies,
          );
        }).toList();
        
        setState(() {
          _comments = commentsWithReplies;
        });
      }
    } catch (e) {
      debugPrint('Error fetching comments: $e');
    }
  }

  Future<void> _postComment() async {
    if (_commentController.text.trim().isEmpty) return;
    setState(() => _postingComment = true);
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    if (user == null) {
      setState(() => _postingComment = false);
      return;
    }

    try {
      // Get username from profile
      final profile = await supabase
          .from('profiles')
          .select('username')
          .eq('id', user.id)
          .maybeSingle();

      final username = profile?['username'] ?? user.email ?? 'Unknown User';

      // Build insert payload - include username after SQL migration
      final insertPayload = <String, dynamic>{
        'book_id': widget.book.id,
        'user_id': user.id,
        'comment': _commentController.text.trim(),
        'username': username, // This will work after running the SQL migration
      };

      await supabase.from('comments').insert(insertPayload);

      // Send notification to book author (if not commenting on own book)
      final authorId = await _getBookAuthorId();
      if (authorId != null && authorId != user.id) {
        await _sendNotification(
          type: 'comment',
          recipientId: authorId,
          bookId: widget.book.id,
          message: '$username commented on "${widget.book.title}"',
          fromUserId: user.id,
          fromUsername: username,
        );
      }

      _commentController.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Text("✓ Comment posted successfully!"),
              ],
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
      _fetchComments();
      // Reset to first page after posting new comment
      setState(() {
        _commentsPage = 1;
      });
    } catch (e) {
      debugPrint('Error posting comment: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to post comment: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _postingComment = false);
      }
    }
  }

  // Get book author_id from database if not in book object
  Future<String?> _getBookAuthorId() async {
    if (widget.book.authorId != null && widget.book.authorId!.isNotEmpty) {
      return widget.book.authorId;
    }
    
    try {
      final supabase = Supabase.instance.client;
      final bookRow = await supabase
          .from('books')
          .select('author_id')
          .eq('id', widget.book.id)
          .maybeSingle();
      
      return bookRow?['author_id']?.toString();
    } catch (e) {
      return null;
    }
  }

  Future<void> _checkFollow() async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    if (user == null) return;
    
    final authorId = await _getBookAuthorId();
    if (authorId == null || authorId.isEmpty) return;
    
    final response = await supabase
        .from('follows')
        .select()
        .eq('follower_id', user.id)
        .eq('following_id', authorId)
        .maybeSingle();
    if (mounted) {
      setState(() => _isFollowing = response != null);
    }
  }

  Future<void> _toggleFollow() async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    if (user == null) return;
    
    final authorId = await _getBookAuthorId();
    if (authorId == null || authorId.isEmpty) return;

    try {
      if (_isFollowing) {
        await supabase
            .from('follows')
            .delete()
            .eq('follower_id', user.id)
            .eq('following_id', authorId);
        if (mounted) {
          setState(() => _isFollowing = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  Icon(Icons.person_remove, color: Colors.white),
                  SizedBox(width: 8),
                  Text("Unfollowed author"),
                ],
              ),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 2),
            ),
          );
        }
      } else {
        await supabase.from('follows').insert({
          'follower_id': user.id,
          'following_id': authorId,
        });
        if (mounted) {
          setState(() => _isFollowing = true);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  Icon(Icons.person_add, color: Colors.white),
                  SizedBox(width: 8),
                  Text("✓ Following author!"),
                ],
              ),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error toggling follow: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to ${_isFollowing ? "unfollow" : "follow"}: $e',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
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

  // Helper function to send notifications
  Future<void> _sendNotification({
    required String type,
    required String? recipientId,
    String? bookId,
    String? commentId,
    required String message,
    required String? fromUserId,
    required String fromUsername,
  }) async {
    if (recipientId == null || recipientId.isEmpty) return;
    
    try {
      final supabase = Supabase.instance.client;
      await supabase.from('notifications').insert({
        'user_id': recipientId, // Recipient
        'type': type,
        'book_id': bookId,
        'comment_id': commentId,
        'message': message,
        'from_user_id': fromUserId,
        'from_username': fromUsername,
        'is_read': false,
      });
    } catch (e) {
      debugPrint('Error sending notification: $e');
      // Don't show error to user - notifications are best effort
    }
  }

  // Post a reply to a comment
  Future<void> _postReply(Comment parentComment) async {
    final controller = _replyControllers[parentComment.id];
    if (controller == null || controller.text.trim().isEmpty) return;
    
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    if (user == null) return;

    try {
      // Get username
      final profile = await supabase
          .from('profiles')
          .select('username')
          .eq('id', user.id)
          .maybeSingle();
      final username = profile?['username'] ?? user.email ?? 'Unknown User';

      // Insert reply
      final replyPayload = <String, dynamic>{
        'book_id': widget.book.id,
        'user_id': user.id,
        'comment': controller.text.trim(),
        'username': username,
        'parent_comment_id': parentComment.id, // Link to parent comment
      };

      await supabase.from('comments').insert(replyPayload);

      // Send notification to parent comment author
      if (parentComment.userId != user.id) {
        await _sendNotification(
          type: 'reply',
          recipientId: parentComment.userId,
          bookId: widget.book.id,
          commentId: parentComment.id,
          message: '$username replied to your comment',
          fromUserId: user.id,
          fromUsername: username,
        );
      }

      controller.clear();
      setState(() {
        _replyingTo[parentComment.id] = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Text("✓ Reply posted!"),
              ],
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }

      _fetchComments();
    } catch (e) {
      debugPrint('Error posting reply: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to post reply: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _commentController.dispose();
    for (final controller in _replyControllers.values) {
      controller.dispose();
    }
    _replyControllers.clear();
    super.dispose();
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
                  // Follow Button - show for all books with author_id
                  FutureBuilder<String?>(
                    future: _getBookAuthorId(),
                    builder: (context, snapshot) {
                      final authorId = snapshot.data ?? widget.book.authorId;
                      final currentUserId = Supabase.instance.client.auth.currentUser?.id;
                      
                      if (authorId != null && 
                          authorId.isNotEmpty && 
                          authorId != currentUserId) {
                        return Container(
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
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),
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
                        // Comments List with Pagination
                        _buildCommentsList(),
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

  Widget _buildCommentsList() {
    if (_comments.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'No comments yet. Be the first to share your thoughts!',
            style: TextStyle(
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withAlpha((0.6 * 255).round()),
              fontStyle: FontStyle.italic,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final totalPages = (_comments.length / _commentsPerPage).ceil();
    final startIndex = (_commentsPage - 1) * _commentsPerPage;
    final endIndex = (startIndex + _commentsPerPage).clamp(0, _comments.length);
    final paginatedComments = _comments.sublist(startIndex, endIndex);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Comments count and page info
        if (_comments.length > _commentsPerPage)
          Padding(
            padding: const EdgeInsets.only(bottom: 12.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${_comments.length} ${_comments.length == 1 ? 'comment' : 'comments'}',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  'Showing ${startIndex + 1}-${endIndex} of ${_comments.length}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ),

        // Paginated comments list
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: paginatedComments.length,
          itemBuilder: (context, index) {
            final comment = paginatedComments[index];
            return Card(
              margin: const EdgeInsets.symmetric(vertical: 4),
              elevation: 0,
              color: Theme.of(
                context,
              ).colorScheme.surface.withAlpha((0.1 * 255).round()),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 16,
                          backgroundColor: const Color(0xFFFFEB3B),
                          child: Text(
                            comment.username.isNotEmpty
                                ? comment.username[0].toUpperCase()
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
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(comment.comment),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _formatDate(comment.createdAt),
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurface.withAlpha((0.6 * 255).round()),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () {
                            setState(() {
                              if (_replyingTo[comment.id] == true) {
                                _replyingTo[comment.id] = false;
                                _replyControllers[comment.id]?.dispose();
                                _replyControllers.remove(comment.id);
                              } else {
                                _replyingTo[comment.id] = true;
                                _replyControllers[comment.id] = TextEditingController();
                              }
                            });
                          },
                          icon: Icon(
                            Icons.reply,
                            size: 16,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          label: Text(
                            _replyingTo[comment.id] == true ? 'Cancel' : 'Reply',
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    // Reply input field
                    if (_replyingTo[comment.id] == true) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _replyControllers[comment.id],
                              decoration: InputDecoration(
                                hintText: 'Reply to ${comment.username}...',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                filled: true,
                                fillColor: Theme.of(context).colorScheme.surface,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                              ),
                              maxLines: 2,
                              minLines: 1,
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: () => _postReply(comment),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFFFEB3B),
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                            ),
                            child: const Text('Reply'),
                          ),
                        ],
                      ),
                    ],
                    // Display replies
                    if (comment.replies.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Container(
                        margin: const EdgeInsets.only(left: 16),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          border: Border(
                            left: BorderSide(
                              color: Colors.grey[300]!,
                              width: 2,
                            ),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: comment.replies.map((reply) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 12,
                                        backgroundColor: const Color(0xFFFFEB3B).withAlpha((0.3 * 255).round()),
                                        child: Text(
                                          reply.username.isNotEmpty
                                              ? reply.username[0].toUpperCase()
                                              : '?',
                                          style: const TextStyle(
                                            color: Colors.black87,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        reply.username,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Padding(
                                    padding: const EdgeInsets.only(left: 32),
                                    child: Text(
                                      reply.comment,
                                      style: const TextStyle(fontSize: 13),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.only(left: 32, top: 4),
                                    child: Text(
                                      _formatDate(reply.createdAt),
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurface
                                            .withAlpha((0.5 * 255).round()),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        ),

        // Pagination widget for comments
        if (totalPages > 1)
          Padding(
            padding: const EdgeInsets.only(top: 16.0),
            child: PaginationWidget(
              currentPage: _commentsPage,
              totalPages: totalPages,
              onPageChanged: (page) {
                setState(() {
                  _commentsPage = page;
                });
              },
            ),
          ),
      ],
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
