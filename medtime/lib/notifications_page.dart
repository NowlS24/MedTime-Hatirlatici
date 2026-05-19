// notifications_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  
  String _getTargetUid() {
    final currentUser = FirebaseAuth.instance.currentUser;
    return currentUser?.uid ?? "gecici_test_kullanicisi_123";
  }

  Stream<QuerySnapshot> _getNotificationsStream() {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(_getTargetUid())
        .collection('notifications')
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  //  TEK TEK BİLDİRİM SİLME FONKSİYONU
  Future<void> _deleteSingleNotification(String docId) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(_getTargetUid())
          .collection('notifications')
          .doc(docId)
          .delete();
    } catch (e) {
      debugPrint("Bildirim silinirken hata oluştu: $e");
    }
  }

  //  TÜM BİLDİRİMLERİ TEK TIKLA SİLME FONKSİYONU
  Future<void> _clearAllNotifications(List<QueryDocumentSnapshot> docs) async {
    if (docs.isEmpty) return;

    // Kullanıcıya onay soran şık bir diyalog penceresi (UX Standardı)
    bool confirm = await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text("Bildirimleri Temizle"),
            content: const Text("Tüm bildirim geçmişinizi silmek istediğinize emin misiniz?"),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text("Vazgeç", style: TextStyle(color: Colors.grey)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                onPressed: () => Navigator.pop(context, true),
                child: const Text("Hepsini Sil", style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirm) return;

    // Firebase toplu silme işlemi (WriteBatch)
    final batch = FirebaseFirestore.instance.batch();
    for (var doc in docs) {
      batch.delete(doc.reference);
    }

    try {
      await batch.commit();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("✨ Tüm bildirim geçmişi temizlendi."),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.black87,
        ),
      );
    } catch (e) {
      debugPrint("Toplu silme hatası: $e");
    }
  }

  //  Tarihi bugün yapan
  String _formatNotificationTime(Timestamp? timestamp) {
    if (timestamp == null) return "Şimdi";
    
    DateTime notificationDate = timestamp.toDate();
    DateTime now = DateTime.now();
    
    String hour = notificationDate.hour.toString().padLeft(2, '0');
    String minute = notificationDate.minute.toString().padLeft(2, '0');
    
    if (notificationDate.year == now.year &&
        notificationDate.month == now.month &&
        notificationDate.day == now.day) {
      return "Bugün $hour:$minute";
    }
    
    DateTime yesterday = now.subtract(const Duration(days: 1));
    if (notificationDate.year == yesterday.year &&
        notificationDate.month == yesterday.month &&
        notificationDate.day == yesterday.day) {
      return "Dün $hour:$minute";
    }

    List<String> months = [
      "", "Ocak", "Şubat", "Mart", "Nisan", "Mayıs", "Haziran", 
      "Temmuz", "Ağustos", "Eylül", "Ekim", "Kasım", "Aralık"
    ];
    return "${notificationDate.day} ${months[notificationDate.month]} $hour:$minute";
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: _getNotificationsStream(),
      builder: (context, snapshot) {
        final notificationDocs = snapshot.data?.docs ?? [];

        return Scaffold(
          backgroundColor: const Color(0xFFF9F9F7),
          appBar: AppBar(
            title: const Text("Bildirimler", style: TextStyle(fontWeight: FontWeight.bold)),
            backgroundColor: Colors.transparent,
            elevation: 0,
            foregroundColor: Colors.black,
            actions: [
              //  Bildirim listesi boş değilse sağ üstte "Tümünü Temizle" ikonu belirir
              if (notificationDocs.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.delete_sweep_rounded, color: Colors.redAccent, size: 28),
                  tooltip: "Tümünü Temizle",
                  onPressed: () => _clearAllNotifications(notificationDocs),
                ),
            ],
          ),
          body: () {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: Color(0xFF2D6A4F)),
              );
            }

            if (notificationDocs.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.notifications_off_outlined, size: 70, color: Colors.black26),
                    const SizedBox(height: 16),
                    const Text(
                      "Henüz bir bildiriminiz bulunmuyor.",
                      style: TextStyle(color: Colors.black38, fontSize: 16, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: notificationDocs.length,
              itemBuilder: (context, index) {
                final doc = notificationDocs[index];
                final data = doc.data() as Map<String, dynamic>;
                final String docId = doc.id;
                
                final String title = data['title'] ?? 'İlaç Zamanı';
                final String body = data['body'] ?? '';
                final String ogun = data['ogun'] ?? 'Sabah';
                final Timestamp? timestamp = data['timestamp'] as Timestamp?;
                
                final String timeString = _formatNotificationTime(timestamp);
                
                Color iconColor = ogun == 'Sabah' ? Colors.orange : const Color(0xFF2D6A4F);
                IconData notificationIcon = ogun == 'Sabah' ? Icons.wb_sunny_rounded : Icons.nights_stay_rounded;

                //  Sürükleyerek Silme Yapısı (Dismissible) Entegre Edildi
                return Dismissible(
                  key: Key(docId),
                  direction: DismissDirection.endToStart, // Sadece sağdan sola kaydırınca silinsin
                  background: Container(
                    margin: const EdgeInsets.only(bottom: 15),
                    padding: const EdgeInsets.only(right: 20),
                    alignment: Alignment.centerRight,
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withOpacity(0.85),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text("Sil", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        SizedBox(width: 8),
                        Icon(Icons.delete_outline, color: Colors.white),
                      ],
                    ),
                  ),
                  onDismissed: (direction) {
                    _deleteSingleNotification(docId);
                  },
                  child: Card(
                    margin: const EdgeInsets.only(bottom: 15),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    color: const Color(0xFFE8F5E9).withOpacity(0.5),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      leading: CircleAvatar(
                        backgroundColor: iconColor,
                        child: Icon(notificationIcon, color: Colors.white, size: 20),
                      ),
                      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(body),
                      trailing: Text(
                        timeString, 
                        style: const TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.w500)
                      ),
                    ),
                  ),
                );
              },
            );
          }(),
        );
      },
    );
  }
}