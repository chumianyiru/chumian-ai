class Post {
  final int id;
  final String title;
  final String content;
  final String? mediaUrl;
  final int likes;
  final int comments;
  final bool liked;
  final DateTime createdAt;

  Post({
    required this.id,
    required this.title,
    required this.content,
    this.mediaUrl,
    required this.likes,
    required this.comments,
    required this.liked,
    required this.createdAt,
  });

  factory Post.fromJson(Map<String, dynamic> json) {
    return Post(
      id: json['id'] as int,
      title: json['title'] as String,
      content: json['content'] as String,
      mediaUrl: json['media_url'] as String?,
      likes: json['likes'] as int? ?? 0,
      comments: json['comments'] as int? ?? 0,
      liked: json['liked'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Post copyWith({int? likes, bool? liked, int? comments}) {
    return Post(
      id: id,
      title: title,
      content: content,
      mediaUrl: mediaUrl,
      likes: likes ?? this.likes,
      comments: comments ?? this.comments,
      liked: liked ?? this.liked,
      createdAt: createdAt,
    );
  }
}

class Comment {
  final int id;
  final String content;
  final String? authorNickname;
  final DateTime createdAt;

  Comment({
    required this.id,
    required this.content,
    this.authorNickname,
    required this.createdAt,
  });

  factory Comment.fromJson(Map<String, dynamic> json) {
    return Comment(
      id: json['id'] as int,
      content: json['content'] as String,
      authorNickname: json['author_nickname'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
