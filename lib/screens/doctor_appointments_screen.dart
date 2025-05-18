import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:provider/provider.dart';
import 'package:medical_app/models/appointment.dart'; // Import Appointment model
import 'package:medical_app/providers/user_provider.dart'; // Import UserProvider

class DoctorAppointmentsScreen extends StatefulWidget {
  const DoctorAppointmentsScreen({Key? key}) : super(key: key);

  @override
  _DoctorAppointmentsScreenState createState() => _DoctorAppointmentsScreenState();
}

class _DoctorAppointmentsScreenState extends State<DoctorAppointmentsScreen> {
  List<Appointment> _appointments = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final int? loggedInDoctorId = userProvider.userId;
    print('DEBUG (DoctorAppointmentsScreen): Fetching appointments for doctor ID: $loggedInDoctorId');

    if (loggedInDoctorId != null && userProvider.isDoctor) {
      _fetchDoctorAppointments(loggedInDoctorId);
    } else {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error: Doctor not logged in or role mismatch.';
      });
    }
  }

  Future<void> _fetchDoctorAppointments(int doctorId) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _appointments = [];
    });

    final String apiUrl = 'http://10.0.2.2/medical_api/api/appointments/read.php?user_id=$doctorId'; // Using the same read endpoint

    try {
      final response = await http.get(Uri.parse(apiUrl));
      Map<String, dynamic>? responseBody;
      try { responseBody = jsonDecode(response.body); } catch (e) { /* ignore */ }

      if (response.statusCode == 200) {
        if (responseBody != null && responseBody['success'] == true && responseBody['data'] != null) {
          List<dynamic> appointmentsJson = responseBody['data'];
          List<Appointment> fetchedAppointments = appointmentsJson.map((json) => Appointment.fromJson(json)).toList();
          setState(() {
            _appointments = fetchedAppointments;
            _isLoading = false;
          });
        } else {
          setState(() {
            _appointments = [];
            _isLoading = false;
            _errorMessage = responseBody?['message'] ?? 'No appointments found for this doctor.';
          });
          print('API 404/Error: ${responseBody?['message']} Status: ${response.statusCode}, Body: ${response.body}');
        }
      } else {
        String errorMsg = 'Server error. Status: ${response.statusCode}';
        try { final errorBody = jsonDecode(response.body); errorMsg = errorBody['message'] ?? errorMsg; } catch (e) { /* ignore */ }
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
      print('Error fetching doctor appointments: ${e.toString()}');
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
        title: const Text('My Schedule'), // جدول مواعيدي (للطبيب)
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
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
                  final int? loggedInDoctorId = userProvider.userId;
                  if (loggedInDoctorId != null) {
                    _fetchDoctorAppointments(loggedInDoctorId);
                  } else {
                    _showSnackBar('Doctor ID not available to retry.');
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
        child: Text('No upcoming appointments.'), // لا توجد مواعيد قادمة
      )
          : ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
        itemCount: _appointments.length,
        itemBuilder: (context, index) {
          final appointment = _appointments[index];
          return Card(
            key: ValueKey(appointment.id),
            elevation: 3.0,
            child: ListTile(
              contentPadding: const EdgeInsets.all(12.0),
              leading: CircleAvatar(
                backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                child: Icon(Icons.person_outline, color: Theme.of(context).colorScheme.primary), // Icon for patient
                radius: 28,
              ),
              title: Text(
                appointment.patient?.fullName ?? 'Patient Name N/A', // Patient's name
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  if (appointment.patient?.numTelephone != null && appointment.patient!.numTelephone!.isNotEmpty)
                    Text('Phone: ${appointment.patient!.numTelephone!}', style: Theme.of(context).textTheme.bodyMedium),
                  Text('Date: ${appointment.dateRendezvous}'),
                  Text('Status: ${appointment.statut.toUpperCase()}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: appointment.statut == 'confirme' ? Colors.green[700] :
                      appointment.statut == 'annule_patient' || appointment.statut == 'annule_medecin' ? Colors.red[700] :
                      appointment.statut == 'termine' ? Colors.blueGrey[700] :
                      Colors.orange[700], // For 'demande'
                    ),
                  ),
                ],
              ),
              // TODO: Add onTap to view patient details or manage appointment (confirm/cancel/reschedule)
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