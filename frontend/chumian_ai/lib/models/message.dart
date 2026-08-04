class Message {
  final int? id;
  final String role;
  final String content;
  final String? reasoning;
  final DateTime? createdAt;
  final List<Attachment> attachments;

  Message({
    this.id,
    required this.role,
    required this.content,
    this.reasoning,
    this.createdAt,
    this.attachments = const [],
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id'] as int?,
      role: json['role'] as String,
      content: json['content'] as String,
      reasoning: json['reasoning'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      attachments: (json['attachments'] as List<dynamic>?)
              ?.map((e) => Attachment.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  Message copyWith({String? content, String? reasoning}) {
    return Message(
      id: id,
      role: role,
      content: content ?? this.content,
      reasoning: reasoning ?? this.reasoning,
      createdAt: createdAt,
      attachments: attachments,
    );
  }
}

class Attachment {
  final String url;
  final String type;

  Attachment({required this.url, required this.type});

  factory Attachment.fromJson(Map<String, dynamic> json) {
    return Attachment(
      url: json['url'] as String,
      type: json['type'] as String,
    );
  }
}
