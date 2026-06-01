import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_provider.dart';
import 'features/home/screens/home_screen.dart';
import 'features/auth/screens/login_screen.dart';
import 'services/supabase_service.dart';
import 'services/dict_service.dart';
import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 设置状态栏样式
  if (Platform.isAndroid) {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
    ));
  }

  // 初始化认证服务（从本地存储恢复会话）
  await AuthService.instance.initialize();

  // 初始化字典服务（预加载字典数据）
  await DictService.instance.initialize();

  // 初始化通知服务
  await NotificationService.instance.initialize();

  runApp(const PureEnjoyApp());
}

class PureEnjoyApp extends StatelessWidget {
  const PureEnjoyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ThemeProvider(),
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return MaterialApp(
            title: '纯享',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme(themeProvider.colorScheme.seedColor),
            darkTheme: AppTheme.darkTheme(themeProvider.colorScheme.seedColor),
            themeMode: themeProvider.themeMode,
            home: const AuthWrapper(),
            // 中文本地化配置
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [
              Locale('zh', 'CN'), // 简体中文
            ],
            locale: const Locale('zh', 'CN'),
          );
        },
      ),
    );
  }
}

/// 认证状态包装器
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    // 检查是否已登录
    if (AuthService.instance.isAuthenticated) {
      return const HomeScreen();
    }
    return const LoginScreen();
  }
}
