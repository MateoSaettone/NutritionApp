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

  // Survey controllers
  final _dietaryCtrl = TextEditingController();
  final _moodCtrl    = TextEditingController();
  final _energyCtrl  = TextEditingController();

  // Fitbit OAuth info
  final clientId    = '23QDNH';
  final redirectUri = 'http://localhost:8080';

  @override
  void initState() {
    super.initState();
    _initFitbitConnection();
  }

  @override
  void dispose() {
    _dietaryCtrl.dispose();
    _moodCtrl.dispose();
    _energyCtrl.dispose();
    super.dispose();
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

  Future<void> _fetchSteps(String accessToken) async {
    final res = await http.get(
      Uri.parse('https://api.fitbit.com/1/user/-/activities/steps/date/today/1d.json'),
      headers: {'Authorization': 'Bearer $accessToken'},
    );
    if (res.statusCode == 200) {
      final data = json.decode(res.body);
      setState(() => steps = data['activities-steps'][0]['value']);
    }
  }

  Future<void> _syncNow() async {
    if (_accessToken == null) return;
    await _fetchSteps(_accessToken!);
    await _firestore.collection('fitbit_data').add({
      'metric':    'steps',
      'value':     steps,
      'timestamp': FieldValue.serverTimestamp(),
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Synced steps to Firestore!')),
    );
  }

  Future<void> _submitSurvey() async {
    final dietary = _dietaryCtrl.text.trim();
    final mood    = int.tryParse(_moodCtrl.text.trim());
    final energy  = int.tryParse(_energyCtrl.text.trim());

    if (dietary.isEmpty || mood == null || energy == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please complete all survey fields.')),
      );
      return;
    }

    await _firestore.collection('survey_responses').add({
      'dietaryHabits': dietary,
      'moodRating':    mood,
      'energyLevel':   energy,
      'timestamp':     FieldValue.serverTimestamp(),
    });

    _dietaryCtrl.clear();
    _moodCtrl.clear();
    _energyCtrl.clear();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Survey submitted!')),
    );
  }

  Future<void> _signOut() async {
    await _auth.signOut();
    await _secureStorage.delete(key: 'fitbit_token');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nutrition App'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _signOut,
            tooltip: 'Sign Out',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text("Firebase Initialized! 🚀"),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: fitbitConnected ? null : _connectToFitbit,
              child: Text(
                fitbitConnected && steps != null
                    ? "Connected to Fitbit ✅"
                    : "Connect to Fitbit",
              ),
            ),
            if (fitbitConnected && steps != null) ...[
              const SizedBox(height: 20),
              Text("Steps Today: $steps 🏃"),
            ],
            const SizedBox(height: 30),
            ElevatedButton.icon(
              onPressed: fitbitConnected ? _syncNow : null,
              icon: const Icon(Icons.sync),
              label: const Text("Sync Now to Firestore"),
            ),
            const Divider(height: 40),
            const Text(
              'Daily Wellness Survey',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _dietaryCtrl,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Describe your dietary habits today',
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _moodCtrl,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Mood rating (1–10)',
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _energyCtrl,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Energy level (1–10)',
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _submitSurvey,
              child: const Text('Submit Survey'),
            ),
          ],
        ),
      ),
    );
  }
}
