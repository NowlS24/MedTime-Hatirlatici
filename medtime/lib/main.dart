// main.dart
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart'; // BULUT İÇİN 1. EKLEME
import 'firebase_options.dart'; //  BULUT İÇİN 2. EKLEME

// Önce oluşturduğun diğer sayfaları buraya tanıtıyoruz (import ediyoruz)
import 'dashboard_page.dart';
import 'medications_page.dart';
import 'appointments_page.dart';
import 'notifications_page.dart';
import 'notification_service.dart'; // BİLDİRİM İÇİN EKLEME 
import 'package:medtime/profile_complete_screen.dart';

// void main kısmını async yapıp Firebase'i ve Bildirim Servisini uyandırıyoruz
void main() async {
  // Flutter elementlerinin düzgün yüklenmesini garantiye alıyoruz
  WidgetsFlutterBinding.ensureInitialized();
  
  // Bulut altyapısını başlatan komut
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Yerel bildirim motorunu başlatan komut
  await NotificationService().initNotification();

  runApp(const MedTimeApp());
}

class MedTimeApp extends StatelessWidget {
  const MedTimeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MedTime',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF2E7D32), // MedTime Yeşil
      ),
      home: const ProfileCompleteScreen(),
    );
  }
}

class MedTimeNavigation extends StatefulWidget {
  const MedTimeNavigation({super.key});

  @override
  State<MedTimeNavigation> createState() => _MedTimeNavigationState();
}

class _MedTimeNavigationState extends State<MedTimeNavigation> {
  int _currentIndex = 0;

  // 4 sayfalık sıra
  final List<Widget> _pages = [
    const DashboardPage(),
    const MedicationsPage(),
    const AppointmentsPage(),
    const NotificationsPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_currentIndex], 
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        type: BottomNavigationBarType.fixed,
        selectedItemColor: const Color(0xFF2E7D32),
        unselectedItemColor: Colors.grey,
        showSelectedLabels: false,
        showUnselectedLabels: false,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_outlined), activeIcon: Icon(Icons.home), label: "Ana Sayfa"),
          BottomNavigationBarItem(icon: Icon(Icons.medication_outlined), activeIcon: Icon(Icons.medication), label: "İlaçlarım"),
          BottomNavigationBarItem(icon: Icon(Icons.calendar_month_outlined), activeIcon: Icon(Icons.calendar_month), label: "Randevular"),
          BottomNavigationBarItem(icon: Icon(Icons.notifications_outlined), activeIcon: Icon(Icons.notifications), label: "Bildirimler"),
        ],
      ),
    );
  }
}