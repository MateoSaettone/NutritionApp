class Insight {
  final int id;
  final String category;
  final String title;
  final String description;
  final int score;
  final String? recommendation;

  const Insight({
    required this.id,
    required this.category,
    required this.title,
    required this.description,
    required this.score,
    this.recommendation,
  });
} 