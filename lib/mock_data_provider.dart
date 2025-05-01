// lib/mock_data_provider.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:math';

class MockDataProvider {
  static final Random _random = Random();
  
  // Generate a random value within a range
  static int randomInt(int min, int max) {
    return min + _random.nextInt(max - min);
  }
  
  static double randomDouble(double min, double max) {
    return min + _random.nextDouble() * (max - min);
  }
  
  // Generate mock activity insights
  static List<Map<String, dynamic>> getMockActivityInsights() {
    return [
      {
        'title': 'Great Activity Level',
        'description': 'You\'re averaging ${numberFormat(randomInt(9000, 12000))} steps daily, which exceeds the recommended 10,000 steps!',
        'icon': Icons.directions_walk,
        'color': Colors.green,
      },
      {
        'title': 'Most Active Day',
        'description': 'Your most active day of the week is ${['Monday', 'Wednesday', 'Thursday', 'Saturday'][randomInt(0, 4)]} with an average of ${numberFormat(randomInt(12000, 15000))} steps.',
        'icon': Icons.calendar_today,
        'color': Colors.purple,
      },
      {
        'title': 'Meeting Activity Guidelines',
        'description': 'You\'re getting ${randomInt(30, 60)} minutes of intense activity daily, which meets health recommendations.',
        'icon': Icons.fitness_center,
        'color': Colors.green,
      },
    ];
  }
  
  // Generate mock sleep insights
  static List<Map<String, dynamic>> getMockSleepInsights() {
    return [
      {
        'title': 'Optimal Sleep Duration',
        'description': 'You\'re averaging ${randomDouble(7.0, 8.5).toStringAsFixed(1)} hours of sleep, which is within the recommended range.',
        'icon': Icons.bedtime,
        'color': Colors.indigo,
      },
      {
        'title': 'Excellent Deep Sleep',
        'description': 'Your deep sleep makes up ${randomInt(20, 30)}% of your total sleep, which is above average.',
        'icon': Icons.nightlight,
        'color': Colors.indigo,
      },
      {
        'title': 'Normal REM Sleep',
        'description': 'Your REM sleep makes up ${randomInt(15, 25)}% of your total sleep, which is within the normal range.',
        'icon': Icons.psychology,
        'color': Colors.blue,
      },
    ];
  }
  
  // Generate mock correlation insights
  static List<Map<String, dynamic>> getMockCorrelationInsights() {
    return [
      {
        'title': 'Evening Walks Improve Sleep',
        'description': 'Your 7 PM walks correlate with better sleep quality. You fall asleep 15 minutes faster on days with evening walks.',
        'icon': Icons.nights_stay,
        'color': Colors.indigo,
      },
      {
        'title': 'Morning Exercise Boosts Heart Health',
        'description': 'Your heart rate variability is 12% higher on days when you exercise before noon.',
        'icon': Icons.monitor_heart,
        'color': Colors.red,
      },
      {
        'title': 'Hydration and Energy',
        'description': 'On days when you log at least 64oz of water, your reported energy levels are 25% higher.',
        'icon': Icons.water_drop,
        'color': Colors.blue,
      },
      {
        'title': 'Consistent Sleep Schedule',
        'description': 'When you go to bed within 30 minutes of your average bedtime, you get 8% more REM sleep.',
        'icon': Icons.schedule,
        'color': Colors.purple,
      },
    ];
  }
  
  // Generate mock nutrition insights
  static List<Map<String, dynamic>> getMockNutritionInsights() {
    return [
      {
        'title': 'Protein Intake',
        'description': 'Your average protein intake is 0.7g per pound of body weight, which supports muscle maintenance.',
        'icon': Icons.egg_alt,
        'color': Colors.amber,
      },
      {
        'title': 'Meal Timing',
        'description': 'You tend to consume most of your calories before 7 PM, which aligns well with your sleep schedule.',
        'icon': Icons.schedule,
        'color': Colors.green,
      },
      {
        'title': 'Carbohydrate Distribution',
        'description': 'Consider shifting more of your carbohydrate intake to pre and post-workout periods for optimal energy.',
        'icon': Icons.bakery_dining,
        'color': Colors.orange,
      },
    ];
  }
  
  // Mock steps data
  static Map<String, dynamic> getMockStepsData() {
    return {
      'steps': randomInt(7000, 12000).toString(),
      'caloriesBurned': randomInt(1800, 2500).toString(),
      'activeMinutes': randomInt(30, 120).toString(),
      'distance': (randomDouble(4.0, 8.0)).toStringAsFixed(1),
      'floors': randomInt(5, 15).toString(),
      'stationaryMinutes': randomInt(480, 720).toString(),
    };
  }
  
  // Mock heart rate data
  static Map<String, dynamic> getMockHeartRateData() {
    return {
      'restingHR': randomInt(58, 75).toString(),
      'minHR': randomInt(50, 60).toString(),
      'maxHR': randomInt(110, 140).toString(),
      'hrData': List.generate(24, (index) {
        return {
          'time': DateTime(
            DateTime.now().year,
            DateTime.now().month,
            DateTime.now().day,
            index,
            0,
          ),
          'value': randomInt(60, 100),
        };
      }),
    };
  }
  
  // Mock sleep data
  static Map<String, dynamic> getMockSleepData() {
    final sleepHours = randomInt(6, 9);
    final sleepMinutes = randomInt(0, 60);
    final totalSleepMinutes = sleepHours * 60 + sleepMinutes;
    
    final deepSleepMinutes = (totalSleepMinutes * 0.2).round();
    final remSleepMinutes = (totalSleepMinutes * 0.25).round();
    final lightSleepMinutes = (totalSleepMinutes * 0.45).round();
    final awakeSleepMinutes = totalSleepMinutes - deepSleepMinutes - remSleepMinutes - lightSleepMinutes;
    
    final now = DateTime.now();
    final startTime = DateTime(now.year, now.month, now.day, 23, 0).subtract(const Duration(days: 1));
    final endTime = startTime.add(Duration(minutes: totalSleepMinutes));
    
    return {
      'duration': '$sleepHours hr ${sleepMinutes.toString().padLeft(2, '0')} min',
      'efficiency': '${randomInt(85, 98)}%',
      'deepSleep': '$deepSleepMinutes min',
      'lightSleep': '$lightSleepMinutes min',
      'remSleep': '$remSleepMinutes min',
      'awakeSleep': '$awakeSleepMinutes min',
      'startTime': DateFormat('h:mm a').format(startTime),
      'endTime': DateFormat('h:mm a').format(endTime),
    };
  }
  
  // Mock exercise data
  static List<Map<String, dynamic>> getMockExerciseData() {
    final exerciseTypes = [
      'Running',
      'Walking',
      'Cycling',
      'Strength Training',
      'Swimming',
      'Yoga',
      'HIIT',
      'Elliptical',
    ];
    
    final now = DateTime.now();
    
    return List.generate(randomInt(1, 4), (index) {
      final startHour = randomInt(7, 19);
      final exerciseTime = DateTime(now.year, now.month, now.day, startHour, randomInt(0, 59));
      
      return {
        'name': exerciseTypes[randomInt(0, exerciseTypes.length)],
        'duration': randomInt(15, 90),
        'calories': randomInt(100, 500),
        'distance': randomDouble(1.0, 10.0),
        'startTime': exerciseTime,
      };
    });
  }
  
  // Mock weekly steps data
  static List<int> getMockWeeklyStepsData() {
    return List.generate(7, (index) => randomInt(5000, 15000));
  }
  
  // Mock mood and energy ratings
  static List<double> getMockMoodRatings() {
    return List.generate(7, (index) => randomDouble(4.0, 9.0));
  }
  
  static List<double> getMockEnergyLevels() {
    return List.generate(7, (index) => randomDouble(3.0, 8.0));
  }
  
  // Generate mock chart data for steps
  static List<FlSpot> getMockStepsChartData(int days) {
    return List.generate(days, (index) => 
      FlSpot(index.toDouble(), randomInt(5000, 15000).toDouble())
    );
  }
  
  // Generate mock chart data for heart rate
  static List<FlSpot> getMockHeartRateChartData(int points) {
    List<FlSpot> spots = [];
    double lastValue = randomInt(60, 80).toDouble();
    
    for (int i = 0; i < points; i++) {
      // Create somewhat realistic heart rate data with small variations
      double change = randomDouble(-5, 5);
      // Keep the heart rate within realistic bounds
      lastValue = max(50, min(100, lastValue + change));
      spots.add(FlSpot(i.toDouble(), lastValue));
    }
    
    return spots;
  }
  
  // Generate mock sleep data for charts
  static List<FlSpot> getMockSleepDurationData(int days) {
    return List.generate(days, (index) => 
      FlSpot(index.toDouble(), randomDouble(5.5, 8.5))
    );
  }
  
  // Generate mock pie chart data for sleep stages
  static List<PieChartSectionData> getMockSleepPieChartData() {
    final deepPercent = randomInt(15, 25) / 100;
    final remPercent = randomInt(20, 30) / 100;
    final lightPercent = randomInt(40, 50) / 100;
    final awakePercent = 1 - deepPercent - remPercent - lightPercent;
    
    return [
      PieChartSectionData(
        value: deepPercent * 100,
        title: 'Deep',
        color: Colors.blue,
        radius: 60,
        titleStyle: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
      PieChartSectionData(
        value: lightPercent * 100,
        title: 'Light',
        color: Colors.cyan,
        radius: 60,
        titleStyle: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
      PieChartSectionData(
        value: remPercent * 100,
        title: 'REM',
        color: Colors.green,
        radius: 60,
        titleStyle: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
      PieChartSectionData(
        value: awakePercent * 100,
        title: 'Awake',
        color: Colors.grey,
        radius: 60,
        titleStyle: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
    ];
  }
  
  // Generate mock weekly summary data
  static Map<String, dynamic> getMockWeeklySummaryData() {
    final dailySteps = List.generate(7, (index) => randomInt(5000, 15000));
    final dailyMoodRatings = List.generate(7, (index) => randomDouble(4.0, 9.0));
    final dailyEnergyLevels = List.generate(7, (index) => randomDouble(3.0, 8.0));
    
    // Calculate averages and totals
    final totalSteps = dailySteps.fold(0, (sum, steps) => sum + steps);
    final avgSteps = dailySteps.isNotEmpty ? totalSteps / dailySteps.length : 0;
    
    final nonZeroMoodDays = dailyMoodRatings.where((mood) => mood > 0).length;
    final weeklyAvgMood = nonZeroMoodDays > 0 
        ? dailyMoodRatings.fold(0.0, (sum, mood) => sum + mood) / nonZeroMoodDays 
        : 0;
    
    final nonZeroEnergyDays = dailyEnergyLevels.where((energy) => energy > 0).length;
    final weeklyAvgEnergy = nonZeroEnergyDays > 0 
        ? dailyEnergyLevels.fold(0.0, (sum, energy) => sum + energy) / nonZeroEnergyDays 
        : 0;
    
    return {
      'dailySteps': dailySteps,
      'dailyMoodRatings': dailyMoodRatings,
      'dailyEnergyLevels': dailyEnergyLevels,
      'weeklyAvgMood': weeklyAvgMood,
      'weeklyAvgEnergy': weeklyAvgEnergy,
      'totalSteps': totalSteps,
      'avgSteps': avgSteps,
    };
  }
  
  // Generate weekly insights
  static List<Map<String, dynamic>> getMockWeeklyInsights() {
    return [
      {
        'title': 'Activity Trend',
        'description': 'Your activity level is ${['increasing', 'consistent', 'varying', 'slightly decreasing'][randomInt(0, 4)]} compared to last week.',
        'icon': Icons.trending_up,
        'color': Colors.blue,
      },
      {
        'title': 'Sleep Quality',
        'description': 'Your average sleep quality has ${['improved', 'remained stable', 'slightly decreased'][randomInt(0, 3)]} this week.',
        'icon': Icons.nightlight,
        'color': Colors.indigo,
      },
      {
        'title': 'Weekly Goal Progress',
        'description': 'You\'ve reached your daily step goal on ${randomInt(3, 7)} days this week. ${randomInt(0, 2) == 0 ? 'Great job!' : 'Keep it up!'}',
        'icon': Icons.emoji_events,
        'color': Colors.amber,
      },
    ];
  }
  
  // Generate mock stats data
  static Map<String, Map<String, dynamic>> getMockStatsData() {
    final weekDays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final randomDay = weekDays[randomInt(0, weekDays.length)];
    final randomDay2 = weekDays[randomInt(0, weekDays.length)];
    
    return {
      'steps': {
        'total': randomInt(35000, 80000),
        'average': randomInt(5000, 11500),
        'max': randomInt(12000, 18000),
        'min': randomInt(2000, 4500),
        'maxDay': randomDay,
        'minDay': randomDay2,
        'goal': 10000,
        'daysAboveGoal': randomInt(2, 7),
      },
      'heartRate': {
        'average': randomInt(58, 75),
        'max': randomInt(75, 90),
        'min': randomInt(50, 57),
        'variance': (randomDouble(1.5, 5.0)).toStringAsFixed(1),
      },
      'sleep': {
        'avgDuration': randomInt(360, 480), // in minutes
        'avgDeepPercentage': randomDouble(15.0, 25.0),
        'avgRemPercentage': randomDouble(20.0, 30.0),
        'bestNight': randomDay,
        'worstNight': randomDay2,
      },
      'activity': {
        'totalActiveMinutes': randomInt(120, 350),
        'totalCaloriesBurned': randomInt(10000, 18000),
        'mostActiveDay': randomDay,
        'leastActiveDay': randomDay2,
      }
    };
  }
  
  // Helper methods
  static String numberFormat(int number) {
    return NumberFormat('#,###').format(number);
  }
  
  // Generate survey mock data
  static Map<String, dynamic> getMockSurveyData() {
    return {
      'moodRating': randomDouble(5.0, 9.0),
      'energyLevel': randomDouble(4.0, 8.0),
      'dietType': ['Balanced', 'High-Protein', 'Low-Carb', 'Vegetarian', 'Vegan'][randomInt(0, 5)],
      'dietaryNotes': 'Sample dietary notes with details about meals consumed today.',
    };
  }
  
  // Generate chart data for statistics page
  static Map<String, List<FlSpot>> getMockChartData() {
    return {
      'steps': List.generate(7, (index) => 
        FlSpot(index.toDouble(), randomInt(5000, 15000).toDouble())
      ),
      'heartRate': List.generate(7, (index) => 
        FlSpot(index.toDouble(), randomInt(55, 75).toDouble())
      ),
      'heartRateIntraday': List.generate(24, (index) => 
        FlSpot(index.toDouble(), randomInt(60, 100).toDouble())
      ),
      'calories': List.generate(7, (index) => 
        FlSpot(index.toDouble(), randomInt(1800, 2800).toDouble())
      ),
      'activeMinutes': List.generate(7, (index) => 
        FlSpot(index.toDouble(), randomInt(20, 90).toDouble())
      ),
      'sleepDuration': List.generate(7, (index) => 
        FlSpot(index.toDouble(), randomDouble(6.0, 8.5))
      ),
      'deepSleep': List.generate(7, (index) => 
        FlSpot(index.toDouble(), randomDouble(15.0, 25.0))
      ),
      'remSleep': List.generate(7, (index) => 
        FlSpot(index.toDouble(), randomDouble(20.0, 30.0))
      ),
    };
  }
  
  // Generate daily activity data with specific date
  static Map<String, dynamic> getMockDailyActivityData(DateTime date) {
    // Generate step count with some weekly patterns (more on weekdays, less on weekends)
    int baseSteps = 9000;
    if (date.weekday == 6 || date.weekday == 7) { // Weekend
      baseSteps = 7000;
    }
    
    final steps = randomInt(baseSteps - 2000, baseSteps + 3000);
    
    // Calculate other metrics based on steps
    final caloriesBurned = (steps * 0.04 + randomInt(500, 800)).round();
    final distance = (steps * 0.0008).toStringAsFixed(1);
    final activeMinutes = (steps / 150).round();
    
    return {
      'steps': steps.toString(),
      'caloriesBurned': caloriesBurned.toString(),
      'activeMinutes': activeMinutes.toString(),
      'distance': distance,
      'floors': randomInt(5, 15).toString(),
      'stationaryMinutes': randomInt(480, 720).toString(),
      'date': DateFormat('yyyy-MM-dd').format(date),
    };
  }
  
  // Generate consistent mock data for a specific date
  static Map<String, dynamic> getMockDataForDate(DateTime date) {
    // Seed the random generator with the date to get consistent results
    final dateSeed = date.year * 10000 + date.month * 100 + date.day;
    final random = Random(dateSeed);
    
    // Generate daily data with consistent patterns
    final isWeekend = date.weekday == 6 || date.weekday == 7;
    
    // Steps are higher on weekdays, lower on weekends
    final baseSteps = isWeekend ? 7500 : 10500;
    final variability = 2000;
    final steps = baseSteps + random.nextInt(variability) - variability ~/ 2;
    
    // Sleep duration is longer on weekends, shorter on weekdays
    final baseSleepHours = isWeekend ? 8.0 : 7.0;
    final sleepHours = baseSleepHours + (random.nextDouble() * 1.5 - 0.75);
    final sleepMinutes = random.nextInt(60);
    
    final sleepHoursInt = sleepHours.floor();
    final totalSleepMinutes = (sleepHours * 60).round();
    
    return {
      'activity': {
        'steps': steps.toString(),
        'caloriesBurned': (steps * 0.04 + 600 + random.nextInt(200)).round().toString(),
        'activeMinutes': (steps / 150).round().toString(),
        'distance': (steps * 0.0008).toStringAsFixed(1),
        'floors': (steps / 2000 + random.nextInt(5)).round().toString(),
        'stationaryMinutes': (1440 - (steps / 100)).round().toString(),
      },
      'heartRate': {
        'restingHR': (60 + random.nextInt(15)).toString(),
        'minHR': (50 + random.nextInt(8)).toString(),
        'maxHR': (110 + random.nextInt(30)).toString(),
      },
      'sleep': {
        'duration': '$sleepHoursInt hr ${sleepMinutes.toString().padLeft(2, '0')} min',
        'efficiency': '${85 + random.nextInt(14)}%',
        'deepSleep': '${(totalSleepMinutes * 0.2).round()} min',
        'lightSleep': '${(totalSleepMinutes * 0.45).round()} min',
        'remSleep': '${(totalSleepMinutes * 0.25).round()} min',
        'awakeSleep': '${(totalSleepMinutes * 0.1).round()} min',
        'startTime': '10:30 PM',
        'endTime': '6:45 AM',
      },
    };
  }
}