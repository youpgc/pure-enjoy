#version 320 es
/*
 /// 2D 分层弯曲渲染器：逐片元**逆映射**（片元位置 → 源像素）＋横向线性两抽头
 /// ＋竖向亚像素两抽头。数学与已验收样片同源（沙盒 `pet_anim_demo/cat_gl_warp.mjs`
 /// 的定版档：线性核 + 竖向亚像素），口径来自 `lib/constants/pet_bend.dart`。
 ///
 /// 三条随编排一起冻结的硬约束（改数值要回样片复跑门禁）：
 /// 1. `|θ| ≤ 1°`——转过局部角 a 后整行的竖向采样窗口高 ≈ a×side px，素材额头那条
 ///    横向亮带会被整行捞成一条白线（共振点 1.04°），工作幅度必须留在 1° 以内；
 /// 2. 表情档之间**硬切**，本着色器不做任何帧间混合（AI 帧间 RGB 差异铺满 15~19%，
 ///    混合必全身重影）——换档由 Dart 侧换 `uTex` 承担；
 /// 3. 归零线 `yn` 以下真·不动：两条权重场都在那条线归零（`wR`/`wA` 在 Dart 侧算好
 ///    只传角度，这里按同一公式复算权重）。
 ///
 /// 为什么必须是着色器而不是「整行平移」：canvas 2D/`drawImage` 只能做轴对齐矩形裁切，
 /// 每行横向偏移要么取整到设备像素（⇒ 连续渐变被量化成台阶，即用户判死的「平移缺口」），
 /// 要么整幅交给浏览器双线性（⇒ 读起来是「蒙层」）。这里两轴各自两抽头、由着色器精确
 /// 控制，横移不取整、竖向留亚像素——竖向一旦取整，呼吸会把每一帧的整幅画面推着跳 1px
 /// （即「全身漂移」），所以**两轴都不允许量化**。
 ///
 /// 单位口径：所有像素/角度都在 `side×side` 生产栅格上定义，显示缩放只经 `uRes.x`
 /// （k＝**逻辑**像素/栅格单位——`FlutterFragCoord()` 就是逻辑像素，见 main 的实测口径）
 /// 进入；几何常量不因显示尺寸改变。
*/
#include <flutter/runtime_effect.glsl>

precision highp float;

uniform vec4 uPose; // th(弧度，正=顺时针) A(头部竖向低垂 px，正=向下) py(支点 y) 未用
uniform vec4 uGeo;  // yn(归零线) 1/(yn-headTop) 1/dn(低垂斜坡 px) side(栅格边长)
uniform vec4 uXf;   // sx sy tx ty（栅格单位；tx/ty 已含画布内边距）
uniform vec4 uRes;  // k(逻辑像素/栅格单位) 1/side 未用 未用
uniform sampler2D uTex;

out vec4 frag_color;

/// 整段 smoothstep：样片里权重场与关键帧插值用的同一条曲线
float ss(float u) {
  u = clamp(u, 0.0, 1.0);
  return u * u * (3.0 - 2.0 * u);
}

/// 取整数纹素索引处的像素。越界一律返回透明——样片是靠素材四周 64px 透明垫边做到这一点的
/// （`padOf` 把 384 帧贴进 512 画布再采样），这里不垫图、直接判界，几何常量因此不动。
/// 越界只可能发生在素材四周一圈全透明区，加这道判断不改变整数相位的采样结果（恒等性保住）。
vec4 tap(float i, float j) {
  if (i < 0.0 || j < 0.0 || i >= uGeo.w || j >= uGeo.w) return vec4(0.0);
  // 纹素中心 =（索引 + 0.5）× 纹素宽。v=0 在图像顶部，与 main 里 y 向下的片元坐标同向。
  // （曾按「Skia-GL / Impeller-GLES 上传时翻行」加过 `#ifdef IMPELLER_TARGET_OPENGLES`
  // 分档，装机实测直接否掉：走翻转分支时宠物上下颠倒——耳朵朝下、尾巴朝上。）
  float v = (j + 0.5) * uRes.y;
  return texture(uTex, vec2((i + 0.5) * uRes.y, v));
}

void main() {
  // `FlutterFragCoord()` 实测口径（2026-10-07 装机探针反解，模拟器 Impeller-GLES、dpr=3）：
  // **画布局部、逻辑像素、y 向下**——Impeller 的顶点着色器把 MVP **之前**的几何位置
  // 直接交给片元，所以它既不含 dpr 缩放，也不含画布在屏幕上的位置。
  // 判据：`mod(64)` 回绕间距 192 设备像素 = 64 逻辑像素（dpr=3），且回绕点落在
  // 「画布边缘 + 64 的整数倍」处（画布原点处相位为 0），画布顶边向下绿色递增。
  // 上一轮按「渲染目标设备像素」理解并减掉画布原点，等于把 `u`/`v` 整幅推出界，
  // `tap()` 逐像素判界返回全透明——那才是「宠物不见了」的真因。
  vec2 fc = FlutterFragCoord();
  // 逻辑像素 → 栅格单位、**自上而下**的行列号（像素中心取整数）
  float c = fc.x - 0.5;
  float r = fc.y - 0.5;
  float k = uRes.x;
  // 正向变换是「以脚底中心为原点的缩放＋刚体平移」，这里解它的逆
  float v = (r / k - uXf.w) / uXf.y;
  float u = (c / k - uXf.z) / uXf.x;
  // 旋转权重带：头顶 1 → 归零线 0（整段 smoothstep，头部不能是平台）
  float a = uPose.x * ss((uGeo.x - v - 0.5) * uGeo.y);
  // 低垂权重带：上段平台（整块头连眼睛一起刚性下沉）→ 斜坡收到 0，斜坡有长度下限
  float dv = uPose.y * ss((uGeo.x - v) * uGeo.z);
  // 与样片同一条几何：正向只做 x' = x - a(y - py)、y' = y + dv；
  // 竖向旋转项 a(x - px) 已按样片实测收回（|θ|≲2° 内它只会制造第二批竖向量化误差）。
  // x 不依赖 y，一次代入即精确解。
  float xs = u + a * (v - uPose.z);
  float ys = v - dv;
  // 两轴各两抽头的线性核（凸组合、零振铃）：整数相位时 fx=fy=0，权重塌成单边 1，
  // 逐位等于「不 bend 的普通贴图」，这就是恒等性的落点。
  float bx = floor(xs);
  float by = floor(ys);
  float fx = xs - bx;
  float fy = ys - by;
  vec4 ca = mix(tap(bx, by), tap(bx + 1.0, by), fx);
  vec4 cb = mix(tap(bx, by + 1.0), tap(bx + 1.0, by + 1.0), fx);
  frag_color = mix(ca, cb, fy);
}
