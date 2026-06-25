import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide ChangeNotifierProvider, Consumer;
import 'package:provider/provider.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_provider.dart';
import 'features/home/screens/home_screen.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/auth/auth_provider.dart';
import 'services/supabase_service.dart';
import 'services/dict_service.dart';
import 'services/notification_service.dart';

/// 全局 NavigatorKey，用于通知点击跳转
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 加载环境变量（优先从 --dart-define 读取，其次从 .env 文件加载）
  try {
    await dotenv.load(fileName: '.env');
  } catch (e) {
    // .env 文件不存在时忽略（生产环境使用 --dart-define 注入）
    if (kDebugMode) {
      debugPrint('⚠️ .env 文件未找到，将使用 --dart-define 注入的环境变量');
    }
  }

  // 设置状态栏样式
  if (Platform.isAndroid) {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
    ));
  }

  // 初始化认证服务（包含会话恢复）
  await AuthService.instance.initialize();

  // 字典服务和通知服务改为后台懒加载，不阻塞启动
  _lazyInitializeServices();

  runApp(const ProviderScope(child: PureEnjoyApp()));
}

/// 后台懒加载服务，不阻塞首屏渲染
void _lazyInitializeServices() {
  // 字典服务：改为在首页加载，此处只初始化本地缓存
  DictService.instance.initialize().catchError((e) {
    if (kDebugMode) {
      debugPrint('字典服务本地缓存初始化失败');
    }
  });

  // 通知服务：后台初始化
  NotificationService.instance.initialize().catchError((e) {
    if (kDebugMode) {
      debugPrint('通知服务后台初始化失败');
    }
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
/// 使用 Riverpod 监听认证状态变化
class AuthWrapper extends ConsumerWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);

    // 已登录 -> 首页
    if (authState.isAuthenticated) {
      return const HomeScreen();
    }

    // 未登录 -> 登录页
    return const LoginScreen();
  }
}
