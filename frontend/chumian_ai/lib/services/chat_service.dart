import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/conversation.dart';
import '../models/message.dart';
import '../models/model.dart';
import '../utils/constants.dart';
import 'api_client.dart';

class StreamDelta {
  final String content;
  final String reasoning;
  final bool done;
  final int? messageId;
  final int? cost;
  final int? balance;

  StreamDelta({
    required this.content,
    required this.reasoning,
    required this.done,
    this.messageId,
    this.cost,
    this.balance,
  });
}

class ChatService {
  static final ChatService _instance = ChatService._internal();
  factory ChatService() => _instance;
  ChatService._internal();

  Future<List<AiModel>> fetchModels() async {
    final res = await ApiClient().get('/api/chat/models');
    return (res as List)
        .map((e) => AiModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<Conversation>> fetchConversations() async {
    final res = await ApiClient().get('/api/chat/conversations');
    return (res as List)
        .map((e) => Conversation.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Conversation> createConversation({
    required String title,
    required String model,
  }) async {
    final res = await ApiClient().post('/api/chat/conversations', body: {
      'title': title,
      'model': model,
    });
    return Conversation.fromJson(res as Map<String, dynamic>);
  }

  Future<List<Message>> fetchMessages(int conversationId) async {
    final res = await ApiClient()
        .get('/api/chat/conversations/$conversationId/messages');
    return (res as List)
        .map((e) => Message.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> deleteConversation(int conversationId) async {
    await ApiClient().delete('/api/chat/conversations/$conversationId');
  }

  Stream<StreamDelta> sendMessageStream(
    int conversationId,
    String content, {
    List<Attachment> attachments = const [],
  }) async* {
    final uri = Uri.parse(kBaseUrl).replace(
      path: '/api/chat/conversations/$conversationId/messages',
    );
    final request = http.Request('POST', uri);
    request.headers['Content-Type'] = 'application/json';
    if (ApiClient().token != null) {
      request.headers['X-Session-Token'] = ApiClient().token!;
    }
    request.body = jsonEncode({
      'content': content,
      'attachments': attachments
          .map((a) => {'url': a.url, 'type': a.type})
          .toList(),
    });

    final streamed = await ApiClient().send(request);
    await for (final chunk in streamed.stream
        .transform(utf8.decoder)
        .transform(const LineSplitter())) {
      if (!chunk.startsWith('data:')) continue;
      final jsonText = chunk.substring(5).trim();
      if (jsonText.isEmpty || jsonText == '[DONE]') continue;
      try {
        final data = jsonDecode(jsonText) as Map<String, dynamic>;
        yield StreamDelta(
          content: data['content'] as String? ?? '',
          reasoning: data['reasoning'] as String? ?? '',
          done: data['done'] as bool? ?? false,
          messageId: data['message_id'] as int?,
          cost: data['cost'] as int?,
          balance: data['balance'] as int?,
        );
      } catch (_) {
        // ignore malformed lines
      }
    }
  }
}
