//Forcefully run this app in web mode using the command below
//flutter run -d web-server --web-port=8080 --web-hostname=localhost

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:html' as html; // For parsing fragment from browser

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Nutrition App',
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool fitbitConnected = false;
  String? steps;

  // Your Fitbit dev info
  final String clientId = '23QDNH';
  final String redirectUri = 'http://localhost:8080';

  @override
  void initState() {
    super.initState();

    final baseUri = Uri.base;
    final fragment = baseUri.fragment;

    if (fragment.isNotEmpty && fragment.contains('access_token=')) {
      final token = _extractAccessTokenFromFragment(fragment);
      if (token != null) {
        _fetchSteps(token);
      }
    }
  }

  String? _extractAccessTokenFromFragment(String fragment) {
    for (final piece in fragment.split('&')) {
      if (piece.startsWith('access_token=')) {
        return piece.substring('access_token='.length);
      }
    }
    return null;
  }

  void _connectToFitbit() async {
    final authUrl = Uri.https('www.fitbit.com', '/oauth2/authorize', {
      'response_type': 'token',
      'client_id': clientId,
      'redirect_uri': redirectUri,
      'scope': 'activity heartrate location nutrition profile settings sleep social weight',
      'expires_in': '604800',
    });

    if (await canLaunchUrl(authUrl)) {
      await launchUrl(authUrl, mode: LaunchMode.externalApplication);
    } else {
      print('Could not launch Fitbit OAuth URL');
    }
  }

  void _fetchSteps(String accessToken) async {
    final response = await http.get(
      Uri.parse('https://api.fitbit.com/1/user/-/activities/steps/date/today/1d.json'),
      headers: {
        'Authorization': 'Bearer $accessToken',
      },
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final todaysSteps = data['activities-steps'][0]['value'];

      setState(() {
        steps = todaysSteps;
        fitbitConnected = true;
      });
    } else {
      print('Failed to fetch step count: ${response.statusCode}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nutrition App')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
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
            if (fitbitConnected && steps != null)
              Padding(
                padding: const EdgeInsets.only(top: 20),
                child: Text("Steps Today: $steps 🏃"),
              )
            else if (fitbitConnected)
              const Padding(
                padding: EdgeInsets.only(top: 10),
                child: Text("Fitbit Connected! ✅"),
              ),
          ],
        ),
      ),
    );
  }
}
