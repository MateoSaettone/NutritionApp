// lib/daily_report_page.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class DailyReportPage extends StatefulWidget {
  const DailyReportPage({Key? key}) : super(key: key);

  @override
  _DailyReportPageState createState() => _DailyReportPageState();
}

class _DailyReportPageState extends State<DailyReportPage> {
  DateTime selectedDate = DateTime.now();
  bool isLoading = true;
  String? accessToken;
  Map<String, dynamic> fitbitData = {
    'steps': 'N/A',
    'caloriesBurned': 'N/A',
    'activeMinutes': 'N/A',
    'distance': 'N/A',
  };
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    _loadFitbitToken();
  }

  Future<void> _loadFitbitToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('fitbit_token');
      
      setState(() {
        accessToken = token;
      });
      
      if (token != null) {
        await _fetchDailyData(token);
      } else {
        setState(() {
          isLoading = false;
          errorMessage = 'Please connect your Fitbit to view daily reports';
        });
      }
    } catch (e) {
      setState(() {
        isLoading = false;
        errorMessage = 'Error loading data: $e';
      });
    }
  }

  Future<void> _fetchDailyData(String token) async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });
    
    try {
      final dateString = DateFormat('yyyy-MM-dd').format(selectedDate);
      
      // Fetch steps data
      final stepsResponse = await http.get(
        Uri.parse('https://api.fitbit.com/1/user/-/activities/steps/date/$dateString/1d.json'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );
      
      // Fetch calories data
      final caloriesResponse = await http.get(
        Uri.parse('https://api.fitbit.com/1/user/-/activities/calories/date/$dateString/1d.json'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );
      
      // Fetch active minutes data
      final activeMinutesResponse = await http.get(
        Uri.parse('https://api.fitbit.com/1/user/-/activities/minutesVeryActive/date/$dateString/1d.json'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );
      
      // Fetch distance data
      final distanceResponse = await http.get(
        Uri.parse('https://api.fitbit.com/1/user/-/activities/distance/date/$dateString/1d.json'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );
      
      if (stepsResponse.statusCode == 200 && 
          caloriesResponse.statusCode == 200 &&
          activeMinutesResponse.statusCode == 200 &&
          distanceResponse.statusCode == 200) {
        
        final stepsData = json.decode(stepsResponse.body);
        final caloriesData = json.decode(caloriesResponse.body);
        final activeMinutesData = json.decode(activeMinutesResponse.body);
        final distanceData = json.decode(distanceResponse.body);
        
        setState(() {
          fitbitData = {
            'steps': stepsData['activities-steps'][0]['value'],
            'caloriesBurned': caloriesData['activities-calories'][0]['value'],
            'activeMinutes': activeMinutesData['activities-minutesVeryActive'][0]['value'],
            'distance': distanceData['activities-distance'][0]['value'],
          };
          isLoading = false;
        });
      } else if (stepsResponse.statusCode == 401 || 
                caloriesResponse.statusCode == 401 ||
                activeMinutesResponse.statusCode == 401 ||
                distanceResponse.statusCode == 401) {
        // Handle authentication error
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('fitbit_token');
        
        setState(() {
          isLoading = false;
          errorMessage = 'Authentication expired. Please reconnect your Fitbit.';
          accessToken = null;
        });
      } else {
        setState(() {
          isLoading = false;
          errorMessage = 'Failed to load Fitbit data. Please try again later.';
        });
      }
    } catch (e) {
      setState(() {
        isLoading = false;
        errorMessage = 'Error fetching data: $e';
      });
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    
    if (picked != null && picked != selectedDate) {
      setState(() {
        selectedDate = picked;
      });
      
      if (accessToken != null) {
        await _fetchDailyData(accessToken!);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Daily Report'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Daily Report: ${DateFormat('EEEE, MMM d, yyyy').format(selectedDate)}',
                  style: const TextStyle(
                    fontSize: 18.0, 
                    fontWeight: FontWeight.bold
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.calendar_today),
                  onPressed: () => _selectDate(context),
                ),
              ],
            ),
            const SizedBox(height: 16.0),
            
            if (errorMessage != null) ...[
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 48.0,
                      color: Colors.red.shade700,
                    ),
                    const SizedBox(height: 16.0),
                    Text(
                      errorMessage!,
                      style: TextStyle(
                        color: Colors.red.shade700,
                        fontSize: 16.0,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24.0),
                    if (errorMessage!.contains('Please reconnect') || 
                        errorMessage!.contains('Please connect')) ...[
                      ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context); // Go back to home page to connect
                        },
                        child: const Text('Go to Home Page'),
                      ),
                    ],
                  ],
                ),
              ),
            ] else if (isLoading) ...[
              const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16.0),
                    Text('Loading your daily activity data...'),
                  ],
                ),
              ),
            ] else ...[
              _buildDailyActivityCard(),
              const SizedBox(height: 24.0),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDailyActivityCard() {
    return Card(
      elevation: 4.0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.0),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Daily Activity Summary',
              style: TextStyle(
                fontSize: 18.0,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16.0),
            _buildMetricRow(Icons.directions_walk, 'Steps', fitbitData['steps']),
            const Divider(),
            _buildMetricRow(Icons.local_fire_department, 'Calories Burned', fitbitData['caloriesBurned']),
            const Divider(),
            _buildMetricRow(Icons.timer, 'Active Minutes', fitbitData['activeMinutes']),
            const Divider(),
            _buildMetricRow(Icons.straighten, 'Distance (km)', fitbitData['distance']),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, color: Colors.blue, size: 24.0),
          const SizedBox(width: 16.0),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 16.0),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16.0,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}