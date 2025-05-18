import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:provider/provider.dart'; // Import provider package

import 'package:medical_app/models/doctor.dart'; // Import Doctor model
import 'package:medical_app/models/availability_slot.dart'; // Import AvailabilitySlot model

// Import your UserProvider
import 'package:medical_app/providers/user_provider.dart';


class DoctorDetailsScreen extends StatefulWidget {
  // This screen expects the doctor's user_id as an argument
  final int doctorUserId;

  const DoctorDetailsScreen({Key? key, required this.doctorUserId}) : super(key: key);

  @override
  _DoctorDetailsScreenState createState() => _DoctorDetailsScreenState();
}

class _DoctorDetailsScreenState extends State<DoctorDetailsScreen> {
  // State for general screen loading (e.g., during initial fetches or booking)
  bool _isLoading = true; // General loading state

  // State for Doctor Details fetch
  Doctor? _doctorDetails;
  // State for specific error message for doctor details fetch
  String? _doctorErrorMessage; // Specific error message for doctor details fetch

  // State for general error message from any operation (fetch or booking)
  String? _errorMessage; // General error message (can hold doctor error or availability error or booking error)


  // State for Availability fetch
  Map<String, List<AvailabilitySlot>> _groupedAvailability = {}; // To hold availability grouped by day
  bool _isAvailabilityLoading = true; // Specific loading state for availability fetch (used for initial indicator and section)
  String? _availabilityErrorMessage; // Specific error message for availability fetch


  // State for selected appointment time
  // Will store the full selected DateTime including date and time
  DateTime? _selectedAppointmentDateTime; // To store the final selected date and time


  @override
  void initState() {
    super.initState();
    // Fetch doctor details and availability concurrently
    _fetchInitialData(); // Call combined initial data fetch
  }

  // Combined function to fetch doctor details AND availability initially
  Future<void> _fetchInitialData() async {
    setState(() {
      _isLoading = true; // Set general loading to true
      _errorMessage = null; // Clear previous general errors
      _doctorDetails = null; // Clear previous doctor data
      _doctorErrorMessage = null; // Clear specific doctor error
      _groupedAvailability = {}; // Clear previous availability data
      _selectedAppointmentDateTime = null; // Clear selected time

      _isAvailabilityLoading = true; // Set specific availability loading to true
      _availabilityErrorMessage = null; // Clear previous specific availability errors
    });

    // API Endpoint URLs
    final String doctorApiUrl = 'http://10.0.2.2/medical_api/api/doctors/read_single.php?user_id=${widget.doctorUserId}';
    final String availabilityApiUrl = 'http://10.0.2.2/medical_api/api/availability/read.php?medecin_id=${widget.doctorUserId}';


    // Use temporary error variables for individual fetches within this function scope
    String? tempDoctorError;
    String? tempAvailabilityError;


    try {
      // --- Fetch Doctor Details ---
      final doctorResponse = await http.get(Uri.parse(doctorApiUrl));
      final doctorResponseBody = jsonDecode(doctorResponse.body);

      if (doctorResponse.statusCode == 200 && doctorResponseBody['success'] == true && doctorResponseBody['data'] != null) {
        _doctorDetails = Doctor.fromJson(doctorResponseBody['data']);
      } else {
        // Handle specific doctor details error
        tempDoctorError = doctorResponseBody['message'] ?? 'Failed to load doctor details.';
        print('Doctor Details API Error: Status: ${doctorResponse.statusCode}, Body: ${doctorResponseBody.body}');
      }

      // --- Fetch Availability ---
      final availabilityResponse = await http.get(Uri.parse(availabilityApiUrl));
      final availabilityResponseBody = jsonDecode(availabilityResponse.body);

      if (availabilityResponse.statusCode == 200 && availabilityResponseBody['success'] == true && availabilityResponseBody['data'] != null) {
        List<dynamic> availabilityJson = availabilityResponseBody['data'];
        List<AvailabilitySlot> fetchedSlots = availabilityJson.map((json) => AvailabilitySlot.fromJson(json)).toList();

        // Group slots by day of the week
        Map<String, List<AvailabilitySlot>> grouped = {};
        for (var slot in fetchedSlots) {
          if (!grouped.containsKey(slot.jourSemaine)) {
            grouped[slot.jourSemaine] = [];
          }
          grouped[slot.jourSemaine]!.add(slot);
        }
        _groupedAvailability = grouped; // Assign to state variable
        _isAvailabilityLoading = false; // Clear specific availability loading

      } else if (availabilityResponse.statusCode == 404) {
        // Backend reported 404 (No Availability) - This is not a critical error, just no data
        _groupedAvailability = {}; // Keep empty
        _isAvailabilityLoading = false; // Clear specific availability loading
        _availabilityErrorMessage = availabilityResponseBody['message'] ?? 'No availability found.'; // Set specific availability message
        print('Availability API: No availability found.');
      }
      else {
        // Backend reported success: false or non-404 status code
        tempAvailabilityError = availabilityResponseBody['message'] ?? 'Failed to load availability.';
        print('Availability API Error: Status: ${availabilityResponse.statusCode}, Body: ${availabilityResponseBody.body}');
        _isAvailabilityLoading = false; // Clear specific availability loading
      }


    } catch (e) {
      // Handle network or other errors during fetches
      tempDoctorError = tempDoctorError ?? 'Network error fetching doctor details: ${e.toString()}'; // Assign network error if no API error
      tempAvailabilityError = tempAvailabilityError ?? 'Network error fetching availability: ${e.toString()}'; // Assign network error if no API error

      print('Error during initial data fetching: $e');
    } finally {
      // Set overall loading to false and combine error messages
      setState(() {
        _isLoading = false; // Set general loading to false
        // Combine errors - Prioritize doctor error if doctorDetails is null
        _errorMessage = (_doctorDetails == null && tempDoctorError != null) ? tempDoctorError : tempAvailabilityError;

        // Keep specific availability error if it occurred (even if doctor loaded)
        _availabilityErrorMessage = _availabilityErrorMessage ?? tempAvailabilityError;
      });
    }
  }


  // Function to show a dialog for choosing time and date (simplified)
  Future<void> _selectAppointmentDateTime(BuildContext context, AvailabilitySlot slot) async {
    TextEditingController dateController = TextEditingController();
    TextEditingController timeController = TextEditingController();

    // Ensure controllers are disposed after the dialog, regardless of how it's closed
    // Using a try-finally block or disposing in the actions is more reliable.
    // Let's dispose them in the actions.


    final DateTime? confirmedDateTime = await showDialog<DateTime>( // Specify the return type as DateTime?
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Select Appointment Date and Time'), // اختر تاريخ ووقت الموعد
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              // Input for Date (Simplified - expects YYYY-MM-DD format)
              TextField(
                controller: dateController,
                keyboardType: TextInputType.datetime,
                decoration: InputDecoration(labelText: 'Date (${slot.jourSemaine}, YYYY-MM-DD)'), // التاريخ (اليوم، سنة-شهر-يوم)
              ),
              const SizedBox(height: 12),
              // Input for Time (Simplified - expects HH:MM:SS format)
              TextField(
                controller: timeController,
                keyboardType: TextInputType.datetime,
                decoration: InputDecoration(labelText: 'Time (HH:MM:SS)'), // الوقت (ساعة:دقيقة:ثانية)
              ),
              // TODO: Add validation to check if selected time is within the slot's heureDebut and heureFin
            ],
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'), // إلغاء
              onPressed: () {
                dateController.dispose(); // Dispose controllers
                timeController.dispose();
                Navigator.of(context).pop(null); // Return null on cancel
              },
            ),
            ElevatedButton(
              child: const Text('Confirm'), // تأكيد
              onPressed: () {
                String fullDateTimeString = '${dateController.text.trim()} ${timeController.text.trim()}';
                try {
                  DateTime parsedDateTime = DateTime.parse(fullDateTimeString);

                  if (parsedDateTime.isBefore(DateTime.now())) {
                    _showSnackBar('Selected time is in the past.'); // الوقت المحدد في الماضي
                    // Don't pop here if you want to stay in dialog on error.
                    // For this example, we pop anyway on invalid input after showing snackbar.
                    dateController.dispose(); // Dispose controllers
                    timeController.dispose();
                    return Navigator.of(context).pop(null); // Return null if validation fails
                  }

                  // TODO: Add check if the day of parsedDateTime matches slot.jourSemaine (requires more date logic)
                  // TODO: Add check if the time falls within slot.heureDebut and slot.heureFin (requires more time logic)

                  // Validation successful, dispose controllers and pop dialog, returning the selected DateTime
                  dateController.dispose(); // Dispose controllers
                  timeController.dispose();
                  Navigator.of(context).pop(parsedDateTime); // Return the selected DateTime


                } catch (e) {
                  _showSnackBar('Invalid date or time format. Use YYYY-MM-DD HH:MM:SS'); // تنسيق تاريخ أو وقت غير صالح
                  // Pop anyway on invalid input for this example
                  dateController.dispose(); // Dispose controllers
                  timeController.dispose();
                  Navigator.of(context).pop(null); // Return null if parsing fails
                }
              },
            ),
          ],
        );
      },
    );

    // This code runs AFTER the dialog is closed (either via pop(value) or tapping outside)

    // Check if a DateTime was returned (meaning 'Confirm' was pressed with valid data)
    if (confirmedDateTime != null) {
      setState(() {
        _selectedAppointmentDateTime = confirmedDateTime; // Update state with the confirmed DateTime
      });
      // Now that state is updated and dialog is closed, the build method will rebuild
      // and the Book Appointment button should become enabled.
    }
  }

  // Function to handle booking the appointment
  Future<void> _bookAppointment() async {
    // Check if a date and time has been selected (should be guaranteed by button state)
    if (_selectedAppointmentDateTime == null) {
      _showSnackBar('Please select a date and time first.'); // Should not happen if button is enabled correctly
      return;
    }

    // Check if doctor details are loaded (should be guaranteed)
    if (_doctorDetails == null) {
      _showSnackBar('Doctor details not loaded.'); // Should not happen
      return;
    }

    // Set general loading state to true for the booking process
    setState(() {
      _isLoading = true; // Show general loading indicator during booking
      _errorMessage = null; // Clear previous error message before booking
    });

    // --- Get patientId from UserProvider ---
    // We need to access the provider here to get the logged-in user's ID.
    // listen: false is used because we are inside an event handler (onPressed)
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final int? patientId = userProvider.userId; // Get the logged-in user's ID from Provider

    // Check if patientId is available and user is a patient
    if (patientId == null || !userProvider.isPatient) {
      _showSnackBar('Error: Patient not logged in.'); // رسالة خطأ إذا لم يكن المستخدم مريضاً
      setState(() { _isLoading = false; }); // Stop loading
      // TODO: Maybe navigate back to login screen
      return;
    }

    final int medecinId = widget.doctorUserId; // Doctor's user ID from widget

    // Format the selected DateTime for the API (YYYY-MM-DD HH:MM:SS)
    // Using toIso8601String().split('.')[0] gives YYYY-MM-DDTHH:MM:SS - need to replace T with space
    final String appointmentDateTimeString = _selectedAppointmentDateTime!.toIso8601String().split('.')[0].replaceFirst('T', ' ');


    // Prepare data for API call (matching api/appointments/create.php)
    var data = {
      "patient_id": patientId, // <<< Use the actual patient ID from Provider
      "medecin_id": medecinId,
      "date_rendezvous": appointmentDateTimeString,
      // Add optional notes if you have a UI field for it
      // "notes_patient": "...",
    };

    // API Endpoint URL for booking appointment
    final String apiUrl = 'http://10.0.2.2/medical_api/api/appointments/create.php'; // Adjust IP as needed


    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
          // TODO: Add Authorization Header with User Token if using token-based auth
          // If using token, you would get it from userProvider.user?.token
          // 'Authorization': 'Bearer ${userProvider.user?.token}',
        },
        body: jsonEncode(data),
      );

      // Attempt to decode response body for potential error message even on non-201 status
      Map<String, dynamic>? responseBody; // Defined responseBody here
      try { responseBody = jsonDecode(response.body); } catch(e) { /* ignore */ } // Safely decode

      if (response.statusCode == 201) {
        // Booking successful
        _showSnackBar(responseBody?['message'] ?? 'Appointment booked successfully!'); // Use ?. for safe access
        print('Booking successful! Appointment ID: ${responseBody?['id']}'); // Use ?. for safe access

        // Reset selected time and optionally refresh availability or navigate
        setState(() {
          _selectedAppointmentDateTime = null; // Reset selected time after successful booking
        });

        // TODO: Optionally refresh availability or navigate to appointments list
        // Refresh availability after successful booking to show the time slot as booked
        // This requires implementing the logic in availability/read.php to return booked slots too
        // _fetchAvailability(widget.doctorUserId); // Refetch availability to show booked/updated status
        // Navigator.pushReplacementNamed(context, '/my_appointments'); // Navigate to appointments list

      } else {
        // Booking failed (e.g., 409 Conflict, 400 Bad Request, 500 Error)
        // Set general error message
        setState(() {
          _errorMessage = responseBody?['message'] ?? 'Failed to book appointment: Status ${response.statusCode}'; // Use ?. for safe access
        });
        _showSnackBar(_errorMessage!); // Show specific backend message
        print('Booking failed. Status: ${response.statusCode}, Body: ${response.body}');
      }

    } catch (e) {
      // Handle network or other errors
      setState(() {
        _errorMessage = 'An error occurred during booking: ${e.toString()}'; // Set general error message
      });
      _showSnackBar(_errorMessage!);
      print('Error during booking: $e');
    } finally {
      // Set general loading state to false after booking attempt
      setState(() {
        _isLoading = false; // Hide general loading indicator
      });
    }
  }

  // Helper function to show messages using SnackBar
  void _showSnackBar(String message) {
    if (mounted) { // Check if the widget is still in the widget tree
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 4), // Increased duration
        ),
      );
    }
  }


  @override
  Widget build(BuildContext context) {
    // Use a single loading variable for all async operations on this screen
    // Combine loading/error states for initial display and booking process
    // _isLoading handles both initial data fetches AND booking process state
    // _isAvailabilityLoading and _availabilityErrorMessage are specific for the Availability section UI state

    // Determine if the initial data loading phase is still active
    bool isInitialDataLoading = _isLoading && _doctorDetails == null && _errorMessage == null;
    // Determine if there's a general error to display prominently
    bool hasGeneralError = _errorMessage != null;


    Widget bodyContent;

    // Show initial loading spinner only if doctor details haven't loaded yet AND no general error
    if (isInitialDataLoading) {
      bodyContent = const Center(child: CircularProgressIndicator());
    } else if (hasGeneralError) { // Check if there's a general error message
      bodyContent = Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Error: $_errorMessage', // Use the general error message
                style: const TextStyle(color: Colors.red, fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              // Retry button tries to fetch both doctor details and availability again
              ElevatedButton(
                onPressed: () {
                  // Call the initial data fetch function
                  _fetchInitialData(); // Corrected function name
                },
                child: const Text('Retry'), // أعد المحاولة
              ),
            ],
          ),
        ),
      );
    } else if (_doctorDetails == null) {
      // This state should ideally not be reached if there's no error and not loading
      // But as a safeguard, show a message if doctor details are unexpectedly null
      bodyContent = const Center(child: Text('Doctor data not available.')); // بيانات الطبيب غير متاحة
    }
    else {
      // Display doctor details AND availability
      final doctor = _doctorDetails!; // Use non-nullable version after checks

      // Define a fixed order for days of the week
      final List<String> orderedDays = ['Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi', 'Samedi', 'Dimanche'];

      // Filter and sort the grouped availability by the defined order
      List<MapEntry<String, List<AvailabilitySlot>>> sortedAvailability = _groupedAvailability.entries.toList();
      sortedAvailability.sort((a, b) {
        int indexA = orderedDays.indexOf(a.key);
        int indexB = orderedDays.indexOf(b.key);
        if (indexA == -1) return 1; // Unknown days last
        if (indexB == -1) return -1;
        return indexA.compareTo(indexB);
      });


      bodyContent = SingleChildScrollView( // Allow scrolling
        key: const ValueKey('doctorDetailsContent'), // Key for the main content area
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, // Align content to the start (left)
          children: <Widget>[
            // --- Doctor Details Section ---
            Text(
              '${doctor.nom} ${doctor.prenom}',
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),

            // Speciality
            Text(
              'Speciality: ${doctor.speciality.nomSpecialite}', // التخصص
              style: const TextStyle(fontSize: 18, fontStyle: FontStyle.italic, color: Colors.grey),
            ),
            const SizedBox(height: 16),

            // Description
            if (doctor.description != null && doctor.description!.isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('About the Doctor:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)), // عن الطبيب
                  const SizedBox(height: 4),
                  Text(
                    doctor.description!,
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 16),
                ],
              ),

            // Contact Info (Optional - display based on privacy)
            const Text('Contact Info:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)), // معلومات الاتصال
            const SizedBox(height: 4),
            if (doctor.email != null && doctor.email!.isNotEmpty)
              Text('Email: ${doctor.email!}', style: const TextStyle(fontSize: 16)), // البريد الإلكتروني
            if (doctor.numTelephone != null && doctor.numTelephone!.isNotEmpty)
              Text('Phone: ${doctor.numTelephone!}', style: const TextStyle(fontSize: 16)), // رقم الهاتف
            const SizedBox(height: 16),

            // Address
            if (doctor.address != null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Clinic Address:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)), // عنوان العيادة
                  const SizedBox(height: 4),
                  if (doctor.address!.rue != null && doctor.address!.rue!.isNotEmpty)
                    Text('Street: ${doctor.address!.rue!}', style: const TextStyle(fontSize: 16)), // الشارع
                  if (doctor.address!.quartier != null && doctor.address!.quartier!.isNotEmpty)
                    Text('District: ${doctor.address!.quartier!}', style: const TextStyle(fontSize: 16)), // الحي
                  if (doctor.address!.ville != null && doctor.address!.ville!.isNotEmpty)
                    Text('City: ${doctor.address!.ville!}', style: const TextStyle(fontSize: 16)), // المدينة
                  const SizedBox(height: 16),
                ],
              ),

            if (doctor.cin != null && doctor.cin!.isNotEmpty) // Assuming cin is used for certificate_url
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Certificate Identifier:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)), // معرف الشهادة
                  const SizedBox(height: 4),
                  Text(doctor.cin!, style: const TextStyle(fontSize: 16)),
                  const SizedBox(height: 16),
                ],
              ),
            // If you added profilePictureUrl column and fetch it
            // if (doctor.profilePictureUrl != null && doctor.profilePictureUrl!.isNotEmpty)
            //  Column(
            //    crossAxisAlignment: CrossAxisAlignment.start,
            //    children: [
            //       const Text('Profile Picture:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            //       const SizedBox(height: 8),
            //       Image.network(doctor.profilePictureUrl!), // Use Image.network to display the image
            //       const SizedBox(height: 16),
            //    ],
            //  ),

            const Divider(height: 32, thickness: 1), // Separator

            // --- Availability Section ---
            const Text('Availability:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)), // أوقات التوفر
            const SizedBox(height: 8),

            // Display Availability state and list
            // Use specific availability loading/error for this section
            if (_isAvailabilityLoading) // Use specific availability loading
              const Center(child: CircularProgressIndicator()) // Maybe use a smaller indicator here
            else if (_availabilityErrorMessage != null) // Use specific availability error
              Text(
                'Error loading availability: $_availabilityErrorMessage',
                style: const TextStyle(fontSize: 16, color: Colors.red),
              )
            else if (_groupedAvailability.isEmpty) // Check if availability is empty
                const Text(
                  'No availability details available.',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                )
              else // Display grouped availability
                Column( // Column for ALL grouped availability
                  key: const ValueKey('groupedAvailabilityList'), // Key for the outer availability column
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: sortedAvailability.map((entry) {
                    String day = entry.key;
                    List<AvailabilitySlot> slots = entry.value;
                    return Column( // Column for each day (e.g., "Lundi")
                      key: ValueKey(day), // Key for the daily column
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(day, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)), // Day name
                        const SizedBox(height: 4),
                        Column( // Inner Column (wraps time slots)
                          key: ValueKey('${day}_slots'), // Key for the inner slots column
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: slots.map((slot) {
                            // Make each slot time range clickable
                            return InkWell(
                              key: ValueKey(slot.id), // Key for individual slot
                              onTap: () {
                                // Call the function to select date and time for THIS slot
                                _selectAppointmentDateTime(context, slot);
                              },
                              child: Padding( // Add some padding for tap area
                                padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
                                child: Text(
                                  '${slot.heureDebut.substring(0, 5)} - ${slot.heureFin.substring(0, 5)}', // Format time to HH:MM
                                  style: TextStyle(
                                      fontSize: 16,
                                      // Optional: Highlight selected slot (basic check if selected time is within this slot's start time)
                                      // This highlighting logic is complex and needs proper date/time comparison
                                      // For now, just change color if ANY time is selected
                                      color: _selectedAppointmentDateTime != null
                                          ? Colors.blue // Highlight if a time is selected (basic indicator)
                                          : Colors.black
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 12), // Spacing after each day's slots
                      ],
                    );
                  }).toList(),
                ),

            const SizedBox(height: 24),

            // --- Booking Button ---
            Center(
              // Button is enabled only if availability is loaded, not empty, AND a time is selected, AND not currently booking
              child: ElevatedButton(
                // Disable button if availability is empty, or if no time is selected, or if general loading is true (booking or initial fetch)
                onPressed: _groupedAvailability.isEmpty || _selectedAppointmentDateTime == null || _isLoading
                    ? null // Disable button
                    : _bookAppointment, // Call the booking function when enabled and pressed
                child: _isLoading // Show loading indicator on button if overall loading is true
                    ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2.0,
                  ),
                )
                    : const Text('Book Appointment'), // احجز موعد
              ),
            ),
          ],
        ),
      );
    }


    return Scaffold(
      appBar: AppBar(
        title: const Text('Doctor Details'), // عنوان الشاشة: تفاصيل الطبيب
      ),
      body: bodyContent, // Display the content based on loading/error/data state
    );
  }
}