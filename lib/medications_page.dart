// medications_page.dart
import 'dart:convert';
import 'package:flutter/foundation.dart'; 
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; 
import 'package:firebase_auth/firebase_auth.dart';    
import 'package:flutter_local_notifications/flutter_local_notifications.dart'; 
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class MedicationsPage extends StatefulWidget {
  const MedicationsPage({super.key});

  @override
  State<MedicationsPage> createState() => _MedicationsPageState();
}

class _MedicationsPageState extends State<MedicationsPage> {
  late MobileScannerController _scannerController;

  final TextEditingController _manualNameController = TextEditingController();
  final TextEditingController _manualDosageController = TextEditingController();
  
  // 📆 Takvim ve Saat Entegrasyonu Değişkenleri
  TimeOfDay? _selectedTime;
  String _selectedOgun = "Sabah"; 

  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();

  @override
  void initState() {
    super.initState();
    _bildirimSisteminiBaslat();
    _scannerController = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
      facing: CameraFacing.back,
    );
  }

  @override
  void dispose() {
    _scannerController.dispose();
    _manualNameController.dispose();
    _manualDosageController.dispose();
    super.dispose();
  }

  // 🔔 Bildirim sistemini başlatan fonksiyon
  Future<void> _bildirimSisteminiBaslat() async {
    tz.initializeTimeZones();
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);
    await _notificationsPlugin.initialize(initializationSettings);
  }

  //  Gerçek Zamanlı Alarm Motoru 
  Future<void> _herGunTekrarlayanIlacAlarmiKur({
    required int id,
    required String ilacAdi,
    required int saat,
    required int dakika,
    required String ogunAdi,
  }) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'vital_ai_health_channel', 
      'Akıllı Sağlık Asistanı Bildirimleri',
      channelDescription: 'Öğün bazlı gerçek zamanlı ilaç hatırlatıcıları',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
    );
    const NotificationDetails notificationDetails = NotificationDetails(android: androidDetails);

    final simdi = tz.TZDateTime.now(tz.local);
    var planlananAn = tz.TZDateTime(tz.local, simdi.year, simdi.month, simdi.day, saat, dakika);
    
    if (planlananAn.isBefore(simdi)) {
      planlananAn = planlananAn.add(const Duration(days: 1));
    }

    await _notificationsPlugin.zonedSchedule(
      id,
      '$ogunAdi İlaç Saati Geldi! 💊', 
      'Gerçek Zamanlı Hatırlatma: $ogunAdi vaktinde almanız gereken "$ilacAdi" ilacının zamanı geldi.', 
      planlananAn,
      notificationDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time, 
    );
  }

  //  Bildirim tetikleyici köprü
  Future<void> _ilacZamanAnaliziVeBildirimKur(String docId, String ilacAdi, int saat, int dakika, String ogun) async {
    int benzersizHashId = docId.hashCode;

    await _herGunTekrarlayanIlacAlarmiKur(
      id: benzersizHashId + (ogun == "Sabah" ? 1 : 3), 
      ilacAdi: ilacAdi,
      saat: saat, 
      dakika: dakika,
      ogunAdi: ogun,
    );
    debugPrint("🔔 $ilacAdi için $ogun ($saat:$dakika) bildirimi kuruldu.");
  }

  // İlaç Silindiğinde Bildirim İptali
  Future<void> _ilacBildirimleriniTemizle(String docId) async {
    int benzersizHashId = docId.hashCode;
    await _notificationsPlugin.cancel(benzersizHashId + 1); 
    await _notificationsPlugin.cancel(benzersizHashId + 3); 
  }

  String _getTargetUid() {
    final currentUser = FirebaseAuth.instance.currentUser;
    return currentUser?.uid ?? "gecici_test_kullanicisi_123";
  }

  Stream<QuerySnapshot> _getMedicationsStream() {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(_getTargetUid())
        .collection('medications')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  // Veritabanına İlaç Ekleme Metodu
  Future<void> _addNewMedication({
    required String name, 
    required String dosage, 
    required int saat, 
    required int dakika, 
    required String ogun
  }) async {
    try {
      final uid = _getTargetUid();
      String zamanMetni = "${saat.toString().padLeft(2, '0')}:${dakika.toString().padLeft(2, '0')} ($ogun)";
      
      final yeniDokuman = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('medications')
          .add({
        'name': name,
        'dosage': dosage,
        'time': zamanMetni,
        'isTaken': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      await _ilacZamanAnaliziVeBildirimKur(yeniDokuman.id, name, saat, dakika, ogun);

      DateTime simdi = DateTime.now();
      DateTime dinamikHedefZamani = DateTime(simdi.year, simdi.month, simdi.day, saat, dakika);

      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('notifications')
          .add({
        'title': '$name Zamanı 💊',
        'body': '$zamanMetni vaktinde almanız gereken $dosage dozunda ilaç listelendi.',
        'ogun': ogun,
        'timestamp': Timestamp.fromDate(dinamikHedefZamani),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("✅ '$name' başarıyla eklendi!"),
          backgroundColor: const Color(0xFF2D6A4F),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("❌ Hata oluştu: $e"),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // İlaç Silme Fonksiyonu
  Future<void> _deleteMedication(String docId) async {
    try {
      await _ilacBildirimleriniTemizle(docId);

      await FirebaseFirestore.instance
          .collection('users')
          .doc(_getTargetUid())
          .collection('medications')
          .doc(docId)
          .delete();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("🗑️ İlaç ve alarmları silindi."),
          backgroundColor: Colors.black87,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      print("İlaç silinemedi: $e");
    }
  }

  Future<void> _processScannedCode(String rawData) async {
    String cleanData = rawData.trim();
    cleanData = cleanData.replaceAll(RegExp(r'[^\x20-\x7E]'), '');

    String parsedGtin = "";
    if (cleanData.startsWith("01") && cleanData.length >= 16) {
      parsedGtin = cleanData.substring(2, 16);
    } else {
      int index01 = cleanData.indexOf("01");
      if (index01 != -1 && cleanData.length >= (index01 + 16)) {
        parsedGtin = cleanData.substring(index01 + 2, index01 + 16);
      } else {
        parsedGtin = cleanData;
      }
    }

    if (parsedGtin.startsWith("0") && parsedGtin.length > 13) {
      parsedGtin = parsedGtin.substring(1);
    }

    _showLoadingDialog();

    try {
      final localDrug = await _searchInLocalJsonDatabase(parsedGtin);
      
      if (mounted) Navigator.pop(context);

      if (localDrug != null) {
        _addNewMedication(
          name: localDrug['Product_Name'] ?? "Bilinmeyen İlaç",
          dosage: localDrug['Active_Ingredient'] ?? "Bilgi Yok",
          saat: 9,
          dakika: 0,
          ogun: "Sabah",
        );
      } else {
        _showBarcodeNotFoundDialog(parsedGtin, "Kayıt bulunamadı.");
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      _showBarcodeNotFoundDialog(parsedGtin, "Veritabanı okuma hatası.");
    }
  }

  Future<Map<String, dynamic>?> _searchInLocalJsonDatabase(String targetBarcode) async {
    final String jsonContent = await rootBundle.loadString('assets/data/ilaclar.json');
    return compute(_findDrugInIsolate, {
      'jsonString': jsonContent,
      'barcode': targetBarcode,
    });
  }

  static Map<String, dynamic>? _findDrugInIsolate(Map<String, String> params) {
    final List<dynamic> rawJsonList = json.decode(params['jsonString']!);
    final String searchBarcode = params['barcode']!.trim();

    List<dynamic> allDrugs = [];
    for (var element in rawJsonList) {
      if (element is Map<String, dynamic> && element.containsKey('data')) {
        allDrugs = element['data'] as List<dynamic>;
        break;
      }
    }

    if (allDrugs.isEmpty) return null;

    String alternativeBarcode = "";
    if (searchBarcode.length == 13) {
      alternativeBarcode = "0$searchBarcode";
    } else if (searchBarcode.length == 14 && searchBarcode.startsWith("0")) {
      alternativeBarcode = searchBarcode.substring(1);
    }

    for (var drug in allDrugs) {
      String currentBarcode = drug['barcode']?.toString().trim() ?? "";
      if (currentBarcode == searchBarcode || 
          (alternativeBarcode.isNotEmpty && currentBarcode == alternativeBarcode)) {
        return drug as Map<String, dynamic>;
      }
    }
    return null;
  }

  void _showLoadingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: Color(0xFF2D6A4F)),
      ),
    );
  }

  void _showBarcodeNotFoundDialog(String barcode, String reason) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("İlaç Tanımlanamadı"),
        content: Text("Manuel eklemek ister misiniz?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("İptal", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2D6A4F)),
            onPressed: () {
              Navigator.pop(context);
              _showManualAddBottomSheet();
            },
            child: const Text("Manuel Ekle", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  //  Düzenlenmiş Bottom Sheet
  void _showManualAddBottomSheet() {
    _manualNameController.clear();
    _manualDosageController.clear();
    setState(() {
      _selectedTime = const TimeOfDay(hour: 9, minute: 0);
      _selectedOgun = "Sabah";
    });

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                top: 20, left: 20, right: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Manuel İlaç Ekle", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF2D6A4F))),
                      IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                    ],
                  ),
                  const SizedBox(height: 15),
                  TextField(
                    controller: _manualNameController,
                    decoration: InputDecoration(
                      labelText: "İlaç Adı",
                      prefixIcon: const Icon(Icons.medication),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _manualDosageController,
                    decoration: InputDecoration(
                      labelText: "Dozaj (Örn: 500 mg)",
                      prefixIcon: const Icon(Icons.shutter_speed),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  const Text("HATIRLATMA SAATİ", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black45)),
                  const SizedBox(height: 6),
                  InkWell(
                    onTap: () async {
                      final TimeOfDay? picked = await showTimePicker(
                        context: context,
                        initialTime: _selectedTime ?? const TimeOfDay(hour: 9, minute: 0),
                      );
                      if (picked != null) {
                        setModalState(() {
                          _selectedTime = picked;
                          if (picked.hour >= 12) {
                            _selectedOgun = "Akşam";
                          } else {
                            _selectedOgun = "Sabah";
                          }
                        });
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade400),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.access_time_filled, color: Color(0xFF2D6A4F)),
                              const SizedBox(width: 10),
                              Text(
                                _selectedTime != null 
                                    ? _selectedTime!.format(context) 
                                    : "Saat Seçiniz",
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          const Icon(Icons.arrow_drop_down, color: Colors.grey),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  const Text("ÖĞÜN ETİKETİ", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black45)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: ChoiceChip(
                          label: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [Icon(Icons.wb_sunny, size: 18), SizedBox(width: 5), Text("Sabah")],
                          ),
                          selected: _selectedOgun == "Sabah",
                          selectedColor: Colors.orange.shade100,
                          checkmarkColor: Colors.orange,
                          labelStyle: TextStyle(color: _selectedOgun == "Sabah" ? Colors.orange.shade900 : Colors.black),
                          onSelected: (bool selected) {
                            if (selected) setModalState(() => _selectedOgun = "Sabah");
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ChoiceChip(
                          label: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [Icon(Icons.nights_stay, size: 18), SizedBox(width: 5), Text("Akşam")],
                          ),
                          selected: _selectedOgun == "Akşam",
                          selectedColor: const Color(0xFFE8F5E9),
                          checkmarkColor: const Color(0xFF2D6A4F),
                          labelStyle: TextStyle(color: _selectedOgun == "Akşam" ? const Color(0xFF2D6A4F) : Colors.black),
                          onSelected: (bool selected) {
                            if (selected) setModalState(() => _selectedOgun = "Akşam");
                          },
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 25),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2D6A4F),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      ),
                      onPressed: () {
                        if (_manualNameController.text.trim().isNotEmpty) {
                          _addNewMedication(
                            name: _manualNameController.text.trim(),
                            dosage: _manualDosageController.text.trim().isEmpty ? "1 Kutu" : _manualDosageController.text.trim(),
                            saat: _selectedTime?.hour ?? 9,
                            dakika: _selectedTime?.minute ?? 0,
                            ogun: _selectedOgun,
                          );
                          Navigator.pop(context);
                        }
                      },
                      child: const Text("Listeye Ekle", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _startCameraScanner() async {
    _scannerController.start();

    final String? scannedCode = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(
            title: const Text('Kodu Hizalayın', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            backgroundColor: const Color(0xFF2D6A4F),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          body: MobileScanner(
            controller: _scannerController,
            onDetect: (capture) {
              final List<Barcode> barcodes = capture.barcodes;
              for (final barcode in barcodes) {
                if (barcode.rawValue != null) {
                  Navigator.pop(context, barcode.rawValue);
                  break;
                }
              }
            },
          ),
        ),
      ),
    );

    _scannerController.stop();

    if (scannedCode != null) {
      _processScannedCode(scannedCode);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F7),
      appBar: AppBar(
        title: const Text("İlaçlarım", style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.black,
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _getMedicationsStream(),
              builder: (context, snapshot) {
                // Listede dinamik widget'lar (StreamBuilder) olduğu için ana listenin başından 'const' kaldırıldı
                return ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    InkWell(
                      onTap: _startCameraScanner,
                      borderRadius: BorderRadius.circular(30),
                      child: Container(
                        height: 220,
                        decoration: BoxDecoration(
                          color: const Color(0xFF2D6A4F),
                          borderRadius: BorderRadius.circular(30),
                          boxShadow: [
                            BoxShadow(color: const Color(0xFF2D6A4F).withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 8)),
                          ],
                        ),
                        child: const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.camera_alt, size: 80, color: Colors.white),
                            SizedBox(height: 10), 
                            Text("Kamerayı Aç ve Tara", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                            Text("Sağlık Bakanlığı Onaylı Ulusal Veri Seti", style: TextStyle(color: Colors.white60, fontSize: 13)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: _showManualAddBottomSheet,
                      icon: const Icon(Icons.add, color: Color(0xFF2D6A4F)),
                      label: const Text("Dilerseniz Kendiniz Manuel Ekleyin", style: TextStyle(color: Color(0xFF2D6A4F), fontWeight: FontWeight.bold)),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: const BorderSide(color: Color(0xFF2D6A4F), width: 1.5),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      ),
                    ),
                    const SizedBox(height: 30),
                    const Text("KAYITLI İLAÇLARINIZ", style: TextStyle(color: Colors.black45, fontWeight: FontWeight.bold, fontSize: 12)),
                    const SizedBox(height: 12),
                    
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(40.0),
                          child: Text(
                            "Henüz bir ilaç eklenmedi. Kutuyu taratın.", 
                            style: TextStyle(color: Colors.black38, fontSize: 16, fontWeight: FontWeight.w500), // FontWeight.medium yerine FontWeight.w500 yapıldı
                          ),
                        ),
                      )
                    else
                      ...snapshot.data!.docs.map((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        final String docId = doc.id;
                        final String name = data['name'] ?? '';
                        final String dosage = data['dosage'] ?? '';
                        final String time = data['time'] ?? '';

                        String subtitleText = dosage;
                        if (time.isNotEmpty) {
                          subtitleText += subtitleText.isNotEmpty ? " • $time" : time;
                        }

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(color: const Color(0xFFE9F5E9), borderRadius: BorderRadius.circular(20)),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                            leading: const Icon(Icons.medication, color: Color(0xFF2D6A4F), size: 30),
                            title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text(subtitleText),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.black38),
                              onPressed: () => _deleteMedication(docId),
                            ),
                          ),
                        );
                      }),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}