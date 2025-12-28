import 'dart:convert';
import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';

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
        print('[AuthService] authenticate() returned: ${googleUser?.email}');
      } else {
        final lightweightUser = await GoogleSignIn.instance
            .attemptLightweightAuthentication();
        print(
          '[AuthService] attemptLightweightAuthentication returned: ${lightweightUser?.email}',
        );
        if (lightweightUser != null) {
          googleUser = lightweightUser;
        } else {
          googleUser = await GoogleSignIn.instance.authenticate();
          print(
            '[AuthService] fallback authenticate() returned: ${googleUser?.email}',
          );
        }
      }

      if (googleUser == null) {
        print('[AuthService] Google sign in cancelled');
        throw 'Google sign in cancelled';
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
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
  Future<AuthResponse> signInWithFacebook() async {
    try {
      // First try using Supabase's OAuth flow (preferred). This initiates a redirect and may not immediately return a session.
      try {
        final started = await _supabase.auth.signInWithOAuth(
          OAuthProvider.facebook,
        );
        print('[AuthService] signInWithOAuth started: $started');
        if (started == true) {
          // The SDK initiated a redirect-based flow. The session will be available after the redirect completes.
          throw 'Supabase OAuth flow started (redirect to browser). Complete the flow and re-check session via Supabase listeners; this method cannot complete a session immediately.';
        }
      } catch (e) {
        // Method might not be available (older SDK) or the call failed; fall through to SDK-based flow
        print('[AuthService] signInWithOAuth not available or failed: $e');
      }

      // Fall back to using the Facebook SDK token exchange
      final LoginResult result = await FacebookAuth.instance.login();
      print(
        '[AuthService] Facebook login result: status=${result.status}, message=${result.message}',
      );
      if (result.status != LoginStatus.success)
        throw 'Facebook sign in failed: ${result.message}';

      final AccessToken? accessToken = result.accessToken;
      if (accessToken == null) throw 'Failed to get Facebook access token';
      print(
        '[AuthService] Facebook access token present; userId=${accessToken.userId}, expires=${accessToken.expires}',
      );
      if (kDebugMode) {
        // Temporary debug: print token locally (do not commit this in production)
        print(
          '[AuthService][DEBUG] Facebook access token: ${accessToken.token}',
        );
      }

      // Diagnostics: call Graph API /me and try debug_token (if app secret provided via env)
      await _diagnoseFacebookToken(accessToken);

      try {
        final res = await _supabase.auth.signInWithIdToken(
          provider: OAuthProvider.facebook,
          idToken: accessToken.token,
        );
        print(
          '[AuthService] Supabase signInWithIdToken result: ${res.session?.user.email ?? res.user?.email ?? 'no user'}, sessionPresent=${res.session != null}',
        );
        return res;
      } catch (e) {
        print('[AuthService] signInWithIdToken failed: $e');
        // Try passing the token as accessToken as well (some providers expect it)
        try {
          final res2 = await _supabase.auth.signInWithIdToken(
            provider: OAuthProvider.facebook,
            idToken: accessToken.token,
            accessToken: accessToken.token,
          );
          print(
            '[AuthService] Supabase signInWithIdToken (with accessToken) result: ${res2.session?.user.email ?? res2.user?.email ?? 'no user'}, sessionPresent=${res2.session != null}',
          );
          return res2;
        } catch (e2) {
          print(
            '[AuthService] signInWithIdToken (with accessToken) also failed: $e2',
          );
          // Provide a helpful error explaining likely cause
          throw 'Facebook sign-in failed: Supabase rejected the Facebook token. Ensure Facebook is enabled in Supabase Auth with correct App ID & Secret, or use the OAuth flow.';
        }
      }
    } catch (e, st) {
      print('[AuthService] signInWithFacebook error: $e\n$st');
      rethrow;
    }
  }

  // --- HELPER: Diagnostics for Facebook tokens ---
  Future<void> _diagnoseFacebookToken(AccessToken accessToken) async {
    try {
      // 1) /me response (basic verification)
      try {
        final uri = Uri.parse(
          'https://graph.facebook.com/me?fields=id,name,email&access_token=${accessToken.token}',
        );
        final HttpClient httpClient = HttpClient();
        final req = await httpClient.getUrl(uri);
        final resp = await req.close();
        final body = await resp.transform(utf8.decoder).join();
        print(
          '[AuthService] Facebook Graph /me response: ${resp.statusCode} $body',
        );
      } catch (e) {
        print('[AuthService] Failed to call Facebook Graph /me: $e');
      }

      // 2) If app id & secret provided in environment, call /debug_token for richer diagnostics
      final fbAppId = Platform.environment['FACEBOOK_APP_ID'];
      final fbAppSecret = Platform.environment['FACEBOOK_APP_SECRET'];
      if (fbAppId != null && fbAppSecret != null) {
        try {
          final appToken = '$fbAppId|$fbAppSecret';
          final uriDebug = Uri.parse(
            'https://graph.facebook.com/debug_token?input_token=${accessToken.token}&access_token=$appToken',
          );
          final httpClient2 = HttpClient();
          final req2 = await httpClient2.getUrl(uriDebug);
          final resp2 = await req2.close();
          final body2 = await resp2.transform(utf8.decoder).join();
          print(
            '[AuthService] Facebook Graph /debug_token response: ${resp2.statusCode} $body2',
          );
        } catch (e) {
          print('[AuthService] Failed to call Facebook Graph /debug_token: $e');
        }
      } else {
        print(
          '[AuthService] FACEBOOK_APP_ID/SECRET not set in environment; skipping /debug_token. To enable, set env vars FACEBOOK_APP_ID and FACEBOOK_APP_SECRET for diagnostics.',
        );
      }
    } catch (e) {
      print('[AuthService] _diagnoseFacebookToken unexpected error: $e');
    }
  }

  // --- GET CURRENT USER EMAIL ---
  String? getCurrentUserEmail() {
    final session = _supabase.auth.currentSession;
    return session?.user.email;
  }
}
