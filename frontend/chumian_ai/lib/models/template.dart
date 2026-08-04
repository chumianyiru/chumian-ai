class Template {
  final int id;
  final String category;
  final String title;
  final String prompt;
  final String? icon;

  Template({
    required this.id,
    required this.category,
    required this.title,
    required this.prompt,
    this.icon,
  });

  factory Template.fromJson(Map<String, dynamic> json) {
    return Template(
      id: json['id'] as int,
      category: json['category'] as String,
      title: json['title'] as String,
      prompt: json['prompt'] as String,
      icon: json['icon'] as String?,
    );
  }
}
