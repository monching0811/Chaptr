import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // --- SIGN UP ---
  Future<AuthResponse> signUp(
    String email,
    String password,
    String username,
  ) async {
    final response = await _supabase.auth.signUp(
      email: email,
      password: password,
      // We pass the username in data so we can use it later
      data: {'username': username},
    );

    // After signing up, we create the profile in our 'profiles' table
    if (response.user != null) {
      await _supabase.from('profiles').insert({
        'id': response.user!.id,
        'username': username,
      });
    }
    return response;
  }

  // --- SIGN IN ---
  Future<AuthResponse> signIn(String email, String password) async {
    return await _supabase.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  // --- SIGN OUT ---
  Future<void> signOut() async {
    await _supabase.auth.signOut();
  }

  // --- GET CURRENT USER EMAIL ---
  String? getCurrentUserEmail() {
    final session = _supabase.auth.currentSession;
    return session?.user.email;
  }
}
