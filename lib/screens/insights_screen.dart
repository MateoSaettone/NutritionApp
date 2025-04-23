import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/insights_provider.dart';
import '../widgets/insight_card.dart';

class InsightsScreen extends StatefulWidget {
  const InsightsScreen({Key? key}) : super(key: key);

  @override
  State<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends State<InsightsScreen> {
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadInsights();
  }

  Future<void> _loadInsights() async {
    setState(() {
      _isLoading = true;
    });
    
    await Provider.of<InsightsProvider>(context, listen: false).loadInsights();
    
    setState(() {
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final insightsProvider = Provider.of<InsightsProvider>(context);
    final insights = insightsProvider.insights;
    final error = insightsProvider.error;

    return Scaffold(
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Error: $error'),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadInsights,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : insights.isEmpty
                  ? const Center(
                      child: Text('No insights available'),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadInsights,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16.0),
                        itemCount: insights.length,
                        itemBuilder: (context, index) {
                          final insight = insights[index];
                          return InsightCard(insight: insight);
                        },
                      ),
                    ),
      floatingActionButton: FloatingActionButton(
        onPressed: _loadInsights,
        tooltip: 'Refresh',
        child: const Icon(Icons.refresh),
      ),
    );
  }
} 