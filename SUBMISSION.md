# GO: Taskforge Student Hackathon submission

**GO is a commitment app for people whose lives are disorganised. You put a fee down, prove your habits every day for 30 days, and get all of it back if you follow through.**

> Everything involving money in GO is **simulated**. No real payment, deposit or transfer exists anywhere in the app.

## The problem
Developers and students set goals, then lose them to scrolling, late nights and a to-do list that nobody checks. Habit apps do not help, because a checkbox is easy to tick and nothing is lost when you quit. Commitment-contract apps that use real money are stressful, risky and legally complex.

## Intended user
Developers and students who want a daily routine (code, study, read, exercise, sleep on time, stay off the phone) and respond to a visible goal with a small cost for quitting. A trusted friend acts as accountability partner. We built accessibility in from the start: large text, high contrast, dyslexia-friendly font, reduced motion and read-aloud.

## The solution
1. **Choose habits.** One screen to pick up to five, then one short setup page per habit (your GitHub username, screen-time limit, minutes, pages, bedtime).
2. **Pay a commitment fee** (simulated, 500 to 3,000 coins) and name a partner.
3. **Charge the battery.** Each completed habit charges the big battery on Home. Every habit has its own tile.
4. **Win rule.** Do at least one habit every day for 30 days (3 grace passes protect a day) and complete at least 90% of all habits. A win returns **the whole fee**. If you do not win, the app keeps it. That forfeited fee is the only way the app would earn, and we say so plainly.
5. **Proof, not honour.**
   - **Camera habits:** a one-time random code word must appear in the shot. Gemini vision judges activity and code word. The AI never fails you alone: unsure or failed results go to your partner (one link, no account), and you can appeal once.
   - **GitHub:** public GitHub activity. Home shows a contribution heat-map; the GitHub screen shows streaks, today's pushes and a daily reminder notification.
   - **Reading:** upload a PDF and read it in GO. A page counts only after 12 seconds of active time on it; flipping past pages, leaving the app or an idle screen count nothing. When the pages reach your goal, the habit completes itself.
   - **Screen time:** a screenshot of the Screen Time page, read by Gemini (see limits).
6. **XP and leaderboard.** 10 XP per passed habit, with a 1.5x boost when the screen-time habit passes. An opt-in leaderboard on the Profile tab shows who is locked in, ranked by XP and streak.
7. **Saves.** A personal diary of video links you can search by describing them (an agent ranks them and explains each match), plus the reading shelf.

## Tools and technologies
Flutter (iOS, Android, web); Firebase Authentication (GitHub, Google, anonymous guest), Cloud Firestore; Gemini 2.5 Flash through Firebase AI Logic (no API key in the app) for camera verification, screenshot reading and link search; the public GitHub API; pdfx and file_picker for the reader; flutter_local_notifications for reminders. There is no server and no paid plan: the game logic runs inside the app.

## Honest limits
- **Money is simulated.** A real product needs a licensed payment provider, a server that holds funds and issues refunds, and legal review: a fee that is returned on success looks like a commitment contract or wager in many places, and app stores have rules for it. We chose not to fake any of that.
- **Demo-grade integrity.** Because there is no server, the rules run in the app and a determined user could edit their own records, including leaderboard scores. A real product decides outcomes on a server.
- **Screen time is proved by screenshot, not read from the phone.** We wanted GO to read real Screen Time totals and reward low usage. iOS only exposes that through Apple's FamilyControls and DeviceActivity APIs, which need a special entitlement Apple approves per app, and Android has a similar wall. So the user uploads a screenshot and Gemini reads the number. A screenshot can be edited, so this habit is self-reported with evidence, not verified.
- **Reading is measured, not proven.** The reader measures active time and page progress, which makes cheating harder, but nothing can prove a person is really reading. PDFs stay on the phone; only the daily page count goes to the cloud.
- **The AI can be wrong or fooled.** That is why a partner can always overrule it.
- **GitHub** is read from public activity; private contributions show only if the user enables them on GitHub. A typed username is self-reported.
- The saves agent **cannot watch videos**. It matches titles, authors and the user's own notes.
- Camera frames are sent to Gemini to be checked and are not stored by GO.
- The game rules are tested by script, but the app has had limited device testing (iPhone simulator).

## What we learned
- Float maths breaks percentage rules (0.1 x 90 is 8.999...). Integer maths fixed the 90% rule.
- An AI should never be the only judge of a penalty. Routing doubt to a human changed the whole design.
- Fetching user-supplied URLs is an SSRF risk, so we fetch only fixed endpoints.
- Do the honest thing about money early: simulating it, and saying so, was better than faking a payment screen.
- Platform walls (Screen Time, paid backend plans) shape a product. Documenting why a feature is a screenshot is part of building it well.

## Examples and permission
Screens and demo data use invented habits, invented links and invented names. No real person's data or video is shown. We give permission for the organisers to use screenshots and the demo for judging and promotion.

## Pre-existing work and AI assistance
- **Pre-existing:** open-source packages (Flutter, FlutterFire, camera, pdfx, file_picker, share_plus, flutter_tts, google_fonts, url_launcher, flutter_local_notifications) and Firebase services. The GO logo and artwork are our own.
- **AI assistance:** the app and this write-up were built with Claude (Anthropic) as a coding assistant, working from our concept and direction. The running app uses Gemini for camera verification, screenshot reading and link search.

## Two-minute demo
1. Sign in with GitHub; pick habits; set each one up.
2. Commit the fee and name a partner; show Home with the battery and habit tiles.
3. Open the GitHub card: heat-map, streak and the daily reminder.
4. Add a PDF and read it: the page counter fills, and the Read habit completes at the goal.
5. Check in a camera habit with the code word; show a partner link.
6. Show the leaderboard on Profile and the win rule: the whole fee back, or the fee kept.
