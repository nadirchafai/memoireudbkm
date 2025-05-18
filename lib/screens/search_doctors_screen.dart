import 'dart:math';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:medical_app/models/doctor.dart'; // Import Doctor model
// import 'package:medical_app/models/speciality.dart'; // Import Speciality model (if needed for filter UI)
// import 'package:medical_app/models/address.dart'; // Import Address model (if needed for display structure)

// Import screen navigated to from here
import 'package:medical_app/screens/doctor_details_screen.dart'; // For navigating to doctor details

class SearchDoctorsScreen extends StatefulWidget {
  const SearchDoctorsScreen({Key? key}) : super(key: key);

  @override
  _SearchDoctorsScreenState createState() => _SearchDoctorsScreenState();
}

class _SearchDoctorsScreenState extends State<SearchDoctorsScreen> {
  List<Doctor> _doctors = []; // List to hold fetched doctors
  bool _isLoading = true; // Loading state
  String? _errorMessage; // Error message if fetching fails

  // TODO: Add controllers for search text field and dropdown for speciality filter later
  // final TextEditingController _searchController = TextEditingController();
  // String? _selectedSpecialityId; // For filter


  @override
  void initState() {
    super.initState();
    _fetchDoctors(); // Fetch doctors when the screen initializes
    // TODO: Add listeners for search/filter controllers if you add them
    // _searchController.addListener(_onSearchChanged);
  }

  // TODO: Implement search/filter logic here
  // void _onSearchChanged() {
  //   // Debounce the search to avoid too many API calls
  //   // Then call _fetchDoctors with search parameter
  //   _fetchDoctors(searchQuery: _searchController.text);
  // }


  // Function to fetch doctors from the backend
  // Add optional parameters for search/filter
  Future<void> _fetchDoctors({String? searchQuery, String? specialityId}) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _doctors = []; // Clear previous list before fetching
    });

    // API Endpoint URL for fetching doctors
    // Adjust IP as needed (10.0.2.2 for Android Emulator)
    String apiUrl = 'http://10.0.2.2/medical_api/api/doctors/read.php';
    // final String apiUrl = 'http://localhost/medical_api/api/doctors/read.php'; // For iOS Sim or Web


    // Build query parameters for filtering
    Map<String, String> queryParams = {};
    if (searchQuery != null && searchQuery.isNotEmpty) {
      queryParams['search'] = searchQuery;
    }
    if (specialityId != null && specialityId.isNotEmpty) {
      queryParams['speciality_id'] = specialityId;
    }

    // Add query parameters to the URL if they exist
    if (queryParams.isNotEmpty) {
      apiUrl += '?' + Uri(queryParameters: queryParams).query;
    }

    print('Fetching doctors from: $apiUrl'); // Debugging URL


    try {
      final response = await http.get(Uri.parse(apiUrl));

      if (response.statusCode == 200) {
        // Success - Parse the list of doctors
        final responseBody = jsonDecode(response.body);
        if (responseBody['success'] == true && responseBody['data'] != null) {
          List<dynamic> doctorsJson = responseBody['data'];
          List<Doctor> fetchedDoctors = doctorsJson.map((json) => Doctor.fromJson(json)).toList();

          setState(() {
            _doctors = fetchedDoctors;
            _isLoading = false;
          });
        } else if (response.statusCode == 404) {
          // Backend reported 404 (Not Found) - No doctors found
          setState(() {
            _doctors = []; // Empty the list
            _isLoading = false;
            _errorMessage = responseBody['message'] ?? 'No doctors found.'; // Backend message usually is "Aucun médecin trouvé."
          });
          print('API 404: No doctors found: ${responseBody['message']}');
        }
        else {
          // Backend reported success: false or unexpected structure, or non-404 but not 200
          // Attempt to decode response body for error message even on non-200 status
          final responseBody = jsonDecode(response.body); // Decode even on error status
          setState(() {
            _doctors = [];
            _isLoading = false;
            _errorMessage = responseBody['message'] ?? 'Failed to load doctors. Status: ${response.statusCode}'; // Include status code
          });
          print('API Error: Status: ${response.statusCode}, Body: ${response.body}');
        }
      } else {
        // Non-200 or Non-404 status code (e.g., 500, 503, network error caught below)
        // Attempt to decode response body for error message even on error status
        String errorMsg = 'Server error occurred. Status: ${response.statusCode}';
        try {
          final responseBody = jsonDecode(response.body);
          errorMsg = responseBody['message'] ?? errorMsg;
        } catch(e) {
          // If body is not JSON, use generic message
        }
        setState(() {
          _isLoading = false;
          _errorMessage = errorMsg;
        });
        print('Network Error: An error occurred during fetch: ${e.toString()}'); // More descriptive error
      }

    } catch (e) {
      // Handle network or other errors (e.g., cannot connect to host, JSON parsing error)
      setState(() {
        _isLoading = false;
        _errorMessage = 'An error occurred: ${e.toString()}';
      });
      print('Error fetching doctors: $e');
    }
  }


  @override
  void dispose() {
    // Clean up controllers if you add any for search later
    // _searchController.dispose();
    super.dispose();
  }


  @override
  Widget build(BuildContext context) {
    // Get current theme colors
    final Color primaryColor = Theme.of(context).colorScheme.primary;
    final Color onPrimaryColor = Theme.of(context).colorScheme.onPrimary; // For text/icons on primary color


    return Scaffold(
      appBar: AppBar(
        title: const Text('Find a Doctor'), // ابحث عن طبيب
        // TODO: Add Search and Filter UI elements here (e.g., search bar, dropdown)
        // actions: [
        //   IconButton(
        //     icon: Icon(Icons.search),
        //     onPressed: () {
        //       // Show search bar or dialog
        //     },
        //   ),
        //   // Add filter button
        // ],
      ),
      body: Column( // Use Column to hold search UI (later) and the list
        children: [
          // TODO: Add Search Text Field and Speciality Dropdown here (Placeholder)
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              // controller: _searchController, // TODO: Implement search controller
              decoration: InputDecoration(
                hintText: 'Search by name, specialty...', // ابحث بالاسم، التخصص...
                prefixIcon: Icon(Icons.search, color: primaryColor),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.0),
                ),
                // suffixIcon: IconButton( // Optional clear button
                //   icon: Icon(Icons.clear),
                //   onPressed: () { /* _searchController.clear(); _fetchDoctors(); */ },
                // ),
              ),
              onSubmitted: (value) {
                // TODO: Call _fetchDoctors with search query: _fetchDoctors(searchQuery: value);
                print('Search submitted: $value');
              },
            ),
          ),
          // TODO: Add Dropdown for Speciality filter

          // Expanded widget is necessary for ListView/GridView inside a Column
          Expanded(
            child: _isLoading // Check loading state
                ? const Center(child: CircularProgressIndicator()) // Show loading indicator
                : _errorMessage != null // Check error state
                ? Center( // Show error message
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Error: $_errorMessage',
                      style: const TextStyle(color: Colors.red, fontSize: 16),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    // Optional: Retry button
                    ElevatedButton(
                      onPressed: _fetchDoctors, // Retry the fetch
                      child: const Text('Retry'), // أعد المحاولة
                    ),
                  ],
                ),
              ),
            )
                : _doctors.isEmpty // Check if doctor list is empty after loading
                ? const Center( // Show message if no doctors found
              child: Text('No doctors available at the moment.'), // لا يوجد أطباء متاحون حالياً
            )
                : ListView.builder( // Display the list of doctors
              padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0), // Add padding around the list
              itemCount: _doctors.length,
              itemBuilder: (context, index) {
                final doctor = _doctors[index];
                // Add a Key for each item to help Flutter with list performance/stability
                return Card( // Use Card for better visual separation (theme applied from main.dart)
                  key: ValueKey(doctor.userId), // Use doctor's user ID as Key
                  elevation: 3.0, // Slightly more elevation for cards
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(12.0), // Padding inside the ListTile
                    // Leading icon (optional)
                    leading: CircleAvatar(
                      // TODO: Replace with doctor.profilePictureUrl if available and implement image loading
                      backgroundColor: Theme.of(context).colorScheme.secondary.withOpacity(0.2), // Lighter accent color
                      child: Icon(Icons.person_outline, color: Theme.of(context).colorScheme.secondary),
                      radius: 28, // Slightly larger avatar
                    ),
                    title: Text(
                      doctor.fullName, // Use the getter for full name
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Column( // Use column for multiple lines in subtitle
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text(
                          doctor.speciality.nomSpecialite, // Speciality name
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.grey[700],
                          ),
                        ),
                        if (doctor.address != null && doctor.address!.ville != null && doctor.address!.ville!.isNotEmpty) // Show address if available
                          Padding(
                            padding: const EdgeInsets.only(top: 4.0),
                            child: Row(
                              children: [
                                Icon(Icons.location_on_outlined, size: 16, color: Colors.grey[600]),
                                const SizedBox(width: 4),
                                Text(
                                  '${doctor.address!.ville}', // Safely access city
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        // Add other details like description summary or phone if needed (be mindful of privacy)
                      ],
                    ),
                    // Optional: Trailing icon
                    trailing: Icon(Icons.arrow_forward_ios, color: Theme.of(context).colorScheme.primary),
                    // Action when tapping on a doctor in the list
                    onTap: () {
                      // Navigate to Doctor Details Screen, passing the doctor's user ID
                      print('Tapped on Doctor: ${doctor.fullName}, ID: ${doctor.userId}');
                      // Using pushNamed to keep SearchDoctorsScreen in the navigation stack
                      Navigator.pushNamed(context, '/doctor_details', arguments: doctor.userId); // Pass doctor's user ID
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}