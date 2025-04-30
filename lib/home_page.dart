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
  String? steps;
  String? _accessToken;
  String? _authError;

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
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('fitbit_token');
      
      if (token != null && token.isNotEmpty) {
        _accessToken = token;
        
        try {
          await _fetchSteps(token);
          setState(() {
            fitbitConnected = true;
          });
        } catch (e) {
          await prefs.remove('fitbit_token');
        }
      }
    } catch (e) {
      // Handle error
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
      'scope': 'activity profile',
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

  Future<void> _storeTokenAndFetchData(String token) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('fitbit_token', token);
      
      _accessToken = token;
      
      // Fetch data
      await _fetchSteps(token);
      
      setState(() {
        fitbitConnected = true;
        isAuthenticating = false;
      });
    } catch (e) {
      setState(() {
        isAuthenticating = false;
        _authError = 'Error: $e';
      });
    }
  }

  Future<void> _fetchSteps(String token) async {
    try {
      final response = await http.get(
        Uri.parse('https://api.fitbit.com/1/user/-/activities/steps/date/today/1d.json'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          steps = data['activities-steps'][0]['value'];
          fitbitConnected = true;
        });
      } else if (response.statusCode == 401) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('fitbit_token');
        setState(() {
          fitbitConnected = false;
          _authError = 'Authentication expired. Please reconnect.';
        });
      } else {
        setState(() {
          steps = 'No data';
          fitbitConnected = true;
        });
      }
    } catch (e) {
      setState(() {
        steps = 'Not available';
        fitbitConnected = true;
        _authError = null;
      });
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
      _accessToken = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nutrition Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sign Out',
            onPressed: _signOut,
          )
        ],
      ),
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
                Navigator.pop(context); // back to home
              },
            ),
            ListTile(
              leading: const Icon(Icons.show_chart),
              title: const Text('Metrics'),
              onTap: () {
                // TODO: route to Metrics page
              },
            ),
            ListTile(
              leading: const Icon(Icons.assignment),
              title: const Text('Surveys'),
              onTap: () {
                // TODO: route to Survey page
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
            // Connection & Sync Row
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: fitbitConnected || isAuthenticating ? null : _connectToFitbit,
                  icon: const Icon(Icons.favorite),
                  label: Text(
                    isAuthenticating 
                      ? 'Connecting...' 
                      : (fitbitConnected ? 'Fitbit Connected' : 'Connect Fitbit')
                  ),
                ),
                const SizedBox(width: 16),
                if (fitbitConnected)
                  Chip(
                    label: Text('Steps: ${steps ?? '-'}'),
                    avatar: const Icon(Icons.directions_walk, size: 20),
                  ),
              ],
            ),
            
            if (_authError != null) ...[
              const SizedBox(height: 16),
              Text(
                _authError!,
                style: TextStyle(color: Colors.red.shade700),
              ),
            ],
            
            const SizedBox(height: 24),
            
            // Grid of placeholder charts
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