// lib/home_page.dart
// run with:
// flutter run -d web-server --web-port=8080 --web-hostname=localhost

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:html' as html;
import 'dart:js' as js;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

import 'daily_report_page.dart'; // Import the new daily report page

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  bool fitbitConnected = false;
  bool isAuthenticating = false;
  bool isLoadingData = false;
  String? steps;
  String? caloriesBurned;
  String? activeMinutes;
  String? heartRate;
  String? _accessToken;
  String? _authError;
  bool _isHoveringFitbitButton = false; // Track hovering state

  // OAuth info
  final clientId = '23Q8PL';
  final redirectUri = 'http://localhost:8080/auth.html';

  @override
  void initState() {
    super.initState();
    _setupAuthListener();
    _checkStoredToken();
  }

  void _setupAuthListener() {
    // Set up a JavaScript listener for the OAuth callback
    js.context['handleFitbitAuth'] = (dynamic result) {
      if (result != null && result.toString().contains('access_token=')) {
        _processAuthResult(result.toString());
      }
    };

    // Listen for postMessage from the auth popup
    html.window.addEventListener('message', (event) {
      final html.MessageEvent e = event as html.MessageEvent;
      if (e.origin == html.window.location.origin) {
        try {
          final data = e.data;
          if (data is Map && data.containsKey('fitbit-auth')) {
            final authUrl = data['fitbit-auth'];
            _processAuthResult(authUrl);
          }
        } catch (e) {
          // Handle error
          setState(() {
            _authError = 'Error processing auth callback: $e';
          });
        }
      }
    });
  }

  void _processAuthResult(String authUrl) {
    // Extract access token from the URL
    if (authUrl.contains('access_token=')) {
      final uri = Uri.parse(authUrl.replaceFirst('#', '?'));
      final accessToken = uri.queryParameters['access_token'];
      
      if (accessToken != null) {
        _storeTokenAndFetchData(accessToken);
      } else {
        setState(() {
          isAuthenticating = false;
          _authError = 'Failed to extract access token';
        });
      }
    } else {
      setState(() {
        isAuthenticating = false;
        _authError = 'No access token found in response';
      });
    }
  }

  Future<void> _checkStoredToken() async {
    try {
      setState(() {
        isLoadingData = true;
      });
      
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('fitbit_token');
      
      if (token != null && token.isNotEmpty) {
        _accessToken = token;
        
        try {
          await _fetchFitbitData(token);
          setState(() {
            fitbitConnected = true;
            isLoadingData = false;
          });
        } catch (e) {
          await prefs.remove('fitbit_token');
          setState(() {
            fitbitConnected = false;
            isLoadingData = false;
            _authError = 'Error loading Fitbit data: $e';
          });
        }
      } else {
        setState(() {
          isLoadingData = false;
        });
      }
    } catch (e) {
      setState(() {
        isLoadingData = false;
        _authError = 'Error checking stored token: $e';
      });
    }
  }

  void _connectToFitbit() {
    setState(() {
      isAuthenticating = true;
      _authError = null;
    });
    
    // Generate a unique state parameter
    final state = DateTime.now().millisecondsSinceEpoch.toString();
    
    // Construct OAuth URL with necessary scopes
    final authUrl = Uri.https('www.fitbit.com', '/oauth2/authorize', {
      'response_type': 'token',
      'client_id': clientId,
      'redirect_uri': redirectUri,
      'scope': 'activity heartrate profile sleep nutrition',  // Extended scope
      'expires_in': '604800',
      'state': state,
    }).toString();
    
    // Open the auth URL in a new window
    final authWindow = html.window.open(
      authUrl,
      'fitbit_auth',
      'width=800,height=600,menubar=no,toolbar=no,location=no'
    );
    
    // If popup blocker prevents opening, fallback to redirecting current window
    if (authWindow == null) {
      html.window.location.href = authUrl;
    }
  }

  // New method: Disconnect from Fitbit
  Future<void> _disconnectFitbit() async {
    try {
      // Show confirmation dialog
      final bool? confirmDisconnect = await showDialog<bool>(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Disconnect Fitbit'),
            content: const Text(
              'Are you sure you want to disconnect your Fitbit account? '
              'This will remove all access to your Fitbit data from this app.'
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('CANCEL'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('DISCONNECT'),
              ),
            ],
          );
        },
      );
      
      if (confirmDisconnect == true) {
        // Clear stored token
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('fitbit_token');
        
        setState(() {
          fitbitConnected = false;
          steps = null;
          caloriesBurned = null;
          activeMinutes = null;
          heartRate = null;
          _accessToken = null;
          _authError = null;
        });
        
        // Show success snackbar
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Successfully disconnected from Fitbit'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      setState(() {
        _authError = 'Error disconnecting: $e';
      });
    }
  }

  Future<void> _storeTokenAndFetchData(String token) async {
    try {
      setState(() {
        isLoadingData = true;
      });
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('fitbit_token', token);
      
      _accessToken = token;
      
      // Fetch data
      try {
        await _fetchFitbitData(token);
      } catch (e) {
        // Continue even if data fetching fails
        print('Error fetching initial data: $e');
      }
      
      setState(() {
        fitbitConnected = true;
        isAuthenticating = false;
        isLoadingData = false;
      });
      
      // Show success snackbar
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Successfully connected to Fitbit'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      setState(() {
        isAuthenticating = false;
        isLoadingData = false;
        _authError = 'Error: $e';
      });
    }
  }

  Future<void> _fetchFitbitData(String token) async {
    try {
      setState(() {
        isLoadingData = true;
      });
      
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      
      try {
        // Fetch steps data
        final stepsResponse = await http.get(
          Uri.parse('https://api.fitbit.com/1/user/-/activities/steps/date/today/1d.json'),
          headers: {
            'Authorization': 'Bearer $token',
            'Accept': 'application/json',
          },
        );
        
        if (stepsResponse.statusCode == 200) {
          final data = json.decode(stepsResponse.body);
          setState(() {
            steps = data['activities-steps'][0]['value'];
          });
        } else if (stepsResponse.statusCode == 401) {
          // Handle authentication error
          throw Exception('Authentication expired');
        }
      } catch (e) {
        print('Error fetching steps: $e');
        setState(() {
          steps = 'Not available';
        });
      }
      
      try {
        // Fetch calories data
        final caloriesResponse = await http.get(
          Uri.parse('https://api.fitbit.com/1/user/-/activities/calories/date/today/1d.json'),
          headers: {
            'Authorization': 'Bearer $token',
            'Accept': 'application/json',
          },
        );
        
        if (caloriesResponse.statusCode == 200) {
          final data = json.decode(caloriesResponse.body);
          setState(() {
            caloriesBurned = data['activities-calories'][0]['value'];
          });
        }
      } catch (e) {
        print('Error fetching calories: $e');
        setState(() {
          caloriesBurned = 'Not available';
        });
      }
      
      try {
        // Fetch active minutes data
        final activeMinutesResponse = await http.get(
          Uri.parse('https://api.fitbit.com/1/user/-/activities/minutesVeryActive/date/today/1d.json'),
          headers: {
            'Authorization': 'Bearer $token',
            'Accept': 'application/json',
          },
        );
        
        if (activeMinutesResponse.statusCode == 200) {
          final data = json.decode(activeMinutesResponse.body);
          setState(() {
            activeMinutes = data['activities-minutesVeryActive'][0]['value'];
          });
        }
      } catch (e) {
        print('Error fetching active minutes: $e');
        setState(() {
          activeMinutes = 'Not available';
        });
      }
      
      try {
        // Fetch heart rate data
        final heartRateResponse = await http.get(
          Uri.parse('https://api.fitbit.com/1/user/-/activities/heart/date/today/1d.json'),
          headers: {
            'Authorization': 'Bearer $token',
            'Accept': 'application/json',
          },
        );
        
        if (heartRateResponse.statusCode == 200) {
          final data = json.decode(heartRateResponse.body);
          // Extract resting heart rate if available
          final zones = data['activities-heart'][0]['value'];
          if (zones is Map && zones.containsKey('restingHeartRate')) {
            setState(() {
              heartRate = zones['restingHeartRate'].toString();
            });
          } else {
            setState(() {
              heartRate = 'N/A';
            });
          }
        }
      } catch (e) {
        print('Error fetching heart rate: $e');
        setState(() {
          heartRate = 'Not available';
        });
      }
      
      setState(() {
        fitbitConnected = true;
        isLoadingData = false;
      });
    } catch (e) {
      if (e.toString().contains('Authentication expired')) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('fitbit_token');
        setState(() {
          fitbitConnected = false;
          isLoadingData = false;
          _authError = 'Authentication expired. Please reconnect.';
        });
      } else {
        setState(() {
          isLoadingData = false;
          _authError = 'Error fetching data: $e';
          // Still consider connected even if data fetch fails
          fitbitConnected = true;
        });
      }
    }
  }

  Future<void> _refreshFitbitData() async {
    if (_accessToken != null) {
      setState(() {
        _authError = null;
      });
      
      try {
        await _fetchFitbitData(_accessToken!);
        
        // Show success message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Data refreshed successfully'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      } catch (e) {
        setState(() {
          _authError = 'Error refreshing data: $e';
        });
      }
    }
  }

  Future<void> _signOut() async {
    await _auth.signOut();
    
    // Clear Fitbit token
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('fitbit_token');
    
    setState(() {
      fitbitConnected = false;
      steps = null;
      caloriesBurned = null;
      activeMinutes = null;
      heartRate = null;
      _accessToken = null;
    });
  }

  void _navigateToDailyReport() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const DailyReportPage()),
    );
  }

  void _navigateToSurvey() {
    Navigator.pushNamed(context, '/survey');
  }

  void _navigateToWeeklySummary() {
    Navigator.pushNamed(context, '/weekly_summary');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nutrition Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Data',
            onPressed: fitbitConnected ? _refreshFitbitData : null,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sign Out',
            onPressed: _signOut,
          ),
        ],
      ),
      // Updated drawer navigation in build method
      drawer: Drawer(
        child: Column(
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(color: Colors.blue),
              child: Row(
                children: const [
                  Icon(Icons.fastfood, color: Colors.white, size: 36),
                  SizedBox(width: 12),
                  Text('NutritionApp',
                      style: TextStyle(color: Colors.white, fontSize: 24)),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.home),
              title: const Text('Home'),
              onTap: () {
                Navigator.pop(context); // close drawer
              },
            ),
            ListTile(
              leading: const Icon(Icons.calendar_today),
              title: const Text('Daily Report'),
              onTap: () {
                Navigator.pop(context); // close drawer
                _navigateToDailyReport();
              },
            ),
            ListTile(
              leading: const Icon(Icons.bar_chart),
              title: const Text('Weekly Summary'),
              onTap: () {
                Navigator.pop(context); // close drawer
                _navigateToWeeklySummary();
              },
            ),
            ListTile(
              leading: const Icon(Icons.assignment),
              title: const Text('Daily Survey'),
              onTap: () {
                Navigator.pop(context); // close drawer
                _navigateToSurvey();
              },
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text('v1.0.0',
                  style: TextStyle(color: Colors.grey.shade600)),
            )
          ],
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Fitbit connection status card
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Fitbit Connection',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Updated button with hover effect
                        MouseRegion(
                          onEnter: (_) => setState(() => _isHoveringFitbitButton = true),
                          onExit: (_) => setState(() => _isHoveringFitbitButton = false),
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: fitbitConnected && _isHoveringFitbitButton 
                                  ? Colors.red 
                                  : null,
                            ),
                            onPressed: isAuthenticating || isLoadingData
                                ? null 
                                : (fitbitConnected 
                                    ? _disconnectFitbit 
                                    : _connectToFitbit),
                            icon: Icon(
                              fitbitConnected && _isHoveringFitbitButton 
                                  ? Icons.link_off 
                                  : Icons.favorite,
                            ),
                            label: Text(
                              isAuthenticating 
                                ? 'Connecting...' 
                                : (fitbitConnected 
                                    ? (_isHoveringFitbitButton 
                                        ? 'Disconnect Fitbit' 
                                        : 'Fitbit Connected')
                                    : 'Connect Fitbit')
                            ),
                          ),
                        ),
                        if (isLoadingData)
                          const CircularProgressIndicator(),
                      ],
                    ),
                    
                    if (_authError != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.error_outline, color: Colors.red.shade700),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _authError!,
                                style: TextStyle(color: Colors.red.shade700),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    
                    if (fitbitConnected) ...[
                      const SizedBox(height: 24),
                      const Text(
                        'Today\'s Activity',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      _buildActivityMetric(Icons.directions_walk, 'Steps', steps ?? '-'),
                      _buildActivityMetric(Icons.local_fire_department, 'Calories Burned', caloriesBurned ?? '-'),
                      _buildActivityMetric(Icons.timer, 'Active Minutes', activeMinutes ?? '-'),
                      _buildActivityMetric(Icons.favorite, 'Resting Heart Rate', heartRate != null ? '$heartRate bpm' : '-'),
                      const SizedBox(height: 16),
                      Center(
                        child: TextButton.icon(
                          icon: const Icon(Icons.calendar_today),
                          label: const Text('View Daily Report'),
                          onPressed: _navigateToDailyReport,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Health insights section
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                children: [
                  _buildChartCard('Daily Steps', Icons.directions_walk),
                  _buildChartCard('Sleep Quality', Icons.bedtime),
                  _buildChartCard('Heart Rate Variability', Icons.favorite_border),
                  _buildChartCard('Stress & Recovery', Icons.self_improvement),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityMetric(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Icon(icon, color: Colors.blue, size: 20),
          const SizedBox(width: 8),
          Expanded(child: Text(label)),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildChartCard(String title, IconData icon) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(icon, color: Colors.blue),
              const SizedBox(width: 8),
              Text(title,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ]),
            const SizedBox(height: 12),
            // Placeholder for actual chart
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Center(child: Text('Chart goes here')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}