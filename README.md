# GO

30-day habit app: pay a simulated premium, charge the battery daily, win half back. Includes a Diary for finding saved video links. **All money is simulated.**

## Run
```
flutterfire configure
flutter pub add firebase_ai http crypto
firebase deploy --only firestore:rules
flutter run -d chrome
```
Enable Anonymous sign-in, create Firestore, and turn on Firebase AI Logic (Gemini Developer API) in the Firebase console. No Blaze plan needed.

Camera: add `NSCameraUsageDescription` to ios/Runner/Info.plist and `CAMERA` permission to AndroidManifest.xml (minSdk 21).

See SUBMISSION.md for the write-up.

## Known limitation: screen time
GO cannot read real Screen Time data (needs Apple's FamilyControls entitlement, which requires approval). The screen-time habit is proved by a screenshot that Gemini reads, so it is self-reported with evidence, not verified. See SUBMISSION.md.
