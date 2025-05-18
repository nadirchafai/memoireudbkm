// lib/models/speciality.dart
class Speciality {
  final int id;
  final String nomSpecialite;

  Speciality({required this.id, required this.nomSpecialite});

  // Factory method to create a Speciality object from a JSON map
  factory Speciality.fromJson(Map<String, dynamic> json) {
    // Safely parse ID as int, handling potential String type from JSON
    final idValue = json['id'];
    final int parsedId = idValue is int ? idValue : int.tryParse(idValue.toString()) ?? 0; // Default to 0 if parsing fails

    return Speciality(
      id: parsedId,
      nomSpecialite: json['nom_specialite'] as String, // Ensure casting to String
    );
  }

  // Optional: Override toString for easier debugging/display in Dropdown if needed
  @override
  String toString() {
    return nomSpecialite;
  }
}