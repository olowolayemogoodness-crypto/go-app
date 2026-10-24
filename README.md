# GO

**Put a fee on your commitment. Follow through and get all of it back.**

GO is a 30-day habit app for developers and students whose days are a mess. You pay a *commitment fee*, complete a few daily habits to charge a big battery, and when you finish the 30 days with real consistency, **the whole fee comes back**. Quit, and you lose it. Every habit is proved, not just ticked.

> All money in GO is **simulated**. No real payment, deposit or transfer happens anywhere. See "Honest limits" in [SUBMISSION.md](SUBMISSION.md).

## What it does
- **Commitment fee.** Pay a simulated fee (500 to 3,000 coins) and name an accountability partner.
- **Win rule.** Do at least one habit every day for 30 days (3 grace passes protect a day) and complete at least 90% of all habits. Win: the fee returns in full. Lose: the app keeps it.
- **Habits with their own widgets.** Pick up to five. Push a commit, screen time, workout, study, read, phone down, spending, tidy up. Each one has its own tile on Home.
- **Proof, not honour.**
  - Camera habits use a one-time random code word shown in the shot. Gemini judges it. The AI never fails you alone: unsure results go to your partner, who answers from one link with no account.
  - **GitHub** habit reads your public GitHub activity. Home shows a contribution heat-map, and a full GitHub screen shows streaks, today's pushes and a daily reminder notification.
  - **Reading** habit uses the in-app PDF reader. A page counts only after 12 seconds of active time on it, so skipping, idling and leaving the app earn nothing.
  - **Screen time** is proved by a screenshot that Gemini reads, because Apple does not allow third-party apps to read Screen Time without special approval.
- **XP and a leaderboard.** Passed habits earn XP, and low screen time earns a 1.5x boost. The Profile tab has an opt-in leaderboard that shows who is locked in.
- **Saves.** A personal shelf for video links you can find again by describing them, plus the reading shelf.
- **Accessible.** Large text, high contrast, dyslexia-friendly font, reduced motion and read-aloud.

## Run it
Requirements: Flutter, a Firebase project (Spark plan is enough), Xcode for the iOS simulator.

```
flutterfire configure
flutter pub get
firebase deploy --only firestore:rules
flutter run -d "iPhone"
```

In the Firebase console: turn on **GitHub, Google and Anonymous** sign-in, create a **Firestore** database, and enable **Firebase AI Logic** (Gemini Developer API). No server, no Cloud Functions and no Blaze plan are needed: all game logic runs in the app.

iOS: the URL scheme for sign-in, the camera description and the notification permission are already in `ios/Runner/Info.plist`.

## Built with
Flutter, Firebase (Auth, Firestore), Gemini through Firebase AI Logic, the public GitHub API, pdfx for PDF reading. The full write-up, limits and credits are in [SUBMISSION.md](SUBMISSION.md).
