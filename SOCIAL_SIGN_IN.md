# Google & Apple sign-in — setup

The code is in place. What remains is console configuration, which can only be
done from your Google, Apple, and Firebase accounts.

Buttons appear only when their client IDs are configured, so a half-finished
provider is simply absent from the login screen rather than broken.

## How it works

1. The app runs the provider flow and receives a signed **identity token**.
2. It posts that token to `POST /api/auth/google` or `POST /api/auth/apple`.
3. The backend verifies the token's signature against the provider's published
   keys, plus issuer, audience, and expiry (`backend/utils/socialAuth.js`).
4. Only then does it issue the app's own JWT.

Accounts are created on first sign-in, matching the existing public
`/register`. Identities are keyed on the provider's `sub`, not the email —
Apple's "Hide My Email" hands out a relay address, and Google emails can change.

## Backend environment variables

Both are comma-separated. **The routes refuse all sign-ins until these are
set** — an unset audience list would mean accepting tokens minted for any app.

```
GOOGLE_CLIENT_IDS=<web client id>,<ios client id>,<android client id>
APPLE_CLIENT_IDS=com.solidcore.ams,<apple services id>
```

`GOOGLE_CLIENT_IDS` must list every client ID the app can present as `aud`:
the Android flow presents the **web** client ID (because it is passed as
`serverClientId`), and iOS presents the **iOS** client ID.

For Apple, native iOS sign-in presents the **bundle ID**; the Android web flow
presents the **Services ID**.

## Google — console steps

1. Firebase console → project `fitness-app-5b6e3` → Project settings.
2. The Android app registered for `com.solidcore.ams` currently has **no OAuth
   client of its own**, only the shared web client. Add your signing
   certificate **SHA-1** (and SHA-256) fingerprints to it. Without this,
   Google sign-in fails on Android with `ApiException: 10 (DEVELOPER_ERROR)`.
   - Debug: `keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android`
   - Release: same command against your upload keystore. **Also add the SHA-1
     that Play App Signing shows in the Play Console**, or sign-in works in
     your local build and fails for everyone who installs from Play.
3. Download the regenerated `google-services.json` into `android/app/`.
4. For iOS: create an **iOS OAuth client** in the same project, then
   - put its client ID in `GOOGLE_IOS_CLIENT_ID` (`assets/config.json`)
   - add its **reversed** client ID as a URL scheme in `ios/Runner/Info.plist`:

```xml
<key>CFBundleURLTypes</key>
<array>
  <dict>
    <key>CFBundleURLSchemes</key>
    <array><string>com.googleusercontent.apps.NNNNN-XXXX</string></array>
  </dict>
</array>
```

## Apple — console steps

Requires a paid Apple Developer Program membership.

1. developer.apple.com → Certificates, Identifiers & Profiles → Identifiers →
   the App ID for `com.solidcore.ams` → enable **Sign In with Apple**.
2. Xcode → Runner target → Signing & Capabilities → **+ Capability** →
   *Sign in with Apple*. `ios/Runner/Runner.entitlements` already holds the
   right entitlement; this step points the build setting at it.
3. Set `APPLE_CLIENT_IDS=com.solidcore.ams` on the backend. iOS is now done.

For **Apple sign-in on Android** (optional — the button hides itself if you
skip this):

4. Create a **Services ID** (e.g. `com.solidcore.ams.web`), enable Sign In with
   Apple on it, and register a Return URL you control.
5. Fill `APPLE_SERVICE_ID` and `APPLE_REDIRECT_URI` in `assets/config.json`,
   and append the Services ID to `APPLE_CLIENT_IDS`.

## Store requirements

- Apple Guideline **4.8**: offering Google sign-in makes Sign in with Apple
  mandatory on iOS. Both are implemented, so this is satisfied — but do not
  ship the Google button on iOS without the Apple one configured.
- Apple Guideline **5.1.1(v)**: an app that creates accounts must let users
  delete them in-app. Already covered by *Delete account* in Privacy &
  Security.

## Verifying

```bash
# Should be rejected — unsigned/forged tokens must never produce a session.
curl -s -X POST $API/auth/google -H 'Content-Type: application/json' \
  -d '{"idToken":"not-a-real-token"}'
# => 401 {"error":"Sign-in could not be verified. Please try again."}
```
