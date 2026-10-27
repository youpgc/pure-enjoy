# 宠物主页场景主题 · 生成提示词与上架台账

七款付费主题 + 默认场景重roll的 ImageGen 提示词（中英双语）、评审结论与上架接线清单。
通用约束源自 App 主页布局：宠物形象渲染在画面 60~70% 高度处，底部约 22% 被沉底状态卡覆盖，顶部约 15% 被返回键/金币胶囊/横幅占据。

## 通用骨架（每条提示词 = 骨架 + 主题段，以下各块已拼装完整，可直接整段复制）

- 吉卜力式柔光绘本插画风，手绘质感，色彩通透，柔光晕染
- 竖版构图 2:3（生成 1024×1536）
- 画面中下 1/3 中央区域干净平坦（卡通宠物的站立展示区，无大型物件遮挡）
- 画面顶部 1/6 为天空留白（UI 横幅区，无重要元素）
- 画面正中央无大型吸睛主体（视觉焦点分布在两侧/远景）
- 无人物、无动物、无文字、无 logo
- 底部 12% 为弃区（水印裁剪带，内容简单即可，一刀切裁掉）

## 默认场景重roll（scene_dream · 梦幻夜空）

首版默认图为旧工具生成（右下角残留「AI生成/WORKBUDDY」水印），已按七主题同款骨架重roll并替换（20261027 过审落位）：紫色月夜 + 湖面倒影 + 暖光宠物小屋（与星夜守望的开阔草原深蓝调、秘境萤光的森林紫区分）。

```text
吉卜力式柔光绘本插画，竖版2:3，梦幻月夜：深紫色星空点缀繁星与一弯明月，柔云轻绕，远处紫色群山剪影，山脚下平静的湖面倒映月光，湖畔草地上有一座圆润可爱的小屋，窗户透出暖黄灯光，一条石板小径从屋前蜿蜒伸向画面中下前景。强调：手绘绘本质感、柔光晕染、色彩通透、明月与窗光的柔和光晕。中下三分之一中央是平坦干净的草地与小径，无大型物件；小屋置于中右侧中景，不遮挡中央；顶部六分之一是星空与明月（装饰性背景）；正中央无吸睛主体。无人物、无动物、无文字、无水印字样。紫蓝色低饱和梦幻调，宁静治愈氛围。
```

英文版（与上等价，生成工具偏好英文时用）：

```text
Ghibli-style soft-lit storybook illustration, portrait 2:3, dreamy moonlit night: a deep purple starry sky scattered with stars and a crescent moon, soft clouds drifting, silhouettes of purple mountains in the distance, a calm lake at their foot reflecting the moonlight, on the lakeside meadow a small rounded cozy cottage with warm yellow light glowing from its windows, a stone path winding from the cottage toward the lower-center foreground. Emphasize: hand-painted picture-book texture, soft glowing light, luminous transparent colors, gentle halos around the moon and windows. The center of the lower third is a clean flat grassy path with no large objects; the cottage sits in the mid-ground to the mid-right, not blocking the center; the top sixth is starry sky with the moon (decorative background); no eye-catching focal subject in the exact center. No people, no animals, no text, no watermark. Low-saturation purple-blue dreamy palette, serene and healing atmosphere.
```

过审后处理（已执行）：裁水印（底部 12%）→ 以 scene_dream.png 同名替换 App `assets/pets/scenes/` 与后台 `public/pet-scenes/` 两处——路径/编码/默认标记全部不变，无需 SQL。

## 七主题提示词

### 1. 晨曦草原（scene_meadow · 基础档 10000）

```text
吉卜力式柔光绘本插画，竖版2:3，清晨的山间草地小径：金色晨光斜照，薄雾笼罩远山，一条土路蜿蜒向远方，木栅栏沿路延伸，野花点缀草甸，空气感光晕，治愈宁静氛围。中下三分之一中央是平坦干净的草地小径，无大型物件；顶部六分之一是柔和的天空与云霞；正中央无吸睛主体，栅栏与远山分置两侧远景。无人物、无动物、无文字、无水印字样。手绘质感，色彩通透，柔光晕染。
```

英文版：

```text
Ghibli-style soft-lit storybook illustration, portrait 2:3, a grassy mountain path in the early morning: golden dawn light slanting in, thin mist over distant hills, a dirt path winding toward the horizon, a wooden fence running alongside, wildflowers scattered across the meadow, airy light halos, serene healing atmosphere. The center of the lower third is a clean flat grassy path with no large objects; the top sixth is soft sky with glowing clouds; no eye-catching focal subject in the exact center — fence and mountains sit in the distance to both sides. No people, no animals, no text, no watermark. Hand-painted texture, luminous transparent colors, soft glowing light.
```

评审结论：已生成入库。站立区干净、顶部天空安全，风格吉卜力偏油画质感，协调度中上。

### 2. 樱花庭院（scene_sakura · 基础档 10000）

```text
吉卜力式柔光绘本插画，竖版2:3，春日日式庭院：樱花树满开，粉色花瓣飘落，木质拱桥横跨清澈溪流，石灯笼与木屋檐廊点缀，柔焦虚化的樱花枝从画幅一角伸入。中下三分之一中央是平坦的泥土小径与草地，无大型物件；顶部六分之一是柔和天空；正中央无吸睛主体，樱花树与石灯笼分置左右。无人物、无动物、无文字、无水印字样。日式水彩清新风格，色彩通透，柔光晕染，治愈氛围。
```

英文版：

```text
Ghibli-style soft-lit storybook illustration, portrait 2:3, a Japanese courtyard in spring: cherry trees in full bloom with pink petals drifting down, a wooden arch bridge across a clear stream, stone lanterns and wooden-house eaves as accents, softly blurred sakura branches reaching in from one corner of the frame. The center of the lower third is a flat dirt path and grass with no large objects; the top sixth is soft sky; no eye-catching focal subject in the exact center — sakura tree and stone lanterns sit to the left and right. No people, no animals, no text, no watermark. Fresh Japanese watercolor style, luminous colors, soft glowing light, healing atmosphere.
```

评审结论：已生成入库。日式水彩清新风，与默认主题（梦幻夜空）协调度上乘。

### 3. 雪原暖屋（scene_snow · 基础档 10000）

```text
吉卜力式柔光绘本插画，竖版2:3，黄昏雪原中的温暖小木屋：雪覆盖的木屋窗户透出暖黄灯光，烟囱升起袅袅炊烟，远处雪山与雪松林，细雪飘落的黄昏天色。中下三分之一中央是平坦开阔的雪地，无大型物件；顶部六分之一是蓝灰渐变的黄昏天空；正中央无吸睛主体，木屋置于中右侧远景。无人物、无动物、无文字、无水印字样。手绘质感，冷暖对比柔和（暖光与蓝雪），治愈氛围。
```

英文版：

```text
Ghibli-style soft-lit storybook illustration, portrait 2:3, a warm wooden cabin in a snowy field at dusk: a snow-covered cabin with warm yellow light glowing in its windows, gentle smoke rising from the chimney, distant snow mountains and pine forest, light snowfall under a dusk sky. The center of the lower third is a flat open snowfield with no large objects; the top sixth is a blue-gray dusk sky gradient; no eye-catching focal subject in the exact center — the cabin sits in the distance to the mid-right. No people, no animals, no text, no watermark. Hand-painted texture, gentle warm-cool contrast (warm light against blue snow), healing atmosphere.
```

评审结论：已生成入库。雪地站立区平坦、顶部纯天空，构图满分；风格偏写实插画，与绘本系略有色差但雪景低饱和观感可接受。

### 4. 椰风海滩（scene_beach · 基础档 10000）

首轮生成构图合格但风格判定为写实厚涂（材质细节强、无手绘轮廓、光影写实），与全家福差异最大，重roll。以下为过审定版提示词（强化绘本风修订版）：

```text
吉卜力式柔光卡通绘本插画，竖版2:3，热带海滩：卡通化的椰子树两三棵，平缓的金色沙滩，碧蓝浅海与白色浪花线，遮阳伞与沙滩椅简笔化处理远景点缀，白云朵朵。强调：手绘轮廓线感、平面化的色彩层次、弱化材质细节（不追求照片级沙粒与树皮质感）、空气感光晕、整体像儿童绘本内页。中下三分之一中央是平坦干净的沙滩，无大型物件；顶部六分之一是蓝天白云；正中央无吸睛主体，椰树与遮阳伞分置两侧远景。无人物、无动物、无文字、无水印字样。色彩明快通透，治愈氛围。
```

英文版：

```text
Ghibli-style soft cartoon storybook illustration, portrait 2:3, a tropical beach: two or three cartoon palm trees, a gentle golden sandy shore, turquoise shallow water with a line of white foam, a simply-drawn parasol and beach chair as distant accents, fluffy white clouds. Emphasize: hand-drawn outlines, flat layered colors, minimized material detail (no photo-realistic sand grains or bark texture), airy light halos, like a page from a children's picture book. The center of the lower third is a clean flat beach with no large objects; the top sixth is blue sky with white clouds; no eye-catching focal subject in the exact center — palms and parasol sit in the distance to both sides. No people, no animals, no text, no watermark. Bright luminous colors, healing atmosphere.
```

评审结论：重roll过审入库。水彩绘本风（手绘纸纹、柔和对色）与全家福协调；站立区干净、伞椅分居右侧、贝壳点缀左下角。

### 5. 星夜守望（scene_starry · 高级档 18000）

```text
吉卜力式柔光绘本插画，竖版2:3，夜晚山谷草原：璀璨星空与银河横贯天幕，一弯新月挂于上方一角，远处群山剪影，开阔草地与零星萤火虫光点。中下三分之一中央是平缓干净的草地，无大型物件；顶部六分之一是深蓝夜空（银河新月为背景装饰）；正中央无吸睛主体，山峦分置两侧远景。无人物、无动物、无文字、无水印字样。深蓝紫色低饱和调，星光柔晕，宁静治愈氛围。
```

英文版：

```text
Ghibli-style soft-lit storybook illustration, portrait 2:3, a valley meadow at night: a brilliant starry sky with the Milky Way stretching across the heavens, a crescent moon hanging at one upper corner, silhouettes of distant mountains, an open meadow with scattered firefly glows. The center of the lower third is smooth clean grass with no large objects; the top sixth is deep-blue night sky (Milky Way and moon as decorative background); no eye-catching focal subject in the exact center, mountains in the distance to both sides. No people, no animals, no text, no watermark. Low-saturation deep blue-purple palette, soft starlight glow, calm healing atmosphere.
```

评审结论：已生成入库。中央空旷利于宠物展示，夜景低饱和与默认主题夜色调性呼应。

### 6. 秘境萤光（scene_glow · 高级档 18000）

```text
吉卜力式柔光绘本插画，竖版2:3，夜晚魔法森林：发光的蘑菇群散发柔光，古老石拱桥与溪流，萤火虫光点漂浮，远处石塔遗迹隐现，紫色调梦幻氛围。中下三分之一中央是干净的泥土小径向远处延伸，两侧蘑菇花草保持距离不遮挡路径；顶部六分之一是夜空与树冠剪影；正中央无吸睛主体，蘑菇群与遗迹分置两侧。无人物、无动物、无文字、无水印字样。发光体的柔光晕染，色彩通透，神秘而治愈。
```

英文版：

```text
Ghibli-style soft-lit storybook illustration, portrait 2:3, a magic forest at night: clusters of glowing mushrooms emitting soft light, an ancient stone arch bridge over a stream, drifting firefly glows, ruins of a stone tower faintly visible in the distance, a dreamy purple atmosphere. The center of the lower third is a clean dirt path receding into the distance, with mushrooms and flowers on both sides kept away from the path; the top sixth is night sky with tree-canopy silhouettes; no eye-catching focal subject in the exact center — mushroom clusters and ruins sit to the sides. No people, no animals, no text, no watermark. Soft glow halos around light sources, luminous transparent colors, mysterious yet healing.
```

评审结论：已生成入库（站位区备注：两侧蘑菇略贴近路径，宠物渲染尺寸适中即可）。梦幻紫调与默认主题同调性。

### 7. 云上浮岛（scene_isle · 高级档 18000 · 招牌款）

```text
吉卜力式柔光绘本插画，竖版2:3，漂浮在云海之上的浮空岛：草顶小岛悬浮于夕阳云海中，岛上一棵大树挂着木质秋千，远处还有几座小浮岛，云层柔软层叠。中下三分之一中央是岛面平坦草地；顶部六分之一是柔和的天空与云；正中央无吸睛主体，大树与秋千置于右侧。无人物、无动物、无文字、无水印字样。日系绘本质感，柔光晕染，梦幻治愈氛围。
```

英文版：

```text
Ghibli-style soft-lit storybook illustration, portrait 2:3, a floating island above a sea of clouds: a grass-topped island hovering amid sunset clouds, a large tree on the island with a wooden swing hanging from it, a few smaller floating islands in the distance, soft layered clouds. The center of the lower third is the flat grassy island top; the top sixth is soft sky and clouds; no eye-catching focal subject in the exact center — the tree and swing sit to the right. No people, no animals, no text, no watermark. Japanese picture-book texture, soft glowing light, dreamy healing atmosphere.
```

评审结论：已生成入库。与默认主题风格协调度最高（日系吉卜力式）。

## 评审标准（生成后逐项过）

1. 中下 1/3 中央干净平坦（宠物站立区）
2. 顶部 15% 只有天空（UI 横幅区）
3. 画面中央无吸睛主体
4. 底部 12% 弃区质量忽略（裁掉）
5. 无人物/动物/文字；水印只在右下角（裁剪带内）
6. 风格统一（柔光绘本系，忌写实厚涂）
7. 竖版

## 水印裁剪

生成图右下角有水印，按底部 12% 一刀切（输出 1024×1352，恰为主页状态卡弃区）：

```bash
python tool/trim_watermark.py <图片目录> --bottom 12
# 输出至 <目录>/trimmed/，PNG 格式不覆盖原图
```

## 上架接线清单

| scene_code | 名称 | 档位 | 资产 | SQL |
|---|---|---|---|---|
| scene_dream | 梦幻夜空 | 默认 | scene_dream.png（重roll版已替换双端 20261027） | 无需 |
| scene_meadow | 晨曦草甸 | 基础 10000 | scene_meadow.png（资产化替换程序化） | asset_ref 更新 |
| scene_sakura | 樱花庭院 | 基础 10000 | scene_sakura.png | 新增行+镜像道具 |
| scene_snow | 雪原暖屋 | 基础 10000 | scene_snow.png | 新增行+镜像道具 |
| scene_beach | 椰风海滩 | 基础 10000 | scene_beach.png | 新增行+镜像道具 |
| scene_starry | 星海之栏 | 高级 18000 | scene_starry.png（资产化替换程序化） | asset_ref 更新 |
| scene_glow | 秘境萤光 | 高级 18000 | scene_glow.png | 新增行+镜像道具 |
| scene_isle | 云上浮岛 | 高级 18000 | scene_isle.png | 新增行+镜像道具 |

App 侧：`PetSceneBackground` 按 scene_code 分派资产（文件名 = scene_code.png），新增主题 = 落图入包 + 服务端上架 + `assetScenes` 集合补码。SQL：`sql/pet/feature_pet_scene_assets_20261027.sql`（已执行归档 20261027）。

管理后台：预览图取 `public/pet-scenes/<scene_code>.png`（与 App 同名同步，已落位八张）；场景列表新增「预览」动作——手机构图相框 + 布局参考线（顶部 UI 区/宠物站位/状态卡区）+ 左右切换浏览全主题。

遗留清理：20260916 首版默认行「月夜云端庭院」（scene_moonlit_garden，资产从未产出，20261009 起下架非默认）——`sql/pet/fix_pet_scene_moonlit_cleanup_20261027.sql` 已执行归档（20261027，守卫通过后删行，目录八行齐整）。
