// lib/home_page.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'web_helper.dart';
import 'mock_data_provider.dart';

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with SingleTickerProviderStateMixin {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  
  // Fitbit connection state
  bool fitbitConnected = false;
  bool isAuthenticating = false;
  bool isLoadingData = false;
  bool _isHoveringFitbitButton = false;
  
  // Mock data state
  bool useMockData = false;
  String? mockDataMessage;
  
  // User data
  String? steps;
  String? caloriesBurned;
  String? activeMinutes;
  String? heartRate;
  String? sleepDuration;
  String? deepSleepPercentage;
  List<Map<String, dynamic>> recentExercises = [];

  // OAuth and state variables
  String? _accessToken;
  String? _authError;
  final clientId = '23Q8PL';
  final redirectUri = 'http://localhost:8080/auth.html';

  // Tab controller for time period views
  late TabController _tabController;
  final List<String> _timePeriods = ['Daily', 'Weekly', 'Monthly'];

  // Charts data
  List<FlSpot> _heartRateData = [];
  List<FlSpot> _stepsData = [];
  bool _chartsInitialized = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _timePeriods.length, vsync: this);
    _setupAuthListener();
    _checkStoredToken();
    _loadUserInsights();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _setupAuthListener() {
    WebHelper.setupAuthListener(_processAuthResult);
  }

  void _processAuthResult(String? authUrl) {
    // Instead of assuming authUrl is non-null
    final safeAuthUrl = authUrl ?? '';
    
    if (safeAuthUrl.contains('access_token=')) {
      final uri = Uri.parse(safeAuthUrl.replaceFirst('#', '?'));
      final accessToken = uri.queryParameters['access_token'];
      if (accessToken != null) {
        _storeTokenAndFetchData(accessToken);
      } else {
        setState(() {
          isAuthenticating = false;
          _authError = 'Failed to extract access token';
          _useMockData('Failed to extract access token. Using sample data.');
        });
      }
    } else {
      setState(() {
        isAuthenticating = false;
        _authError = 'No access token found in response';
        _useMockData('Authentication failed. Using sample data.');
      });
    }
  }

  Future<void> _checkStoredToken() async {
    try {
      setState(() {
        isLoadingData = true;
        useMockData = false;
        mockDataMessage = null;
      });

      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('fitbit_token');

      if (token != null && token.isNotEmpty) {
        _accessToken = token;

        try {
          await _fetchFitbitData(token);
          setState(() {
            fitbitConnected = true;
            isLoadingData = false;
          });
        } catch (e) {
          print('Error loading Fitbit data: $e');
          await prefs.remove('fitbit_token');
          _useMockData('Error loading Fitbit data: $e');
        }
      } else {
        setState(() {
          isLoadingData = false;
          // No token, but not an error
          fitbitConnected = false;
        });
      }
    } catch (e) {
      print('Error checking stored token: $e');
      setState(() {
        isLoadingData = false;
        _authError = 'Error checking stored token: $e';
        // Use mock data as fallback
        _useMockData('Error checking token. Using sample data.');
      });
    }
  }

  void _connectToFitbit() {
    setState(() {
      isAuthenticating = true;
      _authError = null;
      useMockData = false;
      mockDataMessage = null;
    });

    final state = DateTime.now().millisecondsSinceEpoch.toString();
    final authUrl = Uri.https('www.fitbit.com', '/oauth2/authorize', {
      'response_type': 'token',
      'client_id': clientId,
      'redirect_uri': redirectUri,
      'scope': 'activity heartrate profile sleep nutrition weight',
      'expires_in': '604800',
      'state': state,
    }).toString();

    WebHelper.openAuthWindow(authUrl);
  }

  Future<void> _disconnectFitbit() async {
    try {
      // Show confirmation dialog
      final bool? confirmDisconnect = await showDialog<bool>(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Disconnect Fitbit'),
            content: const Text(
              'Are you sure you want to disconnect your Fitbit account? '
              'This will remove all access to your Fitbit data from this app.'
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('CANCEL'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('DISCONNECT'),
              ),
            ],
          );
        },
      );

      if (confirmDisconnect == true) {
        // Clear stored token
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('fitbit_token');

        setState(() {
          fitbitConnected = false;
          steps = null;
          caloriesBurned = null;
          activeMinutes = null;
          heartRate = null;
          sleepDuration = null;
          deepSleepPercentage = null;
          recentExercises = [];
          _accessToken = null;
          _authError = null;
          _chartsInitialized = false;
          useMockData = false;
          mockDataMessage = null;
        });

        // Show success snackbar
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Successfully disconnected from Fitbit'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      setState(() {
        _authError = 'Error disconnecting: $e';
      });
    }
  }

  // Handle failure gracefully with mock data
  void _useMockData(String message) {
    setState(() {
      useMockData = true;
      mockDataMessage = message;
      isAuthenticating = false;
      isLoadingData = false;
      
      // Load mock activity data
      final mockActivityData = MockDataProvider.getMockStepsData();
      steps = mockActivityData['steps'];
      caloriesBurned = mockActivityData['caloriesBurned'];
      activeMinutes = mockActivityData['activeMinutes'];
      
      // Load mock heart rate data
      final mockHrData = MockDataProvider.getMockHeartRateData();
      heartRate = mockHrData['restingHR'];
      
      // Load mock sleep data
      final mockSleepData = MockDataProvider.getMockSleepData();
      sleepDuration = mockSleepData['duration'];
      deepSleepPercentage = mockSleepData['deepSleep'];
      
      // Load mock exercise data
      recentExercises = MockDataProvider.getMockExerciseData();
      
      // Generate mock chart data
      _heartRateData = MockDataProvider.getMockHeartRateChartData(24);
      _stepsData = MockDataProvider.getMockStepsChartData(7);
      _chartsInitialized = true;
    });
  }

  Future<void> _storeTokenAndFetchData(String token) async {
    try {
      setState(() {
        isLoadingData = true;
        useMockData = false;
        mockDataMessage = null;
      });

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('fitbit_token', token);

      _accessToken = token;

      // Fetch data
      try {
        await _fetchFitbitData(token);
        await _initializeChartData(token);
      } catch (e) {
        // Continue even if data fetching fails
        print('Error fetching initial data: $e');
        _useMockData('Error fetching Fitbit data: $e. Using sample data.');
      }

      setState(() {
        fitbitConnected = !useMockData; // Only set connected if not using mock data
        isAuthenticating = false;
        isLoadingData = false;
      });

      // Show success snackbar
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(useMockData 
                ? 'Fitbit connection issues detected. Using sample data.' 
                : 'Successfully connected to Fitbit'),
            backgroundColor: useMockData ? Colors.orange : Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      setState(() {
        isAuthenticating = false;
        isLoadingData = false;
        _authError = 'Error: $e';
        // Use mock data as fallback
        _useMockData('Error connecting to Fitbit: $e. Using sample data.');
      });
    }
  }

  Future<void> _fetchFitbitData(String token) async {
    try {
      setState(() {
        isLoadingData = true;
        _authError = null;
      });

      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      bool hasDataErrors = false;

      try {
        // Fetch steps data
        final stepsResponse = await http.get(
          Uri.parse('https://api.fitbit.com/1/user/-/activities/steps/date/today/1d.json'),
          headers: {
            'Authorization': 'Bearer $token',
            'Accept': 'application/json',
          },
        );

        if (stepsResponse.statusCode == 200) {
          final data = json.decode(stepsResponse.body);
          setState(() {
            steps = data['activities-steps'][0]['value'];
          });
        } else if (stepsResponse.statusCode == 401) {
          // Handle authentication error
          throw Exception('Authentication expired');
        } else {
          print('Steps API error: ${stepsResponse.statusCode}');
          hasDataErrors = true;
          setState(() {
            steps = MockDataProvider.getMockStepsData()['steps'];
          });
        }
      } catch (e) {
        print('Error fetching steps: $e');
        hasDataErrors = true;
        setState(() {
          steps = MockDataProvider.getMockStepsData()['steps'];
        });
      }

      try {
        // Fetch calories data
        final caloriesResponse = await http.get(
          Uri.parse('https://api.fitbit.com/1/user/-/activities/calories/date/today/1d.json'),
          headers: {
            'Authorization': 'Bearer $token',
            'Accept': 'application/json',
          },
        );

        if (caloriesResponse.statusCode == 200) {
          final data = json.decode(caloriesResponse.body);
          setState(() {
            caloriesBurned = data['activities-calories'][0]['value'];
          });
        } else {
          hasDataErrors = true;
          setState(() {
            caloriesBurned = MockDataProvider.getMockStepsData()['caloriesBurned'];
          });
        }
      } catch (e) {
        print('Error fetching calories: $e');
        hasDataErrors = true;
        setState(() {
          caloriesBurned = MockDataProvider.getMockStepsData()['caloriesBurned'];
        });
      }

      try {
        // Fetch active minutes data
        final activeMinutesResponse = await http.get(
          Uri.parse('https://api.fitbit.com/1/user/-/activities/minutesVeryActive/date/today/1d.json'),
          headers: {
            'Authorization': 'Bearer $token',
            'Accept': 'application/json',
          },
        );

        if (activeMinutesResponse.statusCode == 200) {
          final data = json.decode(activeMinutesResponse.body);
          setState(() {
            activeMinutes = data['activities-minutesVeryActive'][0]['value'];
          });
        } else {
          hasDataErrors = true;
          setState(() {
            activeMinutes = MockDataProvider.getMockStepsData()['activeMinutes'];
          });
        }
      } catch (e) {
        print('Error fetching active minutes: $e');
        hasDataErrors = true;
        setState(() {
          activeMinutes = MockDataProvider.getMockStepsData()['activeMinutes'];
        });
      }

      try {
        // Fetch heart rate data
        final heartRateResponse = await http.get(
          Uri.parse('https://api.fitbit.com/1/user/-/activities/heart/date/today/1d.json'),
          headers: {
            'Authorization': 'Bearer $token',
            'Accept': 'application/json',
          },
        );

        if (heartRateResponse.statusCode == 200) {
          final data = json.decode(heartRateResponse.body);
          // Extract resting heart rate if available
          final zones = data['activities-heart'][0]['value'];
          if (zones is Map && zones.containsKey('restingHeartRate')) {
            setState(() {
              heartRate = zones['restingHeartRate'].toString();
            });
          } else {
            setState(() {
              heartRate = 'N/A';
            });
          }
        } else {
          hasDataErrors = true;
          setState(() {
            heartRate = MockDataProvider.getMockHeartRateData()['restingHR'];
          });
        }
      } catch (e) {
        print('Error fetching heart rate: $e');
        hasDataErrors = true;
        setState(() {
          heartRate = MockDataProvider.getMockHeartRateData()['restingHR'];
        });
      }

      try {
        // Fetch sleep data
        final sleepResponse = await http.get(
          Uri.parse('https://api.fitbit.com/1.2/user/-/sleep/date/$today.json'),
          headers: {
            'Authorization': 'Bearer $token',
            'Accept': 'application/json',
          },
        );

        if (sleepResponse.statusCode == 200) {
          final data = json.decode(sleepResponse.body);

          if (data['sleep'] != null && data['sleep'].isNotEmpty) {
            // Calculate total sleep duration in minutes
            int totalSleepMinutes = 0;
            int deepSleepMinutes = 0;

            for (var sleep in data['sleep']) {
              totalSleepMinutes += (sleep['minutesAsleep'] as num).toInt();

              // Calculate deep sleep if summary is available
              if (sleep['levels'] != null && sleep['levels']['summary'] != null) {
                if (sleep['levels']['summary']['deep'] != null) {
                  deepSleepMinutes += (sleep['levels']['summary']['deep']['minutes'] as num).toInt();
                }
              }
            }

            // Convert to hours and minutes
            final hours = totalSleepMinutes ~/ 60;
            final minutes = totalSleepMinutes % 60;

            // Calculate deep sleep percentage
            final deepSleepPercentageValue = totalSleepMinutes > 0 
                ? (deepSleepMinutes / totalSleepMinutes * 100).round() 
                : 0;

            setState(() {
              sleepDuration = '$hours hr ${minutes.toString().padLeft(2, '0')} min';
              deepSleepPercentage = '$deepSleepPercentageValue%';
            });
          } else {
            hasDataErrors = true;
            setState(() {
              sleepDuration = MockDataProvider.getMockSleepData()['duration'];
              deepSleepPercentage = '20%'; // Sample value
            });
          }
        } else {
          hasDataErrors = true;
          setState(() {
            sleepDuration = MockDataProvider.getMockSleepData()['duration'];
            deepSleepPercentage = '20%'; // Sample value
          });
        }
      } catch (e) {
        print('Error fetching sleep data: $e');
        hasDataErrors = true;
        setState(() {
          sleepDuration = MockDataProvider.getMockSleepData()['duration'];
          deepSleepPercentage = '20%'; // Sample value
        });
      }

      try {
        // Fetch recent exercises
        final exerciseResponse = await http.get(
          Uri.parse('https://api.fitbit.com/1/user/-/activities/list.json?sort=desc&limit=5&offset=0'),
          headers: {
            'Authorization': 'Bearer $token',
            'Accept': 'application/json',
          },
        );

        if (exerciseResponse.statusCode == 200) {
          final data = json.decode(exerciseResponse.body);

          if (data['activities'] != null && data['activities'].isNotEmpty) {
            final exercises = <Map<String, dynamic>>[];

            for (var activity in data['activities']) {
              if (activity['activityName'] != null) {
                final String? startTimeStr = activity['startTime'];
                // Add null check for startTime
                if (startTimeStr != null && startTimeStr.isNotEmpty) {
                  try {
                    final DateTime activityDate = DateTime.parse(startTimeStr);
                    
                    exercises.add({
                      'name': activity['activityName'],
                      'duration': activity['duration'] != null 
                          ? (activity['duration'] / 60000).round() // Convert from milliseconds to minutes
                          : 0,
                      'calories': activity['calories'] ?? 0,
                      'date': activityDate,
                    });
                  } catch (e) {
                    print('Error parsing date: $e');
                    // Skip this activity if date parsing fails
                  }
                }
              }
            }

            setState(() {
              recentExercises = exercises;
            });
          } else {
            hasDataErrors = true;
            setState(() {
              recentExercises = MockDataProvider.getMockExerciseData();
            });
          }
        } else {
          hasDataErrors = true;
          setState(() {
            recentExercises = MockDataProvider.getMockExerciseData();
          });
        }
      } catch (e) {
        print('Error fetching exercise data: $e');
        hasDataErrors = true;
        setState(() {
          recentExercises = MockDataProvider.getMockExerciseData();
        });
      }

      // If any data errors occurred, update the mock data state
      if (hasDataErrors) {
        setState(() {
          useMockData = true;
          mockDataMessage = 'Some Fitbit data could not be loaded. Showing partial sample data.';
        });
      }

      setState(() {
        fitbitConnected = !useMockData;
        isLoadingData = false;
      });
    } catch (e) {
      print('Error in _fetchFitbitData: $e');
      
      if (e.toString().contains('Authentication expired')) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('fitbit_token');
        setState(() {
          fitbitConnected = false;
          isLoadingData = false;
          _authError = 'Authentication expired. Please reconnect.';
        });
      } else {
        // Use mock data for all values if there's a catastrophic error
        _useMockData('Error fetching Fitbit data: $e. Using sample data.');
      }
    }
  }

  Future<void> _initializeChartData(String token) async {
    try {
      final now = DateTime.now();
      final today = DateFormat('yyyy-MM-dd').format(now);
      final weekAgo = DateFormat('yyyy-MM-dd').format(now.subtract(const Duration(days: 7)));

      bool hasChartErrors = false;

      try {
        // Fetch heart rate data for the past week
        final heartRateResponse = await http.get(
          Uri.parse('https://api.fitbit.com/1/user/-/activities/heart/date/$weekAgo/$today/1d.json'),
          headers: {
            'Authorization': 'Bearer $token',
            'Accept': 'application/json',
          },
        );

        if (heartRateResponse.statusCode == 200) {
          final data = json.decode(heartRateResponse.body);
          final heartData = data['activities-heart'];

          // Create time series data
          final List<FlSpot> hrData = [];

          for (int i = 0; i < heartData.length; i++) {
            final dayData = heartData[i];
            final value = dayData['value'];

            if (value is Map && value.containsKey('restingHeartRate')) {
              hrData.add(FlSpot(i.toDouble(), value['restingHeartRate'].toDouble()));
            }
          }

          if (hrData.isNotEmpty) {
            setState(() {
              _heartRateData = hrData;
            });
          } else {
            hasChartErrors = true;
            setState(() {
              _heartRateData = MockDataProvider.getMockHeartRateChartData(7);
            });
          }
        } else {
          hasChartErrors = true;
          setState(() {
            _heartRateData = MockDataProvider.getMockHeartRateChartData(7);
          });
        }
      } catch (e) {
        print('Error fetching heart rate chart data: $e');
        hasChartErrors = true;
        setState(() {
          _heartRateData = MockDataProvider.getMockHeartRateChartData(7);
        });
      }

      try {
        // Fetch steps data for the past week
        final stepsResponse = await http.get(
          Uri.parse('https://api.fitbit.com/1/user/-/activities/steps/date/$weekAgo/$today/1d.json'),
          headers: {
            'Authorization': 'Bearer $token',
            'Accept': 'application/json',
          },
        );

        if (stepsResponse.statusCode == 200) {
          final data = json.decode(stepsResponse.body);
          final stepsData = data['activities-steps'];

          // Create time series data
          final List<FlSpot> stepsList = [];

          for (int i = 0; i < stepsData.length; i++) {
            final dayData = stepsData[i];
            final valueStr = dayData['value'];
            if (valueStr != null) {
              try {
                final value = int.parse(valueStr.toString());
                stepsList.add(FlSpot(i.toDouble(), value.toDouble()));
              } catch (e) {
                print('Error parsing steps value: $e');
              }
            }
          }

          if (stepsList.isNotEmpty) {
            setState(() {
              _stepsData = stepsList;
            });
          } else {
            hasChartErrors = true;
            setState(() {
              _stepsData = MockDataProvider.getMockStepsChartData(7);
            });
          }
        } else {
          hasChartErrors = true;
          setState(() {
            _stepsData = MockDataProvider.getMockStepsChartData(7);
          });
        }
      } catch (e) {
        print('Error fetching steps chart data: $e');
        hasChartErrors = true;
        setState(() {
          _stepsData = MockDataProvider.getMockStepsChartData(7);
        });
      }

      // If any chart errors occurred, update the mock data state
      if (hasChartErrors && !useMockData) {
        setState(() {
          useMockData = true;
          mockDataMessage = 'Some chart data could not be loaded. Showing partial sample data.';
        });
      }

      setState(() {
        _chartsInitialized = true;
      });
    } catch (e) {
      print('Error initializing chart data: $e');
      // Use mock chart data as fallback
      setState(() {
        _heartRateData = MockDataProvider.getMockHeartRateChartData(7);
        _stepsData = MockDataProvider.getMockStepsChartData(7);
        _chartsInitialized = true;
        
        if (!useMockData) {
          useMockData = true;
          mockDataMessage = 'Error loading chart data. Using sample charts.';
        }
      });
    }
  }

  Future<void> _loadUserInsights() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return;

      // Here you would typically load insights from Firestore
      // This is a placeholder for demonstration purposes
      await _firestore.collection('users').doc(userId).set({
        'lastLogin': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

    } catch (e) {
      print('Error loading user insights: $e');
    }
  }

  Future<void> _refreshFitbitData() async {
    if (_accessToken != null) {
      setState(() {
        _authError = null;
        isLoadingData = true;
        useMockData = false;
        mockDataMessage = null;
      });

      try {
        await _fetchFitbitData(_accessToken!);
        await _initializeChartData(_accessToken!);

        // Show success message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(useMockData 
                  ? 'Some data could not be refreshed. Showing partial sample data.' 
                  : 'Data refreshed successfully'),
              backgroundColor: useMockData ? Colors.orange : Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } catch (e) {
        setState(() {
          _authError = 'Error refreshing data: $e';
          // Use mock data as fallback
          _useMockData('Error refreshing data: $e. Using sample data.');
        });
      }
    } else {
      // No token available, show message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please connect your Fitbit account first'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _signOut() async {
    try {
      await _auth.signOut();

      // Clear Fitbit token
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('fitbit_token');

      setState(() {
        fitbitConnected = false;
        steps = null;
        caloriesBurned = null;
        activeMinutes = null;
        heartRate = null;
        sleepDuration = null;
        deepSleepPercentage = null;
        _accessToken = null;
        useMockData = false;
        mockDataMessage = null;
      });
    } catch (e) {
      print('Error signing out: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error signing out: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _navigateToDailyReport() {
    Navigator.pushNamed(context, '/daily_report');
  }

  void _navigateToSurvey() {
    Navigator.pushNamed(context, '/survey');
  }

  void _navigateToWeeklySummary() {
    Navigator.pushNamed(context, '/weekly_summary');
  }

  void _navigateToStats() {
    Navigator.pushNamed(context, '/stats');
  }

  void _navigateToInsights() {
    Navigator.pushNamed(context, '/insights');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Health Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Data',
            onPressed: isLoadingData ? null : _refreshFitbitData,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sign Out',
            onPressed: _signOut,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: _timePeriods.map((period) => Tab(text: period)).toList(),
        ),
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(color: Colors.blue),
              child: Row(
                children: const [
                  Icon(Icons.fastfood, color: Colors.white, size: 36),
                  SizedBox(width: 12),
                  Text('Health Tracker',
                      style: TextStyle(color: Colors.white, fontSize: 24)),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.home),
              title: const Text('Home'),
              onTap: () {
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.calendar_today),
              title: const Text('Daily Report'),
              onTap: () {
                Navigator.pop(context);
                _navigateToDailyReport();
              },
            ),
            ListTile(
              leading: const Icon(Icons.bar_chart),
              title: const Text('Weekly Summary'),
              onTap: () {
                Navigator.pop(context);
                _navigateToWeeklySummary();
              },
            ),
            ListTile(
              leading: const Icon(Icons.show_chart),
              title: const Text('Stats & Charts'),
              onTap: () {
                Navigator.pop(context);
                _navigateToStats();
              },
            ),
            ListTile(
              leading: const Icon(Icons.lightbulb),
              title: const Text('Insights'),
              onTap: () {
                Navigator.pop(context);
                _navigateToInsights();
              },
            ),
            ListTile(
              leading: const Icon(Icons.assignment),
              title: const Text('Daily Survey'),
              onTap: () {
                Navigator.pop(context);
                _navigateToSurvey();
              },
            ),
          ],
        ),
      ),
      body: Stack(
        children: [
          // Main content with tabs
          TabBarView(
            controller: _tabController,
            children: [
              _buildDailyView(),
              _buildWeeklyView(),
              _buildMonthlyView(),
            ],
          ),
          
          // Show warning banner if using mock data
          if (useMockData && mockDataMessage != null)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
                color: Colors.amber.shade100,
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.amber.shade800, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        mockDataMessage!,
                        style: TextStyle(color: Colors.amber.shade800, fontSize: 12),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 16),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      color: Colors.amber.shade800,
                      onPressed: () {
                        setState(() {
                          mockDataMessage = null;
                        });
                      },
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _navigateToInsights,
        tooltip: 'View Insights',
        child: const Icon(Icons.lightbulb_outline),
      ),
    );
  }

  Widget _buildDailyView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Fitbit connection status card
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Fitbit Connection',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Updated button with hover effect
                      MouseRegion(
                        onEnter: (_) => setState(() => _isHoveringFitbitButton = true),
                        onExit: (_) => setState(() => _isHoveringFitbitButton = false),
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: fitbitConnected && _isHoveringFitbitButton 
                                ? Colors.red 
                                : null,
                          ),
                          onPressed: isAuthenticating || isLoadingData
                              ? null 
                              : (fitbitConnected 
                                  ? _disconnectFitbit 
                                  : _connectToFitbit),
                          icon: Icon(
                            fitbitConnected && _isHoveringFitbitButton 
                                ? Icons.link_off 
                                : Icons.favorite,
                          ),
                          label: Text(
                            isAuthenticating 
                              ? 'Connecting...' 
                              : (fitbitConnected 
                                  ? (_isHoveringFitbitButton 
                                      ? 'Disconnect Fitbit' 
                                      : 'Fitbit Connected')
                                  : 'Connect Fitbit')
                          ),
                        ),
                      ),
                      if (isLoadingData)
                        const CircularProgressIndicator(),
                    ],
                  ),

                  if (_authError != null) ...[
                    const SizedBox(height: 16),
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
                              _authError!,
                              style: TextStyle(color: Colors.red.shade700),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  if (fitbitConnected || useMockData) ...[
                    const SizedBox(height: 24),
                    const Text(
                      'Today\'s Activity',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    _buildActivityMetric(Icons.directions_walk, 'Steps', steps ?? '-'),
                    _buildActivityMetric(Icons.local_fire_department, 'Calories Burned', caloriesBurned ?? '-'),
                    _buildActivityMetric(Icons.timer, 'Active Minutes', activeMinutes ?? '-'),
                    _buildActivityMetric(Icons.favorite, 'Resting Heart Rate', heartRate != null ? '$heartRate bpm' : '-'),
                    _buildActivityMetric(Icons.bedtime, 'Sleep Duration', sleepDuration ?? '-'),
                    _buildActivityMetric(Icons.nightlight, 'Deep Sleep', deepSleepPercentage ?? '-'),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        ElevatedButton.icon(
                          icon: const Icon(Icons.calendar_today),
                          label: const Text('Daily Report'),
                          onPressed: _navigateToDailyReport,
                        ),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.show_chart),
                          label: const Text('View Stats'),
                          onPressed: _navigateToStats,
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),

          if ((fitbitConnected || useMockData) && recentExercises.isNotEmpty) ...[
            const SizedBox(height: 24),
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Recent Exercises',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    ...recentExercises.map((exercise) => 
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12.0),
                        child: Row(
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
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  Text(
                                    '${exercise['duration']} min • ${exercise['calories']} cal • '
                                    '${exercise['date'] != null ? DateFormat('MMM d').format(exercise['date']) : 'N/A'}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ).toList(),
                  ],
                ),
              ),
            ),
          ],

          if ((fitbitConnected || useMockData) && _chartsInitialized) ...[
            const SizedBox(height: 24),

            // Heart rate quick chart
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Heart Rate Trend',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        TextButton(
                          onPressed: _navigateToStats,
                          child: const Text('View Details'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 200,
                      child: _heartRateData.isNotEmpty 
                        ? LineChart(
                            LineChartData(
                              gridData: FlGridData(show: true),
                              titlesData: FlTitlesData(
                                bottomTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    getTitlesWidget: (value, meta) {
                                      if (value.toInt() >= 0 && value.toInt() < 7) {
                                        final day = DateTime.now().subtract(Duration(days: (7 - value.toInt())));
                                        return Text(DateFormat('E').format(day));
                                      }
                                      return const Text('');
                                    },
                                    reservedSize: 30,
                                  ),
                                ),
                                leftTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    reservedSize: 30,
                                  ),
                                ),
                                topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              ),
                              borderData: FlBorderData(show: true),
                              lineBarsData: [
                                LineChartBarData(
                                  spots: _heartRateData,
                                  isCurved: true,
                                  barWidth: 3,
                                  color: Colors.red,
                                  belowBarData: BarAreaData(show: false),
                                  dotData: FlDotData(show: true),
                                ),
                              ],
                            ),
                          )
                        : const Center(child: Text('No heart rate data available')),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Steps quick chart
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Steps Trend',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        TextButton(
                          onPressed: _navigateToStats,
                          child: const Text('View Details'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 200,
                      child: _stepsData.isNotEmpty
                        ? BarChart(
                            BarChartData(
                              alignment: BarChartAlignment.spaceAround,
                              barTouchData: BarTouchData(
                                enabled: true,
                              ),
                              titlesData: FlTitlesData(
                                show: true,
                                bottomTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    getTitlesWidget: (value, meta) {
                                      if (value.toInt() >= 0 && value.toInt() < 7) {
                                        final day = DateTime.now().subtract(Duration(days: (7 - value.toInt())));
                                        return Text(DateFormat('E').format(day));
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
                              gridData: FlGridData(show: true),
                              borderData: FlBorderData(show: true),
                              barGroups: _stepsData.asMap().entries.map((entry) {
                                return BarChartGroupData(
                                  x: entry.key,
                                  barRods: [
                                    BarChartRodData(
                                      toY: entry.value.y,
                                      color: Colors.blue,
                                      width: 16,
                                      borderRadius: const BorderRadius.only(
                                        topLeft: Radius.circular(4),
                                        topRight: Radius.circular(4),
                                      ),
                                    )
                                  ],
                                );
                              }).toList(),
                            ),
                          )
                        : const Center(child: Text('No steps data available')),
                    ),
                  ],
                ),
              ),
            ),
          ],

          const SizedBox(height: 24),

          // Insights preview
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Health Insights',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      TextButton(
                        onPressed: _navigateToInsights,
                        child: const Text('View All'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Sample insights
                  _buildInsightItem(
                    'Your 7 PM walks correlate with better sleep quality',
                    Icons.directions_walk,
                    Colors.green,
                  ),
                  const SizedBox(height: 12),
                  _buildInsightItem(
                    'Higher heart rate variability on days with morning exercise',
                    Icons.favorite,
                    Colors.red,
                  ),
                  const SizedBox(height: 12),
                  _buildInsightItem(
                    'Better mood reported on days with 8+ hours of sleep',
                    Icons.mood,
                    Colors.amber,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeeklyView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Weekly Summary',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '${DateFormat('MMM d').format(DateTime.now().subtract(const Duration(days: 6)))} - '
                        '${DateFormat('MMM d').format(DateTime.now())}',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    ],
                  ),

                  if (!fitbitConnected && !useMockData) ...[
                    const SizedBox(height: 24),
                    Center(
                      child: Column(
                        children: [
                          Icon(
                            Icons.watch,
                            size: 48,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Connect your Fitbit to see your weekly activity summary',
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.add_link),
                            label: const Text('Connect Fitbit'),
                            onPressed: _connectToFitbit,
                          ),
                        ],
                      ),
                    ),
                  ] else if (isLoadingData) ...[
                    const SizedBox(height: 24),
                    const Center(child: CircularProgressIndicator()),
                  ] else ...[
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.bar_chart),
                      label: const Text('View Weekly Summary'),
                      onPressed: _navigateToWeeklySummary,
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 40),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          if ((fitbitConnected || useMockData) && _chartsInitialized) ...[
            const SizedBox(height: 24),

            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Weekly Activity Trends',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),

                    // Steps chart
                    const Text(
                      'Steps',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 200,
                      child: _stepsData.isNotEmpty
                        ? BarChart(
                            BarChartData(
                              alignment: BarChartAlignment.spaceAround,
                              barTouchData: BarTouchData(
                                enabled: true,
                              ),
                              titlesData: FlTitlesData(
                                show: true,
                                bottomTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    getTitlesWidget: (value, meta) {
                                      if (value.toInt() >= 0 && value.toInt() < 7) {
                                        final day = DateTime.now().subtract(Duration(days: (7 - value.toInt())));
                                        return Text(DateFormat('E').format(day));
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
                              gridData: FlGridData(show: true),
                              borderData: FlBorderData(show: true),
                              barGroups: _stepsData.asMap().entries.map((entry) {
                                return BarChartGroupData(
                                  x: entry.key,
                                  barRods: [
                                    BarChartRodData(
                                      toY: entry.value.y,
                                      color: Colors.blue,
                                      width: 16,
                                      borderRadius: const BorderRadius.only(
                                        topLeft: Radius.circular(4),
                                        topRight: Radius.circular(4),
                                      ),
                                    )
                                  ],
                                );
                              }).toList(),
                            ),
                          )
                        : const Center(child: Text('No steps data available')),
                    ),

                    const SizedBox(height: 24),

                    // Heart rate chart
                    const Text(
                      'Resting Heart Rate',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 200,
                      child: _heartRateData.isNotEmpty 
                        ? LineChart(
                            LineChartData(
                              gridData: FlGridData(show: true),
                              titlesData: FlTitlesData(
                                bottomTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    getTitlesWidget: (value, meta) {
                                      if (value.toInt() >= 0 && value.toInt() < 7) {
                                        final day = DateTime.now().subtract(Duration(days: (7 - value.toInt())));
                                        return Text(DateFormat('E').format(day));
                                      }
                                      return const Text('');
                                    },
                                    reservedSize: 30,
                                  ),
                                ),
                                leftTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    reservedSize: 30,
                                  ),
                                ),
                                topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              ),
                              borderData: FlBorderData(show: true),
                              lineBarsData: [
                                LineChartBarData(
                                  spots: _heartRateData,
                                  isCurved: true,
                                  barWidth: 3,
                                  color: Colors.red,
                                  belowBarData: BarAreaData(show: false),
                                  dotData: FlDotData(show: true),
                                ),
                              ],
                            ),
                          )
                        : const Center(child: Text('No heart rate data available')),
                    ),

                    const SizedBox(height: 16),
                    Center(
                      child: TextButton.icon(
                        icon: const Icon(Icons.show_chart),
                        label: const Text('View Detailed Stats'),
                        onPressed: _navigateToStats,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],

          const SizedBox(height: 24),

          // Weekly insights card
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Weekly Insights',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),

                  _buildInsightItem(
                    'You were more active on weekdays than weekends this week',
                    Icons.date_range,
                    Colors.blue,
                  ),
                  const SizedBox(height: 12),
                  _buildInsightItem(
                    'Your sleep quality improved by 15% compared to last week',
                    Icons.bedtime,
                    Colors.indigo,
                  ),
                  const SizedBox(height: 12),
                  _buildInsightItem(
                    'Your average resting heart rate decreased by 3 bpm',
                    Icons.monitor_heart,
                    Colors.red,
                  ),

                  const SizedBox(height: 16),
                  Center(
                    child: TextButton.icon(
                      icon: const Icon(Icons.lightbulb_outline),
                      label: const Text('View All Insights'),
                      onPressed: _navigateToInsights,
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

  Widget _buildMonthlyView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Monthly Overview',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        DateFormat('MMMM yyyy').format(DateTime.now()),
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    ],
                  ),

                  if (!fitbitConnected && !useMockData) ...[
                    const SizedBox(height: 24),
                    Center(
                      child: Column(
                        children: [
                          Icon(
                            Icons.watch,
                            size: 48,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Connect your Fitbit to see your monthly activity summary',
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.add_link),
                            label: const Text('Connect Fitbit'),
                            onPressed: _connectToFitbit,
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    const SizedBox(height: 16),
                    _buildMonthlyMetric(
                      'Avg. Daily Steps',
                      '9,243',
                      Icons.directions_walk,
                      Colors.blue,
                      '+12% from last month',
                      true,
                    ),
                    const SizedBox(height: 16),
                    _buildMonthlyMetric(
                      'Avg. Sleep Duration',
                      '7h 12m',
                      Icons.bedtime,
                      Colors.indigo,
                      '-3% from last month',
                      false,
                    ),
                    const SizedBox(height: 16),
                    _buildMonthlyMetric(
                      'Avg. Resting Heart Rate',
                      '68 bpm',
                      Icons.favorite,
                      Colors.red,
                      '-2 bpm from last month',
                      true,
                    ),
                    const SizedBox(height: 16),
                    _buildMonthlyMetric(
                      'Total Active Minutes',
                      '620 min',
                      Icons.timer,
                      Colors.orange,
                      '+15% from last month',
                      true,
                    ),
                  ],
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Calendar heatmap card
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Activity Calendar',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),

                  // Placeholder for activity calendar
                  Container(
                    height: 240,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.calendar_month, size: 48, color: Colors.grey),
                          const SizedBox(height: 16),
                          Text(
                            fitbitConnected || useMockData
                                ? 'Calendar view coming soon'
                                : 'Connect Fitbit to see your activity calendar',
                            style: TextStyle(color: Colors.grey.shade700),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Monthly insights
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Monthly Insights',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),

                  _buildInsightItem(
                    'Your most active day is Wednesday, averaging 11,245 steps',
                    Icons.emoji_events,
                    Colors.amber,
                  ),
                  const SizedBox(height: 12),
                  _buildInsightItem(
                    'You sleep better on days when you exercise in the morning',
                    Icons.nightlight,
                    Colors.indigo,
                  ),
                  const SizedBox(height: 12),
                  _buildInsightItem(
                    'Your heart rate variability is higher on weekends',
                    Icons.favorite_border,
                    Colors.pink,
                  ),

                  const SizedBox(height: 16),
                  Center(
                    child: TextButton.icon(
                      icon: const Icon(Icons.lightbulb_outline),
                      label: const Text('View All Insights'),
                      onPressed: _navigateToInsights,
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

  Widget _buildActivityMetric(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Icon(icon, color: Colors.blue, size: 20),
          const SizedBox(width: 8),
          Expanded(child: Text(label)),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold),
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
  
  Widget _buildMonthlyMetric(String label, String value, IconData icon, Color color, String change, bool isPositive) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
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
                  label,
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: isPositive ? Colors.green.shade50 : Colors.red.shade50,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Icon(
                  isPositive ? Icons.arrow_upward : Icons.arrow_downward,
                  size: 12,
                  color: isPositive ? Colors.green : Colors.red,
                ),
                const SizedBox(width: 4),
                Text(
                  change,
                  style: TextStyle(
                    fontSize: 12,
                    color: isPositive ? Colors.green.shade700 : Colors.red.shade700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInsightItem(String text, IconData icon, Color color) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 14),
          ),
        ),
      ],
    );
  }
}