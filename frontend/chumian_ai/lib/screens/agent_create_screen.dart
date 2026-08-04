import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';

import '../services/explore_service.dart';
import '../theme/app_theme.dart';
import '../widgets/gradient_scaffold.dart';

class AgentCreateScreen extends StatefulWidget {
  const AgentCreateScreen({super.key});

  @override
  State<AgentCreateScreen> createState() => _AgentCreateScreenState();
}

class _AgentCreateScreenState extends State<AgentCreateScreen> {
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _systemCtrl = TextEditingController();
  bool _loading = false;

  Future<void> _submit() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      Fluttertoast.showToast(msg: '请输入智能体名称');
      return;
    }

    setState(() => _loading = true);
    try {
      await ExploreService().createAgent(
        name: name,
        description: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
        systemPrompt: _systemCtrl.text.trim().isEmpty ? null : _systemCtrl.text.trim(),
      );
      if (!mounted) return;
      Fluttertoast.showToast(msg: '智能体创建成功');
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      Fluttertoast.showToast(msg: e.toString());
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GradientScaffold(
      appBar: AppBar(title: const Text('制作智能体')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              TextField(
                controller: _nameCtrl,
                decoration: const InputDecoration(
                  hintText: '智能体名称',
                  prefixIcon: Icon(Icons.short_text),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _descCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: '简介（可选）',
                  prefixIcon: Icon(Icons.description_outlined),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _systemCtrl,
                maxLines: 6,
                decoration: const InputDecoration(
                  hintText: '系统提示词（可选）',
                  prefixIcon: Icon(Icons.terminal),
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _loading ? null : _submit,
                  child: _loading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.onPrimary,
                          ),
                        )
                      : const Text('提交'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _systemCtrl.dispose();
    super.dispose();
  }
}
