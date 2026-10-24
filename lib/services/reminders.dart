import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Daily "push a commit" reminder, scheduled on the phone (no server).
class Reminders {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _ready = false;
  static const _key = 'gh_remind';
  static const _id = 7001;

  static Future<void> _ensure() async {
    if (_ready) return;
    tzdata.initializeTimeZones();
    await _plugin.initialize(const InitializationSettings(
      iOS: DarwinInitializationSettings(
          requestAlertPermission: false, requestBadgePermission: false, requestSoundPermission: false),
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    ));
    _ready = true;
  }

  /// Saved reminder time as "HH:mm", or null when off.
  static Future<String?> saved() async {
    try {
      return (await SharedPreferences.getInstance()).getString(_key);
    } catch (_) {
      return null;
    }
  }

  /// Turns the reminder on at [hhmm]. Returns false if notifications are not allowed.
  static Future<bool> enable(String hhmm, String user) async {
    if (kIsWeb) return false;
    try {
      await _ensure();
      final ios = _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
      final okIos = await ios?.requestPermissions(alert: true, sound: true);
      final and = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      final okAnd = await and?.requestNotificationsPermission();
      if (okIos == false || okAnd == false) return false;
      final p = hhmm.split(':');
      final now = DateTime.now();
      var at = DateTime(now.year, now.month, now.day, int.parse(p[0]), int.parse(p[1]));
      if (!at.isAfter(now)) at = at.add(const Duration(days: 1));
      // Scheduled as the same instant in UTC; repeats daily at that time.
      final when = tz.TZDateTime.from(at.toUtc(), tz.UTC);
      await _plugin.zonedSchedule(
        _id,
        'Time to push a commit',
        'Ship something small today, @$user. Keep the streak alive.',
        when,
        const NotificationDetails(
          iOS: DarwinNotificationDetails(),
          android: AndroidNotificationDetails('gh_daily', 'Daily commit reminder', importance: Importance.high),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
      );
      await (await SharedPreferences.getInstance()).setString(_key, hhmm);
      return true;
    } catch (e) {
      debugPrint('Reminder failed: $e');
      return false;
    }
  }

  static Future<void> disable() async {
    try {
      await _ensure();
      await _plugin.cancel(_id);
      await (await SharedPreferences.getInstance()).remove(_key);
    } catch (_) {}
  }
}
