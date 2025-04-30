// lib/survey_page.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class SurveyPage extends StatefulWidget {
  const SurveyPage({Key? key}) : super(key: key);

  @override
  _SurveyPageState createState() => _SurveyPageState();
}

class _SurveyPageState extends State<SurveyPage> {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  
  // Survey values
  double _moodRating = 5;
  double _energyLevel = 5;
  String _selectedDietType = 'Balanced';
  final _dietaryNotesController = TextEditingController();
  
  bool _isSaving = false;
  String? _errorMessage;
  String? _successMessage;
  
  final List<String> _dietTypes = [
    'Balanced',
    'High-Protein',
    'Low-Carb',
    'Vegetarian',
    'Vegan',
    'Keto',
    'Mediterranean',
    'Paleo',
    'Other'
  ];
  
  // Check if survey was already submitted today
  bool _surveySubmittedToday = false;
  Map<String, dynamic>? _todaySurveyData;
  
  @override
  void initState() {
    super.initState();
    _checkTodaySurvey();
  }
  
  Future<void> _checkTodaySurvey() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return;
      
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      
      final surveyDoc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('surveys')
          .doc(today)
          .get();
      
      if (surveyDoc.exists) {
        setState(() {
          _surveySubmittedToday = true;
          _todaySurveyData = surveyDoc.data();
          
          // Populate form with today's data
          if (_todaySurveyData != null) {
            _moodRating = _todaySurveyData!['moodRating']?.toDouble() ?? 5;
            _energyLevel = _todaySurveyData!['energyLevel']?.toDouble() ?? 5;
            _selectedDietType = _todaySurveyData!['dietType'] ?? 'Balanced';
            _dietaryNotesController.text = _todaySurveyData!['dietaryNotes'] ?? '';
          }
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error checking today\'s survey: $e';
      });
    }
  }
  
  Future<void> _submitSurvey() async {
    setState(() {
      _isSaving = true;
      _errorMessage = null;
      _successMessage = null;
    });
    
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) {
        setState(() {
          _errorMessage = 'You must be logged in to submit a survey';
          _isSaving = false;
        });
        return;
      }
      
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      
      // Prepare survey data
      final surveyData = {
        'date': today,
        'timestamp': FieldValue.serverTimestamp(),
        'moodRating': _moodRating,
        'energyLevel': _energyLevel,
        'dietType': _selectedDietType,
        'dietaryNotes': _dietaryNotesController.text,
      };
      
      // Save to Firestore
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('surveys')
          .doc(today)
          .set(surveyData);
      
      setState(() {
        _isSaving = false;
        _surveySubmittedToday = true;
        _todaySurveyData = surveyData;
        _successMessage = 'Survey submitted successfully!';
      });
      
      // Clear success message after delay
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          setState(() {
            _successMessage = null;
          });
        }
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error submitting survey: $e';
        _isSaving = false;
      });
    }
  }
  
  @override
  void dispose() {
    _dietaryNotesController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Daily Health Survey'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header section
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.quiz, 
                          color: Colors.blue,
                          size: 28,
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Daily Wellness Check-In',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              DateFormat('EEEE, MMMM d, yyyy').format(DateTime.now()),
                              style: TextStyle(
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Track your mood, energy levels, and diet to help identify patterns and improve your health.',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey.shade800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Mood rating
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Mood Rating',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'How would you rate your overall mood today?',
                      style: TextStyle(
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('😞'),
                        Expanded(
                          child: Slider(
                            value: _moodRating,
                            min: 1,
                            max: 10,
                            divisions: 9,
                            label: _moodRating.round().toString(),
                            onChanged: (value) {
                              setState(() {
                                _moodRating = value;
                              });
                            },
                          ),
                        ),
                        const Text('😊'),
                      ],
                    ),
                    Center(
                      child: Text(
                        '${_moodRating.round()} / 10',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Energy level
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Energy Level',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'How would you rate your energy levels today?',
                      style: TextStyle(
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Low'),
                        Expanded(
                          child: Slider(
                            value: _energyLevel,
                            min: 1,
                            max: 10,
                            divisions: 9,
                            label: _energyLevel.round().toString(),
                            onChanged: (value) {
                              setState(() {
                                _energyLevel = value;
                              });
                            },
                          ),
                        ),
                        const Text('High'),
                      ],
                    ),
                    Center(
                      child: Text(
                        '${_energyLevel.round()} / 10',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Diet information
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Diet Information',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Diet type dropdown
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        labelText: 'Diet Type',
                        border: OutlineInputBorder(),
                      ),
                      value: _selectedDietType,
                      items: _dietTypes.map((String type) {
                        return DropdownMenuItem<String>(
                          value: type,
                          child: Text(type),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        if (newValue != null) {
                          setState(() {
                            _selectedDietType = newValue;
                          });
                        }
                      },
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Dietary notes
                    TextField(
                      controller: _dietaryNotesController,
                      decoration: const InputDecoration(
                        labelText: 'Dietary Notes',
                        hintText: 'Enter any dietary notes or meals consumed today',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 3,
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Error and success messages
            if (_errorMessage != null) ...[
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
                        _errorMessage!,
                        style: TextStyle(color: Colors.red.shade700),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            
            if (_successMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green.shade700),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _successMessage!,
                        style: TextStyle(color: Colors.green.shade700),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            
            // Submit button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: _isSaving ? null : _submitSurvey,
                child: _isSaving
                    ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(width: 12),
                          Text('Saving...'),
                        ],
                      )
                    : Text(_surveySubmittedToday ? 'Update Survey' : 'Submit Survey'),
              ),
            ),
            
            if (_surveySubmittedToday) ...[
              const SizedBox(height: 8),
              Center(
                child: Text(
                  'You already submitted a survey today',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],
            
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}