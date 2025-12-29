import 'package:flutter/material.dart';
import 'auth_service.dart';
import 'main_navigation.dart';
import 'animations.dart';
import 'widgets/book_flip_loading.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final _authService = AuthService();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _usernameController = TextEditingController();

  bool _isLogin = true;
  bool _isLoading = false;

  void _handleAuth() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final username = _usernameController.text.trim();

    setState(() => _isLoading = true);

    try {
      if (_isLogin) {
        await _authService.signIn(email, password);
      } else {
        await _authService.signUp(email, password, username);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_isLogin ? "Logged in!" : "Registered!")),
        );

        // Navigate to the Main Navigation Shell (Library/Store/Write/Settings)
        Navigator.pushReplacement(
          context,
          createSlideRoute(const MainNavigation()),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _handleGoogleSignIn() async {
    setState(() => _isLoading = true);

    try {
      await _authService.signInWithGoogle();

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Logged in with Google!")));
        Navigator.pushReplacement(
          context,
          createSlideRoute(const MainNavigation()),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Google sign in failed: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _handleFacebookSignIn() async {
    setState(() => _isLoading = true);

    try {
      await _authService.signInWithFacebook();

      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Redirecting to Facebook...")),
        );
        // Navigation will be handled by the auth state listener in main.dart
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Facebook sign in failed: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFFFEB3B), Color(0xFFFFC107)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: _isLoading
                ? const BookFlipLoading()
                : Card(
                    elevation: 10,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.book,
                            size: 80,
                            color: Color(0xFFFFEB3B),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            _isLogin ? "Welcome Back" : "Create Account",
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 20),
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 300),
                            child: _isLogin
                                ? const SizedBox.shrink(key: ValueKey('login'))
                                : TextField(
                                    key: const ValueKey('register'),
                                    controller: _usernameController,
                                    decoration: const InputDecoration(
                                      labelText: "Username",
                                      prefixIcon: Icon(Icons.person),
                                    ),
                                  ),
                          ),
                          TextField(
                            controller: _emailController,
                            decoration: const InputDecoration(
                              labelText: "Email",
                              prefixIcon: Icon(Icons.email),
                            ),
                          ),
                          TextField(
                            controller: _passwordController,
                            decoration: const InputDecoration(
                              labelText: "Password",
                              prefixIcon: Icon(Icons.lock),
                            ),
                            obscureText: true,
                          ),
                          const SizedBox(height: 20),
                          ElevatedButton(
                            onPressed: _handleAuth,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFFFEB3B),
                              foregroundColor: Colors.black,
                              minimumSize: const Size(double.infinity, 50),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(25),
                              ),
                            ),
                            child: Text(_isLogin ? "Login" : "Register"),
                          ),
                          const SizedBox(height: 10),
                          TextButton(
                            onPressed: () =>
                                setState(() => _isLogin = !_isLogin),
                            child: Text(
                              _isLogin
                                  ? "Create an account"
                                  : "Have an account? Login",
                              style: const TextStyle(color: Colors.black54),
                            ),
                          ),
                          const SizedBox(height: 20),
                          const Text("Or sign in with"),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              ElevatedButton.icon(
                                icon: const Icon(Icons.g_mobiledata),
                                label: const Text("Google"),
                                onPressed: _handleGoogleSignIn,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                              ElevatedButton.icon(
                                icon: const Icon(Icons.facebook),
                                label: const Text("Facebook"),
                                onPressed: _handleFacebookSignIn,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
