// notification_service.dart
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();

  // Servisi başlatma fonksiyonu 
  Future<void> initNotification() async {
    tz.initializeTimeZones(); // Zaman dilimlerini başlatıyoruz
    
    const AndroidInitializationSettings androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notificationsPlugin.initialize(initSettings);
  }

  // 1. İLAÇ İÇİN TEKRARLAYAN BİLDİRİM AYARLAMA
  Future<void> scheduleMedicationNotification({
    required int id,
    required String title,
    required String body,
    required int hour,
    required int minute,
  }) async {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduledDate = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    
    // Eğer saat geçtiyse yarına planla
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    await _notificationsPlugin.zonedSchedule(
      id,
      title,
      body,
      scheduledDate,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'medication_channel', 'İlaç Hatırlatıcıları',
          channelDescription: 'İlaç saatleriniz için bildirimler',
          importance: Importance.max,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.exact, 
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time, // Her gün aynı saatte tekrarlar
    );
  }

  // 2. RANDEVU İÇİN TEK SEFERLİK BİLDİRİM AYARLAMA
  Future<void> scheduleAppointmentNotification({
    required int id,
    required String title,
    required String body,
    required DateTime appointmentDateTime,
  }) async {
    // Randevudan 1 saat önce bildirim gitsin
    final scheduledTime = tz.TZDateTime.from(
      appointmentDateTime.subtract(const Duration(hours: 1)), 
      tz.local,
    );

    if (scheduledTime.isBefore(tz.TZDateTime.now(tz.local))) return;

    await _notificationsPlugin.zonedSchedule(
      id,
      title,
      body,
      scheduledTime,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'appointment_channel', 'Randevu Hatırlatıcıları',
          channelDescription: 'Yaklaşan hastane randevularınız için bildirimler',
          importance: Importance.max,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.exact, 
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  // TEK BİR BİLDİRİMİ İPTAL ETME (Kullanıcı ilacı veya randevuyu sildiğinde çağrılır)
  Future<void> cancelNotification(int id) async {
    await _notificationsPlugin.cancel(id);
    debugPrint("🔔 [NotificationService] ID'si $id olan yerel alarm başarıyla iptal edildi.");
  }

  // TÜM YEREL ALARMLARI/BİLDİRİMLERİ TEK TIKLA TEMİZLEME
  Future<void> cancelAllNotifications() async {
    await _notificationsPlugin.cancelAll();
    debugPrint("✨ [NotificationService] Telefondaki tüm ileri tarihli ilaç ve randevu alarmları sıfırlandı.");
  }
}