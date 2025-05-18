import 'package:flutter/material.dart';

// Define a simple model for the logged-in user data
class LoggedInUser {
  final int id;
  final String nom;
  final String prenom;
  final String email;
  final String role;
  // You can add other user details here if needed, like phone, etc.
  // It's good practice to define this model to be clear about what data you store.

  LoggedInUser({
    required this.id,
    required this.nom,
    required this.prenom,
    required this.email,
    required this.role,
  });

  // Factory method to create a LoggedInUser object from the user data map from the API response
  factory LoggedInUser.fromJson(Map<String, dynamic> json) {
    final idValue = json['id'];
    final int parsedId = idValue is int ? idValue : int.tryParse(idValue.toString()) ?? 0;

    return LoggedInUser(
      id: parsedId,
      nom: json['nom'] as String,
      prenom: json['prenom'] as String,
      email: json['email'] as String,
      role: json['role'] as String,
    );
  }
}


class UserProvider extends ChangeNotifier {
  // Nullable LoggedInUser to represent logged-out state
  LoggedInUser? _user;

  // Getter to access the user data
  LoggedInUser? get user => _user;

  // Method to set the user data after successful login
  void setUser(LoggedInUser? user) {
    _user = user;
    // Notify listeners (Widgets that are watching this provider) that data has changed
    notifyListeners();
  }

  // Method to log out the user
  void logout() {
    _user = null;
    // Notify listeners
    notifyListeners();
    // TODO: You might also clear stored tokens or session data here
  }

  // Helper getters to check login state and role
  bool get isLoggedIn => _user != null;
  bool get isPatient => _user?.role == 'patient';
  bool get isDoctor => _user?.role == 'medecin';
  // bool get isAdmin => _user?.role == 'admin'; // If admin role is implemented

  // Get user ID for API calls (handle null user safely)
  int? get userId => _user?.id;
}