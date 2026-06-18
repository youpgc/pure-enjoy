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

/// 全局 NavigatorKey，用于通知点击跳转
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

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

  // 只同步初始化认证服务（从本地存储恢复会话，无网络请求）
  await AuthService.instance.initialize();

  // 字典服务和通知服务改为后台懒加载，不阻塞启动
  _lazyInitializeServices();

  runApp(const PureEnjoyApp());
}

/// 后台懒加载服务，不阻塞首屏渲染
void _lazyInitializeServices() {
  // 字典服务：改为在首页加载，此处只初始化本地缓存
  DictService.instance.initialize().catchError((e) {
    debugPrint('字典服务本地缓存初始化失败: $e');
  });

  // 通知服务：后台初始化
  NotificationService.instance.initialize().catchError((e) {
    debugPrint('通知服务后台初始化失败: $e');
  });
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
            navigatorKey: navigatorKey,
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
    // 检查是否已登录（AuthService.initialize() 已在 main() 中完成）
    if (AuthService.instance.isAuthenticated) {
      return const HomeScreen();
    }
    return const LoginScreen();
  }
}
