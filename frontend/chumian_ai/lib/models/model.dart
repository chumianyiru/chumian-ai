class AiModel {
  final String id;
  final String name;
  final String type;
  final String? description;

  AiModel({
    required this.id,
    required this.name,
    required this.type,
    this.description,
  });

  factory AiModel.fromJson(Map<String, dynamic> json) {
    return AiModel(
      id: json['id'] as String,
      name: json['name'] as String,
      type: json['type'] as String,
      description: json['description'] as String?,
    );
  }
}
