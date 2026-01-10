import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'models/notification_model.dart';
import 'book_detail_screen.dart';
import 'book_model.dart';
import 'widgets/book_flip_loading.dart';
import 'animations.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<NotificationModel> _notifications = [];
  bool _loading = true;
  int _unreadCount = 0;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      setState(() => _loading = false);
      return;
    }

    setState(() => _loading = true);

    try {
      final response = await Supabase.instance.client
          .from('notifications')
          .select()
          .eq('user_id', user.id)
          .order('created_at', ascending: false)
          .limit(100);

      if (mounted) {
        setState(() {
          _notifications = (response as List)
              .map((n) => NotificationModel.fromMap(n))
              .toList();
          _unreadCount = _notifications.where((n) => !n.isRead).length;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading notifications: $e');
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _markAsRead(String notificationId) async {
    try {
      await Supabase.instance.client
          .from('notifications')
          .update({'is_read': true})
          .eq('id', notificationId);

      setState(() {
        final index = _notifications.indexWhere((n) => n.id == notificationId);
        if (index != -1) {
          _notifications[index] = NotificationModel(
            id: _notifications[index].id,
            userId: _notifications[index].userId,
            type: _notifications[index].type,
            bookId: _notifications[index].bookId,
            commentId: _notifications[index].commentId,
            fromUserId: _notifications[index].fromUserId,
            fromUsername: _notifications[index].fromUsername,
            message: _notifications[index].message,
            isRead: true,
            createdAt: _notifications[index].createdAt,
          );
          _unreadCount = _notifications.where((n) => !n.isRead).length;
        }
      });
    } catch (e) {
      debugPrint('Error marking notification as read: $e');
    }
  }

  Future<void> _markAllAsRead() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    try {
      await Supabase.instance.client
          .from('notifications')
          .update({'is_read': true})
          .eq('user_id', user.id)
          .eq('is_read', false);

      _loadNotifications();
    } catch (e) {
      debugPrint('Error marking all as read: $e');
    }
  }

  Future<void> _navigateToBook(String? bookId) async {
    if (bookId == null) return;

    try {
      final response = await Supabase.instance.client
          .from('books')
          .select()
          .eq('id', bookId)
          .single();

      final book = Book.fromMap(response);
      if (mounted) {
        Navigator.push(
          context,
          createSlideRoute(BookDetailScreen(book: book)),
        );
      }
    } catch (e) {
      debugPrint('Error loading book: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Book not found')),
        );
      }
    }
  }

  IconData _getNotificationIcon(String type) {
    switch (type) {
      case 'follow':
        return Icons.person_add;
      case 'comment':
        return Icons.comment;
      case 'reply':
        return Icons.reply;
      default:
        return Icons.notifications;
    }
  }

  Color _getNotificationColor(String type) {
    switch (type) {
      case 'follow':
        return Colors.blue;
      case 'comment':
        return Colors.green;
      case 'reply':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        backgroundColor: const Color(0xFFFFEB3B),
        foregroundColor: Colors.black,
        actions: [
          if (_unreadCount > 0)
            TextButton(
              onPressed: _markAllAsRead,
              child: const Text(
                'Mark all read',
                style: TextStyle(color: Colors.black87),
              ),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: LogoLoading())
          : _notifications.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.notifications_none,
                        size: 80,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No notifications yet',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadNotifications,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(8),
                    itemCount: _notifications.length,
                    itemBuilder: (context, index) {
                      final notification = _notifications[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(
                          vertical: 4,
                          horizontal: 8,
                        ),
                        color: notification.isRead
                            ? null
                            : const Color(0xFFFFEB3B).withAlpha((0.1 * 255).round()),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: _getNotificationColor(notification.type),
                            child: Icon(
                              _getNotificationIcon(notification.type),
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                          title: Text(
                            notification.message,
                            style: TextStyle(
                              fontWeight: notification.isRead
                                  ? FontWeight.normal
                                  : FontWeight.bold,
                            ),
                          ),
                          subtitle: Text(
                            _formatDate(notification.createdAt),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                          trailing: notification.isRead
                              ? null
                              : const Icon(
                                  Icons.circle,
                                  size: 8,
                                  color: Color(0xFFFFEB3B),
                                ),
                          onTap: () async {
                            if (!notification.isRead) {
                              await _markAsRead(notification.id);
                            }
                            if (notification.bookId != null) {
                              await _navigateToBook(notification.bookId);
                            }
                          },
                        ),
                      );
                    },
                  ),
                ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${date.month}/${date.day}/${date.year}';
    }
  }
}
