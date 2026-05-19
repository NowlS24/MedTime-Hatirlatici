// medication_model.dart
class Medication {
  final String id;
  final String name;      // İlacın adı (Örn: Glifor)
  final String dosage;    // Dozu (Örn: 500mg)
  final String time;      // İlaç saati (Örn: 14:20)
  final bool isTaken;     // İçildi mi, içilmedi mi?

  Medication({
    required this.id,
    required this.name,
    required this.dosage,
    required this.time,
    this.isTaken = false, // Varsayılan olarak içilmedi kabul ediyoruz
  });
}
