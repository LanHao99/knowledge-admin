# 人物素材

## MIRA 摄像头头像

- 文件：`mira_camera.png`，1254×1254，带真实透明通道的 PNG。
- 生成时间：2026-10-18。
- 生成方式：OpenAI Codex 内置 imagegen，用户明确要求调用 gptimage 生成。
- 用户要求：二次元人物头像、戴眼镜、长麻花辫、厚夹克。
- 用途：`scenes/desktop/camera.tscn` 的 `Camera.portrait_texture` 默认值。
- CRT 在 Godot 着色器中实时生成，原画不含扫描线、色偏、UI 或文字。

## 最终生成提示词

Use case: stylized-concept. Asset type: transparent PNG character portrait for MIRA, displayed in a square in-game CRT camera window. Primary request: 二次元风格的人物半身头像，戴眼镜，长麻花辫，穿厚夹克。Subject: one adult anime woman, intelligent gentle reserved expression, looking toward the viewer, thin dark round eyeglasses with clear lenses and fully visible eyes, long dark-brown hair in a thick single braided plait draped over one shoulder, wearing a substantial padded winter jacket with a high turned collar over a simple knit layer. Composition: square canvas, centered upper-body bust to mid-torso; all of the head and both shoulders comfortably inside the frame; braid clearly visible over the front of the jacket; a little breathing room above the head; front-facing with a subtle three-quarter turn. Style: polished Japanese anime visual novel character art, clean controlled linework, refined cel shading, readable facial details, natural muted jacket colors, soft neutral lighting. Scene/backdrop: genuine transparent alpha background, isolated character only, crisp clean cutout edges. Constraints: glasses, a visibly long braided plait, and a thick jacket must be unambiguous. No scenery, no text, no UI, no logos or watermark, no CRT effects or scanlines baked into the artwork; these will be added dynamically in Godot.
