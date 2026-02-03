import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();

  factory NotificationService() {
    return _instance;
  }

  NotificationService._internal();

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    tz.initializeTimeZones();
    try {
      final dynamic timeZoneName = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timeZoneName.toString()));
    } catch (e) {
      print("Timezone error: $e. Using Europe/Istanbul as fallback.");
      try {
        tz.setLocalLocation(tz.getLocation('Europe/Istanbul'));
      } catch (_) {
        tz.setLocalLocation(tz.getLocation('UTC'));
      }
    }

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings(
      requestSoundPermission: true,
      requestBadgePermission: true,
      requestAlertPermission: true,
    );

    const WindowsInitializationSettings initializationSettingsWindows =
        WindowsInitializationSettings(
      appName: 'SantiyePro',
      appUserModelId: 'com.santiyepro.app',
      guid: '7c0c6271-f3fd-2b27-f6ed-39dbd14024aa',
    );

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsDarwin,
      macOS: initializationSettingsDarwin,
      windows: initializationSettingsWindows,
    );

    await flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (details) {
        print("Notification tapped: ${details.payload}");
      },
    );

    final androidPlugin = flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    
    if (androidPlugin != null) {
      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        'hatirlatici_v3',
        'Hatırlatıcı Bildirimleri',
        description: 'Önemli iş ve şantiye hatırlatıcıları',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
        showBadge: true,
      );

      await androidPlugin.createNotificationChannel(channel);
    }
  }

  Future<void> scheduleNotification(
      int id, String title, String body, DateTime scheduledTime) async {
    print("Scheduling notification: $title at $scheduledTime (ID: $id)");
    
    final int safeId = id.abs() % 2147483647;
    final now = tz.TZDateTime.now(tz.local);
    final scheduledTZTime = tz.TZDateTime(
      tz.local,
      scheduledTime.year,
      scheduledTime.month,
      scheduledTime.day,
      scheduledTime.hour,
      scheduledTime.minute,
      scheduledTime.second,
    );

    if (scheduledTZTime.isBefore(now)) {
      print("Warning: Scheduled time is in the past.");
      return;
    }

    try {
      // Trying to fix UILocalNotificationDateInterpretation error.
      // If the enum is not found, maybe strict typing issue?
      // I will trust that import works, but maybe I should try AndroidScheduleMode only first if the other is optional?
      // But docs say required.
      // I will put it back.
      await flutterLocalNotificationsPlugin.zonedSchedule(
        safeId,
        title,
        body,
        scheduledTZTime,
        _notificationDetails(),
        androidScheduleMode: AndroidScheduleMode.alarmClock,
        // uiLocalNotificationDateInterpretation removed as it causes build error
      );
    } catch (e) {
      print("Error scheduling notification: $e");
    }
  }

  Future<void> scheduleTestNotification() async {
    tz.initializeTimeZones();
    final nowTZ = tz.TZDateTime.now(tz.local);
    final testTime1 = nowTZ.add(const Duration(seconds: 15));
    final testTime2 = nowTZ.add(const Duration(minutes: 1));
    
    try {
      await flutterLocalNotificationsPlugin.zonedSchedule(
        888,
        "Hassas Test 1 (15sn)",
        "Uygulama kapalıyken bile gelmeli",
        testTime1,
        _notificationDetails(),
        androidScheduleMode: AndroidScheduleMode.alarmClock,
      );

      await flutterLocalNotificationsPlugin.zonedSchedule(
        889,
        "Hassas Test 2 (1dk)",
        "Uygulama kapalıyken bile gelmeli",
        testTime2,
        _notificationDetails(),
        androidScheduleMode: AndroidScheduleMode.alarmClock,
      );
    } catch (e) {
      print("Test schedule error: $e");
    }
  }

  Future<void> cancelNotification(int id) async {
    await flutterLocalNotificationsPlugin.cancel(id);
  }

  NotificationDetails _notificationDetails() {
    return const NotificationDetails(
      android: AndroidNotificationDetails(
        'hatirlatici_v3',
        'Hatırlatıcı Bildirimleri',
        channelDescription: 'Önemli iş ve şantiye hatırlatıcıları',
        importance: Importance.max,
        priority: Priority.max,
        showWhen: true,
        icon: '@mipmap/ic_launcher',
        fullScreenIntent: true,
        category: AndroidNotificationCategory.alarm,
        visibility: NotificationVisibility.public,
      ),
      iOS: DarwinNotificationDetails(
      ),
    );
  }

  Future<void> showInstantNotification(String title, String body) async {
    await flutterLocalNotificationsPlugin.show(
      999,
      title,
      body,
      _notificationDetails(),
    );
  }
  
  Future<void> requestPermissions() async {
    final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
        flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    if (androidImplementation != null) {
      try {
        await androidImplementation.requestNotificationsPermission();
      } catch (e) {
        print("Notification permission request failed: $e");
      }
    }
  }
}
