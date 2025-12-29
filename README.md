# chaptr_ebook_app

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

---

## Facebook auth (mobile)

To enable Facebook sign-in on mobile and complete the OAuth redirect flow:

1. In Supabase dashboard → Authentication → Providers → Facebook, set **App ID** and **App Secret** and add a valid redirect URL like `chaptr://login-callback`.
2. In your Facebook App settings add the same redirect URI in **Valid OAuth Redirect URIs**.
3. In Android, the app registers `chaptr://login-callback` (see `AndroidManifest.xml` intent filter). For iOS add a URL Type in `ios/Runner/Info.plist` with scheme `chaptr`.
4. When `signInWithOAuth` starts, the SDK will open a browser. After completing login the browser will redirect back to `chaptr://login-callback` and Supabase will finish creating the session.
5. The app listens to `supabase.auth.onAuthStateChange` and will navigate the user to the main app screen after the session is established.

Notes:

- For diagnostics, call `https://graph.facebook.com/debug_token?input_token=<USER_TOKEN>&access_token=<APP_ID>|<APP_SECRET>` from a secure host to verify token validity.
- Do not embed your Facebook app secret in the mobile app.
