# Google Drive backup — setup

The in-app "Sign in with Google" button needs an OAuth client registered
in Google Cloud Console. Without it, sign-in fails with
`PlatformException(sign_in_failed, ...: 10, ...)` (DEVELOPER_ERROR).

## One-time setup

1. **Create a Google Cloud project** at https://console.cloud.google.com
   and enable the **Google Drive API** (APIs & Services → Library).

2. **Create OAuth 2.0 credentials** (APIs & Services → Credentials →
   Create Credentials → OAuth client ID).

   - **Android** client:
     - Package name: `com.hlomatsi.yomou`
     - SHA-1 fingerprint: from your release keystore:
       ```
       keytool -list -v -keystore <your-release.keystore> -alias <alias>
       ```
       (For debug builds use the debug keystore:
       `~/.android/debug.keystore`, alias `androiddebugkey`, password `android`.)
   - **iOS** client:
     - Bundle ID: the value in `ios/Runner.xcodeproj` (e.g. `com.hlomatsi.yomou`).

3. **Android**: place the downloaded `google-services.json` in
   `android/app/`. The `google_sign_in` plugin reads the client ID from it.
   (Alternatively pass `serverClientId` to `GoogleSignIn(...)`.)

4. **iOS**: add the reversed client ID to `ios/Runner/Info.plist`:
   ```xml
   <key>CFBundleURLTypes</key>
   <array>
     <dict>
       <key>CFBundleURLSchemes</key>
       <array>
         <string>com.googleusercontent.apps.<YOUR_IOS_CLIENT_ID></string>
       </array>
     </dict>
   </array>
   ```

5. **OAuth consent screen**: set the app name and add your test users
   (while in "Testing" mode) so sign-in is allowed before verification.

6. Rebuild and reinstall. Sign-in should complete and the screen switches to
   "Signed in as …".

## Notes
- Scope used: `https://www.googleapis.com/auth/drive.file` (app-created files
  only; the app cannot see the rest of the user's Drive).
- Backups are stored as `yomou-<timestamp>.bk.zip` in the user's Drive.
- Revoke access anytime from the user's Google account → Security →
  Third-party apps.
