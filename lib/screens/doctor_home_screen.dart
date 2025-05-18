import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:medical_app/providers/user_provider.dart'; // Import UserProvider

// TODO: Import DoctorAppointmentsScreen when created
// import 'package:medical_app/screens/doctor_appointments_screen.dart';

class DoctorHomeScreen extends StatelessWidget {
  const DoctorHomeScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Access the UserProvider to get logged-in user data.
    final userProvider = Provider.of<UserProvider>(context);
    final loggedInUser = userProvider.user;

    // Handle case where user is unexpectedly null
    if (loggedInUser == null || !userProvider.isDoctor) {
      print('Error: Doctor not logged in or role mismatch in Doctor Home Screen.');
      // Use Future.microtask to avoid calling Navigator during build
      Future.microtask(() {
        Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false); // Redirect to login
      });
      return Scaffold(
        appBar: AppBar(title: const Text('Redirecting...')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final String doctorName = '${loggedInUser.prenom} ${loggedInUser.nom}';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Doctor Dashboard'), // لوحة تحكم الطبيب
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () {
              userProvider.logout();
              Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
            },
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              Text(
                'Welcome, Dr. $doctorName!', // رسالة ترحيب بالطبيب
                style: Theme.of(context).textTheme.displayLarge?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              // --- Doctor Action Buttons ---
              ElevatedButton(
                onPressed: () {
                  // Navigate to Doctor's Appointments Screen
                  Navigator.pushNamed(context, '/doctor_appointments'); // <-- Corrected navigation
                },
                child: const Text('My Appointments'), // مواعيدي (كطبيب)
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () {
                  // TODO: Navigate to Manage Availability Screen
                  // Navigator.pushNamed(context, '/manage_availability'); // We will create this route
                  _showTemporarySnackBar(context, "Manage Availability - TODO");
                },
                child: const Text('Manage Availability'), // إدارة أوقات التوفر
              ),
              // Add other doctor features buttons here
            ],
          ),
        ),
      ),
    );
  }

  // Temporary helper for showing TODO messages
  void _showTemporarySnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}