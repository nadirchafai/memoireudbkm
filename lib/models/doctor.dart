// lib/models/doctor.dart
import 'package:medical_app/models/speciality.dart'; // Import Speciality model
import 'package:medical_app/models/address.dart'; // Import Address model

class Doctor {
  final int userId; // Corresponds to u.id / m.user_id
  final String nom;
  final String prenom;
  final String? email; // Email might be optional to display publicly
  final String? numTelephone; // Phone might be optional to display publicly
  final String? cin; // Or certificate identifier (as used in read_single for now)
  final String? description;
  final bool isApproved; // Assuming backend returns 0/1 or false/true
  // final String? certificateUrl; // If you added these columns and fetch them
  // final String? profilePictureUrl; // If you added these columns and fetch them

  final Speciality speciality; // Every doctor must have a speciality
  final Address? address; // Address is optional (can be null)

  Doctor({
    required this.userId,
    required this.nom,
    required this.prenom,
    this.email,
    this.numTelephone,
    this.cin,
    this.description,
    required this.isApproved,
    // this.certificateUrl,
    // this.profilePictureUrl,
    required this.speciality,
    this.address, // Mark as optional
  });

  // Factory method to create a Doctor object from a JSON map
  factory Doctor.fromJson(Map<String, dynamic> json) {
    // Safely parse user_id as int
    final userIdValue = json['user_id'];
    final int parsedUserId = userIdValue is int ? userIdValue : int.tryParse(userIdValue.toString()) ?? 0;

    // Safely parse is_approved as bool (handle potential 0/1 from backend)
    final isApprovedValue = json['is_approved'];
    final bool parsedIsApproved = isApprovedValue is bool ? isApprovedValue : (isApprovedValue == 1 || isApprovedValue == '1');


    return Doctor(
      userId: parsedUserId,
      nom: json['nom'] as String,
      prenom: json['prenom'] as String,
      email: json['email'] as String?, // Use as String?
      numTelephone: json['num_telephone'] as String?,
      cin: json['cin'] as String?,
      description: json['description'] as String?,
      isApproved: parsedIsApproved, // Use the parsed boolean value
      // certificateUrl: json['certificate_url'] as String?, // If added and fetched
      // profilePictureUrl: json['profile_picture_url'] as String?, // If added and fetched

      // Create nested models
      speciality: Speciality.fromJson(json['speciality']), // Assuming 'speciality' key is always present and contains a map
      address: json['address'] != null ? Address.fromJson(json['address']) : null, // Create Address only if 'address' key is not null
    );
  }

  // Optional: Getter for full name
  String get fullName => '$nom $prenom';
}