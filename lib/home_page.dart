// lib/home_page.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:html' as html;

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _auth          = FirebaseAuth.instance;
  final _secureStorage = const FlutterSecureStorage();
  final _firestore     = FirebaseFirestore.instance;

  bool fitbitConnected = false;
  String? steps;
  String? _accessToken;

  // OAuth info
  final clientId    = '23QDNH';
  final redirectUri = 'http://localhost:8080';

  @override
  void initState() {
    super.initState();
    _initFitbitConnection();
  }

  Future<void> _initFitbitConnection() async {
    final fragment = Uri.base.fragment;
    if (fragment.contains('access_token=')) {
      final token = fragment
          .split('&')
          .firstWhere((p) => p.startsWith('access_token='))
          .substring('access_token='.length);
      await _secureStorage.write(key: 'fitbit_token', value: token);
      _accessToken = token;
      await _fetchSteps(token);
      setState(() => fitbitConnected = true);
      return;
    }
    final stored = await _secureStorage.read(key: 'fitbit_token');
    if (stored != null) {
      _accessToken = stored;
      await _fetchSteps(stored);
      setState(() => fitbitConnected = true);
    }
  }

  void _connectToFitbit() async {
    final authUrl = Uri.https('www.fitbit.com', '/oauth2/authorize', {
      'response_type': 'token',
      'client_id': clientId,
      'redirect_uri': redirectUri,
      'scope': 'activity heartrate nutrition profile sleep',
      'expires_in': '604800',
    });
    if (await canLaunchUrl(authUrl)) {
      await launchUrl(authUrl, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _fetchSteps(String token) async {
    final res = await http.get(
      Uri.parse('https://api.fitbit.com/1/user/-/activities/steps/date/today/1d.json'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (res.statusCode == 200) {
      final data = json.decode(res.body);
      setState(() => steps = data['activities-steps'][0]['value']);
    }
  }

  Future<void> _signOut() async {
    await _auth.signOut();
    await _secureStorage.delete(key: 'fitbit_token');
    // After sign-out, AuthGate will redirect to login.
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
                  onPressed: fitbitConnected ? null : _connectToFitbit,
                  icon: const Icon(Icons.favorite),
                  label: Text(fitbitConnected ? 'Fitbit Connected' : 'Connect Fitbit'),
                ),
                const SizedBox(width: 16),
                if (fitbitConnected)
                  Chip(
                    label: Text('Steps: ${steps ?? '-'}'),
                    avatar: const Icon(Icons.directions_walk, size: 20),
                  ),
              ],
            ),
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
