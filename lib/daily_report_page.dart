// lib/daily_report_page.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:fl_chart/fl_chart.dart';

class DailyReportPage extends StatefulWidget {
  const DailyReportPage({Key? key}) : super(key: key);

  @override
  _DailyReportPageState createState() => _DailyReportPageState();
}

class TimeSeriesData {
  final DateTime time;
  final double value;
  
  TimeSeriesData(this.time, this.value);
}

class SleepPhaseData {
  final String phase;
  final double minutes;
  final Color color;
  
  SleepPhaseData(this.phase, this.minutes, this.color);
}

class _DailyReportPageState extends State<DailyReportPage> {
  DateTime selectedDate = DateTime.now();
  bool isLoading = true;
  String? accessToken;
  
  // Activity data
  Map<String, dynamic> fitbitData = {
    'steps': 'N/A',
    'caloriesBurned': 'N/A',
    'activeMinutes': 'N/A',
    'distance': 'N/A',
    'floors': 'N/A',
    'stationaryMinutes': 'N/A',
  };
  
  // Heart rate data
  Map<String, dynamic> heartRateData = {
    'restingHR': 'N/A',
    'minHR': 'N/A',
    'maxHR': 'N/A',
    'hrData': <Map<String, dynamic>>[],
  };
  
  // Sleep data
  Map<String, dynamic> sleepData = {
    'duration': 'N/A',
    'efficiency': 'N/A',
    'deepSleep': 'N/A',
    'lightSleep': 'N/A',
    'remSleep': 'N/A',
    'awakeSleep': 'N/A',
    'startTime': 'N/A',
    'endTime': 'N/A',
  };
  
  // Exercise data
  List<Map<String, dynamic>> exerciseData = [];
  
  String? errorMessage;
  bool showHeartRateChart = false;
  bool showSleepBreakdown = false;
  
  // Charts data
  List<FlSpot> heartRateChartData = [];
  List<PieChartSectionData> sleepChartData = [];

  @override
  void initState() {
    super.initState();
    _loadFitbitToken();
  }

  Future<void> _loadFitbitToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('fitbit_token');
      
      setState(() {
        accessToken = token;
      });
      
      if (token != null) {
        await _fetchDailyData(token);
      } else {
        setState(() {
          isLoading = false;
          errorMessage = 'Please connect your Fitbit to view daily reports';
        });
      }
    } catch (e) {
      setState(() {
        isLoading = false;
        errorMessage = 'Error loading data: $e';
      });
    }
  }

  Future<void> _fetchDailyData(String token) async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });
    
    try {
      final dateString = DateFormat('yyyy-MM-dd').format(selectedDate);
      
      // Fetch activity summary data
      await _fetchActivityData(token, dateString);
      
      // Fetch heart rate data
      await _fetchHeartRateData(token, dateString);
      
      // Fetch sleep data
      await _fetchSleepData(token, dateString);
      
      // Fetch exercise data
      await _fetchExerciseData(token, dateString);
      
      setState(() {
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
        errorMessage = 'Error fetching data: $e';
      });
    }
  }

  Future<void> _fetchActivityData(String token, String dateString) async {
    try {
      // Fetch steps data
      final stepsResponse = await http.get(
        Uri.parse('https://api.fitbit.com/1/user/-/activities/steps/date/$dateString/1d.json'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );
      
      // Fetch calories data
      final caloriesResponse = await http.get(
        Uri.parse('https://api.fitbit.com/1/user/-/activities/calories/date/$dateString/1d.json'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );
      
      // Fetch active minutes data
      final activeMinutesResponse = await http.get(
        Uri.parse('https://api.fitbit.com/1/user/-/activities/minutesVeryActive/date/$dateString/1d.json'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );
      
      // Fetch distance data
      final distanceResponse = await http.get(
        Uri.parse('https://api.fitbit.com/1/user/-/activities/distance/date/$dateString/1d.json'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );
      
      // Fetch floors data
      final floorsResponse = await http.get(
        Uri.parse('https://api.fitbit.com/1/user/-/activities/floors/date/$dateString/1d.json'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );
      
      // Fetch sedentary minutes data
      final sedentaryResponse = await http.get(
        Uri.parse('https://api.fitbit.com/1/user/-/activities/minutesSedentary/date/$dateString/1d.json'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );
      
      if (stepsResponse.statusCode == 200 && 
          caloriesResponse.statusCode == 200 &&
          activeMinutesResponse.statusCode == 200 &&
          distanceResponse.statusCode == 200 &&
          floorsResponse.statusCode == 200 &&
          sedentaryResponse.statusCode == 200) {
        
        final stepsData = json.decode(stepsResponse.body);
        final caloriesData = json.decode(caloriesResponse.body);
        final activeMinutesData = json.decode(activeMinutesResponse.body);
        final distanceData = json.decode(distanceResponse.body);
        final floorsData = json.decode(floorsResponse.body);
        final sedentaryData = json.decode(sedentaryResponse.body);
        
        setState(() {
          fitbitData = {
            'steps': stepsData['activities-steps'][0]['value'],
            'caloriesBurned': caloriesData['activities-calories'][0]['value'],
            'activeMinutes': activeMinutesData['activities-minutesVeryActive'][0]['value'],
            'distance': distanceData['activities-distance'][0]['value'],
            'floors': floorsData['activities-floors'][0]['value'],
            'stationaryMinutes': sedentaryData['activities-minutesSedentary'][0]['value'],
          };
        });
      } else if (stepsResponse.statusCode == 401 || 
                caloriesResponse.statusCode == 401 ||
                activeMinutesResponse.statusCode == 401 ||
                distanceResponse.statusCode == 401) {
        // Handle authentication error
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('fitbit_token');
        
        throw Exception('Authentication expired. Please reconnect your Fitbit.');
      } else {
        throw Exception('Failed to load activity data. Please try again later.');
      }
    } catch (e) {
      print('Error in _fetchActivityData: $e');
      // Will be handled by the caller
      rethrow;
    }
  }
  
  Future<void> _fetchHeartRateData(String token, String dateString) async {
    try {
      // Fetch intraday heart rate data (requires expanded scope)
      final hrResponse = await http.get(
        Uri.parse('https://api.fitbit.com/1/user/-/activities/heart/date/$dateString/1d/1min.json'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );
      
      if (hrResponse.statusCode == 200) {
        final data = json.decode(hrResponse.body);
        
        // Extract resting heart rate and zones if available
        if (data['activities-heart'].isNotEmpty) {
          final heartData = data['activities-heart'][0]['value'];
          String restingHR = 'N/A';
          String minHR = 'N/A';
          String maxHR = 'N/A';
          
          if (heartData is Map) {
            if (heartData.containsKey('restingHeartRate')) {
              restingHR = heartData['restingHeartRate'].toString();
            }
            
            // Extract min/max heart rates from zones if available
            if (heartData.containsKey('heartRateZones') && heartData['heartRateZones'] is List) {
              final zones = heartData['heartRateZones'] as List;
              if (zones.isNotEmpty) {
                minHR = zones[0]['min'].toString();
                maxHR = zones[zones.length - 1]['max'].toString();
              }
            }
          }
          
          // Extract intraday heart rate data if available
          List<Map<String, dynamic>> timeSeriesData = [];
          List<FlSpot> flSpots = [];
          
          if (data.containsKey('activities-heart-intraday') && 
              data['activities-heart-intraday'].containsKey('dataset')) {
            
            final dataset = data['activities-heart-intraday']['dataset'] as List;
            int index = 0;
            for (var dataPoint in dataset) {
              if (dataPoint.containsKey('time') && dataPoint.containsKey('value')) {
                // Parse time string and create DateTime
                final timeString = dataPoint['time'];
                final timeParts = timeString.split(':');
                if (timeParts.length >= 2) {
                  final hour = int.parse(timeParts[0]);
                  final minute = int.parse(timeParts[1]);
                  
                  final dateTime = DateTime(
                    selectedDate.year,
                    selectedDate.month,
                    selectedDate.day,
                    hour,
                    minute,
                  );
                  
                  timeSeriesData.add({
                    'time': dateTime,
                    'value': dataPoint['value'],
                  });
                  
                  // Add data point for the chart
                  flSpots.add(FlSpot(index.toDouble(), dataPoint['value'].toDouble()));
                  index++;
                }
              }
            }
          }
          
          setState(() {
            heartRateData = {
              'restingHR': restingHR,
              'minHR': minHR,
              'maxHR': maxHR,
              'hrData': timeSeriesData,
            };
            
            if (flSpots.isNotEmpty) {
              heartRateChartData = flSpots;
            }
          });
        }
      } else if (hrResponse.statusCode == 401) {
        throw Exception('Authentication expired');
      }
    } catch (e) {
      print('Error fetching heart rate data: $e');
      // Non-fatal, continue with other data
    }
  }
  
  Future<void> _fetchSleepData(String token, String dateString) async {
    try {
      final sleepResponse = await http.get(
        Uri.parse('https://api.fitbit.com/1.2/user/-/sleep/date/$dateString.json'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );
      
      if (sleepResponse.statusCode == 200) {
        final data = json.decode(sleepResponse.body);
        
        if (data['sleep'] != null && data['sleep'].isNotEmpty) {
          // Calculate total sleep metrics
          int totalMinutesAsleep = 0;
          int totalTimeInBed = 0;
          int deepSleepMinutes = 0;
          int lightSleepMinutes = 0;
          int remSleepMinutes = 0;
          int awakeSleepMinutes = 0;
          String startTime = '';
          String endTime = '';
          
          for (var sleep in data['sleep']) {
            // Only consider main sleep if there are multiple entries
            if (sleep['isMainSleep'] == true || data['sleep'].length == 1) {
              totalMinutesAsleep += (sleep['minutesAsleep'] as num).toInt();
              totalTimeInBed += (sleep['timeInBed'] as num).toInt();
              
              // Extract start and end times
              if (sleep['startTime'] != null) {
                startTime = sleep['startTime'];
              }
              if (sleep['endTime'] != null) {
                endTime = sleep['endTime'];
              }
              
              // Extract sleep phases if available
              if (sleep['levels'] != null && sleep['levels']['summary'] != null) {
                final summary = sleep['levels']['summary'];
                
                if (summary.containsKey('deep')) {
                  deepSleepMinutes += (summary['deep']['minutes'] as num).toInt();
                }
                if (summary.containsKey('light')) {
                  lightSleepMinutes += (summary['light']['minutes'] as num).toInt();
                }
                if (summary.containsKey('rem')) {
                  remSleepMinutes += (summary['rem']['minutes'] as num).toInt();
                }
                if (summary.containsKey('wake')) {
                  awakeSleepMinutes += (summary['wake']['minutes'] as num).toInt();
                }
              }
            }
          }
          
          // Calculate hours and minutes for display
          final hours = totalMinutesAsleep ~/ 60;
          final minutes = totalMinutesAsleep % 60;
          
          // Calculate sleep efficiency
          final efficiency = totalTimeInBed > 0 
              ? (totalMinutesAsleep / totalTimeInBed * 100).round() 
              : 0;
          
          // Format start and end times if available
          String formattedStartTime = 'N/A';
          String formattedEndTime = 'N/A';
          
          if (startTime.isNotEmpty) {
            try {
              final startDateTime = DateTime.parse(startTime);
              formattedStartTime = DateFormat('h:mm a').format(startDateTime);
            } catch (e) {
              print('Error parsing sleep start time: $e');
            }
          }
          
          if (endTime.isNotEmpty) {
            try {
              final endDateTime = DateTime.parse(endTime);
              formattedEndTime = DateFormat('h:mm a').format(endDateTime);
            } catch (e) {
              print('Error parsing sleep end time: $e');
            }
          }
          
          // Create sleep phase chart data
          if (deepSleepMinutes > 0 || lightSleepMinutes > 0 || remSleepMinutes > 0) {
            final totalPhaseMinutes = deepSleepMinutes + lightSleepMinutes + remSleepMinutes + awakeSleepMinutes;
            
            if (totalPhaseMinutes > 0) {
              List<PieChartSectionData> sections = [
                PieChartSectionData(
                  value: deepSleepMinutes.toDouble(),
                  title: 'Deep',
                  color: Colors.blue,
                  radius: 60,
                  titleStyle: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                PieChartSectionData(
                  value: lightSleepMinutes.toDouble(),
                  title: 'Light',
                  color: Colors.cyan,
                  radius: 60,
                  titleStyle: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                PieChartSectionData(
                  value: remSleepMinutes.toDouble(),
                  title: 'REM',
                  color: Colors.green,
                  radius: 60,
                  titleStyle: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                PieChartSectionData(
                  value: awakeSleepMinutes.toDouble(),
                  title: 'Awake',
                  color: Colors.grey,
                  radius: 60,
                  titleStyle: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ];
              
              setState(() {
                sleepChartData = sections;
              });
            }
          }
          
          setState(() {
            sleepData = {
              'duration': '$hours hr ${minutes.toString().padLeft(2, '0')} min',
              'efficiency': '$efficiency%',
              'deepSleep': '$deepSleepMinutes min',
              'lightSleep': '$lightSleepMinutes min',
              'remSleep': '$remSleepMinutes min',
              'awakeSleep': '$awakeSleepMinutes min',
              'startTime': formattedStartTime,
              'endTime': formattedEndTime,
            };
          });
        }
      }
    } catch (e) {
      print('Error fetching sleep data: $e');
      // Non-fatal, continue with other data
    }
  }
  
  Future<void> _fetchExerciseData(String token, String dateString) async {
    try {
      // Fetch exercise logs
      final exerciseResponse = await http.get(
        Uri.parse('https://api.fitbit.com/1/user/-/activities/list.json?afterDate=$dateString&sort=asc&offset=0&limit=10'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );
      
      if (exerciseResponse.statusCode == 200) {
        final data = json.decode(exerciseResponse.body);
        
        if (data['activities'] != null) {
          final List<Map<String, dynamic>> exercises = [];
          
          for (var activity in data['activities']) {
            // Filter for activities on the selected date
            final activityDate = activity['startTime'] != null 
                ? DateTime.parse(activity['startTime']) 
                : null;
                
            if (activityDate != null && 
                activityDate.year == selectedDate.year &&
                activityDate.month == selectedDate.month && 
                activityDate.day == selectedDate.day) {
                
              exercises.add({
                'name': activity['activityName'] ?? 'Unknown activity',
                'duration': activity['duration'] != null 
                    ? (activity['duration'] / 60000).round() // Convert from milliseconds to minutes
                    : 0,
                'calories': activity['calories'] ?? 0,
                'steps': activity['steps'] ?? 0,
                'distance': activity['distance'] ?? 0,
                'startTime': activityDate,
              });
            }
          }
          
          // Sort exercises by start time
          exercises.sort((a, b) => 
            (a['startTime'] as DateTime).compareTo(b['startTime'] as DateTime));
          
          setState(() {
            exerciseData = exercises;
          });
        }
      }
    } catch (e) {
      print('Error fetching exercise data: $e');
      // Non-fatal, continue with other data
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Daily Report'),
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
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context);
                          },
                          child: const Text('Go Back'),
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
                      // Date header
                      Card(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Row(
                            children: [
                              const Icon(Icons.calendar_today, color: Colors.blue),
                              const SizedBox(width: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Daily Report',
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    DateFormat('EEEE, MMMM d, yyyy').format(selectedDate),
                                    style: TextStyle(
                                      color: Colors.grey.shade700,
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Activity summary card
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
                                'Activity Summary',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 16),
                              
                              _buildActivityMetric(Icons.directions_walk, 'Steps', fitbitData['steps']),
                              _buildActivityMetric(Icons.local_fire_department, 'Calories Burned', '${fitbitData['caloriesBurned']} cal'),
                              _buildActivityMetric(Icons.timer, 'Active Minutes', '${fitbitData['activeMinutes']} min'),
                              _buildActivityMetric(Icons.straighten, 'Distance', '${fitbitData['distance']} km'),
                              _buildActivityMetric(Icons.stairs, 'Floors', fitbitData['floors']),
                              _buildActivityMetric(Icons.airline_seat_recline_normal, 'Stationary Time', '${fitbitData['stationaryMinutes']} min'),
                            ],
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Heart rate card
                      Card(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Heart Rate',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  IconButton(
                                    icon: Icon(
                                      showHeartRateChart ? Icons.expand_less : Icons.expand_more,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        showHeartRateChart = !showHeartRateChart;
                                      });
                                    },
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceAround,
                                children: [
                                  _buildHeartRateValue('Resting', heartRateData['restingHR']),
                                  _buildHeartRateValue('Min', heartRateData['minHR']),
                                  _buildHeartRateValue('Max', heartRateData['maxHR']),
                                ],
                              ),
                              
                              if (showHeartRateChart && heartRateChartData.isNotEmpty) ...[
                                const SizedBox(height: 24),
                                const Text(
                                  'Heart Rate Throughout Day',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                SizedBox(
                                  height: 200,
                                  child: LineChart(
                                    LineChartData(
                                      gridData: FlGridData(
                                        show: true,
                                        drawHorizontalLine: true,
                                        drawVerticalLine: false,
                                      ),
                                      titlesData: FlTitlesData(
                                        bottomTitles: AxisTitles(
                                          sideTitles: SideTitles(
                                            showTitles: false,
                                          ),
                                        ),
                                        leftTitles: AxisTitles(
                                          sideTitles: SideTitles(
                                            showTitles: true,
                                            interval: 20,
                                            reservedSize: 30,
                                          ),
                                        ),
                                        rightTitles: AxisTitles(
                                          sideTitles: SideTitles(
                                            showTitles: false,
                                          ),
                                        ),
                                        topTitles: AxisTitles(
                                          sideTitles: SideTitles(
                                            showTitles: false,
                                          ),
                                        ),
                                      ),
                                      borderData: FlBorderData(
                                        show: true,
                                        border: Border.all(
                                          color: Colors.grey.shade300,
                                        ),
                                      ),
                                      lineBarsData: [
                                        LineChartBarData(
                                          spots: heartRateChartData,
                                          isCurved: true,
                                          color: Colors.red,
                                          barWidth: 2,
                                          dotData: FlDotData(show: false),
                                          belowBarData: BarAreaData(
                                            show: true,
                                            color: Colors.red.withOpacity(0.1),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Sleep card
                      Card(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Sleep',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  IconButton(
                                    icon: Icon(
                                      showSleepBreakdown ? Icons.expand_less : Icons.expand_more,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        showSleepBreakdown = !showSleepBreakdown;
                                      });
                                    },
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              
                              _buildActivityMetric(Icons.hotel, 'Duration', sleepData['duration']),
                              _buildActivityMetric(Icons.speed, 'Efficiency', sleepData['efficiency']),
                              _buildActivityMetric(Icons.access_time, 'Bedtime', sleepData['startTime']),
                              _buildActivityMetric(Icons.wb_sunny, 'Wake Time', sleepData['endTime']),
                              
                              if (showSleepBreakdown && sleepChartData.isNotEmpty) ...[
                                const SizedBox(height: 24),
                                const Text(
                                  'Sleep Stages',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Expanded(
                                      flex: 1,
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          _buildSleepStageItem('Deep Sleep', sleepData['deepSleep'], Colors.blue),
                                          const SizedBox(height: 8),
                                          _buildSleepStageItem('Light Sleep', sleepData['lightSleep'], Colors.cyan),
                                          const SizedBox(height: 8),
                                          _buildSleepStageItem('REM Sleep', sleepData['remSleep'], Colors.green),
                                          const SizedBox(height: 8),
                                          _buildSleepStageItem('Awake', sleepData['awakeSleep'], Colors.grey),
                                        ],
                                      ),
                                    ),
                                    Expanded(
                                      flex: 1,
                                      child: SizedBox(
                                        height: 200,
                                        child: PieChart(
                                          PieChartData(
                                            sections: sleepChartData,
                                            centerSpaceRadius: 30,
                                            sectionsSpace: 2,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Exercise card
                      if (exerciseData.isNotEmpty) ...[
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
                                  'Exercises',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                
                                ...exerciseData.map((exercise) => _buildExerciseItem(exercise)).toList(),
                              ],
                            ),
                          ),
                        ),
                        
                        const SizedBox(height: 16),
                      ],
                    ],
                  ),
                ),
    );
  }
  
  Widget _buildActivityMetric(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, color: Colors.blue, size: 20),
          const SizedBox(width: 12),
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
  
  Widget _buildHeartRateValue(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.grey.shade700,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        const Text(
          'bpm',
          style: TextStyle(
            fontSize: 12,
          ),
        ),
      ],
    );
  }
  
  Widget _buildSleepStageItem(String stage, String duration, Color color) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            stage,
            style: const TextStyle(fontSize: 14),
          ),
        ),
        Text(
          duration,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ],
    );
  }
  
  Widget _buildExerciseItem(Map<String, dynamic> exercise) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.blue.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.fitness_center, color: Colors.blue),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  exercise['name'],
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Duration: ${exercise['duration']} min',
                  style: TextStyle(
                    color: Colors.grey.shade700,
                  ),
                ),
                Text(
                  'Calories: ${exercise['calories']} cal',
                  style: TextStyle(
                    color: Colors.grey.shade700,
                  ),
                ),
                if (exercise['distance'] != null && exercise['distance'] > 0)
                  Text(
                    'Distance: ${exercise['distance']} km',
                    style: TextStyle(
                      color: Colors.grey.shade700,
                    ),
                  ),
                Text(
                  'Time: ${DateFormat('h:mm a').format(exercise['startTime'])}',
                  style: TextStyle(
                    color: Colors.grey.shade700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}