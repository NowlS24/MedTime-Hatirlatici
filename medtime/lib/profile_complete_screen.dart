// profile_complete_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'main.dart'; // MedTimeNavigation burada tanımlı olduğu için import kalmalı

class ProfileCompleteScreen extends StatefulWidget {
  const ProfileCompleteScreen({super.key});

  @override
  State<ProfileCompleteScreen> createState() => _ProfileCompleteScreenState();
}

class _ProfileCompleteScreenState extends State<ProfileCompleteScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();
  String _selectedGender = ""; // "Kadın" veya "Erkek" tutacak
  bool _isLoading = false;

  // Verileri Firebase'e kaydeden fonksiyon
// Profil verilerini geçici kimlikle Firestore'a kaydeden güncel fonksiyon
  Future<void> _saveProfileToFirebase() async {
    setState(() => _isLoading = true);

    try {
      // AKTİF OTURUM YOKSA TEST İÇİN GEÇİCİ BİR KİMLİK (UID) TANIMLIYORUZ
      final currentUser = FirebaseAuth.instance.currentUser;
      final String testUid = currentUser?.uid ?? "gecici_test_kullanicisi_123";

      // Firestore'a kullanıcının girdiği ad, yaş ve cinsiyet bilgilerini kaydediyoruz
      await FirebaseFirestore.instance.collection('users').doc(testUid).set({
        'uid': testUid,
        'name': _nameController.text.trim(),   // Ad soyad controller nesneniz
        'age': _ageController.text.trim(),     // Yaş controller nesneniz
        'gender': _selectedGender,             // Seçilen cinsiyet değişkeniniz
        'isMockUser': currentUser == null,     // Gerçek kullanıcı mı test kullanıcısı mı ayrımı için
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profil başarıyla kaydedildi! 🎉 (Geçici Kimlik Aktif)'),
          backgroundColor: Color(0xFF2D6A4F),
          behavior: SnackBarBehavior.floating,
        ),
      );

      // Kayıt başarılıysa alt menülü ana sayfaya geçiş yapıyoruz
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const MedTimeNavigation()),
      );

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Kayıt sırasında hata oluştu: $e'), 
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF4A90E2); // Soft mavi
    const backgroundColor = Color(0xFFF8FAFC); // Açık gri/beyaz

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              Center(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: primaryColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.medical_information_outlined, size: 50, color: primaryColor),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                "Profilini Tamamla",
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
              ),
              const SizedBox(height: 8),
              const Text(
                "Sana daha iyi hitap edebilmemiz ve MHRS randevularını düzenleyebilmemiz için birkaç küçük bilgiye ihtiyacımız var.",
                style: TextStyle(fontSize: 14, color: Color(0xFF64748B), height: 1.4),
              ),
              const SizedBox(height: 32),

              // 1. Ad Soyad Giriş Kutusu
              const Text("Adınız", style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF334155))),
              const SizedBox(height: 8),
              TextField(
                controller: _nameController,
                decoration: InputDecoration(
                  hintText: "Adınız",
                  prefixIcon: const Icon(Icons.person_outline, color: primaryColor),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 20),

              // 2. Yaş Giriş Kutusu
              const Text("Yaşınız", style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF334155))),
              const SizedBox(height: 8),
              TextField(
                controller: _ageController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  hintText: "Yaşınız",
                  prefixIcon: const Icon(Icons.cake_outlined, color: primaryColor),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 20),

              // 3. Cinsiyet Seçim Alanı 
              const Text("Cinsiyetiniz", style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF334155))),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedGender = "Kadın"),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          color: _selectedGender == "Kadın" ? primaryColor.withOpacity(0.15) : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: _selectedGender == "Kadın" ? primaryColor : Colors.transparent, width: 2),
                        ),
                        child: Column(
                          children: [
                            Icon(Icons.female, size: 28, color: _selectedGender == "Kadın" ? primaryColor : Colors.grey),
                            const SizedBox(height: 4),
                            Text("Kadın", style: TextStyle(fontWeight: FontWeight.bold, color: _selectedGender == "Kadın" ? primaryColor : Colors.grey)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedGender = "Erkek"),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          color: _selectedGender == "Erkek" ? primaryColor.withOpacity(0.15) : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: _selectedGender == "Erkek" ? primaryColor : Colors.transparent, width: 2),
                        ),
                        child: Column(
                          children: [
                            Icon(Icons.male, size: 28, color: _selectedGender == "Erkek" ? primaryColor : Colors.grey),
                            const SizedBox(height: 4),
                            Text("Erkek", style: TextStyle(fontWeight: FontWeight.bold, color: _selectedGender == "Erkek" ? primaryColor : Colors.grey)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 40),

              // 4. Kaydet ve Devam Et Butonu
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveProfileToFirebase,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text("Kaydet ve Devam Et", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}