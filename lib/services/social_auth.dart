import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import '../api_service.dart';

/// The federated sign-in providers offered alongside email/password.
enum SocialProvider { google, apple }

/// Thrown when a provider sign-in fails for a reason worth showing the user.
/// A cancelled sign-in is not an error — those return null instead.
class SocialAuthException implements Exception {
  final String message;
  SocialAuthException(this.message);
  @override
  String toString() => message;
}

/// Google and Apple sign-in.
///
/// Each provider hands back a signed identity token that only the backend
/// trusts: it verifies the signature against the provider's published keys
/// before issuing an app session (see backend/utils/socialAuth.js). Nothing
/// here decides who the user is.
class SocialAuth {
  SocialAuth._();

  // ── Google ────────────────────────────────────────────────────────────────

  /// True when a Google client ID has been configured. The button stays hidden
  /// otherwise, rather than showing and failing.
  static bool get googleAvailable => AppConfig.googleServerClientId != null;

  static GoogleSignIn? _google;

  static GoogleSignIn _googleClient() => _google ??= GoogleSignIn(
        scopes: const ['email', 'profile'],
        // Android only returns an ID token when a server client ID is set, and
        // iOS has no GoogleService-Info.plist here so it needs the client ID
        // passed explicitly.
        serverClientId: AppConfig.googleServerClientId,
        clientId: !kIsWeb && Platform.isIOS ? AppConfig.googleIosClientId : null,
      );

  /// Runs the Google flow and returns an app session, or null if the user
  /// backed out of the account picker.
  static Future<({ApiUser user, String token})?> signInWithGoogle() async {
    final client = _googleClient();
    GoogleSignInAccount? account;
    try {
      account = await client.signIn();
    } catch (e) {
      throw SocialAuthException('Google sign-in failed. $e');
    }
    if (account == null) return null; // dismissed the picker

    final auth = await account.authentication;
    final idToken = auth.idToken;
    if (idToken == null || idToken.isEmpty) {
      // Almost always a misconfigured OAuth client — an Android client entry
      // with this app's SHA-1, or the wrong serverClientId.
      await client.signOut();
      throw SocialAuthException(
          'Google did not return an identity token. Check the OAuth client configuration.');
    }
    return ApiService.authenticateWithGoogle(idToken: idToken);
  }

  // ── Apple ─────────────────────────────────────────────────────────────────

  /// True where Sign in with Apple can run: natively on iOS/macOS, and on
  /// Android only when a Services ID and redirect URI are configured for the
  /// web flow.
  static Future<bool> appleAvailable() async {
    if (!kIsWeb && (Platform.isIOS || Platform.isMacOS)) {
      return SignInWithApple.isAvailable();
    }
    return AppConfig.appleServiceId != null && AppConfig.appleRedirectUri != null;
  }

  /// Runs the Apple flow and returns an app session, or null if the user
  /// cancelled the sheet.
  static Future<({ApiUser user, String token})?> signInWithApple() async {
    final serviceId   = AppConfig.appleServiceId;
    final redirectUri = AppConfig.appleRedirectUri;

    AuthorizationCredentialAppleID credential;
    try {
      credential = await SignInWithApple.getAppleIDCredential(
        scopes: const [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        webAuthenticationOptions: serviceId == null || redirectUri == null
            ? null
            : WebAuthenticationOptions(
                clientId: serviceId,
                redirectUri: Uri.parse(redirectUri),
              ),
      );
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) return null;
      throw SocialAuthException('Apple sign-in failed. ${e.message}');
    } catch (e) {
      throw SocialAuthException('Apple sign-in failed. $e');
    }

    final identityToken = credential.identityToken;
    if (identityToken == null || identityToken.isEmpty) {
      throw SocialAuthException('Apple did not return an identity token.');
    }

    // Apple sends the name exactly once, on the first authorisation ever. If
    // it is not forwarded now it can never be recovered.
    final name = [credential.givenName, credential.familyName]
        .whereType<String>()
        .where((s) => s.isNotEmpty)
        .join(' ');

    return ApiService.authenticateWithApple(
      identityToken: identityToken,
      name: name.isEmpty ? null : name,
    );
  }

  /// Runs [provider]'s flow. Returns null when the user cancelled.
  static Future<({ApiUser user, String token})?> signIn(SocialProvider provider) =>
      switch (provider) {
        SocialProvider.google => signInWithGoogle(),
        SocialProvider.apple  => signInWithApple(),
      };

  /// Clears any cached Google account so the next sign-in shows the picker.
  /// Apple keeps no client-side session to clear.
  static Future<void> signOut() async {
    try {
      if (_google != null) await _google!.signOut();
    } catch (_) {
      // Signing out of the provider is best-effort; the app session is already
      // gone by this point.
    }
  }
}
