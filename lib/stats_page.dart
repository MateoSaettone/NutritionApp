// lib/stats_page.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:fl_chart/fl_chart.dart';

class StatsPage extends StatefulWidget {
  const StatsPage({Key? key}) : super(key: key);

  @override
  _StatsPageState createState() => _StatsPageState();
}

class _StatsPageState extends State<StatsPage> with SingleTickerProviderStateMixin {
  bool isLoading = true;
  String? accessToken;
  String? errorMessage;
  
  // Date range for data
  late DateTime startDate;
  late DateTime endDate;
  String _selectedRange = 'Week';
  final List<String> _timeRanges = ['Day', 'Week', 'Month'];

  // Tab controller
  late TabController _tabController;
  final List<String> _metricTabs = ['Steps', 'Heart Rate', 'Sleep', 'Activity'];

  // Data
  Map<String, List<FlSpot>> chartData = {
    'steps': [],
    'heartRate': [],
    'heartRateIntraday': [],
    'calories': [],
    'activeMinutes': [],
    'sleepDuration': [],
    'deepSleep': [],
    'remSleep': [],
  };
  
  // Stats
  Map<String, Map<String, dynamic>> stats = {
    'steps': {
      'total': 0,
      'average': 0,
      'max': 0,
      'min': 0,
      'maxDay': '',
      'minDay': '',
      'goal': 10000,
      'daysAboveGoal': 0,
    },
    'heartRate': {
      'average': 0,
      'max': 0,
      'min': 0,
      'variance': 0,
    },
    'sleep': {
      'avgDuration': 0,
      'avgDeepPercentage': 0,
      'avgRemPercentage': 0,
      'bestNight': '',
      'worstNight': '',
    },
    'activity': {
      'totalActiveMinutes': 0,
      'totalCaloriesBurned': 0,
      'mostActiveDay': '',
      'leastActiveDay': '',
    }
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _metricTabs.length, vsync: this);
    _setupDateRange();
    _loadAccessToken();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _setupDateRange() {
    // Default to showing the past week
    endDate = DateTime.now();
    startDate = endDate.subtract(const Duration(days: 7));
  }

  Future<void> _loadAccessToken() async {
    try {
      setState(() {
        isLoading = true;
        errorMessage = null;
      });

      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('fitbit_token');

      if (token != null && token.isNotEmpty) {
        accessToken = token;
        await _loadData();
      } else {
        setState(() {
          isLoading = false;
          errorMessage = 'Please connect your Fitbit account to view stats';
        });
      }
    } catch (e) {
      setState(() {
        isLoading = false;
        errorMessage = 'Error loading access token: $e';
      });
    }
  }
  
  Future<void> _loadData() async {
    try {
      if (accessToken == null) {
        setState(() {
          isLoading = false;
          errorMessage = 'No Fitbit access token available';
        });
        return;
      }
      
      // Get formatted date strings for API calls
      final formattedEndDate = DateFormat('yyyy-MM-dd').format(endDate);
      final formattedStartDate = DateFormat('yyyy-MM-dd').format(startDate);
      
      // Load steps data
      await _loadStepsData(formattedStartDate, formattedEndDate);
      
      // Load heart rate data
      await _loadHeartRateData(formattedStartDate, formattedEndDate);
      
      // Load sleep data
      await _loadSleepData(formattedStartDate, formattedEndDate);
      
      // Load activity data
      await _loadActivityData(formattedStartDate, formattedEndDate);
      
      setState(() {
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
        errorMessage = 'Error loading data: $e';
      });
    }
  }
  
  Future<void> _loadStepsData(String startDate, String endDate) async {
    try {
      final response = await http.get(
        Uri.parse('https://api.fitbit.com/1/user/-/activities/steps/date/$startDate/$endDate.json'),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Accept': 'application/json',
        },
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final stepsData = data['activities-steps'];
        
        // Clear existing data
        chartData['steps'] = [];
        
        // Reset stats
        stats['steps']?['total'] = 0;
        stats['steps']?['max'] = 0;
        stats['steps']?['min'] = 999999;
        stats['steps']?['daysAboveGoal'] = 0;
        
        double total = 0;
        double max = 0;
        double min = double.infinity;
        String maxDay = '';
        String minDay = '';
        int daysAboveGoal = 0;
        int goalSteps = stats['steps']?['goal'] ?? 10000;
        
        // Process the data
        for (int i = 0; i < stepsData.length; i++) {
          final entry = stepsData[i];
          final steps = double.parse(entry['value']);
          final day = DateFormat('yyyy-MM-dd').parse(entry['dateTime']);
          
          // Add to chart data
          chartData['steps']?.add(FlSpot(i.toDouble(), steps));
          
          // Update stats
          total += steps;
          
          if (steps > max) {
            max = steps;
            maxDay = DateFormat('EEE, MMM d').format(day);
          }
          
          if (steps < min) {
            min = steps;
            minDay = DateFormat('EEE, MMM d').format(day);
          }
          
          if (steps >= goalSteps) {
            daysAboveGoal++;
          }
        }
        
        // Calculate average
        final average = stepsData.isNotEmpty ? total / stepsData.length : 0;
        
        // Update stats
        stats['steps']?['total'] = total.round();
        stats['steps']?['average'] = average.round();
        stats['steps']?['max'] = max.round();
        stats['steps']?['min'] = min != double.infinity ? min.round() : 0;
        stats['steps']?['maxDay'] = maxDay;
        stats['steps']?['minDay'] = minDay;
        stats['steps']?['daysAboveGoal'] = daysAboveGoal;
      } else if (response.statusCode == 401) {
        // Token expired
        throw Exception('Fitbit authentication expired. Please reconnect your account.');
      } else {
        throw Exception('Failed to load steps data: ${response.statusCode}');
      }
    } catch (e) {
      print('Error loading steps data: $e');
      // Continue with other data loads
    }
  }
  
  Future<void> _loadHeartRateData(String startDate, String endDate) async {
    try {
      final response = await http.get(
        Uri.parse('https://api.fitbit.com/1/user/-/activities/heart/date/$startDate/$endDate.json'),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Accept': 'application/json',
        },
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final heartData = data['activities-heart'];
        
        // Clear existing data
        chartData['heartRate'] = [];
        
        // Reset stats
        stats['heartRate']?['average'] = 0;
        stats['heartRate']?['max'] = 0;
        stats['heartRate']?['min'] = 999;
        
        double total = 0;
        double max = 0;
        double min = double.infinity;
        List<double> allValues = [];
        
        // Process the data
        for (int i = 0; i < heartData.length; i++) {
          final entry = heartData[i];
          final value = entry['value'];
          
          if (value is Map && value.containsKey('restingHeartRate')) {
            final hr = value['restingHeartRate'].toDouble();
            
            // Add to chart data
            chartData['heartRate']?.add(FlSpot(i.toDouble(), hr));
            
            // Update stats
            total += hr;
            allValues.add(hr);
            
            if (hr > max) {
              max = hr;
            }
            
            if (hr < min) {
              min = hr;
            }
          }
        }
        
        // Calculate average and variance
        final average = allValues.isNotEmpty ? total / allValues.length : 0;
        
        double variance = 0;
        if (allValues.isNotEmpty) {
          double sumSquaredDiff = 0;
          for (var value in allValues) {
            sumSquaredDiff += (value - average) * (value - average);
          }
          variance = sumSquaredDiff / allValues.length;
        }
        
        // Update stats
        stats['heartRate']?['average'] = average.round();
        stats['heartRate']?['max'] = max.round();
        stats['heartRate']?['min'] = min != double.infinity ? min.round() : 0;
        stats['heartRate']?['variance'] = variance.toStringAsFixed(2);
      }
    } catch (e) {
      print('Error loading heart rate data: $e');
      // Continue with other data loads
    }
  }
  
  Future<void> _loadSleepData(String startDate, String endDate) async {
    try {
      final response = await http.get(
        Uri.parse('https://api.fitbit.com/1.2/user/-/sleep/date/$startDate/$endDate.json'),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Accept': 'application/json',
        },
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final sleepData = data['sleep'];
        
        // Clear existing data
        chartData['sleepDuration'] = [];
        chartData['deepSleep'] = [];
        chartData['remSleep'] = [];
        
        // Reset sleep stats
        stats['sleep']?['avgDuration'] = 0;
        stats['sleep']?['avgDeepPercentage'] = 0;
        stats['sleep']?['avgRemPercentage'] = 0;
        
        if (sleepData != null && sleepData.isNotEmpty) {
          // Group sleep data by date
          Map<String, List<dynamic>> sleepByDate = {};
          
          for (var sleep in sleepData) {
            final dateTime = DateTime.parse(sleep['dateOfSleep']);
            final date = DateFormat('yyyy-MM-dd').format(dateTime);
            
            if (!sleepByDate.containsKey(date)) {
              sleepByDate[date] = [];
            }
            
            sleepByDate[date]?.add(sleep);
          }
          
          // Calculate daily totals
          List<MapEntry<DateTime, int>> dailySleepMinutes = [];
          List<MapEntry<DateTime, double>> dailyDeepPercentage = [];
          List<MapEntry<DateTime, double>> dailyRemPercentage = [];
          
          int totalSleepMinutes = 0;
          int totalDeepSleepMinutes = 0;
          int totalRemSleepMinutes = 0;
          
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
                
                // Calculate sleep score for best/worst night (simplified)
                final sleepScore = (dayDeepMinutes / (dayTotalMinutes > 0 ? dayTotalMinutes : 1) * 100).round();
                
                if (sleepScore > bestSleepScore) {
                  bestSleepScore = sleepScore;
                  bestNight = DateFormat('EEE, MMM d').format(DateTime.parse(date));
                }
                
                if (sleepScore < worstSleepScore && dayTotalMinutes > 180) { // At least 3 hours of sleep
                  worstSleepScore = sleepScore;
                  worstNight = DateFormat('EEE, MMM d').format(DateTime.parse(date));
                }
              }
            }
            
            // Add to daily totals
            dailySleepMinutes.add(MapEntry(DateTime.parse(date), dayTotalMinutes));
            
            double deepPercentage = dayTotalMinutes > 0 
                ? (dayDeepMinutes / dayTotalMinutes * 100) 
                : 0;
                
            double remPercentage = dayTotalMinutes > 0 
                ? (dayRemMinutes / dayTotalMinutes * 100) 
                : 0;
                
            dailyDeepPercentage.add(MapEntry(DateTime.parse(date), deepPercentage));
            dailyRemPercentage.add(MapEntry(DateTime.parse(date), remPercentage));
            
            // Add to total for averages
            totalSleepMinutes += dayTotalMinutes;
            totalDeepSleepMinutes += dayDeepMinutes;
            totalRemSleepMinutes += dayRemMinutes;
          });
          
          // Sort by date
          dailySleepMinutes.sort((a, b) => a.key.compareTo(b.key));
          dailyDeepPercentage.sort((a, b) => a.key.compareTo(b.key));
          dailyRemPercentage.sort((a, b) => a.key.compareTo(b.key));
          
          // Add to chart data
          for (int i = 0; i < dailySleepMinutes.length; i++) {
            final minutes = dailySleepMinutes[i].value.toDouble();
            chartData['sleepDuration']?.add(FlSpot(i.toDouble(), minutes / 60)); // Convert to hours
            
            if (i < dailyDeepPercentage.length) {
              chartData['deepSleep']?.add(FlSpot(i.toDouble(), dailyDeepPercentage[i].value));
            }
            
            if (i < dailyRemPercentage.length) {
              chartData['remSleep']?.add(FlSpot(i.toDouble(), dailyRemPercentage[i].value));
            }
          }
          
          // Calculate averages
          final avgDuration = dailySleepMinutes.isNotEmpty 
              ? totalSleepMinutes / dailySleepMinutes.length 
              : 0;
              
          final avgDeepPercentage = totalSleepMinutes > 0 
              ? (totalDeepSleepMinutes / totalSleepMinutes * 100) 
              : 0;
              
          final avgRemPercentage = totalSleepMinutes > 0 
              ? (totalRemSleepMinutes / totalSleepMinutes * 100) 
              : 0;
          
          // Update stats
          stats['sleep']?['avgDuration'] = avgDuration;
          stats['sleep']?['avgDeepPercentage'] = avgDeepPercentage;
          stats['sleep']?['avgRemPercentage'] = avgRemPercentage;
          stats['sleep']?['bestNight'] = bestNight;
          stats['sleep']?['worstNight'] = worstNight;
        }
      }
    } catch (e) {
      print('Error loading sleep data: $e');
      // Continue with other data loads
    }
  }
  
  Future<void> _loadActivityData(String startDate, String endDate) async {
    try {
      // Load calories data
      final caloriesResponse = await http.get(
        Uri.parse('https://api.fitbit.com/1/user/-/activities/calories/date/$startDate/$endDate.json'),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Accept': 'application/json',
        },
      );
      
      // Load active minutes data
      final activeMinutesResponse = await http.get(
        Uri.parse('https://api.fitbit.com/1/user/-/activities/minutesVeryActive/date/$startDate/$endDate.json'),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Accept': 'application/json',
        },
      );
      
      // Process calories data
      if (caloriesResponse.statusCode == 200) {
        final data = json.decode(caloriesResponse.body);
        final caloriesData = data['activities-calories'];
        
        // Clear existing data
        chartData['calories'] = [];
        
        int totalCalories = 0;
        
        // Process the data
        for (int i = 0; i < caloriesData.length; i++) {
          final entry = caloriesData[i];
          final calories = double.parse(entry['value']);
          
          // Add to chart data
          chartData['calories']?.add(FlSpot(i.toDouble(), calories));
          
          // Update total
          totalCalories += calories.round();
        }
        
        // Update stats
        stats['activity']?['totalCaloriesBurned'] = totalCalories;
      }
      
      // Process active minutes data
      if (activeMinutesResponse.statusCode == 200) {
        final data = json.decode(activeMinutesResponse.body);
        final activeMinutesData = data['activities-minutesVeryActive'];
        
        // Clear existing data
        chartData['activeMinutes'] = [];
        
        int totalActiveMinutes = 0;
        int maxActiveMinutes = 0;
        int minActiveMinutes = 999;
        String mostActiveDay = '';
        String leastActiveDay = '';
        
        // Process the data
        for (int i = 0; i < activeMinutesData.length; i++) {
          final entry = activeMinutesData[i];
          final minutes = double.parse(entry['value']);
          final day = DateFormat('yyyy-MM-dd').parse(entry['dateTime']);
          
          // Add to chart data
          chartData['activeMinutes']?.add(FlSpot(i.toDouble(), minutes));
          
          // Update stats
          totalActiveMinutes += minutes.round();
          
          if (minutes.round() > maxActiveMinutes) {
            maxActiveMinutes = minutes.round();
            mostActiveDay = DateFormat('EEE, MMM d').format(day);
          }
          
          if (minutes.round() < minActiveMinutes && minutes.round() > 0) {
            minActiveMinutes = minutes.round();
            leastActiveDay = DateFormat('EEE, MMM d').format(day);
          }
        }
        
        // Update stats
        stats['activity']?['totalActiveMinutes'] = totalActiveMinutes;
        stats['activity']?['mostActiveDay'] = mostActiveDay;
        stats['activity']?['leastActiveDay'] = leastActiveDay;
      }
    } catch (e) {
      print('Error loading activity data: $e');
      // Continue with other data loads
    }
  }
  
  void _updateDateRange(String range) {
    setState(() {
      _selectedRange = range;
      
      // Update date range based on selection
      switch (range) {
        case 'Day':
          endDate = DateTime.now();
          startDate = endDate.subtract(const Duration(hours: 24));
          break;
        case 'Week':
          endDate = DateTime.now();
          startDate = endDate.subtract(const Duration(days: 7));
          break;
        case 'Month':
          endDate = DateTime.now();
          startDate = DateTime(endDate.year, endDate.month - 1, endDate.day);
          break;
      }
      
      // Reload data with new date range
      isLoading = true;
    });
    
    // Load new data
    _loadData();
  }
  
  String _formatMinutes(int minutes) {
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    return '$hours hr ${mins.toString().padLeft(2, '0')} min';
  }
  
  String _getDateForIndex(int index) {
    if (_selectedRange == 'Day') {
      final hour = (index * (24 / chartData['steps']!.length)).round();
      return '$hour:00';
    } else {
      final date = startDate.add(Duration(days: index));
      return DateFormat('MMM d').format(date);
    }
  }
  
  Color _getHeartRateColor(int rate) {
    if (rate < 60) {
      return Colors.blue;
    } else if (rate < 70) {
      return Colors.green;
    } else if (rate < 80) {
      return Colors.amber;
    } else if (rate < 90) {
      return Colors.orange;
    } else {
      return Colors.red;
    }
  }
  
  String _getHeartRateZone(int rate) {
    if (rate < 60) {
      return 'Athlete';
    } else if (rate < 70) {
      return 'Excellent';
    } else if (rate < 80) {
      return 'Good';
    } else if (rate < 90) {
      return 'Average';
    } else {
      return 'Above Average';
    }
  }
  
  String _getHeartRateDescription(int rate) {
    if (rate < 60) {
      return 'Your resting heart rate is in the athletic range. This is typically seen in well-trained endurance athletes.';
    } else if (rate < 70) {
      return 'Your resting heart rate is excellent. Continue your current fitness routine to maintain this level.';
    } else if (rate < 80) {
      return 'Your resting heart rate is good. Regular exercise can help further improve it.';
    } else if (rate < 90) {
      return 'Your resting heart rate is average. Consider increasing your activity level to improve it.';
    } else {
      return 'Your resting heart rate is above average. Regular cardiovascular exercise can help reduce it.';
    }
  }
  
  Color _getSleepQualityColor(int hours) {
    if (hours < 6) {
      return Colors.red;
    } else if (hours < 7) {
      return Colors.orange;
    } else if (hours <= 9) {
      return Colors.green;
    } else {
      return Colors.amber;
    }
  }
  
  String _getSleepQualityText(int hours) {
    if (hours < 6) {
      return 'Poor';
    } else if (hours < 7) {
      return 'Fair';
    } else if (hours <= 9) {
      return 'Optimal';
    } else {
      return 'Excessive';
    }
  }
  
  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
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
        title: const Text('Health Statistics'),
        bottom: TabBar(
          controller: _tabController,
          tabs: _metricTabs.map((String tab) => Tab(text: tab)).toList(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Data',
            onPressed: isLoading ? null : () => _loadData(),
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 64,
                        color: Colors.red.shade300,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        errorMessage!,
                        style: const TextStyle(fontSize: 16),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Go Back'),
                      ),
                    ],
                  ),
                )
              : _buildStatsTab(),
    );
  }
  
  Widget _buildStatsTab() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Time range selector
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Time Range:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: SegmentedButton<String>(
                      segments: _timeRanges.map((range) => 
                        ButtonSegment<String>(
                          value: range,
                          label: Text(range),
                        ),
                      ).toList(),
                      selected: {_selectedRange},
                      onSelectionChanged: (Set<String> newSelection) {
                        _updateDateRange(newSelection.first);
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Metric tabs
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // Steps tab
                _buildStepsTab(),
                
                // Heart rate tab
                _buildHeartRateTab(),
                
                // Sleep tab
                _buildSleepTab(),
                
                // Activity tab
                _buildActivityTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildStepsTab() {
    final dailyAvg = stats['steps']?['average'] ?? 0;
    final totalSteps = stats['steps']?['total'] ?? 0;
    final maxSteps = stats['steps']?['max'] ?? 0;
    final maxDay = stats['steps']?['maxDay'] ?? '';
    final minSteps = stats['steps']?['min'] ?? 0;
    final minDay = stats['steps']?['minDay'] ?? '';
    final goalSteps = stats['steps']?['goal'] ?? 10000;
    final daysAboveGoal = stats['steps']?['daysAboveGoal'] ?? 0;
    
    final goalAchievement = dailyAvg > 0 ? (dailyAvg / goalSteps * 100).round() : 0;
    
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Daily average card
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Daily Average',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        NumberFormat('#,###').format(dailyAvg),
                        style: const TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'Goal: ${NumberFormat('#,###').format(goalSteps)}',
                            style: TextStyle(
                              color: Colors.grey.shade700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$goalAchievement% of goal',
                            style: TextStyle(
                              color: goalAchievement >= 100 ? Colors.green : Colors.orange,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  LinearProgressIndicator(
                    value: dailyAvg / goalSteps > 1 ? 1 : dailyAvg / goalSteps,
                    backgroundColor: Colors.grey.shade200,
                    color: dailyAvg >= goalSteps ? Colors.green : Colors.blue,
                    minHeight: 8,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Goal reached on $daysAboveGoal ${_selectedRange.toLowerCase()}${daysAboveGoal == 1 ? "" : "s"}',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Steps chart
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Steps Trend',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 250,
                    child: chartData['steps']!.isNotEmpty
                      ? BarChart(
                          BarChartData(
                            alignment: BarChartAlignment.spaceAround,
                            barTouchData: BarTouchData(
                              enabled: true,
                              touchTooltipData: BarTouchTooltipData(
                                tooltipBgColor: Colors.blueGrey.shade800,
                                getTooltipItem: (group, groupIndex, rod, rodIndex) {
                                  return BarTooltipItem(
                                    '${NumberFormat('#,###').format(rod.toY.round())} steps\n',
                                    const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    children: [
                                      TextSpan(
                                        text: _getDateForIndex(groupIndex),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontWeight: FontWeight.normal,
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ),
                            titlesData: FlTitlesData(
                              show: true,
                              bottomTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  getTitlesWidget: (value, meta) {
                                    if (_selectedRange == 'Day') {
                                      // Show hours for daily view
                                      final hour = (value.toInt() * (24 / chartData['steps']!.length)).round();
                                      return Text('${hour}h', style: const TextStyle(fontSize: 10));
                                    } else {
                                      // Show days for weekly/monthly view
                                      if (value.toInt() < chartData['steps']!.length) {
                                        final day = startDate.add(Duration(days: value.toInt()));
                                        return Text(DateFormat('E').format(day), style: const TextStyle(fontSize: 10));
                                      }
                                      return const Text('');
                                    }
                                  },
                                  reservedSize: 30,
                                ),
                              ),
                              leftTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  getTitlesWidget: (value, meta) {
                                    if (value == 0) return const Text('0');
                                    return Text('${NumberFormat('#,###').format(value.toInt())}');
                                  },
                                  reservedSize: 40,
                                ),
                              ),
                              topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            ),
                            gridData: FlGridData(
                              show: true,
                              drawVerticalLine: false,
                              getDrawingHorizontalLine: (value) => FlLine(
                                color: Colors.grey.shade300,
                                strokeWidth: 1,
                                dashArray: [5, 5],
                              ),
                            ),
                            borderData: FlBorderData(show: false),
                            barGroups: chartData['steps']!.asMap().entries.map((entry) {
                              final goalLine = entry.value.y >= goalSteps;
                              return BarChartGroupData(
                                x: entry.key,
                                barRods: [
                                  BarChartRodData(
                                    toY: entry.value.y,
                                    color: goalLine ? Colors.green : Colors.blue,
                                    width: 16,
                                    borderRadius: const BorderRadius.only(
                                      topLeft: Radius.circular(4),
                                      topRight: Radius.circular(4),
                                    ),
                                  )
                                ],
                              );
                            }).toList(),
                            // Add goal line
                            extraLinesData: ExtraLinesData(
                              horizontalLines: [
                                HorizontalLine(
                                  y: goalSteps.toDouble(),
                                  color: Colors.red.withOpacity(0.7),
                                  strokeWidth: 1,
                                  dashArray: [5, 5],
                                  label: HorizontalLineLabel(
                                    show: true,
                                    alignment: Alignment.topRight,
                                    padding: const EdgeInsets.only(right: 8, bottom: 4),
                                    style: const TextStyle(
                                      color: Colors.red,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 10,
                                    ),
                                    labelResolver: (line) => 'Goal: ${NumberFormat('#,###').format(goalSteps)}',
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.bar_chart,
                                size: 48,
                                color: Colors.grey.shade400,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No step data available for this time range',
                                style: TextStyle(color: Colors.grey.shade600),
                              ),
                            ],
                          ),
                        ),
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Stats overview
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Stats Overview',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  _buildStatRow('Total Steps', NumberFormat('#,###').format(totalSteps)),
                  const Divider(),
                  _buildStatRow('Daily Average', NumberFormat('#,###').format(dailyAvg)),
                  const Divider(),
                  _buildStatRow('Most Steps', '${NumberFormat('#,###').format(maxSteps)} on $maxDay'),
                  const Divider(),
                  _buildStatRow('Fewest Steps', '${NumberFormat('#,###').format(minSteps)} on $minDay'),
                  
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.shade100),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline, color: Colors.blue),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            goalAchievement >= 100
                              ? 'Great job! You\'re consistently reaching your step goal.'
                              : 'A daily goal of 10,000 steps is recommended for good health.',
                            style: TextStyle(
                              color: Colors.blue.shade800,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildHeartRateTab() {
    final avgHR = stats['heartRate']?['average'] ?? 0;
    final maxHR = stats['heartRate']?['max'] ?? 0;
    final minHR = stats['heartRate']?['min'] ?? 0;
    final variance = stats['heartRate']?['variance'] ?? '0';
    
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Resting heart rate card
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Average Resting Heart Rate',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '$avgHR',
                            style: const TextStyle(
                              fontSize: 36,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Padding(
                            padding: EdgeInsets.only(bottom: 6),
                            child: Text(
                              ' bpm',
                              style: TextStyle(
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: _getHeartRateColor(avgHR).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: _getHeartRateColor(avgHR).withOpacity(0.3)),
                        ),
                        child: Text(
                          _getHeartRateZone(avgHR),
                          style: TextStyle(
                            color: _getHeartRateColor(avgHR),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _getHeartRateDescription(avgHR),
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Heart rate chart
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Heart Rate Trend',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 250,
                    child: chartData['heartRate']!.isNotEmpty
                      ? LineChart(
                          LineChartData(
                            gridData: FlGridData(
                              show: true,
                              drawVerticalLine: false,
                              getDrawingHorizontalLine: (value) => FlLine(
                                color: Colors.grey.shade300,
                                strokeWidth: 1,
                                dashArray: [5, 5],
                              ),
                            ),
                            titlesData: FlTitlesData(
                              show: true,
                              bottomTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  getTitlesWidget: (value, meta) {
                                    if (_selectedRange == 'Day') {
                                      // Show hours for daily view
                                      final hour = (value.toInt() * (24 / chartData['heartRate']!.length)).round();
                                      return Text('${hour}h', style: const TextStyle(fontSize: 10));
                                    } else {
                                      // Show days for weekly/monthly view
                                      if (value.toInt() < chartData['heartRate']!.length) {
                                        final day = startDate.add(Duration(days: value.toInt()));
                                        return Text(DateFormat('E').format(day), style: const TextStyle(fontSize: 10));
                                      }
                                      return const Text('');
                                    }
                                  },
                                  reservedSize: 30,
                                ),
                              ),
                              leftTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  getTitlesWidget: (value, meta) {
                                    if (value % 10 == 0) {
                                      return Text('${value.toInt()}');
                                    }
                                    return const Text('');
                                  },
                                  reservedSize: 30,
                                ),
                              ),
                              topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            ),
                            borderData: FlBorderData(show: false),
                            lineBarsData: [
                              LineChartBarData(
                                spots: chartData['heartRate']!,
                                isCurved: true,
                                curveSmoothness: 0.3,
                                color: Colors.red,
                                barWidth: 3,
                                isStrokeCapRound: true,
                                belowBarData: BarAreaData(
                                  show: true,
                                  color: Colors.red.withOpacity(0.1),
                                ),
                                dotData: FlDotData(
                                  show: true,
                                  getDotPainter: (spot, percent, bar, index) => FlDotCirclePainter(
                                    radius: 4,
                                    color: Colors.red,
                                    strokeWidth: 2,
                                    strokeColor: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                            lineTouchData: LineTouchData(
                              touchTooltipData: LineTouchTooltipData(
                                tooltipBgColor: Colors.blueGrey.shade800,
                                getTooltipItems: (List<LineBarSpot> touchedSpots) {
                                  return touchedSpots.map((LineBarSpot touchedSpot) {
                                    final index = touchedSpot.x.toInt();
                                    final date = _getDateForIndex(index);
                                    return LineTooltipItem(
                                      '${touchedSpot.y.toInt()} bpm\n',
                                      const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                      children: [
                                        TextSpan(
                                          text: date,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                            fontWeight: FontWeight.normal,
                                          ),
                                        ),
                                      ],
                                    );
                                  }).toList();
                                },
                              ),
                            ),
                          ),
                        )
                      : Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.monitor_heart,
                                size: 48,
                                color: Colors.grey.shade400,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No heart rate data available for this time range',
                                style: TextStyle(color: Colors.grey.shade600),
                              ),
                            ],
                          ),
                        ),
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Stats overview
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Heart Rate Overview',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  _buildStatRow('Average Resting HR', '$avgHR bpm'),
                  const Divider(),
                  _buildStatRow('Maximum Resting HR', '$maxHR bpm'),
                  const Divider(),
                  _buildStatRow('Minimum Resting HR', '$minHR bpm'),
                  const Divider(),
                  _buildStatRow('Variability', '$variance bpm'),
                  
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.shade100),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline, color: Colors.blue),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'A normal resting heart rate for adults ranges from 60 to 100 bpm. Athletes may have resting heart rates as low as 40 bpm.',
                            style: TextStyle(
                              color: Colors.blue.shade800,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildSleepTab() {
    final avgDuration = stats['sleep']?['avgDuration'] ?? 0;
    final avgDeepPercentage = stats['sleep']?['avgDeepPercentage'] ?? 0;
    final avgRemPercentage = stats['sleep']?['avgRemPercentage'] ?? 0;
    final bestNight = stats['sleep']?['bestNight'] ?? '';
    final worstNight = stats['sleep']?['worstNight'] ?? '';
    
    // Calculate values for display
    final hours = (avgDuration / 60).floor();
    final minutes = (avgDuration % 60).round();
    
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Sleep duration card
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Average Sleep Duration',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '$hours',
                            style: const TextStyle(
                              fontSize: 36,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Padding(
                            padding: EdgeInsets.only(bottom: 6),
                            child: Text(
                              'h ',
                              style: TextStyle(
                                fontSize: 16,
                              ),
                            ),
                          ),
                          Text(
                            '$minutes',
                            style: const TextStyle(
                              fontSize: 36,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Padding(
                            padding: EdgeInsets.only(bottom: 6),
                            child: Text(
                              'm',
                              style: TextStyle(
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: _getSleepQualityColor(hours).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: _getSleepQualityColor(hours).withOpacity(0.3)),
                        ),
                        child: Text(
                          _getSleepQualityText(hours),
                          style: TextStyle(
                            color: _getSleepQualityColor(hours),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: hours >= 8 ? 1 : hours / 8,
                    backgroundColor: Colors.grey.shade200,
                    color: _getSleepQualityColor(hours),
                    minHeight: 8,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Recommended: 7-9 hours',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Sleep phases card
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Sleep Composition',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _buildSleepPhaseCard(
                          'Deep Sleep',
                          '${avgDeepPercentage.round()}%',
                          Colors.indigo,
                          'Ideal: 15-25%',
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildSleepPhaseCard(
                          'REM Sleep',
                          '${avgRemPercentage.round()}%',
                          Colors.purple,
                          'Ideal: 20-25%',
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildSleepPhaseCard(
                          'Light Sleep',
                          '${(100 - avgDeepPercentage - avgRemPercentage).round()}%',
                          Colors.blue,
                          'Ideal: 50-60%',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Sleep chart
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Sleep Duration Trend',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 250,
                    child: chartData['sleepDuration']!.isNotEmpty
                      ? LineChart(
                          LineChartData(
                            gridData: FlGridData(
                              show: true,
                              drawVerticalLine: false,
                              getDrawingHorizontalLine: (value) => FlLine(
                                color: Colors.grey.shade300,
                                strokeWidth: 1,
                                dashArray: [5, 5],
                              ),
                            ),
                            titlesData: FlTitlesData(
                              show: true,
                              bottomTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  getTitlesWidget: (value, meta) {
                                    if (value.toInt() < chartData['sleepDuration']!.length) {
                                      final day = startDate.add(Duration(days: value.toInt()));
                                      return Text(DateFormat('E').format(day), style: const TextStyle(fontSize: 10));
                                    }
                                    return const Text('');
                                  },
                                  reservedSize: 30,
                                ),
                              ),
                              leftTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  getTitlesWidget: (value, meta) {
                                    return Text('${value.toInt()}h');
                                  },
                                  reservedSize: 30,
                                ),
                              ),
                              topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            ),
                            borderData: FlBorderData(show: false),
                            lineBarsData: [
                              LineChartBarData(
                                spots: chartData['sleepDuration']!,
                                isCurved: true,
                                curveSmoothness: 0.3,
                                color: Colors.indigo,
                                barWidth: 3,
                                isStrokeCapRound: true,
                                belowBarData: BarAreaData(
                                  show: true,
                                  color: Colors.indigo.withOpacity(0.1),
                                ),
                                dotData: FlDotData(
                                  show: true,
                                  getDotPainter: (spot, percent, bar, index) => FlDotCirclePainter(
                                    radius: 4,
                                    color: Colors.indigo,
                                    strokeWidth: 2,
                                    strokeColor: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                            lineTouchData: LineTouchData(
                              touchTooltipData: LineTouchTooltipData(
                                tooltipBgColor: Colors.blueGrey.shade800,
                                getTooltipItems: (List<LineBarSpot> touchedSpots) {
                                  return touchedSpots.map((LineBarSpot touchedSpot) {
                                    final index = touchedSpot.x.toInt();
                                    final date = _getDateForIndex(index);
                                    final hours = touchedSpot.y.toInt();
                                    final minutes = ((touchedSpot.y - hours) * 60).round();
                                    return LineTooltipItem(
                                      '$hours hr $minutes min\n',
                                      const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                      children: [
                                        TextSpan(
                                          text: date,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                            fontWeight: FontWeight.normal,
                                          ),
                                        ),
                                      ],
                                    );
                                  }).toList();
                                },
                              ),
                            ),
                            // Add recommended sleep range
                            extraLinesData: ExtraLinesData(
                              horizontalLines: [
                                HorizontalLine(
                                  y: 7,
                                  color: Colors.green.withOpacity(0.5),
                                  strokeWidth: 1,
                                  dashArray: [5, 5],
                                  label: HorizontalLineLabel(
                                    show: true,
                                    alignment: Alignment.topRight,
                                    padding: const EdgeInsets.only(right: 8, bottom: 4),
                                    style: const TextStyle(
                                      color: Colors.green,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 10,
                                    ),
                                    labelResolver: (line) => 'Min Recommended',
                                  ),
                                ),
                                HorizontalLine(
                                  y: 9,
                                  color: Colors.red.withOpacity(0.5),
                                  strokeWidth: 1,
                                  dashArray: [5, 5],
                                  label: HorizontalLineLabel(
                                    show: true,
                                    alignment: Alignment.topRight,
                                    padding: const EdgeInsets.only(right: 8, bottom: 4),
                                    style: const TextStyle(
                                      color: Colors.red,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 10,
                                    ),
                                    labelResolver: (line) => 'Max Recommended',
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.bedtime,
                                size: 48,
                                color: Colors.grey.shade400,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No sleep data available for this time range',
                                style: TextStyle(color: Colors.grey.shade600),
                              ),
                            ],
                          ),
                        ),
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Sleep stats overview
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Sleep Overview',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  _buildStatRow('Average Duration', '${hours}h ${minutes}m'),
                  const Divider(),
                  _buildStatRow('Deep Sleep', '${avgDeepPercentage.round()}% of total sleep'),
                  const Divider(),
                  _buildStatRow('REM Sleep', '${avgRemPercentage.round()}% of total sleep'),
                  const Divider(),
                  _buildStatRow('Best Sleep Quality', bestNight),
                  const Divider(),
                  _buildStatRow('Worst Sleep Quality', worstNight),
                  
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.shade100),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline, color: Colors.blue),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Deep sleep is crucial for physical recovery, while REM sleep plays a key role in cognitive function and memory consolidation.',
                            style: TextStyle(
                              color: Colors.blue.shade800,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildActivityTab() {
    final totalActiveMinutes = stats['activity']?['totalActiveMinutes'] ?? 0;
    final totalCaloriesBurned = stats['activity']?['totalCaloriesBurned'] ?? 0;
    final mostActiveDay = stats['activity']?['mostActiveDay'] ?? '';
    final leastActiveDay = stats['activity']?['leastActiveDay'] ?? '';
    
    // Calculate daily averages
    final days = _selectedRange == 'Day' ? 1 : (_selectedRange == 'Week' ? 7 : 30);
    final avgActiveMinutes = days > 0 ? totalActiveMinutes / days : 0;
    final avgCaloriesBurned = days > 0 ? totalCaloriesBurned / days : 0;
    
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Activity summary card
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Activity Summary',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _buildActivitySummaryItem(
                          'Active Minutes',
                          totalActiveMinutes.toString(),
                          'total',
                          Icons.timer,
                          Colors.orange,
                          '${avgActiveMinutes.round()} daily avg',
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildActivitySummaryItem(
                          'Calories Burned',
                          NumberFormat('#,###').format(totalCaloriesBurned),
                          'total',
                          Icons.local_fire_department,
                          Colors.red,
                          '${avgCaloriesBurned.round()} daily avg',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Active minutes chart
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Active Minutes Trend',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 250,
                    child: chartData['activeMinutes']!.isNotEmpty
                      ? BarChart(
                          BarChartData(
                            alignment: BarChartAlignment.spaceAround,
                            barTouchData: BarTouchData(
                              enabled: true,
                              touchTooltipData: BarTouchTooltipData(
                                tooltipBgColor: Colors.blueGrey.shade800,
                                getTooltipItem: (group, groupIndex, rod, rodIndex) {
                                  return BarTooltipItem(
                                    '${rod.toY.round()} minutes\n',
                                    const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    children: [
                                      TextSpan(
                                        text: _getDateForIndex(groupIndex),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontWeight: FontWeight.normal,
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ),
                            titlesData: FlTitlesData(
                              show: true,
                              bottomTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  getTitlesWidget: (value, meta) {
                                    if (value.toInt() < chartData['activeMinutes']!.length) {
                                      final day = startDate.add(Duration(days: value.toInt()));
                                      return Text(DateFormat('E').format(day), style: const TextStyle(fontSize: 10));
                                    }
                                    return const Text('');
                                  },
                                  reservedSize: 30,
                                ),
                              ),
                              leftTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  reservedSize: 40,
                                ),
                              ),
                              topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            ),
                            gridData: FlGridData(
                              show: true,
                              drawVerticalLine: false,
                              getDrawingHorizontalLine: (value) => FlLine(
                                color: Colors.grey.shade300,
                                strokeWidth: 1,
                                dashArray: [5, 5],
                              ),
                            ),
                            borderData: FlBorderData(show: false),
                            barGroups: chartData['activeMinutes']!.asMap().entries.map((entry) {
                              return BarChartGroupData(
                                x: entry.key,
                                barRods: [
                                  BarChartRodData(
                                    toY: entry.value.y,
                                    color: Colors.orange,
                                    width: 16,
                                    borderRadius: const BorderRadius.only(
                                      topLeft: Radius.circular(4),
                                      topRight: Radius.circular(4),
                                    ),
                                  )
                                ],
                              );
                            }).toList(),
                            // Add recommended activity line
                            extraLinesData: ExtraLinesData(
                              horizontalLines: [
                                HorizontalLine(
                                  y: 30,
                                  color: Colors.green.withOpacity(0.7),
                                  strokeWidth: 1,
                                  dashArray: [5, 5],
                                  label: HorizontalLineLabel(
                                    show: true,
                                    alignment: Alignment.topRight,
                                    padding: const EdgeInsets.only(right: 8, bottom: 4),
                                    style: const TextStyle(
                                      color: Colors.green,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 10,
                                    ),
                                    labelResolver: (line) => 'Recommended Daily',
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.fitness_center,
                                size: 48,
                                color: Colors.grey.shade400,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No activity data available for this time range',
                                style: TextStyle(color: Colors.grey.shade600),
                              ),
                            ],
                          ),
                        ),
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Calories burned chart
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Calories Burned Trend',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 250,
                    child: chartData['calories']!.isNotEmpty
                      ? LineChart(
                          LineChartData(
                            gridData: FlGridData(
                              show: true,
                              drawVerticalLine: false,
                              getDrawingHorizontalLine: (value) => FlLine(
                                color: Colors.grey.shade300,
                                strokeWidth: 1,
                                dashArray: [5, 5],
                              ),
                            ),
                            titlesData: FlTitlesData(
                              show: true,
                              bottomTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  getTitlesWidget: (value, meta) {
                                    if (value.toInt() < chartData['calories']!.length) {
                                      final day = startDate.add(Duration(days: value.toInt()));
                                      return Text(DateFormat('E').format(day), style: const TextStyle(fontSize: 10));
                                    }
                                    return const Text('');
                                  },
                                  reservedSize: 30,
                                ),
                              ),
                              leftTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  getTitlesWidget: (value, meta) {
                                    return Text(NumberFormat('#,###').format(value.toInt()));
                                  },
                                  reservedSize: 50,
                                ),
                              ),
                              topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            ),
                            borderData: FlBorderData(show: false),
                            lineBarsData: [
                              LineChartBarData(
                                spots: chartData['calories']!,
                                isCurved: true,
                                curveSmoothness: 0.3,
                                color: Colors.red,
                                barWidth: 3,
                                isStrokeCapRound: true,
                                belowBarData: BarAreaData(
                                  show: true,
                                  color: Colors.red.withOpacity(0.1),
                                ),
                                dotData: FlDotData(
                                  show: true,
                                  getDotPainter: (spot, percent, bar, index) => FlDotCirclePainter(
                                    radius: 4,
                                    color: Colors.red,
                                    strokeWidth: 2,
                                    strokeColor: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                            lineTouchData: LineTouchData(
                              touchTooltipData: LineTouchTooltipData(
                                tooltipBgColor: Colors.blueGrey.shade800,
                                getTooltipItems: (List<LineBarSpot> touchedSpots) {
                                  return touchedSpots.map((LineBarSpot touchedSpot) {
                                    final index = touchedSpot.x.toInt();
                                    final date = _getDateForIndex(index);
                                    return LineTooltipItem(
                                      '${NumberFormat('#,###').format(touchedSpot.y.toInt())} cal\n',
                                      const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                      children: [
                                        TextSpan(
                                          text: date,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                            fontWeight: FontWeight.normal,
                                          ),
                                        ),
                                      ],
                                    );
                                  }).toList();
                                },
                              ),
                            ),
                          ),
                        )
                      : Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.local_fire_department,
                                size: 48,
                                color: Colors.grey.shade400,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No calorie data available for this time range',
                                style: TextStyle(color: Colors.grey.shade600),
                              ),
                            ],
                          ),
                        ),
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Activity stats overview
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Activity Overview',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  _buildStatRow('Total Active Minutes', '$totalActiveMinutes minutes'),
                  const Divider(),
                  _buildStatRow('Daily Average', '${avgActiveMinutes.round()} minutes'),
                  const Divider(),
                  _buildStatRow('Total Calories Burned', '${NumberFormat('#,###').format(totalCaloriesBurned)} calories'),
                  const Divider(),
                  _buildStatRow('Most Active Day', mostActiveDay),
                  const Divider(),
                  _buildStatRow('Least Active Day', leastActiveDay),
                  
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.shade100),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline, color: Colors.blue),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'The WHO recommends at least 150 minutes of moderate-intensity physical activity throughout the week.',
                            style: TextStyle(
                              color: Colors.blue.shade800,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildActivitySummaryItem(String label, String value, String subtitle, IconData icon, Color color, String note) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: color.withOpacity(0.8),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            subtitle,
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withOpacity(0.3)),
            ),
            child: Text(
              note,
              style: TextStyle(
                fontSize: 12,
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildSleepPhaseCard(String phase, String percentage, Color color, String note) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            phase,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            percentage,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            note,
            style: TextStyle(
              fontSize: 10,
              color: color.withOpacity(0.8),
            ),
          ),
        ],
      ),
    );
  }
}