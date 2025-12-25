import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth_page.dart'; // 1. Imported the new AuthPage

// IMPORTANT: Replace these placeholders with your actual Supabase credentials!
const String supabaseUrl = 'https://iwabeiwdypqiualdunnj.supabase.co';
const String supabaseAnonKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Iml3YWJlaXdkeXBxaXVhbGR1bm5qIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjUyNjEzOTcsImV4cCI6MjA4MDgzNzM5N30.OwAWRRB25ABJM4kbxpV3FDC9Bsfr5esD6N7BU21PheI';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
    debug: true,
  );

  runApp(const ChaptrApp());
}

final supabase = Supabase.instance.client;

class ChaptrApp extends StatelessWidget {
  const ChaptrApp({super.key});

  @override
  Widget build(BuildContext context) {
    const Color primaryYellow = Color(0xFFFFEB3B);

    return MaterialApp(
      title: 'Chaptr E-book App',
      debugShowCheckedModeBanner: false, // Optional: hides the debug banner
      theme: ThemeData(
        colorScheme: ColorScheme.fromSwatch(
          primarySwatch: Colors.yellow,
          brightness: Brightness.light,
        ),
        primaryColor: primaryYellow,
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryYellow, // Making buttons match your brand
            foregroundColor: Colors.black,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Colors.black,
        colorScheme: const ColorScheme.dark(
          primary: primaryYellow,
          surface: Colors.black,
        ),
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: Colors.white),
          bodyMedium: TextStyle(color: Colors.white),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryYellow,
            foregroundColor: Colors.black,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        useMaterial3: true,
      ),
      themeMode: ThemeMode.system,
      // 2. Changed home from Placeholder to AuthPage
      home: const AuthPage(),
    );
  }
}
