import 'package:flutter/foundation.dart';
import '../models/insight.dart';

class InsightsProvider with ChangeNotifier {
  List<Insight> _insights = [];
  String? _error;

  List<Insight> get insights => _insights;
  String? get error => _error;

  Future<void> loadInsights() async {
    try {
      // In a real app, this would fetch data from an API
      _insights = _generateSampleInsights();
      _error = null;
      notifyListeners();
    } catch (e) {
      _error = 'Failed to load insights: $e';
      notifyListeners();
    }
  }

  // Sample data for demonstration
  List<Insight> _generateSampleInsights() {
    return [
      Insight(
        id: 1,
        category: 'Performance',
        title: 'CPU Usage Spike',
        description: 'CPU usage exceeded 80% for 15 minutes at 2:00 PM',
        score: 75,
        recommendation: 'Check for resource-intensive processes that might be causing the spike',
      ),
      Insight(
        id: 2,
        category: 'Security',
        title: 'Multiple Failed Login Attempts',
        description: '5 failed login attempts detected from IP 192.168.1.105',
        score: 90,
        recommendation: 'Consider blocking this IP address and reviewing your authentication policies',
      ),
      Insight(
        id: 3,
        category: 'Performance',
        title: 'Memory Usage Optimization',
        description: 'Application memory usage is consistently high',
        score: 60,
        recommendation: 'Consider implementing memory optimization techniques',
      ),
      Insight(
        id: 4,
        category: 'Availability',
        title: 'Service Uptime',
        description: 'Your service has maintained 99.9% uptime this month',
        score: 30,
      ),
      Insight(
        id: 5,
        category: 'Security',
        title: 'Software Updates Available',
        description: '3 critical security updates are available for your system',
        score: 85,
        recommendation: 'Update your system as soon as possible to maintain security',
      ),
    ];
  }
} 