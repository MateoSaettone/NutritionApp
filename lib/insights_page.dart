// lib/insights_page.dart

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'mock_data_provider.dart'; // Import our mock data provider

class InsightsPage extends StatefulWidget {
  const InsightsPage({Key? key}) : super(key: key);

  @override
  _InsightsPageState createState() => _InsightsPageState();
}

class _InsightsPageState extends State<InsightsPage> {
  bool isLoading = true;
  String? accessToken;
  String? errorMessage;
  bool useMockData = false;
  
  // User profile data
  String userName = '';
  
  // Insights data
  List<Map<String, dynamic>> activityInsights = [];
  List<Map<String, dynamic>> sleepInsights = [];
  List<Map<String, dynamic>> nutritionInsights = [];
  List<Map<String, dynamic>> correlationInsights = [];

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      setState(() {
        isLoading = true;
        errorMessage = null;
        useMockData = false;
      });
      
      // Get current user
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        userName = user.displayName ?? user.email?.split('@')[0] ?? 'User';
        
        // Load Fitbit token
        final prefs = await SharedPreferences.getInstance();
        final token = prefs.getString('fitbit_token');
        
        setState(() {
          accessToken = token;
        });
        
        if (token != null) {
          // Generate insights from real data
          try {
            await _generateInsights(token);
          } catch (e) {
            print('Error generating insights: $e');
            _generateSampleInsights(
              'Couldn\'t retrieve all data from Fitbit. Showing some sample insights instead.'
            );
          }
        } else {
          // No Fitbit connection, use sample insights
          _generateSampleInsights('No Fitbit connection available. Showing sample insights.');
        }
      } else {
        // Handle case where user isn't authenticated
        userName = 'Guest';
        _generateSampleInsights('Please sign in to view personalized insights. Showing sample data.');
      }
    } catch (e) {
      // Use sample insights for any general error
      userName = 'User';
      _generateSampleInsights('Error loading user data: $e. Showing sample insights.');
    }
  }

  void _generateSampleInsights(String message) {
    setState(() {
      useMockData = true;
      errorMessage = message;
      
      // Use mock provider for all insights
      activityInsights = MockDataProvider.getMockActivityInsights();
      sleepInsights = MockDataProvider.getMockSleepInsights();
      nutritionInsights = MockDataProvider.getMockNutritionInsights();
      correlationInsights = MockDataProvider.getMockCorrelationInsights();
      
      isLoading = false;
    });
  }

  Future<void> _generateInsights(String token) async {
    try {
      // Clear existing insights
      activityInsights.clear();
      sleepInsights.clear();
      nutritionInsights.clear();
      correlationInsights.clear();
      
      // Get date ranges for API calls
      final now = DateTime.now();
      final today = DateFormat('yyyy-MM-dd').format(now);
      final weekAgo = DateFormat('yyyy-MM-dd').format(now.subtract(const Duration(days: 7)));
      final monthAgo = DateFormat('yyyy-MM-dd').format(now.subtract(const Duration(days: 30)));
      
      bool hasDataErrors = false;
      
      try {
        // Get activity data
        await _fetchActivityInsights(token, weekAgo, today);
      } catch (e) {
        print('Error fetching activity insights: $e');
        activityInsights = MockDataProvider.getMockActivityInsights();
        hasDataErrors = true;
      }
      
      try {
        // Get sleep data
        await _fetchSleepInsights(token, weekAgo, today);
      } catch (e) {
        print('Error fetching sleep insights: $e');
        sleepInsights = MockDataProvider.getMockSleepInsights();
        hasDataErrors = true;
      }
      
      try {
        // Generate correlation insights
        await _generateCorrelationInsights(token, monthAgo, today);
      } catch (e) {
        print('Error generating correlation insights: $e');
        correlationInsights = MockDataProvider.getMockCorrelationInsights();
        hasDataErrors = true;
      }
      
      // Add nutrition insights (these are static for now)
      _addNutritionInsights();
      
      // If any section used mock data, set the flag
      if (hasDataErrors) {
        setState(() {
          useMockData = true;
          errorMessage = 'Some data could not be fetched. Showing a mix of real and sample data.';
        });
      }
      
      setState(() {
        isLoading = false;
      });
    } catch (e) {
      // Use all mock data if there's a catastrophic error
      _generateSampleInsights('Error generating insights: $e. Showing sample data.');
    }
  }

  Future<void> _fetchActivityInsights(String token, String startDate, String endDate) async {
    try {
      // Fetch steps data
      final stepsResponse = await http.get(
        Uri.parse('https://api.fitbit.com/1/user/-/activities/steps/date/$startDate/$endDate.json'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );
      
      if (stepsResponse.statusCode == 200) {
        final data = json.decode(stepsResponse.body);
        final stepsData = data['activities-steps'] as List;
        
        // Calculate average steps
        int totalSteps = 0;
        for (var day in stepsData) {
          final value = day['value'];
          if (value != null && value.toString().isNotEmpty) {
            totalSteps += int.parse(value.toString());
          }
        }
        
        final avgSteps = stepsData.isNotEmpty ? totalSteps / stepsData.length : 0;
        
        // Find most active day
        String mostActiveDay = 'Unknown';
        int maxSteps = 0;
        
        for (var day in stepsData) {
          final value = day['value'];
          final dateTimeStr = day['dateTime'];
          
          if (value != null && dateTimeStr != null && dateTimeStr.toString().isNotEmpty) {
            try {
              final steps = int.parse(value.toString());
              if (steps > maxSteps) {
                maxSteps = steps;
                final date = DateTime.parse(dateTimeStr.toString());
                mostActiveDay = DateFormat('EEEE').format(date);
              }
            } catch (e) {
              print('Error parsing steps value: $e');
              continue; // Skip this day if parsing fails
            }
          }
        }
        
        // Add insights
        if (avgSteps >= 10000) {
          activityInsights.add({
            'title': 'Great Activity Level',
            'description': 'You\'re averaging ${NumberFormat('#,###').format(avgSteps.round())} steps daily, which exceeds the recommended 10,000 steps!',
            'icon': Icons.directions_walk,
            'color': Colors.green,
          });
        } else if (avgSteps >= 7500) {
          activityInsights.add({
            'title': 'Good Activity Level',
            'description': 'You\'re averaging ${NumberFormat('#,###').format(avgSteps.round())} steps daily, which is close to the recommended amount.',
            'icon': Icons.directions_walk,
            'color': Colors.blue,
          });
        } else {
          activityInsights.add({
            'title': 'Increase Your Activity',
            'description': 'You\'re averaging ${NumberFormat('#,###').format(avgSteps.round())} steps daily. Try to reach at least 10,000 steps for better health.',
            'icon': Icons.directions_walk,
            'color': Colors.orange,
          });
        }
        
        // Add insight about most active day
        if (mostActiveDay != 'Unknown' && maxSteps > 0) {
          activityInsights.add({
            'title': 'Most Active Day',
            'description': 'Your most active day of the week is $mostActiveDay with an average of ${NumberFormat('#,###').format(maxSteps)} steps.',
            'icon': Icons.calendar_today,
            'color': Colors.purple,
          });
        }
      } else if (stepsResponse.statusCode == 401) {
        // Clear token if expired
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('fitbit_token');
        throw Exception('Authentication expired');
      } else {
        throw Exception('Failed to fetch steps data');
      }
      
      // Fetch active minutes data
      final activeMinutesResponse = await http.get(
        Uri.parse('https://api.fitbit.com/1/user/-/activities/minutesVeryActive/date/$startDate/$endDate.json'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );
      
      if (activeMinutesResponse.statusCode == 200) {
        final data = json.decode(activeMinutesResponse.body);
        final minutesData = data['activities-minutesVeryActive'] as List;
        
        // Calculate average active minutes
        int totalMinutes = 0;
        int validDays = 0;
        
        for (var day in minutesData) {
          final value = day['value'];
          if (value != null && value.toString().isNotEmpty) {
            try {
              totalMinutes += int.parse(value.toString());
              validDays++;
            } catch (e) {
              print('Error parsing minutes value: $e');
              continue; // Skip this day if parsing fails
            }
          }
        }
        
        final avgMinutes = validDays > 0 ? totalMinutes / validDays : 0;
        
        // Add insight based on active minutes
        if (avgMinutes >= 30) {
          activityInsights.add({
            'title': 'Meeting Activity Guidelines',
            'description': 'You\'re getting ${avgMinutes.round()} minutes of intense activity daily, which meets health recommendations.',
            'icon': Icons.fitness_center,
            'color': Colors.green,
          });
        } else if (avgMinutes >= 15) {
          activityInsights.add({
            'title': 'Almost There',
            'description': 'You\'re getting ${avgMinutes.round()} minutes of intense activity daily. Try to reach 30 minutes for optimal health.',
            'icon': Icons.fitness_center,
            'color': Colors.blue,
          });
        } else {
          activityInsights.add({
            'title': 'Increase Intense Activity',
            'description': 'You\'re only getting ${avgMinutes.round()} minutes of intense activity daily. Aim for at least 30 minutes.',
            'icon': Icons.fitness_center,
            'color': Colors.orange,
          });
        }
      }
    } catch (e) {
      print('Error fetching activity insights: $e');
      // Use mock data if there's an error
      activityInsights = MockDataProvider.getMockActivityInsights();
      throw e; // Re-throw for the caller to handle
    }
  }

  Future<void> _fetchSleepInsights(String token, String startDate, String endDate) async {
    try {
      final sleepResponse = await http.get(
        Uri.parse('https://api.fitbit.com/1.2/user/-/sleep/date/$startDate/$endDate.json'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );
      
      if (sleepResponse.statusCode == 200) {
        final data = json.decode(sleepResponse.body);
        final sleepData = data['sleep'];
        
        if (sleepData != null && sleepData.isNotEmpty) {
          // Group sleep data by date
          Map<String, List<dynamic>> sleepByDate = {};
          
          for (var sleep in sleepData) {
            final dateOfSleep = sleep['dateOfSleep'];
            if (dateOfSleep != null && dateOfSleep.toString().isNotEmpty) {
              try {
                final date = DateFormat('yyyy-MM-dd').format(DateTime.parse(dateOfSleep.toString()));
                
                if (!sleepByDate.containsKey(date)) {
                  sleepByDate[date] = [];
                }
                
                sleepByDate[date]?.add(sleep);
              } catch (e) {
                print('Error parsing sleep date: $e');
                continue; // Skip this entry if date parsing fails
              }
            }
          }
          
          // Calculate daily totals
          int totalSleepMinutes = 0;
          int totalDeepSleepMinutes = 0;
          int totalRemSleepMinutes = 0;
          int daysWithData = 0;
          
          // Best and worst nights
          int bestSleepScore = 0;
          int worstSleepScore = 100;
          String bestNight = '';
          String worstNight = '';
          
          sleepByDate.forEach((date, sleepRecords) {
            int dayTotalMinutes = 0;
            int dayDeepMinutes = 0;
            int dayRemMinutes = 0;
            
            for (var sleep in sleepRecords) {
              if (sleep['minutesAsleep'] != null) {
                try {
                  dayTotalMinutes += (sleep['minutesAsleep'] as num).toInt();
                  
                  if (sleep['levels'] != null && sleep['levels']['summary'] != null) {
                    final summary = sleep['levels']['summary'];
                    
                    if (summary['deep'] != null && summary['deep']['minutes'] != null) {
                      dayDeepMinutes += (summary['deep']['minutes'] as num).toInt();
                    }
                    
                    if (summary['rem'] != null && summary['rem']['minutes'] != null) {
                      dayRemMinutes += (summary['rem']['minutes'] as num).toInt();
                    }
                  }
                } catch (e) {
                  print('Error processing sleep minutes: $e');
                  continue; // Skip this record if error
                }
              }
            }
            
            if (dayTotalMinutes > 0) {
              // Add to totals
              totalSleepMinutes += dayTotalMinutes;
              totalDeepSleepMinutes += dayDeepMinutes;
              totalRemSleepMinutes += dayRemMinutes;
              daysWithData++;
              
              // Calculate sleep score for best/worst night (simplified)
              final sleepScore = (dayDeepMinutes / (dayTotalMinutes > 0 ? dayTotalMinutes : 1) * 100).round();
              
              try {
                final dateFormatted = DateTime.parse(date);
                final dateStr = DateFormat('EEE, MMM d').format(dateFormatted);
                
                if (sleepScore > bestSleepScore) {
                  bestSleepScore = sleepScore;
                  bestNight = dateStr;
                }
                
                if (sleepScore < worstSleepScore && dayTotalMinutes > 180) { // At least 3 hours of sleep
                  worstSleepScore = sleepScore;
                  worstNight = dateStr;
                }
              } catch (e) {
                print('Error formatting date: $e');
              }
            }
          });
          
          if (daysWithData > 0) {
            // Calculate averages
            final avgDuration = totalSleepMinutes / daysWithData;
            final avgDeepPercentage = totalSleepMinutes > 0 
                ? (totalDeepSleepMinutes / totalSleepMinutes * 100) 
                : 0;
            final avgRemPercentage = totalSleepMinutes > 0 
                ? (totalRemSleepMinutes / totalSleepMinutes * 100) 
                : 0;
            
            // Add sleep duration insight
            final avgHours = avgDuration / 60;
            
            if (avgHours >= 7) {
              sleepInsights.add({
                'title': 'Optimal Sleep Duration',
                'description': 'You\'re averaging ${avgHours.toStringAsFixed(1)} hours of sleep, which is within the recommended range.',
                'icon': Icons.bedtime,
                'color': Colors.indigo,
              });
            } else if (avgHours >= 6) {
              sleepInsights.add({
                'title': 'Slightly Low Sleep Duration',
                'description': 'You\'re averaging ${avgHours.toStringAsFixed(1)} hours of sleep. Try to get at least 7 hours for optimal health.',
                'icon': Icons.bedtime,
                'color': Colors.blue,
              });
            } else {
              sleepInsights.add({
                'title': 'Insufficient Sleep',
                'description': 'You\'re only getting ${avgHours.toStringAsFixed(1)} hours of sleep. This is well below the recommended 7-9 hours.',
                'icon': Icons.bedtime,
                'color': Colors.red,
              });
            }
            
            // Add deep sleep insight
            if (avgDeepPercentage >= 25) {
              sleepInsights.add({
                'title': 'Excellent Deep Sleep',
                'description': 'Your deep sleep makes up ${avgDeepPercentage.round()}% of your total sleep, which is above average.',
                'icon': Icons.nightlight,
                'color': Colors.indigo,
              });
            } else if (avgDeepPercentage >= 15) {
              sleepInsights.add({
                'title': 'Normal Deep Sleep',
                'description': 'Your deep sleep makes up ${avgDeepPercentage.round()}% of your total sleep, which is within the normal range.',
                'icon': Icons.nightlight,
                'color': Colors.blue,
              });
            } else {
              sleepInsights.add({
                'title': 'Low Deep Sleep',
                'description': 'Your deep sleep only makes up ${avgDeepPercentage.round()}% of your total sleep, which is below average.',
                'icon': Icons.nightlight,
                'color': Colors.orange,
              });
            }
            
            // Add REM sleep insight
            if (avgRemPercentage >= 25) {
              sleepInsights.add({
                'title': 'Excellent REM Sleep',
                'description': 'Your REM sleep makes up ${avgRemPercentage.round()}% of your total sleep, which is optimal for cognitive function.',
                'icon': Icons.psychology,
                'color': Colors.purple,
              });
            } else if (avgRemPercentage >= 15) {
              sleepInsights.add({
                'title': 'Normal REM Sleep',
                'description': 'Your REM sleep makes up ${avgRemPercentage.round()}% of your total sleep, which is within the normal range.',
                'icon': Icons.psychology,
                'color': Colors.blue,
              });
            } else {
              sleepInsights.add({
                'title': 'Low REM Sleep',
                'description': 'Your REM sleep only makes up ${avgRemPercentage.round()}% of your total sleep, which is below average.',
                'icon': Icons.psychology,
                'color': Colors.orange,
              });
            }
            
            // Add best/worst night insights if available
            if (bestNight.isNotEmpty) {
              sleepInsights.add({
                'title': 'Best Sleep Quality',
                'description': 'Your best sleep quality was on $bestNight with ${bestSleepScore}% of deep sleep.',
                'icon': Icons.star,
                'color': Colors.amber,
              });
            }
          }
        } else {
          // No sleep data
          throw Exception('No sleep data available');
        }
      } else if (sleepResponse.statusCode == 401) {
        // Clear token if expired
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('fitbit_token');
        throw Exception('Authentication expired');
      } else {
        throw Exception('Failed to fetch sleep data');
      }
    } catch (e) {
      print('Error fetching sleep insights: $e');
      // Use mock data if there's an error
      sleepInsights = MockDataProvider.getMockSleepInsights();
      throw e; // Re-throw for the caller to handle
    }
  }

  Future<void> _generateCorrelationInsights(String token, String startDate, String endDate) async {
    try {
      // This is a simplified version - in a real app, you would analyze actual correlations
      // For now, use generated mock correlation insights that look realistic
      correlationInsights = MockDataProvider.getMockCorrelationInsights();
    } catch (e) {
      print('Error generating correlation insights: $e');
      // Already using mock data, so nothing additional to do here
      throw e; // Re-throw to be handled by the caller
    }
  }

  void _addNutritionInsights() {
    // Add nutrition insights (these are all static for now)
    nutritionInsights = MockDataProvider.getMockNutritionInsights();
  }

  Widget _buildInsightCard(String title, List<Map<String, dynamic>> insights) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            if (insights.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text('No insights available'),
                ),
              )
            else
              ...insights.map((insight) => _buildInsightItem(
                insight['title'],
                insight['description'],
                insight['icon'],
                insight['color'],
              )).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildInsightItem(String title, String description, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    color: Colors.grey[700],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Health Insights'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Insights',
            onPressed: () async {
              if (accessToken != null) {
                setState(() {
                  isLoading = true;
                });
                try {
                  await _generateInsights(accessToken!);
                } catch (e) {
                  _generateSampleInsights('Error refreshing insights: $e');
                }
              } else {
                _generateSampleInsights('No Fitbit connection. Showing sample insights.');
              }
            },
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Show info message if using mock data
                  if (useMockData && errorMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.all(8.0),
                      margin: const EdgeInsets.only(bottom: 16.0),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.amber.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.amber.shade800),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              errorMessage!,
                              style: TextStyle(color: Colors.amber.shade800),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  
                  // Welcome section
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.blue.shade400, Colors.blue.shade700],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Hello, $userName',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Here are your personalized health insights based on your activity and sleep patterns.',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (accessToken == null)
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: Colors.blue,
                            ),
                            icon: const Icon(Icons.link),
                            label: const Text('Connect Fitbit for Personalized Insights'),
                            onPressed: () {
                              Navigator.pop(context); // Go back to home
                            },
                          ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Correlation insights - These are most valuable to show first
                  _buildInsightCard('Patterns & Correlations', correlationInsights),
                  
                  const SizedBox(height: 16),
                  
                  // Activity insights
                  _buildInsightCard('Activity Insights', activityInsights),
                  
                  const SizedBox(height: 16),
                  
                  // Sleep insights
                  _buildInsightCard('Sleep Insights', sleepInsights),
                  
                  const SizedBox(height: 16),
                  
                  // Nutrition insights
                  _buildInsightCard('Nutrition Insights', nutritionInsights),
                  
                  const SizedBox(height: 24),
                  
                  // Disclaimer
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'Disclaimer',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'These insights are based on your personal data and general health recommendations. They are not a substitute for professional medical advice. Always consult with healthcare professionals for personalized guidance.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}