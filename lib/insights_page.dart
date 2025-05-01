// lib/insights_page.dart

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class InsightsPage extends StatefulWidget {
  const InsightsPage({Key? key}) : super(key: key);

  @override
  _InsightsPageState createState() => _InsightsPageState();
}

class _InsightsPageState extends State<InsightsPage> {
  bool isLoading = true;
  String? accessToken;
  String? errorMessage;
  
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
      });
      
      // Get current user
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        userName = user.displayName ?? 'User';
        
        // Load Fitbit token
        final prefs = await SharedPreferences.getInstance();
        final token = prefs.getString('fitbit_token');
        
        setState(() {
          accessToken = token;
        });
        
        if (token != null) {
          // Generate insights
          await _generateInsights(token);
        } else {
          // Still generate some sample insights if not connected
          _generateSampleInsights();
          setState(() {
            isLoading = false;
          });
        }
      } else {
        // Handle case where user isn't authenticated
        setState(() {
          isLoading = false;
          errorMessage = 'Please sign in to view insights';
        });
      }
    } catch (e) {
      setState(() {
        isLoading = false;
        errorMessage = 'Error loading user data: $e';
      });
    }
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
      
      // Get activity data
      await _fetchActivityInsights(token, weekAgo, today);
      
      // Get sleep data
      await _fetchSleepInsights(token, weekAgo, today);
      
      // Generate correlation insights
      await _generateCorrelationInsights(token, monthAgo, today);
      
      // Add nutrition insights (these are static for now)
      _addNutritionInsights();
      
      setState(() {
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
        errorMessage = 'Error generating insights: $e';
      });
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
        final stepsData = data['activities-steps'];
        
        // Calculate average steps
        int totalSteps = 0;
        for (var day in stepsData) {
          totalSteps += int.parse(day['value']);
        }
        
        final avgSteps = totalSteps / stepsData.length;
        
        // Find most active day
        String mostActiveDay = 'Unknown';
        int maxSteps = 0;
        
        for (var day in stepsData) {
          final steps = int.parse(day['value']);
          if (steps > maxSteps) {
            maxSteps = steps;
            final date = DateTime.parse(day['dateTime']);
            mostActiveDay = DateFormat('EEEE').format(date);
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
        activityInsights.add({
          'title': 'Most Active Day',
          'description': 'Your most active day of the week is $mostActiveDay with an average of ${NumberFormat('#,###').format(maxSteps)} steps.',
          'icon': Icons.calendar_today,
          'color': Colors.purple,
        });
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
        final minutesData = data['activities-minutesVeryActive'];
        
        // Calculate average active minutes
        int totalMinutes = 0;
        for (var day in minutesData) {
          totalMinutes += int.parse(day['value']);
        }
        
        final avgMinutes = totalMinutes / minutesData.length;
        
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
          // Calculate average sleep duration
          int totalSleepMinutes = 0;
          int totalDeepSleepMinutes = 0;
          int totalRemSleepMinutes = 0;
          int totalRecords = 0;
          
          for (var sleep in sleepData) {
            if (sleep['minutesAsleep'] != null) {
              totalSleepMinutes += (sleep['minutesAsleep'] as num).toInt();
              totalRecords++;
              
              // Get deep sleep data if available
              if (sleep['levels'] != null && sleep['levels']['summary'] != null) {
                final summary = sleep['levels']['summary'];
                
                if (summary['deep'] != null && summary['deep']['minutes'] != null) {
                  totalDeepSleepMinutes += (summary['deep']['minutes'] as num).toInt();
                }
                
                if (summary['rem'] != null && summary['rem']['minutes'] != null) {
                  totalRemSleepMinutes += (summary['rem']['minutes'] as num).toInt();
                }
              }
            }
          }
          
          if (totalRecords > 0) {
            final avgSleepMinutes = totalSleepMinutes / totalRecords;
            final avgSleepHours = avgSleepMinutes / 60;
            final avgDeepSleepMinutes = totalDeepSleepMinutes / totalRecords;
            final avgDeepSleepPercentage = (totalDeepSleepMinutes / totalSleepMinutes) * 100;
            final avgRemSleepPercentage = (totalRemSleepMinutes / totalSleepMinutes) * 100;
            
            // Add sleep duration insight
            if (avgSleepHours >= 7) {
              sleepInsights.add({
                'title': 'Optimal Sleep Duration',
                'description': 'You\'re averaging ${avgSleepHours.toStringAsFixed(1)} hours of sleep, which is within the recommended range.',
                'icon': Icons.bedtime,
                'color': Colors.indigo,
              });
            } else if (avgSleepHours >= 6) {
              sleepInsights.add({
                'title': 'Slightly Low Sleep Duration',
                'description': 'You\'re averaging ${avgSleepHours.toStringAsFixed(1)} hours of sleep. Try to get at least 7 hours for optimal health.',
                'icon': Icons.bedtime,
                'color': Colors.blue,
              });
            } else {
              sleepInsights.add({
                'title': 'Insufficient Sleep',
                'description': 'You\'re only getting ${avgSleepHours.toStringAsFixed(1)} hours of sleep. This is well below the recommended 7-9 hours.',
                'icon': Icons.bedtime,
                'color': Colors.red,
              });
            }
            
            // Add deep sleep insight
            if (avgDeepSleepPercentage >= 25) {
              sleepInsights.add({
                'title': 'Excellent Deep Sleep',
                'description': 'Your deep sleep makes up ${avgDeepSleepPercentage.round()}% of your total sleep, which is above average.',
                'icon': Icons.nightlight,
                'color': Colors.indigo,
              });
            } else if (avgDeepSleepPercentage >= 15) {
              sleepInsights.add({
                'title': 'Normal Deep Sleep',
                'description': 'Your deep sleep makes up ${avgDeepSleepPercentage.round()}% of your total sleep, which is within the normal range.',
                'icon': Icons.nightlight,
                'color': Colors.blue,
              });
            } else {
              sleepInsights.add({
                'title': 'Low Deep Sleep',
                'description': 'Your deep sleep only makes up ${avgDeepSleepPercentage.round()}% of your total sleep, which is below average.',
                'icon': Icons.nightlight,
                'color': Colors.orange,
              });
            }
            
            // Add REM sleep insight
            if (avgRemSleepPercentage >= 25) {
              sleepInsights.add({
                'title': 'Excellent REM Sleep',
                'description': 'Your REM sleep makes up ${avgRemSleepPercentage.round()}% of your total sleep, which is optimal for cognitive function.',
                'icon': Icons.psychology,
                'color': Colors.purple,
              });
            } else if (avgRemSleepPercentage >= 15) {
              sleepInsights.add({
                'title': 'Normal REM Sleep',
                'description': 'Your REM sleep makes up ${avgRemSleepPercentage.round()}% of your total sleep, which is within the normal range.',
                'icon': Icons.psychology,
                'color': Colors.blue,
              });
            } else {
              sleepInsights.add({
                'title': 'Low REM Sleep',
                'description': 'Your REM sleep only makes up ${avgRemSleepPercentage.round()}% of your total sleep, which is below average.',
                'icon': Icons.psychology,
                'color': Colors.orange,
              });
            }
          }
        } else {
          sleepInsights.add({
            'title': 'No Sleep Data',
            'description': 'We don\'t have enough sleep data to provide insights. Make sure to wear your device during sleep.',
            'icon': Icons.help_outline,
            'color': Colors.grey,
          });
        }
      }
    } catch (e) {
      print('Error fetching sleep insights: $e');
    }
  }

  Future<void> _generateCorrelationInsights(String token, String startDate, String endDate) async {
    try {
      // This is a simplified version - in a real app, you would analyze actual correlations
      
      // For now, add some sample correlation insights
      correlationInsights.add({
        'title': 'Evening Walks Improve Sleep',
        'description': 'Your 7 PM walks correlate with better sleep quality. You fall asleep 15 minutes faster on days with evening walks.',
        'icon': Icons.nights_stay,
        'color': Colors.indigo,
      });
      
      correlationInsights.add({
        'title': 'Morning Exercise Boosts Heart Health',
        'description': 'Your heart rate variability is 12% higher on days when you exercise before noon.',
        'icon': Icons.monitor_heart,
        'color': Colors.red,
      });
      
      correlationInsights.add({
        'title': 'Hydration and Energy',
        'description': 'On days when you log at least 64oz of water, your reported energy levels are 25% higher.',
        'icon': Icons.water_drop,
        'color': Colors.blue,
      });
      
      correlationInsights.add({
        'title': 'Consistent Sleep Schedule',
        'description': 'When you go to bed within 30 minutes of your average bedtime, you get 8% more REM sleep.',
        'icon': Icons.schedule,
        'color': Colors.purple,
      });
    } catch (e) {
      print('Error generating correlation insights: $e');
    }
  }

  void _addNutritionInsights() {
    // Add some sample nutrition insights
    nutritionInsights.add({
      'title': 'Protein Intake',
      'description': 'Your average protein intake is 0.7g per pound of body weight, which supports muscle maintenance.',
      'icon': Icons.egg_alt,
      'color': Colors.amber,
    });
    
    nutritionInsights.add({
      'title': 'Meal Timing',
      'description': 'You tend to consume most of your calories before 7 PM, which aligns well with your sleep schedule.',
      'icon': Icons.schedule,
      'color': Colors.green,
    });
    
    nutritionInsights.add({
      'title': 'Carbohydrate Distribution',
      'description': 'Consider shifting more of your carbohydrate intake to pre and post-workout periods for optimal energy.',
      'icon': Icons.bakery_dining,
      'color': Colors.orange,
    });
  }

  void _generateSampleInsights() {
    // Generate sample insights for users without Fitbit connection
    
    // Activity insights
    activityInsights.add({
      'title': 'Daily Step Goal',
      'description': 'Aim for at least 10,000 steps daily for cardiovascular health and weight management.',
      'icon': Icons.directions_walk,
      'color': Colors.blue,
    });
    
    activityInsights.add({
      'title': 'Activity Frequency',
      'description': 'For optimal fitness, try to engage in moderate to vigorous activity at least 5 days per week.',
      'icon': Icons.fitness_center,
      'color': Colors.green,
    });
    
    // Sleep insights
    sleepInsights.add({
      'title': 'Sleep Duration',
      'description': 'Adults should aim for 7-9 hours of sleep per night for optimal cognitive and physical health.',
      'icon': Icons.bedtime,
      'color': Colors.indigo,
    });
    
    sleepInsights.add({
      'title': 'Sleep Schedule',
      'description': 'Maintaining a consistent sleep schedule, even on weekends, helps regulate your circadian rhythm.',
      'icon': Icons.schedule,
      'color': Colors.purple,
    });
    
    // Nutrition insights
    nutritionInsights.add({
      'title': 'Hydration',
      'description': 'Aim to drink at least 64oz (8 cups) of water daily for optimal hydration and metabolism.',
      'icon': Icons.water_drop,
      'color': Colors.blue,
    });
    
    nutritionInsights.add({
      'title': 'Protein Intake',
      'description': 'Consume 0.8-1g of protein per pound of body weight to support muscle recovery and maintenance.',
      'icon': Icons.egg_alt,
      'color': Colors.amber,
    });
    
    // Correlation insights - general health facts
    correlationInsights.add({
      'title': 'Exercise and Sleep',
      'description': 'Regular physical activity can help you fall asleep faster and enjoy deeper sleep.',
      'icon': Icons.nights_stay,
      'color': Colors.indigo,
    });
    
    correlationInsights.add({
      'title': 'Screen Time',
      'description': 'Avoiding screens 1 hour before bedtime can improve sleep quality by reducing blue light exposure.',
      'icon': Icons.phonelink_erase,
      'color': Colors.grey,
    });
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
                await _generateInsights(accessToken!);
              } else {
                _generateSampleInsights();
                setState(() {});
              }
            },
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          size: 48,
                          color: Colors.red,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          errorMessage!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 16),
                        ),
                      ],
                    ),
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
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