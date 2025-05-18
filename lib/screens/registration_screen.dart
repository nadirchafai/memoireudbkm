import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:provider/provider.dart'; // Import provider package
import 'package:medical_app/models/speciality.dart'; // Import the Speciality model

// Import the screens you navigate to
// import 'package:medical_app/screens/login_screen.dart'; // Already handled by named route

// Import your UserProvider
import 'package:medical_app/providers/user_provider.dart';


class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({Key? key}) : super(key: key);

  @override
  _RegistrationScreenState createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  // Controllers for text fields
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController(); // Optional phone

  // New Controllers for Doctor-specific fields (assuming CIN is handled elsewhere or optional now)
  // These fields are added to the UI and sent to backend IF role is 'medecin'
  final TextEditingController _certificateUrlController = TextEditingController(); // For certificate URL (or name)
  final TextEditingController _profilePictureUrlController = TextEditingController(); // For profile picture URL


  // Dropdown value for role
  String? _selectedRole = 'patient'; // Default role is patient

  // State for Specialities dropdown
  List<Speciality> _specialities = []; // List to hold fetched specialities
  Speciality? _selectedSpeciality; // To hold the selected speciality object
  bool _specialitiesLoading = true; // Loading state for specialities fetch
  String? _specialitiesLoadingError; // Error message if fetching specialities fails


  // Loading state for registration process
  bool _isRegistering = false; // Specific loading state for the registration button


  @override
  void initState() {
    super.initState();
    _fetchSpecialities(); // Fetch specialities when the screen initializes
  }

  // Function to fetch specialities from the backend
  Future<void> _fetchSpecialities() async {
    setState(() {
      _specialitiesLoading = true;
      _specialitiesLoadingError = null;
      _specialities = []; // Clear previous list
    });

    // API Endpoint URL for fetching specialities
    // Adjust IP as needed (10.0.2.2 for Android Emulator)
    final String apiUrl = 'http://10.0.2.2/medical_api/api/specialities/read.php';
    // final String apiUrl = 'http://localhost/medical_api/api/specialities/read.php'; // For iOS Sim or Web

    try {
      final response = await http.get(Uri.parse(apiUrl));

      if (response.statusCode == 200) {
        // Success - Parse the list of specialities
        final responseBody = jsonDecode(response.body);
        if (responseBody['success'] == true && responseBody['data'] != null) {
          List<dynamic> specialitiesJson = responseBody['data'];
          List<Speciality> fetchedSpecialities = specialitiesJson.map((json) => Speciality.fromJson(json)).toList();

          setState(() {
            _specialities = fetchedSpecialities;
            _specialitiesLoading = false;
            // Optional: Automatically select the first speciality if role is doctor and list is not empty
            if (_selectedRole == 'medecin' && _specialities.isNotEmpty && _selectedSpeciality == null) {
              // _selectedSpeciality = _specialities.first; // Uncomment if you want auto-select
            }
          });
        } else {
          // Backend reported success but no data (e.g., 404 from backend for empty table)
          setState(() {
            _specialities = [];
            _specialitiesLoading = false;
            _specialitiesLoadingError = responseBody?['message'] ?? 'No specialities found.'; // Use ?. for safe access
          });
          print('No specialities found: ${responseBody?['message']}'); // Use ?. for safe access
        }
      } else {
        // Non-200 status code (e.g., 404, 500)
        // Attempt to decode response body for error message even on non-200 status
        String errorMsg = 'Failed to load specialities. Status: ${response.statusCode}';
        try { // More robust decoding attempt
          final errorBody = jsonDecode(response.body);
          errorMsg = errorBody?['message'] ?? errorMsg; // Use ?. for safe access
        } catch (e) { /* ignore */ }

        setState(() {
          _specialitiesLoading = false;
          _specialitiesLoadingError = errorMsg;
        });
        print('Failed to load specialities. Status: ${response.statusCode}, Body: ${response.body}');
      }

    } catch (e) {
      // Handle network or other errors
      setState(() {
        _specialitiesLoading = false;
        _specialitiesLoadingError = 'An error occurred while loading specialities: ${e.toString()}';
      });
      print('Error fetching specialities: $e');
    }
  }


  // Function to handle registration
  Future<void> _register() async {
    FocusScope.of(context).unfocus();

    // Set specific registration loading state
    setState(() {
      _isRegistering = true; // Show loading indicator for registration button
    });

    // Get data from controllers
    String firstName = _firstNameController.text.trim();
    String lastName = _lastNameController.text.trim();
    String email = _emailController.text.trim();
    String password = _passwordController.text; // Don't trim password
    String phone = _phoneController.text.trim();

    // Read doctor-specific fields (even if role is patient, we read but only send if role is medecin)
    String certificateUrl = _certificateUrlController.text.trim();
    String profilePictureUrl = _profilePictureUrlController.text.trim();


    String? role = _selectedRole;

    // Basic validation
    if (firstName.isEmpty || lastName.isEmpty || email.isEmpty || password.isEmpty || role == null) {
      _showSnackBar('Please fill all required fields.');
      // Reset specific registration loading state
      setState(() { _isRegistering = false; });
      return;
    }

    // Prepare data for API call
    Map<String, dynamic> data = {
      "nom": firstName,
      "prenom": lastName,
      "email": email,
      "mot_de_passe": password,
      "role": role,
      if (phone.isNotEmpty) "num_telephone": phone, // Conditionally add if not empty
    };

    // Conditionally add doctor-specific fields if role is 'medecin'
    if (role == 'medecin') {
      // Check if a speciality is selected when role is doctor
      if (_selectedSpeciality == null) {
        _showSnackBar('Please select a Speciality for Doctor.');
        // Reset specific registration loading state
        setState(() { _isRegistering = false; });
        return;
      }
      // Add selected speciality ID (should be int)
      data["specialite_id"] = _selectedSpeciality!.id; // Correctly pass int ID

      // Add the new doctor-specific fields to the data map if not empty
      if (certificateUrl.isNotEmpty) data["certificate_url"] = certificateUrl;
      if (profilePictureUrl.isNotEmpty) data["profile_picture_url"] = profilePictureUrl;

      // If you add a CIN field for doctors in UI, read it and add it here
      // String cinDoctor = _cinController.text.trim();
      // if (cinDoctor.isNotEmpty) data["cin"] = cinDoctor; // Assuming PHP backend expects "cin" or "cin_medecin"
    }
    // If role is patient, you might add patient-specific fields here (e.g., cin, date_naissance)


    // API Endpoint URL for registration
    // Adjust IP as needed (10.0.2.2 for Android Emulator)
    final String apiUrl = 'http://10.0.2.2/medical_api/api/auth/register.php';
    // final String apiUrl = 'http://localhost/medical_api/api/auth/register.php'; // For iOS Sim or Web / Web


    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
          // TODO: Add Authorization Header with User Token if using token-based auth for doctor registration if needed
        },
        body: jsonEncode(data), // Data map now includes potential doctor-specific fields
      );

      // Attempt to decode response body for potential error message even on non-201 status
      Map<String, dynamic>? responseBody; // Defined responseBody here
      try {
        responseBody = jsonDecode(response.body);
      } catch(e) { /* ignore JSON decode error */ }


      if (response.statusCode == 201) {
        // Registration successful
        _showSnackBar(responseBody?['message'] ?? 'Registration successful!'); // Use ?. for safe access
        print('Registration successful!');

        // Optionally clear form and reset state after successful registration
        _firstNameController.clear();
        _lastNameController.clear();
        _emailController.clear();
        _passwordController.clear();
        _phoneController.clear();
        _certificateUrlController.clear(); // Clear the new controllers
        _profilePictureUrlController.clear(); // Clear the new controllers


        setState(() {
          _selectedRole = 'patient'; // Reset role dropdown
          _selectedSpeciality = null; // Reset selected speciality
          // Optionally re-fetch specialities if they can change
          // _fetchSpecialities();
        });

        // Navigate to login screen after successful registration
        // Using pushReplacementNamed so user cannot go back to registration with back button
        Navigator.pushReplacementNamed(context, '/login'); // <-- UNCOMMENTED


      } else {
        // Registration failed - show error message from backend
        _showSnackBar(responseBody?['message'] ?? 'Registration failed: Status ${response.statusCode}'); // Use ?. for safe access
        print('Registration failed. Status: ${response.statusCode}, Body: ${response.body}');
      }

    } catch (e) {
      // Handle network or other errors during API call
      _showSnackBar('An error occurred during registration: ${e.toString()}');
      print('Error during registration: $e');
    } finally {
      // Always reset specific registration loading state
      setState(() {
        _isRegistering = false; // Hide loading indicator
      });
    }
  }

  // Helper function to show messages using SnackBar
  void _showSnackBar(String message) {
    // Ensure the widget is still mounted before showing SnackBar
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 4), // Increased duration
        ),
      );
    }
  }

  @override
  void dispose() {
    // Clean up controllers when the widget is disposed
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _phoneController.dispose();
    _certificateUrlController.dispose(); // Dispose the new controller
    _profilePictureUrlController.dispose(); // Dispose the new controller
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Determine if specific specialities loading is happening to show inline indicator
    bool isSpecialitiesSpecificLoading = _specialitiesLoading; // Using the actual state variable

    // Determine if there's a specific error for specialities section
    String? specialitiesSpecificErrorMessage = _specialitiesLoadingError; // Using the actual state variable

    // Get current theme colors
    final Color primaryColor = Theme.of(context).colorScheme.primary;
    final Color secondaryColor = Theme.of(context).colorScheme.secondary;


    return Scaffold(
      // AppBar is optional for login/register screens, depends on design preference
      // appBar: AppBar(
      //   title: const Text('Create Account'),
      // ),
      body: SafeArea(
        child: Center( // Center the content
          child: SingleChildScrollView( // Allow scrolling
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0), // Add more padding
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center, // Center vertically
              crossAxisAlignment: CrossAxisAlignment.stretch, // Stretch horizontally
              children: <Widget>[
                // App Icon/Logo (Example)
                Icon(
                  Icons.app_registration, // Or your custom logo
                  size: 80,
                  color: primaryColor, // Use primary color from theme
                ),
                const SizedBox(height: 24.0), // Spacing after icon

                Text(
                  'Create Your Account', // عنوان الشاشة
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.displayLarge?.copyWith(
                    color: primaryColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8.0),
                Text(
                  'Join us to manage your appointments easily.', // انضم إلينا لإدارة مواعيدك بسهولة
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 32.0), // Increased spacing


                // --- Basic User Fields ---
                TextField(
                  controller: _firstNameController,
                  decoration: InputDecoration(
                    labelText: 'First Name', // الاسم الأول
                    // border: OutlineInputBorder(), // Handled by theme
                    prefixIcon: Icon(Icons.person_outline, color: primaryColor),
                  ),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 16.0),

                TextField(
                  controller: _lastNameController,
                  decoration: InputDecoration(
                    labelText: 'Last Name', // الاسم الأخير
                    // border: OutlineInputBorder(), // Handled by theme
                    prefixIcon: Icon(Icons.person, color: primaryColor),
                  ),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 16.0),

                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: 'Email', // البريد الإلكتروني
                    // border: OutlineInputBorder(), // Handled by theme
                    prefixIcon: Icon(Icons.email_outlined, color: primaryColor),
                  ),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 16.0),

                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'Password', // كلمة المرور
                    // border: OutlineInputBorder(), // Handled by theme
                    prefixIcon: Icon(Icons.lock_outline, color: primaryColor),
                    // TODO: Add suffix icon to toggle password visibility
                  ),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 16.0),

                TextField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: 'Phone Number (Optional)', // رقم الهاتف (اختياري)
                    // border: OutlineInputBorder(), // Handled by theme
                    prefixIcon: Icon(Icons.phone_outlined, color: primaryColor),
                  ),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 16.0),

                // --- Role Selection Dropdown ---
                DropdownButtonFormField<String>(
                  decoration: InputDecoration(
                    labelText: 'Register as', // التسجيل كـ
                    // border: OutlineInputBorder(), // Handled by theme
                    prefixIcon: Icon(Icons.assignment_ind_outlined, color: primaryColor),
                  ),
                  value: _selectedRole,
                  items: <String>['patient', 'medecin']
                      .map<DropdownMenuItem<String>>((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value == 'patient' ? 'Patient' : 'Doctor'),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    setState(() {
                      _selectedRole = newValue;
                      // Reset selected speciality and doctor-specific fields when role changes to patient
                      if (newValue == 'patient') {
                        _selectedSpeciality = null;
                        _certificateUrlController.clear(); // Clear new controllers
                        _profilePictureUrlController.clear(); // Clear new controllers
                      }
                      // When changing to medecin, if specialities are loaded, maybe select the first one
                      if (newValue == 'medecin' && _specialities.isNotEmpty && _selectedSpeciality == null) {
                        // Optional: Automatically select the first speciality when switching to Doctor if none is selected
                        // _selectedSpeciality = _specialities.first;
                      }
                    });
                  },
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 16.0),

                // --- Conditionally show Doctor-specific fields ---
                if (_selectedRole == 'medecin') // This block is only built if the condition is true
                  Column( // Wrap doctor-specific fields in a Column
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [ // Add children for the column

                      // Speciality Dropdown
                      // Check loading state for specialities
                      isSpecialitiesSpecificLoading // Using the actual state variable
                          ? const Center(child: Padding(padding: EdgeInsets.all(8.0), child: CircularProgressIndicator())) // Show loading for specialities
                      // Check for specific error in fetching specialities
                          : specialitiesSpecificErrorMessage != null // Using the actual state variable
                          ? Padding( // Show error message
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Text(
                          'Error loading specialities: $specialitiesSpecificErrorMessage',
                          style: const TextStyle(color: Colors.red),
                          textAlign: TextAlign.center,
                        ),
                      )
                      // Check if list is empty after loading
                          : _specialities.isEmpty
                          ? const Padding( // Show message if no specialities found
                        padding: EdgeInsets.symmetric(vertical: 8.0),
                        child: Text(
                          'No specialities available.',
                          style: TextStyle(color: Colors.orange),
                          textAlign: TextAlign.center,
                        ),
                      )
                      // Show the dropdown for selection
                          : DropdownButtonFormField<Speciality>(
                        decoration: InputDecoration(
                          labelText: 'Speciality (Required for Doctor)', // التخصص (مطلوب للطبيب)
                          // border: OutlineInputBorder(), // Handled by theme
                          prefixIcon: Icon(Icons.medical_services_outlined, color: primaryColor),
                        ),
                        // Use a unique key to reset dropdown state when items change or selected value changes
                        key: ValueKey(_selectedSpeciality?.id), // Add key
                        value: _selectedSpeciality,
                        items: _specialities.map((Speciality speciality) {
                          return DropdownMenuItem<Speciality>(
                            value: speciality,
                            child: Text(speciality.nomSpecialite),
                          );
                        }).toList(),
                        onChanged: (Speciality? newValue) {
                          setState(() {
                            _selectedSpeciality = newValue;
                          });
                        },
                        isExpanded: true, // Make the dropdown take available width
                        // Add validation indicator if speciality is required and not selected when role is doctor
                        validator: (value) {
                          if (_selectedRole == 'medecin' && value == null) {
                            return 'Please select a speciality'; // رسالة تحقق
                          }
                          return null; // OK
                        },
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),

                      const SizedBox(height: 16.0), // Spacing after Specialty Dropdown

                      // Certificate URL/Name Field (For Doctor)
                      TextField(
                        controller: _certificateUrlController,
                        keyboardType: TextInputType.url,
                        decoration: InputDecoration(
                          labelText: 'Certificate URL/Name (Optional)', // رابط/اسم الشهادة (اختياري)
                          // border: OutlineInputBorder(), // Handled by theme
                          prefixIcon: Icon(Icons.insert_drive_file_outlined, color: primaryColor),
                        ),
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 16.0), // Spacing after Certificate URL

                      // Profile Picture URL Field (For Doctor)
                      TextField(
                        controller: _profilePictureUrlController,
                        keyboardType: TextInputType.url,
                        decoration: InputDecoration(
                          labelText: 'Profile Picture URL (Optional)', // رابط صورة البروفايل (اختياري)
                          // border: OutlineInputBorder(), // Handled by theme
                          prefixIcon: Icon(Icons.image_outlined, color: primaryColor), // Or account_circle_outlined
                        ),
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 16.0), // Spacing after Profile Picture URL
                      // Add other doctor specific fields here like CIN field if you want
                      // const SizedBox(height: 12.0),
                      // TextField(...) for CIN


                    ], // End of Children for doctor-specific fields Column
                  ), // End of Column for doctor-specific fields

                const SizedBox(height: 24.0), // Spacing before the button

                // --- Registration Button ---
                // Button is enabled only if NOT currently registering
                ElevatedButton(
                  onPressed: _isRegistering ? null : _register, // Disable button when registering
                  // style is now handled by theme (elevatedButtonTheme in main.dart)
                  child: _isRegistering // Show loading indicator if registering
                      ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.0,
                    ),
                  )
                      : const Text('Register'), // Button text
                ),
                const SizedBox(height: 12.0), // Spacing

                // Link to Login Screen
                Row( // Use Row for better centering and text styling
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "Already have an account?", // هل لديك حساب؟
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[800]
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        // Navigate to Login Screen using named route, replacing registration screen
                        Navigator.pushReplacementNamed(context, '/login'); // Using pushReplacementNamed
                      },
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0), // Adjust padding
                      ),
                      child: Text(
                        'Login', // تسجيل الدخول
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