// lib/models/appointment.dart
import 'package:medical_app/models/speciality.dart'; // Already imported

// Model for the Patient summary displayed within an Appointment item (for Doctor's list)
class AppointmentPatient {
  final int userId;
  final String nom;
  final String prenom;
  final String? numTelephone; // Optional phone number

  AppointmentPatient({
    required this.userId,
    required this.nom,
    required this.prenom,
    this.numTelephone,
  });

  // Factory method to create an AppointmentPatient from a JSON map
  factory AppointmentPatient.fromJson(Map<String, dynamic> json) {
    final userIdValue = json['user_id']; // PHP returns 'patient_user_id' but we use 'user_id' in fromJson for consistency
    final int parsedUserId = userIdValue is int ? userIdValue : int.tryParse(userIdValue.toString()) ?? 0;

    return AppointmentPatient(
      userId: parsedUserId,
      nom: json['nom'] as String, // PHP returns 'patient_nom'
      prenom: json['prenom'] as String, // PHP returns 'patient_prenom'
      numTelephone: json['num_telephone'] as String?, // PHP returns 'patient_num_telephone'
    );
  }

  // Optional: Getter for full name
  String get fullName => '$nom $prenom';
}

// ... (Rest of the AppointmentDoctor and Appointment classes from previous code) ...
// Ensure you have these from previous steps:

// Model for the Doctor summary displayed within an Appointment item (for Patient's list)
class AppointmentDoctor {
  final int userId;
  final String nom;
  final String prenom;
  final Speciality speciality; // Assuming speciality is always present for a doctor

  AppointmentDoctor({
    required this.userId,
    required this.nom,
    required this.prenom,
    required this.speciality,
  });

  // Factory method to create an AppointmentDoctor from a JSON map
  factory AppointmentDoctor.fromJson(Map<String, dynamic> json) {
    final userIdValue = json['user_id'];
    final int parsedUserId = userIdValue is int ? userIdValue : int.tryParse(userIdValue.toString()) ?? 0;

    // Ensure 'specialite' key is present and contains a map before calling fromJson
    final specialityJson = json['specialite'];
    final Speciality parsedSpeciality = specialityJson != null ? Speciality.fromJson(specialityJson) : Speciality(id: 0, nomSpecialite: 'N/A'); // Provide default if missing


    return AppointmentDoctor(
      userId: parsedUserId,
      nom: json['nom'] as String,
      prenom: json['prenom'] as String,
      speciality: parsedSpeciality,
    );
  }

  // Optional: Getter for full name
  String get fullName => '$nom $prenom';
}

// Model for the Appointment itself
class Appointment {
  final int id;
  final String dateRendezvous; // Keep as String for simplicity initially
  final String statut;
  final String? notesPatient; // Optional notes

  final AppointmentDoctor? medecin; // For Patient's appointment list
  final AppointmentPatient? patient; // For Doctor's appointment list

  Appointment({
    required this.id,
    required this.dateRendezvous,
    required this.statut,
    this.notesPatient,
    this.medecin,
    this.patient,
  });

  // Factory method to create an Appointment object from a JSON map
  factory Appointment.fromJson(Map<String, dynamic> json) {
    final idValue = json['id'];
    final int parsedId = idValue is int ? idValue : int.tryParse(idValue.toString()) ?? 0;

    // Adjust keys for AppointmentPatient based on what the PHP backend returns for a doctor's appointment list
    // In api/appointments/read.php (for doctor role), PHP returns:
    // "patient_user_id", "patient_nom", "patient_prenom", "patient_num_telephone"
    // These are wrapped under a "patient" key in the JSON response by PHP.

    return Appointment(
      id: parsedId,
      dateRendezvous: json['date_rendezvous'] as String,
      statut: json['statut'] as String,
      notesPatient: json['notes_patient'] as String?, // Use as String?

      // Create nested AppointmentDoctor only if 'medecin' key is present and not null
      medecin: json['medecin'] != null ? AppointmentDoctor.fromJson(json['medecin']) : null,

      // Create nested AppointmentPatient only if 'patient' key is present and not null
      // The PHP backend's 'patient' object directly contains 'user_id', 'nom', 'prenom', 'num_telephone'
      // So, AppointmentPatient.fromJson needs to map these correctly.
      patient: json['patient'] != null ? AppointmentPatient.fromJson(json['patient']) : null,
    );
  }
}