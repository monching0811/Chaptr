import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth_page.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final userEmail = Supabase.instance.client.auth.currentUser?.email;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chaptr Home'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await Supabase.instance.client.auth.signOut();
              if (context.mounted) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const AuthPage()),
                );
              }
            },
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.menu_book, size: 100, color: Color(0xFFFFEB3B)),
            const SizedBox(height: 20),
            Text('Welcome, $userEmail!', style: const TextStyle(fontSize: 18)),
            const SizedBox(height: 10),
            const Text('Your library is currently empty.'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFFFFEB3B),
        onPressed: () {
          // We will build the "Add Book" screen next!
        },
        child: const Icon(Icons.add, color: Colors.black),
      ),
    );
  }
}
