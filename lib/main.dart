import 'package:flutter/material.dart';
import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth_page.dart'; // 1. Imported the new AuthPage
import 'main_navigation.dart'; // navigation after auth

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
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class ChaptrApp extends StatefulWidget {
  const ChaptrApp({super.key});

  @override
  State<ChaptrApp> createState() => _ChaptrAppState();
}

class _ChaptrAppState extends State<ChaptrApp> {
  late final StreamSubscription<AuthState> _authSub;

  @override
  void initState() {
    super.initState();

    // Listen for auth state changes so the app can react after OAuth redirect
    _authSub = Supabase.instance.client.auth.onAuthStateChange.listen((ev) {
      final session = ev.session;
      print(
        '[Main] auth state change: ${ev.event}, sessionPresent=${session != null}',
      );

      if (session != null) {
        // User signed in — navigate to main app
        navigatorKey.currentState?.pushReplacement(
          MaterialPageRoute(builder: (_) => const MainNavigation()),
        );
      } else {
        // Signed out — return to auth page
        navigatorKey.currentState?.pushReplacement(
          MaterialPageRoute(builder: (_) => const AuthPage()),
        );
      }
    });
  }

  @override
  void dispose() {
    _authSub.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryYellow = Color(0xFFFFEB3B);

    return MaterialApp(
      navigatorKey: navigatorKey,
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
