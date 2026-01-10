import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'home_screen.dart';
import 'add_book_screen.dart';
import 'bookstore_screen.dart';
import 'profile_screen.dart';
import 'notifications_screen.dart';

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _selectedIndex = 0;
  int _unreadNotifications = 0;

  // Updated list of screens to include the ProfileScreen
  final List<Widget> _screens = [
    const HomeScreen(), // Library
    const BookstoreScreen(), // Store
    const AddBookScreen(), // Write
    const ProfileScreen(), // Settings/Profile
  ];

  @override
  void initState() {
    super.initState();
    _loadUnreadNotifications();
    // Refresh notifications periodically
    _startNotificationListener();
  }

  void _startNotificationListener() {
    // Check for new notifications every 30 seconds
    Future.delayed(const Duration(seconds: 30), () {
      if (mounted) {
        _loadUnreadNotifications();
        _startNotificationListener();
      }
    });
  }

  Future<void> _loadUnreadNotifications() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    try {
      final response = await Supabase.instance.client
          .from('notifications')
          .select('id')
          .eq('user_id', user.id)
          .eq('is_read', false)
          .count();

      if (mounted) {
        setState(() {
          _unreadNotifications = response.count ?? 0;
        });
      }
    } catch (e) {
      // Notifications table might not exist yet
      debugPrint('Error loading notifications: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: const Color(0xFFFFEB3B), // Primary Yellow
        unselectedItemColor: Colors.grey,
        onTap: (index) {
          setState(() => _selectedIndex = index);
          if (index == 0) _loadUnreadNotifications(); // Refresh when viewing library
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.book), label: 'Library'),
          BottomNavigationBarItem(
            icon: Icon(Icons.shopping_cart),
            label: 'Store',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.edit), label: 'Write'),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
