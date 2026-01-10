import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  final SupabaseClient _supabase;

  /// Accept an optional `SupabaseClient` for easier testing; defaults to
  /// `Supabase.instance.client` when not provided.
  AuthService([SupabaseClient? client])
    : _supabase = client ?? Supabase.instance.client;

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

  // --- SIGN IN WITH GOOGLE ---
  Future<AuthResponse> signInWithGoogle() async {
    try {
      // Initialize the GoogleSignIn manager with the web (server) client ID
      // so Android/iOS request an ID token (required by Supabase).
      await GoogleSignIn.instance.initialize(
        clientId:
            '470224077412-dk2dgbckigt2ibu38hnjjbdngndf5v57.apps.googleusercontent.com',
        serverClientId:
            '470224077412-ksm0uvafeqljtoppb4puseqrmtl7866a.apps.googleusercontent.com',
      );
      print('[AuthService] GoogleSignIn.initialize completed');

      // Use the 7.x API. Prefer interactive `authenticate()` on platforms that support it
      // so the ID token is returned. Fall back to lightweight auth and `authenticate()`.
      GoogleSignInAccount? googleUser;
      final supportsAuth = GoogleSignIn.instance.supportsAuthenticate();
      print('[AuthService] supportsAuthenticate: $supportsAuth');

      if (supportsAuth) {
        googleUser = await GoogleSignIn.instance.authenticate();
        print(
          '[AuthService] authenticate() returned: ${googleUser.email ?? 'none'}',
        );
      } else {
        final lightweightUser = await GoogleSignIn.instance
            .attemptLightweightAuthentication();
        print(
          '[AuthService] attemptLightweightAuthentication returned: ${lightweightUser?.email ?? 'none'}',
        );
        googleUser = lightweightUser;
      }

      if (googleUser == null) {
        print('[AuthService] Google sign in cancelled');
        throw 'Google sign in cancelled';
      }

      final GoogleSignInAuthentication googleAuth = googleUser.authentication;
      print(
        "[AuthService] googleAuth: idToken ${googleAuth.idToken != null ? 'present' : 'null'}",
      );

      if (googleAuth.idToken == null) {
        print('[AuthService] Failed to get Google ID token');
        throw 'Failed to get Google ID token';
      }

      final res = await _supabase.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: googleAuth.idToken!,
      );
      print(
        '[AuthService] Supabase signInWithIdToken result: ${res.session?.user.email ?? res.user?.email ?? 'no user'}',
      );
      return res;
    } catch (e, st) {
      print('[AuthService] signInWithGoogle error: $e\n$st');
      rethrow;
    }
  }

  // --- SIGN IN WITH FACEBOOK ---
  Future<void> signInWithFacebook() async {
    try {
      await _supabase.auth.signInWithOAuth(OAuthProvider.facebook);
      print('[AuthService] Facebook OAuth flow initiated');
    } catch (e, st) {
      print('[AuthService] signInWithFacebook error: $e\n$st');
      rethrow;
    }
  }

  // --- GET CURRENT USER EMAIL ---
  String? getCurrentUserEmail() {
    final session = _supabase.auth.currentSession;
    return session?.user.email;
  }
}
