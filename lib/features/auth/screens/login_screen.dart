import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../home/screens/home_screen.dart';
import '../auth_provider.dart';
/// 登录页面
/// 统一账号（用户名/昵称/邮箱/手机号）+ 密码
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});
  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}
class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  // 登录字段
  final _accountController = TextEditingController();
  final _passwordController = TextEditingController();
  // 注册字段
  final _regEmailController = TextEditingController();
  final _regPasswordController = TextEditingController();
  final _regUsernameController = TextEditingController();
  final _regPhoneController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureRegPassword = true;
  bool _isRegister = false;
  @override
  void dispose() {
    _accountController.dispose();
    _passwordController.dispose();
    _regEmailController.dispose();
    _regPasswordController.dispose();
    _regUsernameController.dispose();
    _regPhoneController.dispose();
    super.dispose();
  }
  /// 登录提交（统一账号）
  Future<void> _submitLogin() async {
    if (_isLoading) return;
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final account = _accountController.text.trim();
      final password = _passwordController.text;
      final success = await ref.read(authProvider.notifier).signInWithAccount(
        account: account,
        password: password,
      );
      if (success && mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      } else if (mounted) {
        final error = ref.read(authProvider).error;
        _showSnackBar(error ?? '登录失败，请检查账号和密码');
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('登录出错: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
  /// 注册提交
  Future<void> _submitRegister() async {
    if (_isLoading) return;
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final success = await ref.read(authProvider.notifier).signUp(
        email: _regEmailController.text.trim(),
        password: _regPasswordController.text,
        username: _regUsernameController.text.trim(),
        phone: _regPhoneController.text.trim().isNotEmpty
            ? _regPhoneController.text.trim()
            : null,
      );
      if (success && mounted) {
        _showSnackBar('注册成功！请登录', isSuccess: true);
        setState(() => _isRegister = false);
      } else if (mounted) {
        final error = ref.read(authProvider).error;
        _showSnackBar(error ?? '注册失败，请检查网络或稍后重试');
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('注册出错: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
  void _showSnackBar(String message, {bool isSuccess = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isSuccess ? AppTheme.success : Theme.of(context).colorScheme.error,
      ),
    );
  }
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Logo 和标题
                    Icon(
                      Icons.auto_awesome,
                      size: 64,
                      color: colorScheme.primary,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '纯享',
                      style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.primary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '记录生活，享受每一天',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    if (!_isRegister) ...[
                      // 登录表单
                      _buildLoginForm(colorScheme),
                      const SizedBox(height: 24),
                      // 登录按钮
                      FilledButton(
                        onPressed: _isLoading ? null : _submitLogin,
                        child: _isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('登录'),
                      ),
                    ] else ...[
                      // 注册表单
                      _buildRegisterForm(colorScheme),
                      const SizedBox(height: 24),
                      // 注册按钮
                      FilledButton(
                        onPressed: _isLoading ? null : _submitRegister,
                        child: _isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('注册'),
                      ),
                    ],
                    const SizedBox(height: 16),
                    // 切换登录/注册
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _isRegister ? '已有账号？' : '没有账号？',
                          style: TextStyle(color: colorScheme.onSurfaceVariant),
                        ),
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _isRegister = !_isRegister;
                              _formKey.currentState?.reset();
                            });
                          },
                          child: Text(_isRegister ? '立即登录' : '立即注册'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
  /// 登录表单（统一账号+密码）
  Widget _buildLoginForm(ColorScheme colorScheme) {
    return Column(
      children: [
        TextFormField(
          controller: _accountController,
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(
            labelText: '账号',
            hintText: '用户名/昵称/邮箱/手机号',
            prefixIcon: Icon(Icons.person_outline),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return '请输入账号';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _passwordController,
          obscureText: _obscurePassword,
          textInputAction: TextInputAction.done,
          onFieldSubmitted: (_) => _submitLogin(),
          decoration: InputDecoration(
            labelText: '密码',
            hintText: '请输入密码',
            prefixIcon: const Icon(Icons.lock_outlined),
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
              ),
              onPressed: () {
                setState(() => _obscurePassword = !_obscurePassword);
              },
            ),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return '请输入密码';
            }
            if (value.length < 6) {
              return '密码至少需要6个字符';
            }
            return null;
          },
        ),
      ],
    );
  }
  /// 注册表单
  Widget _buildRegisterForm(ColorScheme colorScheme) {
    return SingleChildScrollView(
      child: Column(
        children: [
          TextFormField(
            controller: _regEmailController,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: '邮箱',
              hintText: '请输入邮箱地址',
              prefixIcon: Icon(Icons.email_outlined),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return '请输入邮箱';
              }
              if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value)) {
                return '请输入有效的邮箱地址';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _regPasswordController,
            obscureText: _obscureRegPassword,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              labelText: '密码',
              hintText: '请输入密码（至少6位）',
              prefixIcon: const Icon(Icons.lock_outlined),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureRegPassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                ),
                onPressed: () {
                  setState(() => _obscureRegPassword = !_obscureRegPassword);
                },
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return '请输入密码';
              }
              if (value.length < 6) {
                return '密码至少需要6个字符';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _regUsernameController,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: '用户名',
              hintText: '请输入用户名（选填）',
              prefixIcon: Icon(Icons.person_outline),
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _regPhoneController,
            keyboardType: TextInputType.phone,
            maxLength: 11,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _submitRegister(),
            decoration: const InputDecoration(
              labelText: '手机号',
              hintText: '请输入手机号（选填）',
              prefixIcon: Icon(Icons.phone_outlined),
              counterText: '',
            ),
            validator: (value) {
              if (value != null && value.isNotEmpty) {
                if (!RegExp(r'^1[3-9]\d{9}$').hasMatch(value)) {
                  return '请输入正确的11位手机号';
                }
              }
              return null;
            },
          ),
        ],
      ),
    );
  }
}