import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:provider/provider.dart'; // Import provider package

// Import the screens you navigate to
import 'package:medical_app/screens/registration_screen.dart'; // For navigating to registration
import 'package:medical_app/screens/patient_home_screen.dart'; // For navigating to patient home

// You will import the doctor home screen here later
// import 'package:medical_app/screens/doctor_home_screen.dart';

// Import your UserProvider and LoggedInUser model
import 'package:medical_app/providers/user_provider.dart';


import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:provider/provider.dart'; // Import provider package

// Import the screens you navigate to
// import 'package:medical_app/screens/registration_screen.dart'; // Already handled by named route
// import 'package:medical_app/screens/patient_home_screen.dart'; // Already handled by named route

// Import your UserProvider
import 'package:medical_app/providers/user_provider.dart';


class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // Controllers for text fields
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  // Loading state
  bool _isLoading = false;

  // Function to handle login
  Future<void> _login() async {
    // Dismiss keyboard
    FocusScope.of(context).unfocus();

    setState(() {
      _isLoading = true; // Show loading indicator
    });

    // Get data from controllers
    String email = _emailController.text.trim();
    String password = _passwordController.text; // Don't trim password

    // Basic validation
    if (email.isEmpty || password.isEmpty) {
      _showSnackBar('Please enter email and password.'); // Show message
      setState(() { _isLoading = false; });
      return;
    }

    // Prepare data for API call
    var data = {
      "email": email,
      "mot_de_passe": password,
    };

    // API Endpoint URL (replace with your local IP)
    // Using 10.0.2.2 for Android Emulator
    final String apiUrl = 'http://10.0.2.2/medical_api/api/auth/login.php';
    // final String apiUrl = 'http://localhost/medical_api/api/auth/login.php'; // For iOS Sim or Web

    try {
      // Make the POST request
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
          // TODO: Add Authorization Header with User Token if using token-based auth
        },
        body: jsonEncode(data), // Encode data as JSON
      );

      // Parse the JSON response
      final responseBody = jsonDecode(response.body);

      // Check the response status code
      if (response.statusCode == 200) {
        // Login successful
        _showSnackBar(responseBody['message'] ?? 'Login successful!');

        // *** Handle successful login ***
        // Capture and save user data in the UserProvider
        if (responseBody['data'] != null && responseBody['data']['user'] != null) {
          final userDataMap = responseBody['data']['user'] as Map<String, dynamic>; // Get the 'user' map
          final loggedInUser = LoggedInUser.fromJson(userDataMap); // Create LoggedInUser object
          final userProvider = Provider.of<UserProvider>(context, listen: false);
          userProvider.setUser(loggedInUser);

          print('User logged in successfully! User ID: ${loggedInUser.id}, Role: ${loggedInUser.role}');

          // Navigate to the appropriate home screen based on role
          if (loggedInUser.role == 'patient') {
            Navigator.pushReplacementNamed(context, '/patient_home');
          } else if (loggedInUser.role == 'medecin') { // <-- ADD THIS BLOCK
            // TODO: Create DoctorHomeScreen and its route
            // For now, we can show a snackbar and navigate to a placeholder or patient home
            _showSnackBar('Doctor login successful! Navigating to Doctor Home (TODO).');
            // Replace with actual navigation when DoctorHomeScreen is ready
            Navigator.pushReplacementNamed(context, '/doctor_home'); // We will create this route and screen
          } else {
            _showSnackBar('Unknown user role: ${loggedInUser.role}.');
            userProvider.logout();
          }

        } else {
          // Handle case where 'data' or 'user' is missing in successful response
          _showSnackBar('Login successful but user data is missing in response.');
          print('Login successful, but response structure is unexpected: ${response.body}');
        }

        // Clear fields after successful login (optional, navigation happens instead)
        _emailController.clear(); // Clearing fields might not be needed if navigating immediately
        _passwordController.clear(); // Clearing fields might not be needed if navigating immediately


      } else {
        // Login failed - show error message from backend
        _showSnackBar(responseBody['message'] ?? 'Login failed.');
        print('Login failed. Status: ${response.statusCode}, Body: ${response.body}');
      }

    } catch (e) {
      // Handle network or other errors
      _showSnackBar('An error occurred: ${e.toString()}');
      print('Error during login: $e'); // Print error to console
    } finally {
      setState(() {
        _isLoading = false; // Hide loading indicator
      });
    }
  }

  // Helper function to show messages using SnackBar
  void _showSnackBar(String message) {
    if (mounted) { // Check if the widget is still in the widget tree
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  void dispose() {
    // Clean up controllers when the widget is disposed
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Get current theme colors
    final Color primaryColor = Theme.of(context).colorScheme.primary;
    final Color secondaryColor = Theme.of(context).colorScheme.secondary;

    return Scaffold(
      // AppBar is optional for login/register screens, depends on design preference
      // appBar: AppBar(
      //   title: const Text('Login'),
      // ),
      body: SafeArea( // Use SafeArea to avoid system intrusions (notch, status bar)
        child: Center( // Center the content on the screen
          child: SingleChildScrollView( // Allow scrolling if content overflows
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0), // Add more padding
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center, // Center vertically
              crossAxisAlignment: CrossAxisAlignment.stretch, // Stretch children horizontally
              children: <Widget>[
                // App Icon/Logo (Example)
                Icon(
                  Icons.medical_services, // Or your custom logo (e.g., Image.asset('assets/logo.png'))
                  size: 80,
                  color: primaryColor, // Use primary color from theme
                ),
                const SizedBox(height: 24.0), // Spacing after icon

                Text(
                  'Welcome Back!', // رسالة ترحيب
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.displayLarge?.copyWith(
                    color: primaryColor, // Use displayLarge for main title
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8.0),
                Text(
                  'Login to continue your health journey.', // تسجيل الدخول للمتابعة
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith( // Use titleMedium or bodyLarge
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 40.0), // Increased spacing


                // Email Field
                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: 'Email', // البريد الإلكتروني
                    // border: OutlineInputBorder(), // Now handled by theme
                    prefixIcon: Icon(Icons.email_outlined, color: primaryColor), // Use outlined icons
                  ),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 16.0), // Increased spacing

                // Password Field
                TextField(
                  controller: _passwordController,
                  obscureText: true, // Hide password
                  decoration: InputDecoration(
                    labelText: 'Password', // كلمة المرور
                    // border: OutlineInputBorder(), // Now handled by theme
                    prefixIcon: Icon(Icons.lock_outline, color: primaryColor), // Use outlined icons
                    // TODO: Add suffix icon to toggle password visibility
                  ),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 32.0), // Increased spacing

                // Login Button
                ElevatedButton(
                  onPressed: _isLoading ? null : _login, // Disable button when loading
                  // style is now handled by theme (elevatedButtonTheme in main.dart)
                  child: _isLoading
                      ? const SizedBox( // Show loading indicator
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      color: Colors.white, // Spinner color
                      strokeWidth: 2.0,
                    ),
                  )
                      : const Text('Login'), // نص الزر: تسجيل الدخول
                ),
                const SizedBox(height: 16.0), // Spacing

                // Link to Registration Screen
                Row( // Use Row for better centering and text styling
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "Don't have an account?", // ليس لديك حساب؟
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey[800],
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        // Navigate to Registration Screen using named route
                        // Using pushReplacementNamed so user cannot go back to login with back button
                        Navigator.pushReplacementNamed(context, '/register');
                      },
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0), // Adjust padding
                      ),
                      child: Text(
                        'Register', // سجل الآن
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: secondaryColor, // Use secondary color for link
                          fontSize: Theme.of(context).textTheme.bodyMedium?.fontSize, // Match size
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}