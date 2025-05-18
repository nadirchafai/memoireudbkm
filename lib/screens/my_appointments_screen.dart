import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:provider/provider.dart'; // Import provider package
import 'package:medical_app/models/appointment.dart'; // Import Appointment model

// Import your UserProvider
import 'package:medical_app/providers/user_provider.dart';


class MyAppointmentsScreen extends StatefulWidget {
  const MyAppointmentsScreen({Key? key}) : super(key: key);

  @override
  _MyAppointmentsScreenState createState() => _MyAppointmentsScreenState();
}

class _MyAppointmentsScreenState extends State<MyAppointmentsScreen> {
  List<Appointment> _appointments = []; // List to hold fetched appointments
  bool _isLoading = true; // Loading state
  String? _errorMessage; // Error message if fetching fails


  @override
  void initState() {
    super.initState();
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final int? loggedInUserId = userProvider.userId;
    print('DEBUG (MyAppointmentsScreen): Fetching appointments for patient ID: $loggedInUserId');

    if (loggedInUserId != null && userProvider.isPatient) {
      _fetchAppointments(loggedInUserId);
    } else {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error: User not logged in as Patient.';
      });
    }
  }

  Future<void> _fetchAppointments(int userId) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _appointments = [];
    });

    final String apiUrl = 'http://10.0.2.2/medical_api/api/appointments/read.php?user_id=$userId';

    try {
      final response = await http.get(Uri.parse(apiUrl));
      Map<String, dynamic>? responseBody;
      try { responseBody = jsonDecode(response.body); } catch(e) { /* ignore */ }

      if (response.statusCode == 200) {
        if (responseBody != null && responseBody['success'] == true && responseBody['data'] != null) {
          List<dynamic> appointmentsJson = responseBody['data'];
          List<Appointment> fetchedAppointments = appointmentsJson.map((json) => Appointment.fromJson(json)).toList();
          setState(() {
            _appointments = fetchedAppointments;
            _isLoading = false;
          });
        } else { // Includes 404 if success:false or data is null
          setState(() {
            _appointments = [];
            _isLoading = false;
            _errorMessage = responseBody?['message'] ?? 'No appointments found or failed to load.';
          });
          print('API Info: ${responseBody?['message']} Status: ${response.statusCode}, Body: ${response.body}');
        }
      } else {
        String errorMsg = 'Server error. Status: ${response.statusCode}';
        try { final errorBody = jsonDecode(response.body); errorMsg = errorBody['message'] ?? errorMsg; } catch(e) { /* ignore */ }
        setState(() {
          _isLoading = false;
          _errorMessage = errorMsg;
        });
        print('Network Error. Status: ${response.statusCode}. Body: ${response.body}');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'An error occurred: ${e.toString()}';
      });
      print('Error fetching appointments: ${e.toString()}');
    }
  }

  void _showSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Appointments'), // مواعيدي
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
          ? Center(
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
              ElevatedButton(
                onPressed: () {
                  final userProvider = Provider.of<UserProvider>(context, listen: false);
                  final int? loggedInUserId = userProvider.userId;
                  if (loggedInUserId != null) {
                    _fetchAppointments(loggedInUserId);
                  } else {
                    _showSnackBar('User ID not available to retry.');
                  }
                },
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      )
          : _appointments.isEmpty
          ? const Center(
        child: Text('No appointments found.'),
      )
          : ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
        itemCount: _appointments.length,
        itemBuilder: (context, index) {
          final appointment = _appointments[index];
          return Card( // Use Card for better visual separation
            key: ValueKey(appointment.id), // Use appointment ID as Key
            elevation: 3.0,
            child: ListTile(
              contentPadding: const EdgeInsets.all(12.0),
              leading: CircleAvatar( // Icon for appointment
                backgroundColor: Theme.of(context).colorScheme.secondary.withOpacity(0.2),
                child: Icon(
                  appointment.statut == 'confirme' ? Icons.check_circle_outline :
                  appointment.statut == 'annule_patient' || appointment.statut == 'annule_medecin' ? Icons.cancel_outlined :
                  appointment.statut == 'termine' ? Icons.event_available_outlined :
                  Icons.schedule_outlined, // Default for 'demande'
                  color: appointment.statut == 'confirme' ? Colors.green :
                  appointment.statut == 'annule_patient' || appointment.statut == 'annule_medecin' ? Colors.red :
                  appointment.statut == 'termine' ? Colors.blueGrey :
                  Theme.of(context).colorScheme.secondary,
                ),
                radius: 28,
              ),
              title: Text(
                appointment.medecin?.fullName ?? 'Doctor Name N/A', // Doctor's name
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  Text(
                    'Speciality: ${appointment.medecin?.speciality.nomSpecialite ?? 'N/A'}', // Doctor's speciality
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey[700]),
                  ),
                  const SizedBox(height: 2),
                  Text('Date: ${appointment.dateRendezvous}'), // Date and Time
                  Text('Status: ${appointment.statut.toUpperCase()}', // Status
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: appointment.statut == 'confirme' ? Colors.green[700] :
                      appointment.statut == 'annule_patient' || appointment.statut == 'annule_medecin' ? Colors.red[700] :
                      appointment.statut == 'termine' ? Colors.blueGrey[700] :
                      Colors.orange[700], // For 'demande'
                    ),
                  ),
                  if (appointment.notesPatient != null && appointment.notesPatient!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Text('Notes: ${appointment.notesPatient!}', style: Theme.of(context).textTheme.bodySmall),
                    ),
                ],
              ),
              // TODO: Add onTap for managing appointment (cancel, reschedule, view details if any)
              // trailing: IconButton(
              //   icon: Icon(Icons.more_vert),
              //   onPressed: () { /* Show options menu */ },
              // ),
            ),
          );
        },
      ),
    );
  }
}