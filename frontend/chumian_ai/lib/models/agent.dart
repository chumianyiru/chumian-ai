class Agent {
  final int id;
  final String name;
  final String? description;
  final String? systemPrompt;
  final String? icon;
  final bool published;
  final DateTime createdAt;

  Agent({
    required this.id,
    required this.name,
    this.description,
    this.systemPrompt,
    this.icon,
    required this.published,
    required this.createdAt,
  });

  factory Agent.fromJson(Map<String, dynamic> json) {
    return Agent(
      id: json['id'] as int,
      name: json['name'] as String,
      description: json['description'] as String?,
      systemPrompt: json['system_prompt'] as String?,
      icon: json['icon'] as String?,
      published: json['published'] as bool? ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }
}
