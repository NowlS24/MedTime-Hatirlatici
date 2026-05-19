// appointments_page.dart
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

// DİNAMİK RANDEVU VERİ MODELİ
class LiveAppointment {
  final String title;
  final String subTitle;
  final String dateStr;
  final DateTime? rawDateTime; // Bildirim hesabı için ham tarih
  final Color statusColor;

  LiveAppointment({
    required this.title,
    required this.subTitle,
    required this.dateStr,
    this.rawDateTime,
    required this.statusColor,
  });
}

class AppointmentsPage extends StatefulWidget {
  const AppointmentsPage({super.key});

  @override
  State<AppointmentsPage> createState() => _AppointmentsPageState();
}

// KALICI HAFIZA KÖPRÜSÜ
List<LiveAppointment>? _persistedAppointments;
String _persistedSyncText = "Son güncelleme: Henüz yapılmadı";

class _AppointmentsPageState extends State<AppointmentsPage> {
  bool _isLoading = false;
  List<LiveAppointment> _currentAppointments = [];
  
  // Bildirim yöneticisi nesnemiz
  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();

  @override
  void initState() {
    super.initState();
    _bildirimleriHazirla();
    
    if (_persistedAppointments != null) {
      _currentAppointments = _persistedAppointments!;
    } else {
      _currentAppointments = _gosterilecekBosDurum();
    }
  }

  // Bildirim kütüphanesini ilk açılışta ayağa kaldıran fonksiyon
  Future<void> _bildirimleriHazirla() async {
    tz.initializeTimeZones(); // Saat dilimlerini eşitle
    
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
        
    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);
        
    await _notificationsPlugin.initialize(initializationSettings);
  }

  //   Randevu saatine göre tetikleyicileri kurar
  Future<void> _randevuBildirimleriniPlanla(String hekimAdi, DateTime randevuZamani, int uniqueId) async {
    final now = DateTime.now();
    if (randevuZamani.isBefore(now)) return; // Geçmiş randevuya bildirim kurma 

    // Bildirim detay ayarları (Android için)
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'medtime_mhairs_channel',
      'MHRS Randevu Hatırlatıcıları',
      channelDescription: 'Randevulara kalan süreyi hatırlatır.',
      importance: Importance.max,
      priority: Priority.high,
    );
    const NotificationDetails notificationDetails = NotificationDetails(android: androidDetails);

    // 1. Kural: 5 Gün Kala Bildirimi
    final besGunOnce = randevuZamani.subtract(const Duration(days: 5));
    if (besGunOnce.isAfter(now)) {
      await _notificationsPlugin.zonedSchedule(
        uniqueId + 5000,
        'MHRS Randevu Hatırlatması 🗓️',
        '$hekimAdi randevunuza 5 gün kaldı. Sakın unutmayın!',
        tz.TZDateTime.from(besGunOnce, tz.local),
        notificationDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      );
    }

    // 2. Kural: 1 Gün Kala Bildirimi
    final birGunOnce = randevuZamani.subtract(const Duration(days: 1));
    if (birGunOnce.isAfter(now)) {
      await _notificationsPlugin.zonedSchedule(
        uniqueId + 1000,
        'Yarın Randevunuz Var! 🏥',
        'Yarın $hekimAdi randevunuz bulunuyor. Kontrol etmeyi unutmayın.',
        tz.TZDateTime.from(birGunOnce, tz.local),
        notificationDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      );
    }

    // 3. Kural: 1 Saat Kala Bildirimi
    final birSaatOnce = randevuZamani.subtract(const Duration(hours: 1));
    if (birSaatOnce.isAfter(now)) {
      await _notificationsPlugin.zonedSchedule(
        uniqueId + 100,
        'Randevuya Son 1 Saat! ⏳',
        '1 saat sonra $hekimAdi randevunuz başlıyor. Hazırlık yapmayı unutmayın.',
        tz.TZDateTime.from(birSaatOnce, tz.local),
        notificationDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      );
    }
  }

  Future<void> _mhrsRandevulariniGetir() async {
    setState(() {
      _isLoading = true;
    });

    final dio = Dio();
    const String n8nWebhookUrl = 'https://medtimeilac.app.n8n.cloud/webhook-test/mhrs-aktif-randevular';

    try {
      final response = await dio.post(n8nWebhookUrl);

      if (response.statusCode == 200 && response.data != null) {
        final List<dynamic> gelenRandevular = response.data['randevular'] ?? [];
        
        List<LiveAppointment> yeniListe = [];
        int idSayac = 0;

        await _notificationsPlugin.cancelAll();

        for (var item in gelenRandevular) {
          final String hamTarihStr = item['randevuZamani'] ?? "";
          DateTime? ayrisanTarih;
          try {
            ayrisanTarih = DateTime.parse(hamTarihStr);
          } catch (_) {}

          final String doktorUnvanliAd = item['hekim']?['ad'] != null 
              ? "Dr. ${item['hekim']['ad']} ${item['hekim']['soyad']}"
              : "MHRS Randevusu";

          yeniListe.add(
            LiveAppointment(
              title: doktorUnvanliAd,
              subTitle: "${item['klinik']?['ad'] ?? 'Poliklinik'} • ${item['kurum']?['ad'] ?? 'Devlet Hastanesi'}",
              dateStr: _mhrsTarihFormatla(hamTarihStr),
              rawDateTime: ayrisanTarih,
              statusColor: const Color(0xFF2D6A4F), 
            ),
          );

          // Tarihte sorun yoksa otomatik bildirim döngüsü tetiklenecek
          if (ayrisanTarih != null) {
            idSayac++;
            _randevuBildirimleriniPlanla(doktorUnvanliAd, ayrisanTarih, idSayac * 10);
          }
        }

        final now = DateTime.now();
        final minuteStr = now.minute < 10 ? "0${now.minute}" : "${now.minute}";
        final hourStr = now.hour < 10 ? "0${now.hour}" : "${now.hour}";

        setState(() {
          _currentAppointments = yeniListe.isEmpty ? _gosterilecekBosDurum() : yeniListe;
          _persistedSyncText = "Son güncelleme: Bugün $hourStr:$minuteStr";
          _persistedAppointments = _currentAppointments; 
          _isLoading = false;
        });

      } else {
        _hataDurumuGoster("Sunucu hatası: ${response.statusCode}");
      }
    } catch (e) {
      _hataDurumuGoster("Bağlantı hatası oluştu");
      debugPrint("Bağlantı Hatası Detayı: $e");
    }
  }

  String _mhrsTarihFormatla(String hamTarih) {
    if (hamTarih.isEmpty) return "Belirsiz Tarih";
    try {
      DateTime parsed = DateTime.parse(hamTarih);
      List<String> aylar = ["Oca", "Şub", "Mar", "Nis", "May", "Haz", "Tem", "Ağu", "Eyl", "Eki", "Kas", "Ara"];
      String gun = parsed.day.toString();
      String ay = aylar[parsed.month - 1];
      String saat = parsed.hour < 10 ? "0${parsed.hour}" : "${parsed.hour}";
      String dakika = parsed.minute < 10 ? "0${parsed.minute}" : "${parsed.minute}";
      return "$gun $ay • $saat:$dakika";
    } catch (_) {
      return hamTarih;
    }
  }

  List<LiveAppointment> _gosterilecekBosDurum() {
    return [
      LiveAppointment(
        title: "Aktif Randevunuz Bulunmuyor",
        subTitle: "Yaklaşan bir randevu kaydı getirmek için lütfen güncelleyin.",
        dateStr: "Bilgi",
        statusColor: Colors.grey,
      )
    ];
  }

  void _hataDurumuGoster(String mesaj) {
    setState(() {
      _isLoading = false;
      _persistedSyncText = mesaj;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFBFBF9),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        toolbarHeight: 80,
        title: const Text(
          "Randevular",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 28),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                ElevatedButton.icon(
                  onPressed: _isLoading ? null : _mhrsRandevulariniGetir,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD32F2F), 
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                    minimumSize: const Size(0, 32),
                  ),
                  icon: _isLoading
                      ? const SizedBox(
                          height: 12,
                          width: 12,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 1.5),
                        )
                      : const Icon(Icons.autorenew_rounded, size: 14), 
                  label: Text(
                    _isLoading ? "Çekiliyor..." : "Randevuları Güncelle", 
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _persistedSyncText,
                  style: const TextStyle(color: Colors.black38, fontSize: 10, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 10),
            _buildCalendarCard(),

            const SizedBox(height: 32),
            const Text(
              "YAKLAŞAN RANDEVULAR",
              style: TextStyle(color: Colors.black45, fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 1.1),
            ),
            const SizedBox(height: 16),

            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _currentAppointments.length,
              itemBuilder: (context, index) {
                final appointment = _currentAppointments[index];
                return _buildAppointmentTile(
                  appointment.title,
                  appointment.subTitle,
                  appointment.dateStr,
                  appointment.statusColor,
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCalendarCard() {
    final days = ["Pt", "Sa", "Ça", "Pe", "Cu", "Ct", "Pz"];
    
    // Telefonun o anki canlı zaman bilgilerini çekiyoruz.
    final now = DateTime.now();
    final currentDay = now.day;
    final currentYear = now.year;
    
    List<String> aylar = [
      "Ocak", "Şubat", "Mart", "Nisan", "Mayıs", "Haziran", 
      "Temmuz", "Ağustos", "Eylül", "Ekim", "Kasım", "Aralık"
    ];
    String currentMonthStr = aylar[now.month - 1];

    // Ayın kaç çektiğini dinamik buluyoruz 
    final totalDaysInMonth = DateUtils.getDaysInMonth(currentYear, now.month);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 20, offset: const Offset(0, 10))],
      ),
      child: Column(
        children: [
          // Başlık artık tamamen dinamik
          Text("$currentMonthStr $currentYear", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: days.map((day) => Text(day, style: const TextStyle(color: Colors.black38, fontWeight: FontWeight.w500))).toList(),
          ),
          const SizedBox(height: 16),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: totalDaysInMonth, 
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7),
            itemBuilder: (context, index) {
              int day = index + 1;
              
              // Telefonun canlı günü neyse o parlayacak
              bool isSelected = day == currentDay; 
              
              return Center(
                child: Container(
                  width: 35,
                  height: 35,
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFF2D6A4F) : Colors.transparent,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      "$day", 
                      style: TextStyle(
                        color: isSelected ? Colors.white : Colors.black87, 
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAppointmentTile(String name, String detail, String time, Color sideColor) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(width: 3, height: 50, decoration: BoxDecoration(color: sideColor, borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(time, style: TextStyle(color: sideColor, fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 4),
                Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18), overflow: TextOverflow.ellipsis),
                Text(detail, style: const TextStyle(color: Colors.black45, fontSize: 14), overflow: TextOverflow.ellipsis, maxLines: 2),
              ],
            ),
          ),
        ],
      ),
    );
  }
}