import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import '../models/client_task.dart';

class AlarmService {
  AlarmService._();
  static final AlarmService instance = AlarmService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  final FlutterTts _tts = FlutterTts();
  Timer? _voiceLoopTimer;

  // Bumped channel ID so Android creates a fresh MAX-volume Alarm channel
  static const String _channelId = 'agency_78_loud_alarm_v2';
  static const String _channelName = '78 Agency Loud Alarms';
  static const String _channelDesc =
      'Loud insistent lock-screen alarms for 78 Agency client tasks';

  Future<void> init({
    required void Function(String? taskId) onNotificationTap,
  }) async {
    tz.initializeTimeZones();
    tz.setLocalLocation(tz.UTC);

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidInit,
      iOS: iosInit,
    );

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        onNotificationTap(response.payload);
      },
    );

    await requestPermissions();
  }

  Future<void> requestPermissions() async {
    final androidImpl = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (androidImpl != null) {
      await androidImpl.requestNotificationsPermission();
      await androidImpl.requestExactAlarmsPermission();
    }

    final iosImpl = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    if (iosImpl != null) {
      await iosImpl.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
    }
  }

  NotificationDetails _alarmNotificationDetails() {
    // FLAG_INSISTENT (4) loops the loud tun_tun_alarm.wav continuously on lock screen until tapped!
    final androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDesc,
      importance: Importance.max,
      priority: Priority.max,
      fullScreenIntent: true,
      category: AndroidNotificationCategory.alarm,
      audioAttributesUsage: AudioAttributesUsage.alarm,
      sound: const RawResourceAndroidNotificationSound('tun_tun_alarm'),
      playSound: true,
      enableVibration: true,
      additionalFlags: Int32List.fromList(<int>[4]),
      visibility: NotificationVisibility.public,
      ticker: '78 Agency Alarm — Kaam karna hai!',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      interruptionLevel: InterruptionLevel.timeSensitive,
    );

    return NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );
  }

  Future<void> speakAlarmVoice(String clientName, {bool isRomanUrdu = true}) async {
    await _tts.setVolume(1.0);
    await _tts.setLanguage(isRomanUrdu ? 'ur-PK' : 'en-US');
    await _tts.setSpeechRate(0.46);
    await _tts.setPitch(1.08);
    final msg = isRomanUrdu
        ? 'Kaam karna hai! $clientName ke kaam ka time ho gaya hai! Uthiye aur kaam karein!'
        : 'Time to work! $clientName task is due right now!';
    await _tts.speak(msg);
  }

  void startLoudVoiceLoop(String clientName, {bool isRomanUrdu = true}) {
    stopVoice();
    speakAlarmVoice(clientName, isRomanUrdu: isRomanUrdu);
    _voiceLoopTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      speakAlarmVoice(clientName, isRomanUrdu: isRomanUrdu);
    });
  }

  Future<void> stopVoice() async {
    _voiceLoopTimer?.cancel();
    _voiceLoopTimer = null;
    await _tts.stop();
  }

  Future<void> scheduleTaskAlarm(ClientTask task) async {
    if (task.completed) return;
    if (task.scheduledAt.isBefore(DateTime.now())) return;

    final tzTime = tz.TZDateTime.from(task.scheduledAt.toUtc(), tz.UTC);

    try {
      await _plugin.zonedSchedule(
        task.notificationId,
        '⏰ ${task.clientName} — Kaam karna hai!',
        task.title,
        tzTime,
        _alarmNotificationDetails(),
        androidScheduleMode: AndroidScheduleMode.alarmClock,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: task.id,
      );
    } catch (_) {
      await _plugin.zonedSchedule(
        task.notificationId,
        '⏰ ${task.clientName} — Kaam karna hai!',
        task.title,
        tzTime,
        _alarmNotificationDetails(),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: task.id,
      );
    }
  }

  Future<void> triggerTestAlarm() async {
    await speakAlarmVoice('Client', isRomanUrdu: true);
    await _plugin.show(
      999999,
      '⏰ 78 Agency Alarm — Kaam karna hai!',
      'Tun-tun alarm lock screen par bhi zor se bajega!',
      _alarmNotificationDetails(),
      payload: 'test_alarm',
    );
  }

  Future<void> cancelTaskAlarm(int notificationId) async {
    await _plugin.cancel(notificationId);
  }
}
