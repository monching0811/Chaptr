import 'package:flutter/material.dart';
import 'home_screen.dart';
import 'add_book_screen.dart';

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _selectedIndex = 0;

  // List of screens for the bottom nav
  final List<Widget> _screens = [
    const HomeScreen(), // Library Icon
    const Center(child: Text("Bookstore Coming Soon")), // Bookstore Icon
    const AddBookScreen(), // Write Icon
    const Center(child: Text("Settings Coming Soon")), // Settings Icon
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: const Color(
          0xFFFFEB3B,
        ), // Primary Yellow from Proposal
        unselectedItemColor: Colors.grey,
        onTap: (index) => setState(() => _selectedIndex = index),
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
