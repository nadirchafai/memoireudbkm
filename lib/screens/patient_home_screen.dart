import 'package:flutter/material.dart';
import 'package:provider/provider.dart'; // Import provider package

// Import screens navigated to from here
import 'package:medical_app/screens/search_doctors_screen.dart'; // For navigating to search doctors
import 'package:medical_app/screens/my_appointments_screen.dart'; // For navigating to my appointments

// Import your UserProvider and LoggedInUser model
import 'package:medical_app/providers/user_provider.dart';


class PatientHomeScreen extends StatelessWidget {
  // This screen now gets user data from UserProvider, NOT from Navigator arguments.
  // Using super.key for concise constructor
  const PatientHomeScreen({super.key}); // Correct constructor using super.key


  @override
  Widget build(BuildContext context) {
    // Access the UserProvider to get logged-in user data.
    // listen: true is the default and needed here to rebuild the widget if the user changes (e.g., logs out).
    final userProvider = Provider.of<UserProvider>(context);
    final loggedInUser = userProvider.user; // Get the logged-in user object

    print('DEBUG(PatientHome): Provider accessed. LoggedInUser object: $loggedInUser'); // <-- DEBUG PRINT
    print('DEBUG(PatientHome): Is logged in according to provider? ${userProvider.isLoggedIn}'); // <-- DEBUG PRINT


    // Handle case where user is unexpectedly null (e.g., navigated here without logging in)
    // This shouldn't happen with pushReplacementNamed after login if provider is set correctly.
    if (loggedInUser == null) {
      print('Error: Logged-in user data is unexpectedly null in Patient Home Screen. Redirecting to login.');
      // TODO: Maybe show an error message to the user before redirecting
      // Use Future.microtask to avoid calling Navigator during build
      Future.microtask(() {
        Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false); // Redirect to login
      });
      // Return a placeholder while redirecting
      return Scaffold(
        appBar: AppBar(title: const Text('Redirecting...')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    // Extract user details from the LoggedInUser object
    final int userId = loggedInUser.id;
    final String firstName = loggedInUser.nom;
    final String lastName = loggedInUser.prenom;
    final String userRole = loggedInUser.role;


    return Scaffold(
      appBar: AppBar(
        title: const Text('Patient Dashboard'), // لوحة تحكم المريض
        // Optional: Add logout button here (using the provider)
        actions: [
          IconButton(
            icon: Icon(Icons.logout), // أيقونة تسجيل الخروج
            tooltip: 'Logout', // نص تلميحي للزر
            onPressed: () {
              // Call the logout method on the provider
              userProvider.logout(); // Clears user data in provider
              // Navigate back to the login screen and remove all previous routes
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
              // Welcome Message
              Text(
                'Welcome, $firstName $lastName!', // رسالة ترحيب
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              // Display Role (Optional on Home Screen)
              Text(
                'Your Role: ${userRole.toUpperCase()}', // عرض الدور
                style: const TextStyle(fontSize: 18, fontStyle: FontStyle.italic),
              ),
              const SizedBox(height: 40),

              // --- Patient Action Buttons ---
              // Button to Search Doctors
              ElevatedButton(
                onPressed: () {
                  // Navigate to Search Doctors Screen
                  Navigator.pushNamed(context, '/search_doctors');
                },
                child: const Text('Find a Doctor'), // ابحث عن طبيب
              ),
              const SizedBox(height: 12),

              // Button to View Appointments
              ElevatedButton(
                onPressed: () {
                  // Navigate to View Appointments Screen (My Appointments)
                  // MyAppointmentsScreen will read user ID from Provider
                  Navigator.pushNamed(context, '/my_appointments');
                },
                child: const Text('My Appointments'), // مواعيدي
              ),
              // Add other patient features buttons here

              // The Logout button is now in the AppBar actions
              /*
               const SizedBox(height: 40),
               TextButton(
                 onPressed: () {
                   // Logout logic (now handled in AppBar action)
                 },
                 child: const Text('Logout'), // تسجيل الخروج
               ),
               */
            ],
          ),
        ),
      ),
    );
  }
}