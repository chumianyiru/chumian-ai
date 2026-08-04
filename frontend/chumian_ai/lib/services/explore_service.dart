import '../models/agent.dart';
import '../models/post.dart';
import '../models/template.dart';
import 'api_client.dart';

class ExploreService {
  static final ExploreService _instance = ExploreService._internal();
  factory ExploreService() => _instance;
  ExploreService._internal();

  Future<List<Template>> fetchTemplates(String category) async {
    final res = await ApiClient()
        .get('/api/explore/templates', query: {'category': category});
    return (res as List)
        .map((e) => Template.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<Agent>> fetchAgents() async {
    final res =
        await ApiClient().get('/api/explore/agents', query: {'published': 'true'});
    return (res as List)
        .map((e) => Agent.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Agent> createAgent({
    required String name,
    String? description,
    String? systemPrompt,
    String? icon,
    bool published = true,
  }) async {
    final res = await ApiClient().post('/api/explore/agents', body: {
      'name': name,
      'description': description,
      'system_prompt': systemPrompt,
      'icon': icon,
      'published': published,
    });
    return Agent.fromJson(res as Map<String, dynamic>);
  }

  Future<List<Post>> fetchPosts() async {
    final res = await ApiClient().get('/api/explore/posts');
    return (res as List)
        .map((e) => Post.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Post> createPost({
    required String title,
    required String content,
    String? mediaUrl,
  }) async {
    final res = await ApiClient().post('/api/explore/posts', body: {
      'title': title,
      'content': content,
      'media_url': mediaUrl,
    });
    return Post.fromJson(res as Map<String, dynamic>);
  }

  Future<int> likePost(int postId) async {
    final res = await ApiClient().post('/api/explore/posts/$postId/like');
    return res['likes'] as int? ?? 0;
  }

  Future<List<Comment>> fetchComments(int postId) async {
    final res = await ApiClient().get('/api/explore/posts/$postId/comments');
    return (res as List)
        .map((e) => Comment.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Comment> createComment(int postId, String content) async {
    final res = await ApiClient()
        .post('/api/explore/posts/$postId/comments', body: {'content': content});
    return Comment.fromJson(res as Map<String, dynamic>);
  }
}
