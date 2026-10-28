# 宠物种属骨架屏占位图 · 生成提示词

四系各属的骨架屏占位图提示词——**纯灰色剪影**，用于图鉴/无资源场景的默认占位资源。
要求只有轮廓特征正确（一眼可辨猫/犬/兔/鼠），单色灰、无五官细节。

## 剪影特征锚（各系唯一辨识点）

- 猫：圆润头 + 尖耳 + 细长卷尾
- 犬：直立三角耳 + 吻部凸起 + 短尾上翘
- 兔：超长直立耳 + 椭圆坐姿 + 小绒球尾
- 鼠：圆滚梨形身 + 头顶小圆耳 + 身后小短尾

## ① 猫系（cat）

```text
极简扁平风格，纯浅灰色单色卡通宠物剪影：一只小猫的坐姿轮廓，正面稍侧视角，圆润头型、尖尖双耳、细长尾巴轻卷身侧，剪影内无五官、无细节、无渐变。纯白背景，居中全身，边缘平滑，无文字无水印。
```

```text
Minimalist flat style, solid light gray cartoon cat silhouette: sitting kitten outline, three-quarter front view, round head, pointed ears, slender tail curled beside the body, no facial features, no details, no gradients. Pure white background, full body centered, smooth edges, no text, no watermark.
```

## ② 犬系（dog）

```text
极简扁平风格，纯浅灰色单色卡通宠物剪影：一只小狗的坐姿轮廓，正面稍侧视角，头顶直立三角耳、明显的吻部凸起、短尾上翘、前胸微宽，剪影内无五官、无细节、无渐变。纯白背景，居中全身，边缘平滑，无文字无水印。
```

```text
Minimalist flat style, solid light gray cartoon dog silhouette: sitting puppy outline, three-quarter front view, upright triangular ears, visible muzzle protrusion, short perky tail, slightly broad chest, no facial features, no details, no gradients. Pure white background, full body centered, smooth edges, no text, no watermark.
```

## ③ 兔系（rabbit）

```text
极简扁平风格，纯浅灰色单色卡通宠物剪影：一只小兔的坐姿轮廓，正面稍侧视角，两只超长直立耳朵、紧凑椭圆身形、身后小绒球尾巴，剪影内无五官、无细节、无渐变。纯白背景，居中全身，边缘平滑，无文字无水印。
```

```text
Minimalist flat style, solid light gray cartoon rabbit silhouette: sitting bunny outline, three-quarter front view, two extra-long upright ears, compact oval body, tiny pom-pom tail behind, no facial features, no details, no gradients. Pure white background, full body centered, smooth edges, no text, no watermark.
```

## ④ 鼠系（mouse）

```text
极简扁平风格，纯浅灰色单色卡通宠物剪影：一只小仓鼠的坐姿轮廓，正面稍侧视角，圆滚梨形身材，头顶小圆耳，两颊饱满，身形低矮，身后有一个小短尾，剪影内无五官、无细节、无渐变。纯白背景，居中全身，边缘平滑，无文字无水印。
```

```text
Minimalist flat style, solid light gray cartoon hamster silhouette: sitting hamster outline, three-quarter front view, round chubby pear-shaped body, small round ears on top, full cheeks, low body with a short stubby tail, no facial features, no details, no gradients. Pure white background, full body centered, smooth edges, no text, no watermark.
```

## 过审后接线（待做）

1. 抠白底（或直接用白底方形图）→ `assets/pets/placeholders/<family>.png`（cat/dog/rabbit/mouse）
2. 回退链接点：`pet_dex_screen.dart` 的 `_dexPetArt`（现回退 `Icons.cruelty_free_outlined` 图标）与 `pet_art_resolver` 无素材分支 → 按 family 取占位图
3. 后台预览可复用（public/pet-art/ 旁落 placeholder）
