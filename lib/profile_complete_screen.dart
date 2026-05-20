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

  // Profil verilerini cihaz tabanlı gerçek anonim kimlikle kaydeden güvenli fonksiyon
  Future<void> _saveProfileToFirebase() async {
    setState(() => _isLoading = true);

    try {
      // 🔐 1. EĞER AKTİF OTURUM YOKSA ARKA PLANDA KALICI ANONİM OTURUM AÇIYORUZ
      // Bu işlem cihaz hafızasına sabit bir UID mühürler, ilaç silme hatasını çözer.
      if (FirebaseAuth.instance.currentUser == null) {
        await FirebaseAuth.instance.signInAnonymously();
      }

      final currentUser = FirebaseAuth.instance.currentUser;
      final String uniqueUid = currentUser?.uid ?? "acil_durum_id_${DateTime.now().millisecondsSinceEpoch}";

      // 2. Firestore'a kullanıcının girdiği ad, yaş ve cinsiyet bilgilerini benzersiz kimlikle kaydediyoruz
      await FirebaseFirestore.instance.collection('users').doc(uniqueUid).set({
        'uid': uniqueUid,
        'name': _nameController.text.trim(),
        'age': _ageController.text.trim(),
        'gender': _selectedGender,
        'isMockUser': false, // Artık cihaz tabanlı gerçek bir oturum var
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profil başarıyla kaydedildi! 🎉 Oturumunuz Güvenle Başlatıldı.'),
          backgroundColor: Color(0xFF2E7D32),
          behavior: SnackBarBehavior.floating,
        ),
      );

      // 3. Kayıt başarılıysa alt menülü ana sayfaya kesin geçiş yapıyoruz
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
    const primaryColor = Color(0xFF2E7D32); // MedTime Yeşil rengiyle senkronize edildi
    const backgroundColor = Color(0xFFF8FAFC);

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

              // Ad Soyad Giriş Kutusu
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

              // Yaş Giriş Kutusu
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

              // Cinsiyet Seçim Alanı 
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

              // Kaydet ve Devam Et Butonu
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