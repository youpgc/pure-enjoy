# Flutter ProGuard Rules
# 保留 Flutter 引擎相关类
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# 保留 Dart 侧调用的 Java 类
-keep class com.pureenjoy.app.** { *; }

# 保留 JSON 序列化相关类（Gson/Moshi等）
-keepattributes Signature
-keepattributes *Annotation*
-keepattributes EnclosingMethod
-keepattributes InnerClasses

# 保留网络请求相关类
-keep class com.google.gson.** { *; }
-keep class retrofit2.** { *; }
-keep class okhttp3.** { *; }
-keep class okio.** { *; }

# 保留 Supabase 相关类
-keep class io.github.jan.supabase.** { *; }

# 保留共享偏好设置
-keep class android.content.SharedPreferences { *; }

# 保留 WebView 相关
-keep class android.webkit.** { *; }

# 保留本地通知相关
-keep class com.dexterous.flutterlocalnotifications.** { *; }

# 保留图片加载相关
-keep class com.bumptech.glide.** { *; }
-keep class coil.** { *; }

# 保留 UUID 生成
-keep class java.util.UUID { *; }

# 保留 Kotlin 协程
-keepnames class kotlinx.coroutines.internal.MainDispatcherFactory {}
-keepnames class kotlinx.coroutines.CoroutineExceptionHandler {}
-keepnames class kotlinx.coroutines.android.AndroidExceptionPreHandler {}
-keepnames class kotlinx.coroutines.android.AndroidDispatcherFactory {}

# 保留反射使用的类
-keepclassmembers class * {
    @com.google.gson.annotations.SerializedName <fields>;
}

# 忽略 Play Core 缺失类（R8）
-dontwarn com.google.android.play.core.splitcompat.SplitCompatApplication
-dontwarn com.google.android.play.core.tasks.OnFailureListener
-dontwarn com.google.android.play.core.tasks.OnSuccessListener
-dontwarn com.google.android.play.core.tasks.Task
-dontwarn com.google.android.play.core.splitinstall.**
-dontwarn com.google.android.play.core.**
