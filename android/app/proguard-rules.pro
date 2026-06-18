# Flutter ProGuard Rules - 优化版
# 只保留必要的类，其他允许R8删除

# Flutter 引擎
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# 应用包名
-keep class com.pureenjoy.app.** { *; }

# 保留注解和签名
-keepattributes Signature
-keepattributes *Annotation*
-keepattributes EnclosingMethod
-keepattributes InnerClasses

# 本地通知
-keep class com.dexterous.flutterlocalnotifications.** { *; }

# Kotlin 协程
-keepnames class kotlinx.coroutines.internal.MainDispatcherFactory {}
-keepnames class kotlinx.coroutines.CoroutineExceptionHandler {}

# 忽略 Play Core 缺失类
-dontwarn com.google.android.play.core.**

# 允许删除未使用的类和方法
-dontusemixedcaseclassnames
-dontskipnonpubliclibraryclasses
-dontpreverify
-verbose
-optimizations !code/simplification/arithmetic,!field/*,!class/merging/*
