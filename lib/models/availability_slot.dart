// lib/models/availability_slot.dart
class AvailabilitySlot {
  final int id;
  final int medecinId; // Corresponds to medecin_id
  final String jourSemaine; // Day of the week
  final String heureDebut; // Start time (HH:MM:SS)
  final String heureFin; // End time (HH:MM:SS)

  AvailabilitySlot({
    required this.id,
    required this.medecinId,
    required this.jourSemaine,
    required this.heureDebut,
    required this.heureFin,
  });

  // Factory method to create an AvailabilitySlot object from a JSON map
  factory AvailabilitySlot.fromJson(Map<String, dynamic> json) {
    // Safely parse IDs as int
    final idValue = json['id'];
    final int parsedId = idValue is int ? idValue : int.tryParse(idValue.toString()) ?? 0;

    final medecinIdValue = json['medecin_id'];
    final int parsedMedecinId = medecinIdValue is int ? medecinIdValue : int.tryParse(medecinIdValue.toString()) ?? 0;


    return AvailabilitySlot(
      id: parsedId,
      medecinId: parsedMedecinId,
      jourSemaine: json['jour_semaine'] as String,
      heureDebut: json['heure_debut'] as String, // Keep as String for now
      heureFin: json['heure_fin'] as String,     // Keep as String for now
    );
  }
}