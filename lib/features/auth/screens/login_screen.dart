import 'dart:async';
import 'package:flutter/material.dart';
import '../../../services/supabase_service.dart';
import '../../home/screens/home_screen.dart';

/// 登录方式枚举
enum LoginMethod {
  usernamePassword,
  phonePassword,
  phoneCode,
}

/// 登录页面
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _formKey = GlobalKey<FormState>();

  // 用户名+密码
  final _usernameController = TextEditingController();
  final _passwordController1 = TextEditingController();

  // 手机号+密码
  final _phoneController1 = TextEditingController();
  final _passwordController2 = TextEditingController();

  // 手机号+验证码
  final _phoneController2 = TextEditingController();
  final _smsCodeController = TextEditingController();

  // 注册字段
  final _regUsernameController = TextEditingController();
  final _regEmailController = TextEditingController();
  final _regPhoneController = TextEditingController();
  final _regPasswordController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword1 = true;
  bool _obscurePassword2 = true;
  bool _obscureRegPassword = true;
  bool _isRegister = false;

  // 验证码倒计时
  int _countdown = 0;
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _usernameController.dispose();
    _passwordController1.dispose();
    _phoneController1.dispose();
    _passwordController2.dispose();
    _phoneController2.dispose();
    _smsCodeController.dispose();
    _regUsernameController.dispose();
    _regEmailController.dispose();
    _regPhoneController.dispose();
    _regPasswordController.dispose();
    _countdownTimer?.cancel();
    super.dispose();
  }

  /// 开始倒计时
  void _startCountdown() {
    setState(() => _countdown = 60);
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _countdown--;
        if (_countdown <= 0) {
          timer.cancel();
        }
      });
    });
  }

  /// 发送验证码
  Future<void> _sendSmsCode() async {
    final phone = _phoneController2.text.trim();
    if (phone.isEmpty || phone.length != 11) {
      _showSnackBar('请输入正确的11位手机号');
      return;
    }
    if (_countdown > 0) return;

    setState(() => _isLoading = true);
    try {
      final success = await SupabaseService.instance.sendSmsCode(phone);
      if (success && mounted) {
        _showSnackBar('验证码已发送', isSuccess: true);
        _startCountdown();
      } else if (mounted) {
        _showSnackBar('验证码发送失败，请重试');
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('发送验证码出错: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// 登录提交
  Future<void> _submitLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final supabaseService = SupabaseService.instance;
      bool success = false;

      switch (_tabController.index) {
        case 0: // 用户名+密码
          success = await supabaseService.signInWithUsername(
            _usernameController.text.trim(),
            _passwordController1.text,
          );
          break;
        case 1: // 手机号+密码
          success = await supabaseService.signInWithPhone(
            _phoneController1.text.trim(),
            _passwordController2.text,
          );
          break;
        case 2: // 手机号+验证码
          success = await supabaseService.signInWithPhoneCode(
            _phoneController2.text.trim(),
            _smsCodeController.text.trim(),
          );
          break;
      }

      if (success && mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      } else if (mounted) {
        _showSnackBar('登录失败，请检查用户名和密码');
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
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final supabaseService = SupabaseService.instance;
      final success = await supabaseService.signUp(
        username: _regUsernameController.text.trim(),
        password: _regPasswordController.text,
        email: _regEmailController.text.trim().isNotEmpty
            ? _regEmailController.text.trim()
            : null,
        phone: _regPhoneController.text.trim().isNotEmpty
            ? _regPhoneController.text.trim()
            : null,
      );

      if (success && mounted) {
        _showSnackBar('注册成功！请登录', isSuccess: true);
        setState(() => _isRegister = false);
      } else if (mounted) {
        _showSnackBar('注册失败，请检查网络或稍后重试');
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
                      // 登录方式 Tab 切换
                      Container(
                        margin: const EdgeInsets.only(bottom: 24),
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerHighest.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: TabBar(
                          controller: _tabController,
                          indicator: BoxDecoration(
                            color: colorScheme.primary,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          indicatorSize: TabBarIndicatorSize.tab,
                          dividerColor: Colors.transparent,
                          labelColor: colorScheme.onPrimary,
                          unselectedLabelColor: colorScheme.onSurfaceVariant,
                          labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                          unselectedLabelStyle: const TextStyle(fontSize: 13),
                          tabs: const [
                            Tab(text: '用户名登录'),
                            Tab(text: '手机号登录'),
                            Tab(text: '验证码登录'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Tab 内容
                      SizedBox(
                        height: 280,
                        child: TabBarView(
                          controller: _tabController,
                          children: [
                            // 用户名+密码
                            _buildUsernamePasswordForm(colorScheme),
                            // 手机号+密码
                            _buildPhonePasswordForm(colorScheme),
                            // 手机号+验证码
                            _buildPhoneCodeForm(colorScheme),
                          ],
                        ),
                      ),

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

  /// 用户名+密码表单
  Widget _buildUsernamePasswordForm(ColorScheme colorScheme) {
    return Column(
      children: [
        TextFormField(
          controller: _usernameController,
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(
            labelText: '用户名',
            hintText: '请输入用户名',
            prefixIcon: Icon(Icons.person_outline),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return '请输入用户名';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _passwordController1,
          obscureText: _obscurePassword1,
          textInputAction: TextInputAction.done,
          onFieldSubmitted: (_) => _submitLogin(),
          decoration: InputDecoration(
            labelText: '密码',
            hintText: '请输入密码',
            prefixIcon: const Icon(Icons.lock_outlined),
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword1 ? Icons.visibility_outlined : Icons.visibility_off_outlined,
              ),
              onPressed: () {
                setState(() => _obscurePassword1 = !_obscurePassword1);
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

  /// 手机号+密码表单
  Widget _buildPhonePasswordForm(ColorScheme colorScheme) {
    return Column(
      children: [
        TextFormField(
          controller: _phoneController1,
          keyboardType: TextInputType.phone,
          maxLength: 11,
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(
            labelText: '手机号',
            hintText: '请输入11位手机号',
            prefixIcon: Icon(Icons.phone_outlined),
            counterText: '',
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return '请输入手机号';
            }
            if (!RegExp(r'^1[3-9]\d{9}$').hasMatch(value)) {
              return '请输入正确的11位手机号';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _passwordController2,
          obscureText: _obscurePassword2,
          textInputAction: TextInputAction.done,
          onFieldSubmitted: (_) => _submitLogin(),
          decoration: InputDecoration(
            labelText: '密码',
            hintText: '请输入密码',
            prefixIcon: const Icon(Icons.lock_outlined),
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword2 ? Icons.visibility_outlined : Icons.visibility_off_outlined,
              ),
              onPressed: () {
                setState(() => _obscurePassword2 = !_obscurePassword2);
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

  /// 手机号+验证码表单
  Widget _buildPhoneCodeForm(ColorScheme colorScheme) {
    return Column(
      children: [
        TextFormField(
          controller: _phoneController2,
          keyboardType: TextInputType.phone,
          maxLength: 11,
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(
            labelText: '手机号',
            hintText: '请输入11位手机号',
            prefixIcon: Icon(Icons.phone_outlined),
            counterText: '',
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return '请输入手机号';
            }
            if (!RegExp(r'^1[3-9]\d{9}$').hasMatch(value)) {
              return '请输入正确的11位手机号';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _smsCodeController,
          keyboardType: TextInputType.number,
          maxLength: 6,
          textInputAction: TextInputAction.done,
          onFieldSubmitted: (_) => _submitLogin(),
          decoration: InputDecoration(
            labelText: '验证码',
            hintText: '请输入验证码',
            prefixIcon: const Icon(Icons.message_outlined),
            counterText: '',
            suffixIcon: SizedBox(
              width: 100,
              child: TextButton(
                onPressed: _countdown > 0 ? null : (_isLoading ? null : _sendSmsCode),
                child: Text(
                  _countdown > 0 ? '${_countdown}s' : '获取验证码',
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            ),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return '请输入验证码';
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
            controller: _regUsernameController,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: '用户名',
              hintText: '请输入用户名',
              prefixIcon: Icon(Icons.person_outline),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return '请输入用户名';
              }
              if (value.length < 2) {
                return '用户名至少需要2个字符';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _regEmailController,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: '邮箱',
              hintText: '请输入邮箱地址（选填）',
              prefixIcon: Icon(Icons.email_outlined),
            ),
            validator: (value) {
              if (value != null && value.isNotEmpty) {
                if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                  return '请输入有效的邮箱地址';
                }
              }
              return null;
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _regPhoneController,
            keyboardType: TextInputType.phone,
            maxLength: 11,
            textInputAction: TextInputAction.next,
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
          const SizedBox(height: 12),
          TextFormField(
            controller: _regPasswordController,
            obscureText: _obscureRegPassword,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _submitRegister(),
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
        ],
      ),
    );
  }
}
