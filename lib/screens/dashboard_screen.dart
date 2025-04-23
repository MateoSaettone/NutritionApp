import 'package:flutter/material.dart';
import '../widgets/dashboard_card.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Daily View',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: DashboardCard(
                  title: 'Calories',
                  value: '-200',
                  subtitle: 'Balance',
                  details: [
                    {'label': 'Consumed', 'value': '1,800'},
                    {'label': 'Burned', 'value': '2,000'},
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: DashboardCard(
                  title: 'Sleep',
                  value: '7.5',
                  subtitle: 'Hours',
                  progressValue: 0.75,
                  progressLabel: 'Good quality (75%)',
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: DashboardCard(
                  title: 'HRV',
                  value: '55',
                  subtitle: 'ms',
                  showChart: true,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: DashboardCard(
                  title: 'Stress & Recovery',
                  isDoubleValue: true,
                  doubleValues: [
                    {'label': 'Stress', 'value': '45', 'color': Colors.orange},
                    {'label': 'Recovery', 'value': '70', 'color': Colors.green},
                  ],
                  progressValue: 0.65,
                  progressLabel: 'Good balance (65%)',
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            'Health Insights',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your health data is looking good',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Tap on the Insights tab to see more detailed analysis and recommendations.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
} 