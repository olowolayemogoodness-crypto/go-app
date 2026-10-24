# GO — Taskforge Student Hackathon submission

**GO** is a 30-day habit app. You pay a *simulated* premium, finish daily activities to charge a big battery, and win half the premium back if you keep the streak. It also has a personal Diary where you find saved video links by describing them.

> All money in GO is **simulated**. No real payment, deposit or transfer happens anywhere.

## The problem
Students set goals and drop them within days. Existing habit apps are easy to cheat (tap a checkbox) and give little reason to keep going. Commitment-contract apps that use real money can be stressful, risky and legally complex.

## Intended user
Students who want to build a daily habit (study, workout, reading, coding) and are motivated by a visible goal and a small cost of quitting. A trusted friend acts as an accountability partner. Accessibility options (large text, high contrast, dyslexia-friendly font, reduced motion, read-aloud) are built in.

## Solution
1. Choose 1 to 5 daily activities (camera-proof or GitHub) and pay a simulated premium.
2. Each finished activity charges the **battery** on the home screen; finishing everything fills it.
3. **Win rule:** do at least one activity every day for 30 days (3 grace passes protect a day) **and** complete at least 90% of all activities. A win returns **half the premium**.
4. **Be honest about the stakes:** if you do not win, the app keeps the whole premium (simulated). Earlier drafts said the app never profits from failure; that is no longer true, and we say so plainly.
5. **Proof:** camera check-ins with a one-time random code word, judged by Gemini vision. GitHub activities use the public GitHub events API (no AI). The AI never fails you alone: unsure or failed results go to your partner (one-link, no login), and you may appeal once.
6. **Diary:** save video links, then describe one in plain words. An agent ranks your saved links and explains why each matched.

## Tools
Flutter (web, Android, iOS); Firebase Hosting, Anonymous Auth, Firestore; Gemini through Firebase AI Logic (vision for check-ins, text for the diary search). No Cloud Functions, so it runs on the free Spark plan; GitHub public events API; YouTube/TikTok/Vimeo oEmbed for link titles.

## Limitations
- **Demo-grade integrity:** the game logic runs inside the app and Firestore rules cannot stop a determined user from editing their own records. A real product needs a server to decide outcomes.
- **Screen time is proved by screenshot, not read from the phone.** We wanted GO to read a user's real Screen Time totals and give an XP boost for low screen time. iOS only exposes that data through Apple's Screen Time APIs (FamilyControls and DeviceActivity). Using them needs a special entitlement that Apple must approve for each app, which a hackathon build cannot get in time, and Android has a similar permission wall. So the user uploads a screenshot of their Screen Time page and Gemini reads the number from it. A screenshot can be faked or edited, so this habit is self-reported with evidence, not verified. A production version would use the native APIs.
- Money is simulated; a real version would need a licensed payment partner (e.g. Paystack or Flutterwave) and legal review.
- The AI checker can be wrong or fooled. That is why a partner can always overrule it.
- The Diary agent **cannot watch videos**. It matches only title, author and your own notes; sites other than YouTube/TikTok/Vimeo need a typed title.
- Camera frames are sent to Gemini for checking and are not stored by GO.
- Rule logic is tested by script; the Flutter UI has had limited device testing.

## What we learned
- Float math breaks "90%" rules (0.1 × 90 is 8.999…); integer math fixed it.
- Never let an AI be the only judge of a penalty; routing doubt to a human changed the whole design.
- Fetching user-supplied URLs is an SSRF risk, so only fixed oEmbed endpoints are fetched.

## Examples and permission
Screens and demo data use invented activities and invented links. No real person's data or video is shown.

## Pre-existing work and AI assistance
- Pre-existing: open-source packages (Flutter, FlutterFire, camera, share_plus, flutter_tts, google_fonts, url_launcher) and Firebase services.
- AI assistance: the app, backend and this write-up were built with Claude (Anthropic) as a coding assistant, and the running app uses Gemini for check-in verification and diary search. The GO logo is an original drawing; the reference image was inspiration only.

## 2-minute demo
1. Start a program (2 activities, premium 1000). 2. Home shows the empty battery. 3. Check in with the camera and code word; battery charges. 4. Show GitHub check. 5. Show a partner link. 6. Open Diary, save a link, find it by description. 7. Show the win rule and "app keeps the premium otherwise".
