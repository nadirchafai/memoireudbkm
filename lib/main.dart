// lib/main.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:medical_app/providers/user_provider.dart';
import 'package:google_fonts/google_fonts.dart'; // Import Google Fonts
import 'package:medical_app/screens/doctor_home_screen.dart'; // Import Doctor Home Screen
// Import screen files...
import 'package:medical_app/screens/registration_screen.dart';
import 'package:medical_app/screens/login_screen.dart';
import 'package:medical_app/screens/patient_home_screen.dart';
import 'package:medical_app/screens/search_doctors_screen.dart';
import 'package:medical_app/screens/doctor_details_screen.dart';
import 'package:medical_app/screens/my_appointments_screen.dart';
import 'package:medical_app/screens/doctor_appointments_screen.dart'; // Import Doctor Appointments Screen


void main() {
  runApp(
    ChangeNotifierProvider(
      create: (context) => UserProvider(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Define custom colors
    const Color primaryColor = Color(0xFF2962FF); // A nice shade of blue (Material Blue Accent 700)
    const Color secondaryColor = Color(0xFF00B0FF); // A lighter, vibrant blue (Material Light Blue Accent 400)

    return MaterialApp(
      title: 'Medical Appointments App',
      theme: ThemeData(
        // --- Color Scheme ---
        colorScheme: ColorScheme.fromSeed(
          seedColor: primaryColor, // Base color for generating the scheme
          primary: primaryColor,
          secondary: secondaryColor,
          // You can also define error, surface, background colors here if needed
        ),

        // --- Typography ---
        // Use GoogleFonts for the entire app's text theme
        // Applying 'Cairo' as the default font family
        textTheme: GoogleFonts.cairoTextTheme(
          Theme.of(context).textTheme, // Start with the default theme
        ).copyWith(
          // Optionally customize specific text styles
          displayLarge: GoogleFonts.cairo(fontSize: 24, fontWeight: FontWeight.bold, color: primaryColor),
          titleLarge: GoogleFonts.cairo(fontSize: 20, fontWeight: FontWeight.w600),
          bodyMedium: GoogleFonts.cairo(fontSize: 16),
          labelLarge: GoogleFonts.cairo(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white), // For button text
        ),

        // --- AppBar Theme ---
        appBarTheme: AppBarTheme(
          backgroundColor: primaryColor, // AppBar background color
          foregroundColor: Colors.white, // Text and icon color in AppBar
          elevation: 4.0, // Slight shadow for AppBar
          titleTextStyle: GoogleFonts.cairo( // Font for AppBar title
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),

        // --- ElevatedButton Theme ---
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: secondaryColor, // Button background color
            foregroundColor: Colors.white, // Button text color
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            textStyle: GoogleFonts.cairo(fontSize: 16, fontWeight: FontWeight.bold),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8.0), // Rounded corners for buttons
            ),
          ),
        ),

        // --- TextField (InputDecoration) Theme ---
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8.0),
            borderSide: BorderSide(color: Colors.grey[400]!),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8.0),
            borderSide: BorderSide(color: primaryColor, width: 2.0),
          ),
          labelStyle: GoogleFonts.cairo(color: Colors.grey[700]),
          floatingLabelStyle: GoogleFonts.cairo(color: primaryColor), // Label style when focused
        ),

        // --- Card Theme ---
        cardTheme: CardTheme(
          elevation: 2.0,
          margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10.0),
          ),
        ),

        // Use Material 3 for newer visual components (optional)
        useMaterial3: true,
      ),

      initialRoute: '/login',
      routes: {
        '/login': (context) => const LoginScreen(),
        '/register': (context) => const RegistrationScreen(),
        '/patient_home': (context) => const PatientHomeScreen(),
        '/search_doctors': (context) => const SearchDoctorsScreen(),
        '/doctor_home': (context) => const DoctorHomeScreen(),
        '/doctor_appointments': (context) => const DoctorAppointmentsScreen(),
        '/doctor_details': (context) {
          final int? doctorUserId = ModalRoute.of(context)?.settings.arguments as int?;
          if (doctorUserId == null) {
            return Scaffold( appBar: AppBar(title: const Text('Error')), body: Center(child: Text('Doctor ID is required.')),);
          }
          return DoctorDetailsScreen(doctorUserId: doctorUserId);
        },
        '/my_appointments': (context) => const MyAppointmentsScreen(),
      },
      debugShowCheckedModeBanner: false,
    );
  }
}