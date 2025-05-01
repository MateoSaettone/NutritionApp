// lib/weekly_summary_page.dart

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:ui' as ui;
import 'mock_data_provider.dart'; // Import mock data provider

class WeeklySummaryPage extends StatefulWidget {
  const WeeklySummaryPage({Key? key}) : super(key: key);

  @override
  _WeeklySummaryPageState createState() => _WeeklySummaryPageState();
}

class _WeeklySummaryPageState extends State<WeeklySummaryPage> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  
  bool isLoading = true;
  String? errorMessage;
  bool useMockData = false;
  String? accessToken;
  
  // Weekly data containers
  List<int> dailySteps = List.filled(7, 0);
  List<double> dailyMoodRatings = List.filled(7, 0);
  List<double> dailyEnergyLevels = List.filled(7, 0);
  double weeklyAvgMood = 0;
  double weeklyAvgEnergy = 0;
  int totalSteps = 0;
  double avgSteps = 0;
  
  // Date references
  late DateTime startOfWeek;
  late DateTime endOfWeek;
  List<String> weekDays = [];
  
  @override
  void initState() {
    super.initState();
    _initializeDates();
    _loadWeeklyData();
  }
  
  void _initializeDates() {
    // Calculate the start of the week (Sunday)
    final now = DateTime.now();
    startOfWeek = now.subtract(Duration(days: now.weekday % 7));
    startOfWeek = DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);
    
    // Calculate end of week (Saturday)
    endOfWeek = startOfWeek.add(const Duration(days: 6));
    
    // Generate list of weekday names
    weekDays = List.generate(7, (index) {
      final day = startOfWeek.add(Duration(days: index));
      return DateFormat('E').format(day); // Short day name (e.g., "Mon")
    });
  }
  
  Future<void> _loadWeeklyData() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
      useMockData = false;
    });
    
    try {
      // Check if Fitbit is connected
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('fitbit_token');
      
      setState(() {
        accessToken = token;
      });
      
      // If Fitbit is connected, try to load step data
      if (token != null) {
        try {
          await _fetchFitbitWeeklyData(token);
        } catch (e) {
          print('Error fetching Fitbit data: $e');
          _useMockStepData('Error connecting to Fitbit: $e');
        }
      } else {
        _useMockStepData('No Fitbit connection available');
      }
      
      // Load survey data from Firestore regardless of Fitbit connection
      try {
        await _fetchSurveyData();
      } catch (e) {
        print('Error fetching survey data: $e');
        _useMockSurveyData('Error loading survey data: $e');
      }
      
      // Calculate weekly averages
      _calculateWeeklyAverages();
      
      setState(() {
        isLoading = false;
      });
    } catch (e) {
      _useAllMockData('Error loading weekly data: $e');
    }
  }
  
  void _useMockStepData(String message) {
    setState(() {
      useMockData = true;
      final mockData = MockDataProvider.getMockWeeklySummaryData();
      dailySteps = List<int>.from(mockData['dailySteps']);
      totalSteps = mockData['totalSteps'];
      avgSteps = mockData['avgSteps'];
      
      // Append message to existing error or set new one
      if (errorMessage != null) {
        errorMessage = '$errorMessage\n$message';
      } else {
        errorMessage = message;
      }
    });
  }
  
  void _useMockSurveyData(String message) {
    setState(() {
      useMockData = true;
      final mockData = MockDataProvider.getMockWeeklySummaryData();
      dailyMoodRatings = List<double>.from(mockData['dailyMoodRatings']);
      dailyEnergyLevels = List<double>.from(mockData['dailyEnergyLevels']);
      weeklyAvgMood = mockData['weeklyAvgMood'];
      weeklyAvgEnergy = mockData['weeklyAvgEnergy'];
      
      // Append message to existing error or set new one
      if (errorMessage != null) {
        errorMessage = '$errorMessage\n$message';
      } else {
        errorMessage = message;
      }
    });
  }
  
  void _useAllMockData(String message) {
    setState(() {
      isLoading = false;
      useMockData = true;
      errorMessage = message;
      
      final mockData = MockDataProvider.getMockWeeklySummaryData();
      dailySteps = List<int>.from(mockData['dailySteps']);
      dailyMoodRatings = List<double>.from(mockData['dailyMoodRatings']);
      dailyEnergyLevels = List<double>.from(mockData['dailyEnergyLevels']);
      weeklyAvgMood = mockData['weeklyAvgMood'];
      weeklyAvgEnergy = mockData['weeklyAvgEnergy'];
      totalSteps = mockData['totalSteps'];
      avgSteps = mockData['avgSteps'];
    });
  }
  
  Future<void> _fetchFitbitWeeklyData(String token) async {
    try {
      // Format dates for Fitbit API
      final startDateStr = DateFormat('yyyy-MM-dd').format(startOfWeek);
      final endDateStr = DateFormat('yyyy-MM-dd').format(endOfWeek);
      
      // Fetch weekly steps data
      final stepsResponse = await http.get(
        Uri.parse('https://api.fitbit.com/1/user/-/activities/steps/date/$startDateStr/$endDateStr.json'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );
      
      if (stepsResponse.statusCode == 200) {
        final data = json.decode(stepsResponse.body);
        final stepsData = data['activities-steps'] as List;
        
        // Reset daily steps array
        dailySteps = List.filled(7, 0);
        
        // Process steps data for each day
        for (int i = 0; i < 7 && i < stepsData.length; i++) {
          final dayData = stepsData[i];
          final dayDateStr = dayData['dateTime'] as String?;
          
          if (dayDateStr != null && dayDateStr.isNotEmpty) {
            final dayDate = DateFormat('yyyy-MM-dd').parse(dayDateStr);
            
            // Calculate the day index (0 = Sunday, 6 = Saturday)
            final dayIndex = dayDate.difference(startOfWeek).inDays;
            
            if (dayIndex >= 0 && dayIndex < 7) {
              dailySteps[dayIndex] = int.tryParse(dayData['value'].toString()) ?? 0;
            }
          }
        }
      } else if (stepsResponse.statusCode == 401) {
        // Handle expired token
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('fitbit_token');
        throw Exception('Fitbit authentication expired. Please reconnect your Fitbit account.');
      } else {
        throw Exception('Failed to load Fitbit data: ${stepsResponse.statusCode}');
      }
    } catch (e) {
      // Re-throw for the caller to handle
      throw Exception('Error fetching Fitbit data: $e');
    }
  }
  
  Future<void> _fetchSurveyData() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) {
        throw Exception('User not logged in');
      }
      
      // Format dates for Firestore queries
      final startDateStr = DateFormat('yyyy-MM-dd').format(startOfWeek);
      final endDateStr = DateFormat('yyyy-MM-dd').format(endOfWeek);
      
      // Query surveys for the week
      final surveys = await _firestore
          .collection('users')
          .doc(userId)
          .collection('surveys')
          .where('date', isGreaterThanOrEqualTo: startDateStr)
          .where('date', isLessThanOrEqualTo: endDateStr)
          .get();
      
      // Initialize daily mood and energy arrays
      dailyMoodRatings = List.filled(7, 0);
      dailyEnergyLevels = List.filled(7, 0);
      List<bool> hasMoodData = List.filled(7, false);
      List<bool> hasEnergyData = List.filled(7, false);
      
      // Process survey data
      for (final survey in surveys.docs) {
        final data = survey.data();
        final String? dateStr = data['date'] as String?;
        if (dateStr != null && dateStr.isNotEmpty) {
          final date = DateFormat('yyyy-MM-dd').parse(dateStr);
          final dayIndex = date.difference(startOfWeek).inDays;
          if (dayIndex >= 0 && dayIndex < 7) {
            if (data.containsKey('moodRating')) {
              dailyMoodRatings[dayIndex] = (data['moodRating'] as num).toDouble();
              hasMoodData[dayIndex] = true;
            }
            if (data.containsKey('energyLevel')) {
              dailyEnergyLevels[dayIndex] = (data['energyLevel'] as num).toDouble();
              hasEnergyData[dayIndex] = true;
            }
          }
        }
      }
      
      // Check if we have any real survey data
      final hasSomeRealMoodData = hasMoodData.any((has) => has);
      final hasSomeRealEnergyData = hasEnergyData.any((has) => has);
      
      // If we have no survey data at all, use mock data
      if (!hasSomeRealMoodData && !hasSomeRealEnergyData) {
        final mockData = MockDataProvider.getMockWeeklySummaryData();
        dailyMoodRatings = List<double>.from(mockData['dailyMoodRatings']);
        dailyEnergyLevels = List<double>.from(mockData['dailyEnergyLevels']);
        
        // Mark as using some mock data, but don't override other real data
        setState(() {
          useMockData = true;
          // Only add error message if not already set
          if (errorMessage == null) {
            errorMessage = 'No survey data available for this week. Showing sample mood and energy data.';
          }
        });
      }
    } catch (e) {
      // Re-throw for the caller to handle
      throw Exception('Error fetching survey data: $e');
    }
  }
  
  void _calculateWeeklyAverages() {
    // Calculate total steps and average steps
    totalSteps = dailySteps.fold(0, (sum, steps) => sum + steps);
    int nonZeroDays = dailySteps.where((steps) => steps > 0).length;
    avgSteps = nonZeroDays > 0 ? totalSteps / nonZeroDays : 0;
    
    // Calculate average mood and energy
    int nonZeroMoodDays = dailyMoodRatings.where((mood) => mood > 0).length;
    int nonZeroEnergyDays = dailyEnergyLevels.where((energy) => energy > 0).length;
    
    weeklyAvgMood = nonZeroMoodDays > 0 
        ? dailyMoodRatings.fold(0.0, (sum, mood) => sum + mood) / nonZeroMoodDays 
        : 0;
    
    weeklyAvgEnergy = nonZeroEnergyDays > 0 
        ? dailyEnergyLevels.fold(0.0, (sum, energy) => sum + energy) / nonZeroEnergyDays 
        : 0;
  }
  
  Future<void> _refreshData() async {
    await _loadWeeklyData();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Weekly summary refreshed'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Weekly Summary'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: isLoading ? null : _refreshData,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Loading weekly data...'),
                ],
              ),
            )
          : errorMessage != null && useMockData
              // Show data with warning banner
              ? RefreshIndicator(
                  onRefresh: _refreshData,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Warning banner
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
                        // Regular content continues below
                        ..._buildSummaryContent(),
                      ],
                    ),
                  ),
                )
              : errorMessage != null
                  // Show error with retry button
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.error_outline,
                            size: 48,
                            color: Colors.red.shade700,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            errorMessage!,
                            style: TextStyle(color: Colors.red.shade700),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton(
                            onPressed: _refreshData,
                            child: const Text('Try Again'),
                          ),
                        ],
                      ),
                    )
                  // Show regular content
                  : RefreshIndicator(
                      onRefresh: _refreshData,
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: _buildSummaryContent(),
                        ),
                      ),
                    ),
    );
  }
  
  List<Widget> _buildSummaryContent() {
    return [
      // Date range header
      Card(
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  Icon(Icons.calendar_today, color: Colors.blue),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Weekly Summary',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${DateFormat('MMM d').format(startOfWeek)} - ${DateFormat('MMM d').format(endOfWeek)}',
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      
      const SizedBox(height: 24),
      
      // Weekly activity summary
      Card(
        elevation: 3,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Weekly Activity Overview',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              
              // Summary metrics
              _buildSummaryMetric(
                Icons.directions_walk,
                'Total Steps',
                NumberFormat('#,###').format(totalSteps),
              ),
              const Divider(),
              _buildSummaryMetric(
                Icons.show_chart,
                'Daily Average Steps',
                NumberFormat('#,###').format(avgSteps.round()),
              ),
              const Divider(),
              _buildSummaryMetric(
                Icons.mood,
                'Average Mood Rating',
                weeklyAvgMood > 0 
                    ? '${weeklyAvgMood.toStringAsFixed(1)}/10' 
                    : 'No data',
              ),
              const Divider(),
              _buildSummaryMetric(
                Icons.battery_charging_full,
                'Average Energy Level',
                weeklyAvgEnergy > 0 
                    ? '${weeklyAvgEnergy.toStringAsFixed(1)}/10' 
                    : 'No data',
              ),
            ],
          ),
        ),
      ),
      
      const SizedBox(height: 24),
      
      // Steps chart
      Card(
        elevation: 3,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Daily Steps',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: 200,
                child: _buildStepsBarChart(),
              ),
            ],
          ),
        ),
      ),
      
      const SizedBox(height: 24),
      
      // Mood & Energy chart
      Card(
        elevation: 3,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Mood & Energy Levels',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: 200,
                child: _buildMoodEnergyChart(),
              ),
              const SizedBox(height: 16),
              
              // Legend
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.circle, color: Colors.blue, size: 12),
                  const SizedBox(width: 4),
                  const Text('Mood'),
                  const SizedBox(width: 24),
                  Icon(Icons.circle, color: Colors.orange, size: 12),
                  const SizedBox(width: 4),
                  const Text('Energy'),
                ],
              ),
            ],
          ),
        ),
      ),
      
      const SizedBox(height: 24),
      
      // Insights and Recommendations
      Card(
        elevation: 3,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Insights & Recommendations',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              
              // Generate some basic insights based on the data
              ..._generateInsights(),
            ],
          ),
        ),
      ),
      
      const SizedBox(height: 24),
    ];
  }
  
  Widget _buildSummaryMetric(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: Colors.blue),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 16),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildStepsBarChart() {
    const double barWidth = 25.0;
    
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxHeight = constraints.maxHeight - 30; // Leave room for labels
        final maxSteps = dailySteps.fold(0, (max, steps) => steps > max ? steps : max);
        final scale = maxSteps > 0 ? maxHeight / maxSteps : 0;
        
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: List.generate(7, (dayIndex) {
            final steps = dailySteps[dayIndex];
            final barHeight = steps > 0 ? steps * scale : 0;
            
            return Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // Bar value
                Text(
                  steps > 0 ? NumberFormat.compact().format(steps) : '',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                
                // Bar
                Container(
                  width: barWidth,
                  height: barHeight > 0 ? barHeight.toDouble() : 2.0,
                  decoration: BoxDecoration(
                    color: steps > 0 ? Colors.blue : Colors.grey.shade300,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                
                // Day label
                Text(
                  weekDays[dayIndex],
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            );
          }),
        );
      },
    );
  }
  
  Widget _buildMoodEnergyChart() {
    // Colors for the chart
    const moodColor = Colors.blue;
    const energyColor = Colors.orange;
    
    return LayoutBuilder(
      builder: (context, constraints) {
        final chartWidth = constraints.maxWidth;
        final chartHeight = constraints.maxHeight - 30; // Leave room for labels
        
        return CustomPaint(
          size: Size(chartWidth, constraints.maxHeight),
          painter: LineChartPainter(
            moodData: dailyMoodRatings,
            energyData: dailyEnergyLevels,
            moodColor: moodColor,
            energyColor: energyColor,
            weekDays: weekDays,
            chartHeight: chartHeight,
          ),
        );
      },
    );
  }
  
  List<Widget> _generateInsights() {
    final insights = <Widget>[];
    
    // Check if we have enough data
    final hasStepsData = dailySteps.any((steps) => steps > 0);
    final hasMoodData = dailyMoodRatings.any((mood) => mood > 0);
    final hasEnergyData = dailyEnergyLevels.any((energy) => energy > 0);
    
    if (!hasStepsData && !hasMoodData && !hasEnergyData) {
      insights.add(
        const ListTile(
          leading: Icon(Icons.info, color: Colors.blue),
          title: Text('Not enough data'),
          subtitle: Text('Start tracking your daily activity and complete surveys to see insights here.'),
        ),
      );
      return insights;
    }
    
    // Steps insights
    if (hasStepsData) {
      final avgStepsGoal = 10000; // Common daily step goal
      if (avgSteps >= avgStepsGoal) {
        insights.add(
          ListTile(
            leading: const Icon(Icons.directions_walk, color: Colors.green),
            title: const Text('Great job staying active!'),
            subtitle: Text('You\'re averaging ${NumberFormat('#,###').format(avgSteps.round())} steps per day, which meets the recommended goal.'),
          ),
        );
      } else {
        insights.add(
          ListTile(
            leading: const Icon(Icons.directions_walk, color: Colors.orange),
            title: const Text('Increase your daily activity'),
            subtitle: Text('Try to aim for 10,000 steps per day. You\'re currently averaging ${NumberFormat('#,###').format(avgSteps.round())}.'),
          ),
        );
      }
    }
    
    // Mood insights
    if (hasMoodData) {
      if (weeklyAvgMood >= 7) {
        insights.add(
          ListTile(
            leading: const Icon(Icons.mood, color: Colors.green),
            title: const Text('Positive mood patterns'),
            subtitle: Text('Your average mood rating is ${weeklyAvgMood.toStringAsFixed(1)}/10, which is quite good. Keep up the positive habits!'),
          ),
        );
      } else if (weeklyAvgMood < 5) {
        insights.add(
          ListTile(
            leading: const Icon(Icons.mood_bad, color: Colors.red),
            title: const Text('Mood improvement opportunity'),
            subtitle: const Text('Your mood ratings are on the lower side. Consider speaking with a healthcare professional or trying stress reduction techniques.'),
          ),
        );
      }
    }
    
    // Energy insights
    if (hasEnergyData) {
      if (weeklyAvgEnergy < 5) {
        insights.add(
          ListTile(
            leading: const Icon(Icons.battery_alert, color: Colors.orange),
            title: const Text('Low energy levels'),
            subtitle: const Text('Your energy levels are lower than optimal. Try improving sleep quality and maintaining a regular sleep schedule.'),
          ),
        );
      }
    }
    
    // Correlation insights (basic)
    if (hasStepsData && hasMoodData) {
      // Calculate a very basic correlation
      int matchingDays = 0;
      int positiveCorrelations = 0;
      
      for (int i = 0; i < 7; i++) {
        if (dailySteps[i] > 0 && dailyMoodRatings[i] > 0) {
          matchingDays++;
          
          final isHighSteps = dailySteps[i] > 7000; // Arbitrary threshold
          final isHighMood = dailyMoodRatings[i] > 6; // Arbitrary threshold
          
          if (isHighSteps == isHighMood) {
            positiveCorrelations++;
          }
        }
      }
      
      if (matchingDays >= 3) { // Only show if we have at least 3 days of matching data
        final correlationStrength = positiveCorrelations / matchingDays;
        
        if (correlationStrength >= 0.7) {
          insights.add(
            const ListTile(
              leading: Icon(Icons.insights, color: Colors.purple),
              title: Text('Activity and mood connection'),
              subtitle: Text('There appears to be a positive relationship between your physical activity and mood. Regular exercise may help maintain positive mood.'),
            ),
          );
        }
      }
    }
    
    // If no specific insights, add a general one
    if (insights.isEmpty) {
      insights.add(
        const ListTile(
          leading: Icon(Icons.tips_and_updates, color: Colors.blue),
          title: Text('Keep tracking for better insights'),
          subtitle: Text('Continue logging your daily activity and completing surveys to receive more personalized insights and recommendations.'),
        ),
      );
    }
    
    return insights;
  }
}

// Custom painter for line chart
class LineChartPainter extends CustomPainter {
  final List<double> moodData;
  final List<double> energyData;
  final Color moodColor;
  final Color energyColor;
  final List<String> weekDays;
  final double chartHeight;
  
  LineChartPainter({
    required this.moodData,
    required this.energyData,
    required this.moodColor,
    required this.energyColor,
    required this.weekDays,
    required this.chartHeight,
  });
  
  @override
  void paint(Canvas canvas, Size size) {
    final width = size.width;
    
    // Define paint objects
    final moodPaint = Paint()
      ..color = moodColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    
    final energyPaint = Paint()
      ..color = energyColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    
    final gridPaint = Paint()
      ..color = Colors.grey.shade300
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    
    // Draw grid lines
    for (int i = 0; i <= 10; i += 2) {
      final y = chartHeight - (i / 10 * chartHeight);
      canvas.drawLine(
        Offset(0, y),
        Offset(width, y),
        gridPaint,
      );
    }
    
    // Calculate x-coordinates
    final pointWidth = width / 6; // 7 points, 6 intervals
    
    // Draw mood line
    final moodPath = Path();
    bool moodPathStarted = false;
    
    for (int i = 0; i < 7; i++) {
      if (moodData[i] > 0) {
        final x = i * pointWidth;
        final y = chartHeight - (moodData[i] / 10 * chartHeight);
        
        if (!moodPathStarted) {
          moodPath.moveTo(x, y);
          moodPathStarted = true;
        } else {
          moodPath.lineTo(x, y);
        }
        
        // Draw point
        canvas.drawCircle(
          Offset(x, y),
          4,
          Paint()..color = moodColor,
        );
      }
    }
    
    if (moodPathStarted) {
      canvas.drawPath(moodPath, moodPaint);
    }
    
    // Draw energy line
    final energyPath = Path();
    bool energyPathStarted = false;
    
    for (int i = 0; i < 7; i++) {
      if (energyData[i] > 0) {
        final x = i * pointWidth;
        final y = chartHeight - (energyData[i] / 10 * chartHeight);
        
        if (!energyPathStarted) {
          energyPath.moveTo(x, y);
          energyPathStarted = true;
        } else {
          energyPath.lineTo(x, y);
        }
        
        // Draw point
        canvas.drawCircle(
          Offset(x, y),
          4,
          Paint()..color = energyColor,
        );
      }
    }
    
    if (energyPathStarted) {
      canvas.drawPath(energyPath, energyPaint);
    }
    
    // Draw x-axis labels (days)
    for (int i = 0; i < 7; i++) {
      final x = i * pointWidth;
      final y = chartHeight + 10;
      
      // Draw the day label text
      final dayText = weekDays[i];
      
      // Center text below the point
      final textX = x - (dayText.length * 3.5); // Approximation for centering
      
      final builder = ui.ParagraphBuilder(ui.ParagraphStyle(
        textAlign: TextAlign.center,
        fontSize: 12,
      ))
        ..pushStyle(ui.TextStyle(
          color: Colors.grey.shade700,
          fontSize: 12,
        ))
        ..addText(dayText);
        
      final paragraph = builder.build()
        ..layout(ui.ParagraphConstraints(width: 50));
      
      canvas.drawParagraph(paragraph, Offset(textX, y));
    }
  }
  
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}