import 'dart:io';

import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:image_picker/image_picker.dart';

import '../services/explore_service.dart';
import '../services/media_service.dart';
import '../theme/app_theme.dart';
import '../widgets/gradient_scaffold.dart';

class PostCreateScreen extends StatefulWidget {
  const PostCreateScreen({super.key});

  @override
  State<PostCreateScreen> createState() => _PostCreateScreenState();
}

class _PostCreateScreenState extends State<PostCreateScreen> {
  final _titleCtrl = TextEditingController();
  final _contentCtrl = TextEditingController();
  File? _imageFile;
  String? _mediaUrl;
  bool _uploading = false;
  bool _submitting = false;

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;
    setState(() {
      _imageFile = File(picked.path);
      _mediaUrl = null;
    });
  }

  Future<String?> _uploadImage() async {
    if (_imageFile == null) return _mediaUrl;
    setState(() => _uploading = true);
    try {
      final res = await MediaService().uploadFile(_imageFile!);
      return res['url'] as String?;
    } catch (e) {
      Fluttertoast.showToast(msg: '图片上传失败: $e');
      return null;
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _submit() async {
    final title = _titleCtrl.text.trim();
    final content = _contentCtrl.text.trim();
    if (title.isEmpty || content.isEmpty) {
      Fluttertoast.showToast(msg: '请填写标题和内容');
      return;
    }

    setState(() => _submitting = true);
    try {
      String? mediaUrl;
      if (_imageFile != null) {
        mediaUrl = await _uploadImage();
        if (mediaUrl == null) {
          setState(() => _submitting = false);
          return;
        }
      }
      await ExploreService().createPost(
        title: title,
        content: content,
        mediaUrl: mediaUrl,
      );
      if (!mounted) return;
      Fluttertoast.showToast(msg: '发布成功，等待审核');
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      Fluttertoast.showToast(msg: e.toString());
      setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GradientScaffold(
      appBar: AppBar(
        title: const Text('发布帖子'),
        actions: [
          TextButton(
            onPressed: _submitting || _uploading ? null : _submit,
            child: _submitting || _uploading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('发布'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              TextField(
                controller: _titleCtrl,
                decoration: const InputDecoration(
                  hintText: '标题',
                  prefixIcon: Icon(Icons.title),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _contentCtrl,
                maxLines: 8,
                decoration: const InputDecoration(
                  hintText: '分享你的想法...',
                  prefixIcon: Icon(Icons.notes),
                ),
              ),
              const SizedBox(height: 20),
              if (_imageFile != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.input),
                  child: Stack(
                    children: [
                      Image.file(
                        _imageFile!,
                        height: 180,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: GestureDetector(
                          onTap: () => setState(() {
                            _imageFile = null;
                            _mediaUrl = null;
                          }),
                          child: Container(
                            decoration: const BoxDecoration(
                              color: Colors.black54,
                              shape: BoxShape.circle,
                            ),
                            padding: const EdgeInsets.all(6),
                            child: const Icon(
                              Icons.close,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              else
                OutlinedButton.icon(
                  onPressed: _pickImage,
                  icon: const Icon(Icons.image),
                  label: const Text('添加图片'),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _contentCtrl.dispose();
    super.dispose();
  }
}
