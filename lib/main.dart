// lib/main.dart
// flutter run -d web-server --web-port=8080 --web-hostname=localhost

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart'; // Add this import for date formatting
import 'firebase_options.dart';

import 'login_page.dart';
import 'home_page.dart';
import 'sign_up_page.dart';
import 'daily_report_page.dart';  // Import new pages
import 'survey_page.dart';
import 'weekly_summary_page.dart';

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
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        cardTheme: CardTheme(
          elevation: 3,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        appBarTheme: const AppBarTheme(
          elevation: 0,
          centerTitle: false,
        ),
      ),
      home: const AuthGate(),
      routes: {
        '/login': (c) => const LoginPage(),
        '/signup': (c) => const SignUpPage(),
        '/home': (c) => const HomePage(),
        '/daily_report': (c) => const DailyReportPage(),  // Add routes for new pages
        '/survey': (c) => const SurveyPage(),
        '/weekly_summary': (c) => const WeeklySummaryPage(),
      },
    );
  }
}

/// Listens to FirebaseAuth state and shows LoginPage or HomePage.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasData) {
          return const HomePage();
        }
        return const LoginPage();
      },
    );
  }
}