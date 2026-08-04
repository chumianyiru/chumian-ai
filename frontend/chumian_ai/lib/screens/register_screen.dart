import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';

import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../widgets/gradient_scaffold.dart';
import 'home_screen.dart';
import 'oobe_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _emailCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  final _inviteCodeCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _nicknameCtrl = TextEditingController();
  bool _loading = false;
  bool _sendingCode = false;
  int _countdown = 0;
  bool _obscure = true;

  Future<void> _sendCode() async {
    final email = _emailCtrl.text.trim();
    if (!email.endsWith('@qq.com')) {
      Fluttertoast.showToast(msg: '仅支持 QQ 邮箱');
      return;
    }
    setState(() => _sendingCode = true);
    try {
      await AuthService().sendCode(email);
      if (!mounted) return;
      Fluttertoast.showToast(msg: '验证码已发送');
      setState(() => _countdown = 60);
      _startCountdown();
    } catch (e) {
      if (!mounted) return;
      Fluttertoast.showToast(msg: e.toString());
    } finally {
      if (mounted) setState(() => _sendingCode = false);
    }
  }

  void _startCountdown() {
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return false;
      setState(() => _countdown--);
      return _countdown > 0;
    });
  }

  Future<void> _register() async {
    final email = _emailCtrl.text.trim();
    final code = _codeCtrl.text.trim();
    final inviteCode = _inviteCodeCtrl.text.trim();
    final password = _passwordCtrl.text;
    final nickname = _nicknameCtrl.text.trim();

    if (!email.endsWith('@qq.com')) {
      Fluttertoast.showToast(msg: '仅支持 QQ 邮箱');
      return;
    }
    if (code.length != 6) {
      Fluttertoast.showToast(msg: '请输入 6 位验证码');
      return;
    }
    if (inviteCode.isEmpty) {
      Fluttertoast.showToast(msg: '请输入邀请码');
      return;
    }
    if (password.length < 6) {
      Fluttertoast.showToast(msg: '密码不能少于 6 位');
      return;
    }
    if (nickname.isEmpty) {
      Fluttertoast.showToast(msg: '请输入昵称');
      return;
    }

    setState(() => _loading = true);
    try {
      final user = await AuthService().register(
        email: email,
        code: code,
        inviteCode: inviteCode,
        password: password,
        nickname: nickname,
      );
      if (!mounted) return;
      if (user.oobeCompleted) {
        _goTo(const HomeScreen());
      } else {
        _goTo(const OobeScreen());
      }
    } catch (e) {
      if (!mounted) return;
      Fluttertoast.showToast(msg: e.toString());
      setState(() => _loading = false);
    }
  }

  void _goTo(Widget screen) {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => screen),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return GradientScaffold(
      appBar: AppBar(title: const Text('注册账号')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
          child: Column(
            children: [
              const SizedBox(height: 12),
              TextField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  hintText: 'QQ 邮箱',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _codeCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  hintText: '验证码',
                  prefixIcon: const Icon(Icons.verified_outlined),
                  suffixIcon: TextButton(
                    onPressed: (_countdown > 0 || _sendingCode)
                        ? null
                        : _sendCode,
                    child: Text(_countdown > 0
                        ? '$_countdown s'
                        : (_sendingCode ? '发送中' : '获取验证码')),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _inviteCodeCtrl,
                decoration: const InputDecoration(
                  hintText: '邀请码',
                  prefixIcon: Icon(Icons.card_membership_outlined),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordCtrl,
                obscureText: _obscure,
                decoration: InputDecoration(
                  hintText: '密码',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    onPressed: () => setState(() => _obscure = !_obscure),
                    icon: Icon(
                      _obscure ? Icons.visibility_off : Icons.visibility,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _nicknameCtrl,
                decoration: const InputDecoration(
                  hintText: '昵称',
                  prefixIcon: Icon(Icons.person_outline),
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _loading ? null : _register,
                  child: _loading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.onPrimary,
                          ),
                        )
                      : const Text('注册'),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    '已有账号？',
                    style: TextStyle(color: AppColors.onSurfaceVariant),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('去登录'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _codeCtrl.dispose();
    _inviteCodeCtrl.dispose();
    _passwordCtrl.dispose();
    _nicknameCtrl.dispose();
    super.dispose();
  }
}
