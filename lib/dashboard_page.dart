// dashboard_page.dart
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http; 
import 'dart:convert'; 
import 'package:cloud_firestore/cloud_firestore.dart'; 
import 'package:firebase_auth/firebase_auth.dart'; 
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

class HomeMedication {
  final String id; 
  final String name;
  final String time;
  final String dosage;
  final bool isTaken;

  HomeMedication({
    required this.id,
    required this.name,
    required this.time,
    required this.dosage,
    required this.isTaken,
  });

  factory HomeMedication.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return HomeMedication(
      id: doc.id,
      name: data['name'] ?? '',
      time: data['time'] ?? '',
      dosage: data['dosage'] ?? '',
      isTaken: data['isTaken'] ?? false,
    );
  }
}

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  List<dynamic> _pharmacies = [];
  bool _isPharmacyLoading = true;
  String _currentDistrict = ""; 
  
  late Stream<DocumentSnapshot> _userStream;
  late Stream<QuerySnapshot> _medicationsStream;

  String _getTargetUid() {
    final currentUser = FirebaseAuth.instance.currentUser;
    return currentUser?.uid ?? "gecici_test_kullanicisi_123";
  }

  @override
  void initState() {
    super.initState();
    final uid = _getTargetUid();
    _userStream = FirebaseFirestore.instance.collection('users').doc(uid).snapshots();
    _medicationsStream = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('medications')
        .orderBy('time')
        .snapshots();

    _determineCityAndFetchPharmacies(); 
  }

  Future<void> _determineCityAndFetchPharmacies() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _setDefaultLocation();
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _setDefaultLocation();
        return;
      }
    }
    
    if (permission == LocationPermission.deniedForever) {
      _setDefaultLocation();
      return;
    } 

    try {
      Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.low);

      List<Placemark> placemarks = await placemarkFromCoordinates(
          position.latitude, position.longitude);
      
      if (placemarks.isEmpty) {
        _setDefaultLocation();
        return;
      }

      Placemark place = placemarks.first;
      String? cityName = place.administrativeArea;
      String? districtName = place.subAdministrativeArea; 

      String detectedDistrict = "Merkez";
      if (districtName != null && districtName.isNotEmpty) {
        String cleanedDistrict = districtName.trim();
        if (!cleanedDistrict.toLowerCase().contains("merkez")) {
          detectedDistrict = cleanedDistrict;
        }
      }

      if (mounted) {
        setState(() {
          _currentDistrict = detectedDistrict;
        });
      }

      if (cityName != null && cityName.isNotEmpty) {
        cityName = cityName
            .replaceAll('İ', 'I')
            .replaceAll('ı', 'i')
            .replaceAll('ü', 'u')
            .replaceAll('Ü', 'U')
            .replaceAll('ç', 'c')
            .replaceAll('Ç', 'C')
            .replaceAll('ş', 's')
            .replaceAll('Ş', 'S')
            .replaceAll('ğ', 'g')
            .replaceAll('Ğ', 'G');
        
        cityName = cityName.split(' ').first;
        await _fetchPharmaciesByCity(cityName);
      } else {
        await _fetchPharmaciesByCity("Bilecik");
      }
    } catch (e) {
      _setDefaultLocation();
    }
  }

  void _setDefaultLocation() async {
    if (mounted) {
      setState(() { _currentDistrict = "Merkez"; });
    }
    await _fetchPharmaciesByCity("Bilecik");
  }

  Future<void> _fetchPharmaciesByCity(String city) async {
    if (!mounted) return;
    setState(() { _isPharmacyLoading = true; });

    const String apiKey = "5HtGHb6fge04Wlx9DrhpFA:27lakj573WxzTVf28Dwtox"; 
    final String url = "https://api.collectapi.com/health/dutyPharmacy?il=$city";

    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {
          "content-type": "application/json",
          "authorization": "apikey $apiKey"
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> allPharmacies = data['result'] ?? [];

        List<dynamic> userDistrictPharmacies = [];
        List<dynamic> otherPharmacies = [];

        for (var pharmacy in allPharmacies) {
          String pharmacyDist = pharmacy['dist']?.toString().toLowerCase() ?? '';
          String targetDistrict = _currentDistrict.toLowerCase();

          bool isMatch = false;
          if (targetDistrict == "merkez") {
            isMatch = (pharmacyDist == "merkez" || pharmacyDist.contains("bilecik merkez"));
          } else {
            isMatch = pharmacyDist.contains(targetDistrict);
          }

          if (isMatch) {
            userDistrictPharmacies.add(pharmacy);
          } else {
            otherPharmacies.add(pharmacy);
          }
        }

        if (mounted) {
          setState(() {
            _pharmacies = [...userDistrictPharmacies, ...otherPharmacies];
            _isPharmacyLoading = false;
          });
        }
      } else {
        if (mounted) setState(() { _isPharmacyLoading = false; });
      }
    } catch (e) {
      if (mounted) setState(() { _isPharmacyLoading = false; });
    }
  }

  Future<void> _updateMedicationStatus(String docId, bool currentStatus) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(_getTargetUid())
          .collection('medications')
          .doc(docId)
          .update({'isTaken': !currentStatus});

      if (!mounted) return;    
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(currentStatus ? "İlaç alınmadı olarak işaretlendi." : "Harika! İlacınızı aldınız."),
          duration: const Duration(seconds: 2),
          backgroundColor: const Color(0xFF2D6A4F),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Durum güncellenirken bir hata oluştu.")),
      );
    }
  }

  String _getGreetingMessage() {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 12) return "Günaydın";
    if (hour >= 12 && hour < 18) return "Merhaba";
    if (hour >= 18 && hour < 22) return "İyi Akşamlar";
    return "İyi Geceler";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFBFBF9),
      body: SafeArea(
        child: StreamBuilder<DocumentSnapshot>(
          stream: _userStream,
          builder: (context, userSnapshot) {
            String userName = "MedTime Üyesi";
            if (userSnapshot.hasData && userSnapshot.data!.exists) {
              final userData = userSnapshot.data!.data() as Map<String, dynamic>?;
              if (userData != null) {
                userName = userData['name'] ?? "Kullanıcı";
              }
            }

            return StreamBuilder<QuerySnapshot>(
              stream: _medicationsStream,
              builder: (context, medSnapshot) {
                List<HomeMedication> todaysMedications = [];
                HomeMedication? nextMedication;

                if (medSnapshot.hasData) {
                  todaysMedications = medSnapshot.data!.docs
                      .map((doc) => HomeMedication.fromFirestore(doc))
                      .toList();

                  try {
                    nextMedication = todaysMedications.firstWhere((med) => !med.isTaken);
                  } catch (e) {
                    nextMedication = null;
                  }
                }

                return CustomScrollView(
                  physics: const BouncingScrollPhysics(),
                  slivers: [
                    SliverPadding(
                      padding: const EdgeInsets.all(24.0),
                      sliver: SliverList(
                        delegate: SliverChildListDelegate([
                          // --- ÜST KARŞILAMA ALANI ---
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "${_getGreetingMessage()},", 
                                    style: const TextStyle(fontSize: 16, color: Colors.black45, fontWeight: FontWeight.w500),
                                  ),
                                  const SizedBox(height: 4), 
                                  Text(
                                    "$userName 👋", 
                                    style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Colors.black87),
                                  ),
                                ],
                              ),
                              Container(
                                width: 48,
                                height: 48,
                                decoration: const BoxDecoration(color: Color(0xFF2D6A4F), shape: BoxShape.circle),
                                child: const Icon(Icons.person, color: Colors.white),
                              ),
                            ],
                          ),
                          const SizedBox(height: 32),

                          // --- SIRADEKİ İLAÇ KARTI ---
                          const Text(
                            "SIRADAKİ İLACINIZ",
                            style: TextStyle(color: Colors.black45, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1.1),
                          ),
                          const SizedBox(height: 12),
                          nextMedication == null
                              ? Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(24),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(24),
                                    border: Border.all(color: Colors.grey.shade200),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.check_circle_outline, color: const Color(0xFF2D6A4F).withAlpha(180), size: 28),
                                      const SizedBox(width: 14),
                                      const Expanded(
                                        child: Text(
                                          "Harika! Şu an almanız gereken bekleyen bir ilaç yok.",
                                          style: TextStyle(color: Colors.black54, fontSize: 14, fontWeight: FontWeight.w500),
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              : Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(24),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF2D6A4F),
                                    borderRadius: BorderRadius.circular(28),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFF2D6A4F).withOpacity(0.2), 
                                        blurRadius: 15, 
                                        offset: const Offset(0, 8),
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: Text(
                                              nextMedication.name,
                                              style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                            decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
                                            child: Text(
                                              nextMedication.time,
                                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        nextMedication.dosage,
                                        style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 15),
                                      ),
                                      const SizedBox(height: 20),
                                      ElevatedButton(
                                        onPressed: () => _updateMedicationStatus(nextMedication!.id, nextMedication.isTaken),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.white,
                                          foregroundColor: const Color(0xFF2D6A4F),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                          minimumSize: const Size(double.infinity, 50),
                                          elevation: 0,
                                        ),
                                        child: const Text("İçtim Olarak İşaretle", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                      ),
                                    ],
                                  ),
                                ),

                          const SizedBox(height: 32),

                          // --- NÖBETÇİ ECZANELER BÖLÜMÜ ---
                          Text(
                            "NÖBETÇİ ECZANELER ${_currentDistrict.isNotEmpty ? '($_currentDistrict)' : ''}",
                            style: const TextStyle(color: Colors.black45, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1.1),
                          ),
                          const SizedBox(height: 12),
                          _isPharmacyLoading
                              ? const Center(
                                  child: Padding(
                                    padding: EdgeInsets.all(24.0),
                                    child: CircularProgressIndicator(color: Color(0xFF2D6A4F)),
                                  ),
                                )
                              : _pharmacies.isEmpty
                                  ? const Text("Nöbetçi eczane verisi bulunamadı.")
                                  : SizedBox(
                                      height: 140,
                                      child: ListView.builder(
                                        scrollDirection: Axis.horizontal,
                                        physics: const BouncingScrollPhysics(),
                                        itemCount: _pharmacies.length,
                                        itemBuilder: (context, index) {
                                          final pharmacy = _pharmacies[index];
                                          String pharmacyDist = pharmacy['dist']?.toString().toLowerCase() ?? '';
                                          String targetDistrict = _currentDistrict.toLowerCase();
                                          
                                          bool isMyDistrict = false;
                                          if (targetDistrict == "merkez") {
                                            isMyDistrict = (pharmacyDist == "merkez" || pharmacyDist.contains("bilecik merkez"));
                                          } else {
                                            isMyDistrict = pharmacyDist.contains(targetDistrict);
                                          }

                                          return Container(
                                            width: 280,
                                            margin: const EdgeInsets.only(right: 14, bottom: 4),
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius: BorderRadius.circular(24),
                                              border: Border.all(
                                                color: isMyDistrict ? const Color(0xFF2D6A4F).withOpacity(0.4) : Colors.grey.shade200,
                                                width: isMyDistrict ? 1.5 : 1,
                                              ),
                                              boxShadow: [
                                                BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 4)),
                                              ],
                                            ),
                                            child: Padding(
                                              padding: const EdgeInsets.all(20.0),
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: [
                                                  Row(
                                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                    children: [
                                                      Expanded(
                                                        child: Text(
                                                          pharmacy['name'] ?? 'Eczane',
                                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87),
                                                          overflow: TextOverflow.ellipsis,
                                                        ),
                                                      ),
                                                      Icon(
                                                        Icons.local_hospital, 
                                                        color: isMyDistrict ? const Color(0xFF2D6A4F) : Colors.redAccent, 
                                                        size: 18,
                                                      ),
                                                    ],
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    pharmacy['dist'] != null ? "${pharmacy['dist']} Bölgesi" : 'Bölge bilinmiyor', 
                                                    style: const TextStyle(color: Colors.grey, fontSize: 13),
                                                  ),
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    pharmacy['address'] ?? 'Adres bilgisi yok', 
                                                    style: const TextStyle(color: Colors.black54, fontSize: 13), 
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                  const SizedBox(height: 6),
                                                  Row(
                                                    children: [
                                                      const Icon(Icons.phone, size: 14, color: Color(0xFF2D6A4F)),
                                                      const SizedBox(width: 4),
                                                      Text(
                                                        pharmacy['phone'] ?? 'Telefon yok', 
                                                        style: const TextStyle(color: Color(0xFF2D6A4F), fontSize: 12, fontWeight: FontWeight.w600),
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                          const SizedBox(height: 32),

                          // --- BUGÜNKÜ İLAÇ PROGRAMI BAŞLIĞI ---
                          const Text(
                            "BUGÜNKÜ İLAÇ PROGRAMINIZ",
                            style: TextStyle(color: Colors.black45, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1.1),
                          ),
                          const SizedBox(height: 12),
                        ]),
                      ),
                    ),

                    // --- BUGÜNKÜ İLAÇ LİSTESİ (SLIVER) ---
                    medSnapshot.connectionState == ConnectionState.waiting
                        ? const SliverToBoxAdapter(child: Center(child: CircularProgressIndicator(color: Color(0xFF2D6A4F))))
                        : todaysMedications.isEmpty
                            ? SliverToBoxAdapter(
                                child: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(32),
                                  alignment: Alignment.center,
                                  child: const Column(
                                    children: [
                                      Icon(Icons.medication_outlined, size: 48, color: Colors.black26),
                                      const SizedBox(height: 12),
                                      Text(
                                        "Bugün için eklenmiş bir ilaç bulunmuyor.",
                                        style: TextStyle(color: Colors.black45, fontSize: 14),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            : SliverPadding(
                                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                                sliver: SliverList(
                                  delegate: SliverChildBuilderDelegate(
                                    (context, index) {
                                      final med = todaysMedications[index];
                                      return GestureDetector(
                                        onTap: () => _updateMedicationStatus(med.id, med.isTaken),
                                        child: AnimatedContainer(
                                          duration: const Duration(milliseconds: 200),
                                          margin: const EdgeInsets.only(bottom: 12),
                                          padding: const EdgeInsets.all(16),
                                          decoration: BoxDecoration(
                                            color: med.isTaken ? Colors.grey.shade50 : Colors.white,
                                            borderRadius: BorderRadius.circular(20),
                                            border: Border.all(
                                              color: med.isTaken ? Colors.grey.shade200 : Colors.grey.shade100,
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Row(
                                                children: [
                                                  Icon(
                                                    med.isTaken ? Icons.check_circle : Icons.radio_button_unchecked,
                                                    color: med.isTaken ? const Color(0xFF2D6A4F) : Colors.grey,
                                                  ),
                                                  const SizedBox(width: 12),
                                                  Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Text(
                                                        med.isTaken ? med.name : med.name, 
                                                        style: TextStyle(
                                                          fontWeight: FontWeight.bold, 
                                                          fontSize: 16,
                                                          decoration: med.isTaken ? TextDecoration.lineThrough : null,
                                                          color: med.isTaken ? Colors.black38 : Colors.black87,
                                                        ),
                                                      ),
                                                      Text(
                                                        med.dosage, 
                                                        style: TextStyle(
                                                          color: med.isTaken ? Colors.black26 : Colors.grey, 
                                                          fontSize: 13,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                              Text(
                                                med.time, 
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold, 
                                                  color: med.isTaken ? Colors.black38 : const Color(0xFF2D6A4F),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                    childCount: todaysMedications.length,
                                  ),
                                ),
                              ),
                    const SliverToBoxAdapter(child: SizedBox(height: 40)),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}