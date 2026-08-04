import 'dart:io';

import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:image_picker/image_picker.dart';

import '../models/conversation.dart';
import '../models/message.dart';
import '../models/model.dart';
import '../services/chat_service.dart';
import '../services/media_service.dart';
import '../theme/app_theme.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/message_bubble.dart';
import '../widgets/model_selector.dart';

class ChatScreen extends StatefulWidget {
  final String? initialPrompt;

  const ChatScreen({super.key, this.initialPrompt});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _inputCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  final List<AiModel> _models = [];
  final List<Message> _messages = [];
  Conversation? _conversation;
  AiModel? _selectedModel;
  bool _loadingModels = true;
  bool _creating = true;
  bool _streaming = false;
  bool _generatingMedia = false;

  @override
  void initState() {
    super.initState();
    _loadModels();
  }

  Future<void> _loadModels() async {
    try {
      final models = await ChatService().fetchModels();
      if (!mounted) return;
      setState(() {
        _models.addAll(models);
        _selectedModel = models.isNotEmpty ? models.first : null;
      });
      await _ensureConversation();
    } catch (e) {
      if (!mounted) return;
      Fluttertoast.showToast(msg: '获取模型失败: $e');
    } finally {
      if (mounted) setState(() => _loadingModels = false);
    }
  }

  Future<void> _ensureConversation() async {
    if (_conversation != null) return;
    setState(() => _creating = true);
    try {
      final conv = await ChatService().createConversation(
        title: '新对话',
        model: _selectedModel?.id ?? 'GLM-4-Flash',
      );
      if (!mounted) return;
      setState(() => _conversation = conv);
      if (widget.initialPrompt != null && widget.initialPrompt!.isNotEmpty) {
        _send(widget.initialPrompt!);
      }
    } catch (e) {
      if (!mounted) return;
      Fluttertoast.showToast(msg: '创建对话失败: $e');
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  Future<void> _send(String content, {List<Attachment> attachments = const []}) async {
    if (content.trim().isEmpty && attachments.isEmpty) return;
    await _ensureConversation();
    if (_conversation == null) return;

    final userMessage = Message(
      role: 'user',
      content: content.trim(),
      attachments: attachments,
    );

    setState(() {
      _messages.add(userMessage);
      _inputCtrl.clear();
      _streaming = true;
    });
    _scrollToBottom();

    final aiIndex = _messages.length;
    _messages.add(Message(role: 'assistant', content: '', reasoning: ''));
    setState(() {});

    try {
      await for (final delta in ChatService().sendMessageStream(
        _conversation!.id,
        content.trim(),
        attachments: attachments,
      )) {
        if (!mounted) return;
        setState(() {
          final current = _messages[aiIndex];
          _messages[aiIndex] = current.copyWith(
            content: current.content + delta.content,
            reasoning: current.reasoning == null || current.reasoning!.isEmpty
                ? delta.reasoning
                : current.reasoning! + delta.reasoning,
          );
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (!mounted) return;
      Fluttertoast.showToast(msg: '发送失败: $e');
    } finally {
      if (mounted) setState(() => _streaming = false);
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _clearConversation() async {
    final confirmed = await showConfirmDialog(
      context,
      title: '清除对话',
      content: '确定要清空当前对话的所有消息吗？',
      isDanger: true,
    );
    if (!confirmed || !mounted) return;
    setState(() => _messages.clear());
  }

  Future<void> _generateImage() async {
    final prompt = _inputCtrl.text.trim();
    if (prompt.isEmpty) {
      Fluttertoast.showToast(msg: '请先输入画面描述');
      return;
    }
    setState(() => _generatingMedia = true);
    try {
      final res = await MediaService().generateImage(prompt: prompt);
      if (!mounted) return;
      final url = res['url'] as String?;
      final type = res['type'] as String? ?? 'image';
      if (url != null) {
        _send('', attachments: [Attachment(url: url, type: type)]);
      }
    } catch (e) {
      if (!mounted) return;
      Fluttertoast.showToast(msg: '生成图片失败: $e');
    } finally {
      if (mounted) setState(() => _generatingMedia = false);
    }
  }

  Future<void> _generateVideo() async {
    final prompt = _inputCtrl.text.trim();
    if (prompt.isEmpty) {
      Fluttertoast.showToast(msg: '请先输入视频描述');
      return;
    }
    setState(() => _generatingMedia = true);
    try {
      final res = await MediaService().generateVideo(prompt: prompt);
      if (!mounted) return;
      final taskId = res['task_id'] as String?;
      if (taskId != null) {
        Fluttertoast.showToast(msg: '视频生成任务已提交');
      }
    } catch (e) {
      if (!mounted) return;
      Fluttertoast.showToast(msg: '生成视频失败: $e');
    } finally {
      if (mounted) setState(() => _generatingMedia = false);
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;
    setState(() => _generatingMedia = true);
    try {
      final res = await MediaService().uploadFile(File(picked.path));
      if (!mounted) return;
      final url = res['url'] as String?;
      final type = res['type'] as String? ?? 'image';
      if (url != null) {
        _send('', attachments: [Attachment(url: url, type: type)]);
      }
    } catch (e) {
      if (!mounted) return;
      Fluttertoast.showToast(msg: '上传失败: $e');
    } finally {
      if (mounted) setState(() => _generatingMedia = false);
    }
  }

  Future<void> _selectModel() async {
    final model = await showModelSelector(context, _models, _selectedModel);
    if (model != null && mounted) {
      setState(() => _selectedModel = model);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AppBar(
          title: Text(_selectedModel?.name ?? '对话'),
          actions: [
            if (_loadingModels)
              const Padding(
                padding: EdgeInsets.only(right: 16),
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            else
              TextButton.icon(
                onPressed: _selectModel,
                icon: const Icon(Icons.tune, size: 18),
                label: Text(_selectedModel?.name ?? '模型'),
              ),
            IconButton(
              onPressed: _clearConversation,
              icon: const Icon(Icons.delete_outline),
            ),
          ],
        ),
        Expanded(
          child: GestureDetector(
            onTap: () => FocusScope.of(context).unfocus(),
            child: _creating
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    controller: _scrollCtrl,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final msg = _messages[index];
                      return MessageBubble(
                        message: msg,
                        showDisclaimer: msg.role == 'assistant',
                      );
                    },
                  ),
          ),
        ),
        _buildInputArea(),
      ],
    );
  }

  Widget _buildInputArea() {
    return Container(
      margin: const EdgeInsets.only(left: 16, right: 16, bottom: 8, top: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.button),
        boxShadow: AppShadows.card,
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: _streaming || _generatingMedia ? null : _pickImage,
                  icon: const Icon(Icons.image_outlined),
                  color: AppColors.primary,
                ),
                IconButton(
                  onPressed: _streaming || _generatingMedia ? null : _generateImage,
                  icon: const Icon(Icons.palette_outlined),
                  color: AppColors.primary,
                ),
                IconButton(
                  onPressed: _streaming || _generatingMedia ? null : _generateVideo,
                  icon: const Icon(Icons.videocam_outlined),
                  color: AppColors.primary,
                ),
              ],
            ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _inputCtrl,
                    enabled: !_streaming,
                    minLines: 1,
                    maxLines: 5,
                    decoration: const InputDecoration(
                      hintText: '输入消息...',
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                    ),
                    onSubmitted: (v) => _send(v),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _streaming ? null : () => _send(_inputCtrl.text),
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: _streaming ? AppColors.outline : AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: _streaming
                        ? const Padding(
                            padding: EdgeInsets.all(10),
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.onSurfaceVariant,
                            ),
                          )
                        : const Icon(
                            Icons.send,
                            color: AppColors.onPrimary,
                            size: 20,
                          ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }
}
