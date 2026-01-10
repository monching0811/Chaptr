import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:chaptr_ebook_app/auth_service.dart';
import 'package:flutter_facebook_auth_platform_interface/flutter_facebook_auth_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockSupabaseClient extends Mock implements SupabaseClient {}

class MockAuth extends Mock implements GoTrueClient {}

class FakeFacebookPlatform extends FacebookAuthPlatform
    with MockPlatformInterfaceMixin {
  final LoginResult result;
  FakeFacebookPlatform(this.result);

  @override
  Future<LoginResult> login({
    List<String>? permissions,
    LoginBehavior? loginBehavior,
  }) async => result;

  @override
  Future<LoginResult> expressLogin() async => result;

  @override
  Future<void> logOut() async {}

  @override
  Future<Map<String, dynamic>> getUserData({
    String? fields,
    String? locale,
  }) async => {};

  @override
  Future<void> webAndDesktopInitialize({
    required String appId,
    bool cookie = false,
    bool xfbml = false,
    String? version,
  }) async {}

  @override
  Future<void> autoLogAppEventsEnabled(bool enabled) async {}

  @override
  Future<FacebookPermissions?> get permissions async => null;

  @override
  Future<bool> get isAutoLogAppEventsEnabled async => false;

  @override
  bool get isWebSdkInitialized => false;

  @override
  Future<AccessToken?> get accessToken async => null;
}

class MockLoginResult extends Mock implements LoginResult {}

class MockAccessToken extends Mock implements AccessToken {}

FacebookAuthPlatform? _previousFacebookPlatform;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    registerFallbackValue(OAuthProvider.facebook);

    // Replace the Facebook platform implementation with a fake so tests don't hit platform channels
    final mockLogin = MockLoginResult();
    final mockAccess = MockAccessToken();

    // stub the login result and access token getters
    when(() => mockLogin.status).thenReturn(LoginStatus.success);
    when(() => mockLogin.message).thenReturn(null);
    when(() => mockLogin.accessToken).thenReturn(mockAccess);
    when(() => mockAccess.token).thenReturn('fake-token');
    when(() => mockAccess.userId).thenReturn('123');
    when(
      () => mockAccess.expires,
    ).thenReturn(DateTime.now().add(Duration(hours: 1)));
    when(() => mockAccess.lastRefresh).thenReturn(DateTime.now());

    _previousFacebookPlatform = FacebookAuthPlatform.instance;
    FacebookAuthPlatform.instance = FakeFacebookPlatform(mockLogin);
  });

  tearDownAll(() {
    // Restore original platform implementation
    if (_previousFacebookPlatform != null) {
      FacebookAuthPlatform.instance = _previousFacebookPlatform!;
    }
  });

  test('signInWithFacebook initiates OAuth flow', () async {
    final mockSupabase = MockSupabaseClient();
    final mockAuth = MockAuth();

    // Return the mocked auth client
    when(() => mockSupabase.auth).thenReturn(mockAuth);
    // Stub the signInWithOAuth call to complete without error
    when(
      () => mockAuth.signInWithOAuth(OAuthProvider.facebook),
    ).thenAnswer((_) async => true);

    final service = AuthService(mockSupabase);

    // Should not throw
    await expectLater(service.signInWithFacebook(), completes);

    // Verify signInWithOAuth was called
    verify(() => mockAuth.signInWithOAuth(OAuthProvider.facebook)).called(1);
  });
}
