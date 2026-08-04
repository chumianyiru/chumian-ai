import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/message.dart';
import '../theme/app_theme.dart';

class MessageBubble extends StatefulWidget {
  final Message message;
  final bool isUser;
  final bool showDisclaimer;

  MessageBubble({
    super.key,
    required this.message,
    this.showDisclaimer = false,
  }) : isUser = message.role == 'user';

  @override
  State<MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<MessageBubble> {
  bool _showReasoning = false;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: widget.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(
          left: widget.isUser ? 48 : 16,
          right: widget.isUser ? 16 : 48,
          bottom: 12,
        ),
        child: Column(
          crossAxisAlignment: widget.isUser
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: widget.isUser ? AppColors.userBubble : AppColors.aiBubble,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(AppRadius.bubble),
                  topRight: const Radius.circular(AppRadius.bubble),
                  bottomLeft: Radius.circular(widget.isUser ? AppRadius.bubble : 4),
                  bottomRight: Radius.circular(widget.isUser ? 4 : AppRadius.bubble),
                ),
                boxShadow: AppShadows.low,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!widget.isUser &&
                      widget.message.reasoning != null &&
                      widget.message.reasoning!.isNotEmpty)
                    _buildReasoning(),
                  MarkdownBody(
                    data: widget.message.content.isEmpty
                        ? widget.isUser
                            ? ''
                            : '正在思考中...'
                        : widget.message.content,
                    selectable: true,
                    styleSheet: MarkdownStyleSheet(
                      p: const TextStyle(
                        fontSize: 15,
                        height: 1.55,
                        color: AppColors.onSurface,
                      ),
                      code: TextStyle(
                        fontSize: 13,
                        backgroundColor: AppColors.secondaryContainer,
                        color: AppColors.onSurface,
                      ),
                      codeblockDecoration: BoxDecoration(
                        color: AppColors.secondaryContainer,
                        borderRadius: BorderRadius.circular(AppRadius.input),
                      ),
                      blockquote: const TextStyle(
                        color: AppColors.onSurfaceVariant,
                        fontStyle: FontStyle.italic,
                      ),
                      blockquoteDecoration: const BoxDecoration(
                        border: Border(
                          left: BorderSide(color: AppColors.primary, width: 3),
                        ),
                      ),
                      h1: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.onSurface,
                      ),
                      h2: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.onSurface,
                      ),
                      h3: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.onSurface,
                      ),
                      listBullet: const TextStyle(
                        color: AppColors.primary,
                      ),
                      a: const TextStyle(
                        color: AppColors.primary,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                    onTapLink: (text, href, title) {
                      if (href != null) {
                        launchUrl(Uri.parse(href),
                            mode: LaunchMode.externalApplication);
                      }
                    },
                  ),
                ],
              ),
            ),
            if (widget.showDisclaimer) ...[
              const SizedBox(height: 6),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  'AI生成不一定代表真实，如果您感觉到了异常，请立即停止使用。',
                  style: TextStyle(
                    fontSize: 13,
                    fontStyle: FontStyle.italic,
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildReasoning() {
    return GestureDetector(
      onTap: () => setState(() => _showReasoning = !_showReasoning),
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.secondaryContainer,
          borderRadius: BorderRadius.circular(AppRadius.chip),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _showReasoning
                      ? Icons.expand_less
                      : Icons.expand_more,
                  size: 16,
                  color: AppColors.reasoning,
                ),
                const SizedBox(width: 4),
                const Text(
                  '正在思考中...',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.reasoning,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            if (_showReasoning)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  widget.message.reasoning!,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.reasoning,
                    height: 1.5,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
