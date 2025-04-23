import 'package:flutter/material.dart';

class DashboardCard extends StatelessWidget {
  final String title;
  final String? value;
  final String? subtitle;
  final List<Map<String, String>>? details;
  final double? progressValue;
  final String? progressLabel;
  final bool isDoubleValue;
  final List<Map<String, dynamic>>? doubleValues;
  final bool showChart;

  const DashboardCard({
    Key? key,
    required this.title,
    this.value,
    this.subtitle,
    this.details,
    this.progressValue,
    this.progressLabel,
    this.isDoubleValue = false,
    this.doubleValues,
    this.showChart = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
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
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          if (!isDoubleValue && value != null) ...[
            Text(
              value!,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            if (subtitle != null)
              Text(
                subtitle!,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
          ],
          if (isDoubleValue && doubleValues != null) ...[
            Row(
              children: doubleValues!.map((valueMap) {
                return Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        valueMap['value'],
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: valueMap['color'],
                            ),
                      ),
                      Text(
                        valueMap['label'],
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
          if (details != null && details!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: details!.map((detail) {
                return Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        detail['value']!,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        detail['label']!,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
          if (progressValue != null) ...[
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: progressValue,
              backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation<Color>(
                progressValue! > 0.7
                    ? Colors.green
                    : progressValue! > 0.4
                        ? Colors.amber
                        : Colors.red,
              ),
            ),
            if (progressLabel != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  progressLabel!,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
          ],
          if (showChart) ...[
            const SizedBox(height: 8),
            Container(
              height: 100,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Center(
                child: Text('Chart placeholder'),
              ),
            ),
          ],
        ],
      ),
    );
  }
} 