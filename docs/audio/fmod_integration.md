# FMOD 接入与音效设计建议

核对日期：2026-10-18。适用工程：Knowledge Admin。本文交付接入说明与设计建议，文中的 AudioManager、资源表和自定义事件均为待实现方案。

## 结论与现状

建议沿用当前 Utopia-rise FMOD GDExtension，以统一音频入口连接桌面、闪卡和 AVG。声音方向为“可信的复古操作系统，安静的学习空间，逐渐显露的记忆异常”。

| 核对项 | 当前结果 |
| --- | --- |
| Godot | 项目声明 4.7；本机运行中的引擎路径对应的程序返回 `4.7.2.stable.official.ed1daf0bf`。 |
| 插件 | `addons/fmod/plugin.cfg` 为 6.1.0，插件已列入 `project.godot` 的启用列表。 |
| 原生运行库 | Windows 的 `fmod.dll`、`fmodL.dll`、`fmodstudio.dll`、`fmodstudioL.dll` 均为 2.3.6，即 FMOD 2.03.06。编辑器、Debug、Release 的扩展 DLL 均存在。 |
| 自动加载 | 已注册 `FmodManager`，UID 与插件脚本相符；它负责逐帧更新和系统通知，没有业务音库加载逻辑。 |
| 音库路径 | `Fmod/General/banks_path` 已设为 `res://assets/Banks`；目录存在，递归检查得到 0 个 `.bank`。 |
| 业务播放 | 在 `src`、`scenes`、`game` 中未发现 FMOD 播放调用或原生 AudioStreamPlayer 播放节点。 |
| 设置与导出 | 尚无声音设置；当前导出目标为 Windows Desktop，嵌入 PCK。 |

本地参考工程为 `D:/game design/godot/public-demo/fmod-gdextension-demo`。两工程的 `plugin.cfg`、`FmodManager.gd`、`fmod.gdextension`、Windows 编辑器扩展 DLL 和 `fmod.dll` 的 SHA-256 分别一致。

因此，当前接入重点是构建音库、加载运行时音库和连接业务事件。官方 6.1.0 发布说明对应 Godot 4.5 / FMOD 2.03.06；本地扩展声明最低 Godot 4.5。对本工程的 4.7.2 兼容性仍需实际播放及导出验证。[对应版本发布说明](https://github.com/utopia-rise/fmod-gdextension/releases/tag/6.1.0-4.5.0)

## 插件导入与音库准备

### 新工程的导入流程

1. 从同一插件的发布页下载 `addon.zip`，解压后保持 `res://addons/fmod/plugin.cfg`、`fmod.gdextension` 和 `libs` 的目录关系。使用已经核对过的同套版本。
2. Windows x86_64 同时准备扩展的 editor、template_debug、template_release DLL，以及对应的 FMOD 调试与发布运行库。本工程这些文件已经存在。
3. 打开 Godot，在“项目 → 项目设置 → 插件”中启用 `FMOD GDExtension`；确认只有一个插件提供的 `FmodManager` 自动加载项。原生扩展刚加入工程时重新打开编辑器。

以上目录与启用方式见[插件安装指南](https://fmod-gdextension.readthedocs.io/en/latest/user-guide/1-install/)。本工程已具备这些配置，后续直接检查音库与运行结果。

### 在 FMOD Studio 中制作并构建

1. 首轮使用 FMOD Studio 2.03.06，与已经核对的运行库和插件发布组合一致。
2. 创建本项目自己的 Studio 工程，导入 WAV 素材，建立 `event:/UI/Confirm` 测试事件，并将它分配到 `UI` Bank。
3. 选择 Desktop 构建平台，把生成的音库输出或同步到本工程 `assets/Banks`。构建后检查该目录根部确有 `Master.strings.bank`、`Master.bank` 和 `UI.bank`；避免路径实际落在未配置的 `Desktop` 子目录。
4. 在 Godot 的 FMOD General 设置中确认 Banks Path 为 `res://assets/Banks`、Auto Initialize 开启。调试时可开启 Live Update；本项目建议先以默认缓冲和立体声建立稳定播放。
5. 使用工具栏的 `Fmod Explorer` 查看和试听测试事件。若编辑器尚未刷新音库，重新打开工程后检查。

Auto Initialize、Live Update 与 Explorer 的作用见[初始化说明](https://fmod-gdextension.readthedocs.io/en/latest/user-guide/2-initialization/)。Explorer 的试听成功只说明编辑器侧可以访问该事件，运行时还需要单独加载音库。

建议保留可编辑的 `.fspro`、Metadata 和源音频；`.bank` 是构建产物。本地示例提供了演示 Banks，本次扫描未发现 `.fspro`，因此参考它的接入方式，并为正式内容建立自己的 Studio 源工程。

### 在游戏运行时加载

建立统一音频场景，使用 `FmodBankLoader`，首轮顺序为：

```text
Master.strings.bank
Master.bank
UI.bank
Study.bank
System.bank
```

把 Loader 放在依赖这些 Banks 的发声节点之前。全局音库由常驻音频场景持有；章节音乐和语音后续按需加载。若改用 `FmodServer.load_bank()`，必须保存返回的 `FmodBank` 引用。[音库加载与引用规则](https://fmod-gdextension.readthedocs.io/en/latest/user-guide/4-loading-banks/)

该文档的文字警告与其中一个代码示例对主音库顺序存在差异；此处采用文字警告和本地示例工程共同使用的顺序：strings 在前，Master 在后。

## 示例工程的参考价值

| 本地参考文件 | 可复用的做法 | 在本项目的使用方式 |
| --- | --- | --- |
| `high_level_2D/FmodNodesTest.tscn` | `FmodBankLoader`、Emitter、Inspector 参数。 | 作为第一轮接通与调试参考，优先使用编辑器可检查的配置。 |
| `low_level_2D/FmodTest.gd` | 保存 Bank 引用、显式加载。 | AudioManager 若承担动态音库管理，可沿用此持有方式。 |
| `high_level_2D/Emitter.gd` | 用 `fmod_parameters/RPM` 调整声音。 | 改成叙事情绪、系统异常程度等项目参数，值变化时更新。 |
| `high_level_2D/ChangeColor.gd` | 区域进入、离开时切换播放状态。 | 借鉴状态切换思路，接学习开始、退出、对话开关。 |
| `high_level_2D/SayWelcomeButton.gd` 与 `ChooseLanguageButton.gd` | Programmer callback 和语言 Bank。 | 留到正式配音阶段，再接台词键和语言切换。 |

示例中的车辆移动、脚步、3D 碰撞适合空间演示。本项目的桌面操作声和音乐先采用非空间化事件，在 Studio 中移除不需要的空间化处理。`FmodEventEmitter2D` 是 Godot 节点类型，`attached=false` 只改变位置跟随行为，不能代替 Studio 中的事件空间化设计。

Emitter 提供事件选择、参数、一次性播放与生命周期选项，具体能力见[事件播放指南](https://fmod-gdextension.readthedocs.io/en/latest/user-guide/5-playing-events/)。常驻音乐节点保持存活；临时发声节点才按需要使用 `auto_release`。

## 声音方向

### 桌面：可信、轻巧、有机械质感

开关窗口使用短促、圆润的数字提示，少量硬盘寻道或继电器质感。通常 40–180 ms 即可；启动提示可延长到 1–2 秒。可选的系统底噪保持极低，并允许关闭。用原创音色建立本项目的系统身份。

窗口拖动、缩放和鼠标悬停默认保持安静；同一动作只播放一次。窗口碎裂采用“低频冲击 → 数字裂响 → 稀疏碎片尾音”，让它同时像界面损坏与记忆断裂。

### 学习：提供确认，保护注意力

翻面使用轻柔纸感与电子点击结合的短声。四档评分优先使用同一声音家族和相近响度，通过音色区分；Again 也保持中性，避免刺耳的失败警报。四档评分是自我评估，应让声音支持如实选择。

连续学习默认使用无歌词、弱节奏、稀疏旋律的音乐，也支持纯静音。完成会话时给一次短而温暖的确认。声音反馈跟随已成功发生的操作。

### 剧情：把异常藏进熟悉的系统声

MIRA 初次出现时可复用系统通知动机，随后逐渐补全音程与温暖的泛音，呼应“碎片化记忆逐渐恢复”。重要揭示先短暂减少背景层，再加入低密度故障纹理，避免靠持续大音量制造紧张。

文字音效可选：以短语或约 60–100 ms 的最小间隔触发，过滤空格、标点和跳过全文造成的批量显示。已有正式配音时减少文字点击。以上时长、响度关系与参数范围均为初始试听建议。

## 首轮事件表

以下为 15 个普通事件和 1 个音乐事件，名称需要在本项目的 Studio 工程中新建。

| FMOD 事件 | 触发时机 | 听感与控制建议 |
| --- | --- | --- |
| `event:/UI/Confirm` | 普通按钮确认成功。 | 40–80 ms，2–4 个细微变体。 |
| `event:/UI/Reject` | 操作被拒绝且界面显示原因。 | 柔和低音提示，不与 Again 混用。 |
| `event:/Window/Open` | 新窗口真正创建。 | 短上行；激活已有窗口时不重播。 |
| `event:/Window/Close` | 窗口真正关闭。 | 短下行；取消关闭确认时不播放。 |
| `event:/Window/Minimize` | 成功最小化。 | 更轻的收束声。 |
| `event:/Window/Restore` | 从最小化恢复。 | 与最小化成对。 |
| `event:/Study/Flip` | 卡片从正面成功进入背面。 | 轻柔翻页，键鼠共用一个触发点。 |
| `event:/Study/Grade` | 接到成功评分通知。 | `Rating=1..4` 切换四种中性音色。 |
| `event:/Study/Complete` | 学习会话成功结束。 | 约 0.5–1 秒的温暖确认。 |
| `event:/System/Boot` | 启动转场开始。 | 一次短动机，允许快速进入桌面时淡出。 |
| `event:/Ambience/SystemHum` | 桌面空闲。 | 极低循环底噪，默认可关闭。 |
| `event:/Story/Notify` | 正式剧情到来。 | 可辨识的 MIRA 动机；教程可沿用普通提示。 |
| `event:/Story/Glitch` | 文本 glitch 特效发生。 | 短故障声，首轮冷却建议 300 ms。 |
| `event:/Window/Impact` | 有效破损引发冲击。 | 强度随 `Damage=0..1` 变化。 |
| `event:/Window/Shatter` | 碎裂动画实际开始。 | 冲击、裂响、尾音；限制并发，避免重复冲击。 |
| `event:/Music/State` | 桌面、学习、剧情之间切换。 | 保持一条常驻音乐实例，通过参数过渡。 |

普通确认声不能与专用翻面、评分、开窗声重复叠加。建议统一入口优先选择专用事件，UI 类单事件并发先限制到 2–4，重复点击冷却先从 50–80 ms 试听。

音库分工建议：`UI.bank` 放 UI 与 Window 事件，`Study.bank` 放学习反馈，`System.bank` 放启动、底噪与首轮剧情提示；音乐单独放 `Music.bank`，后续按章节拆分。碎裂音中的裂响应与实际 `impact_duration` 对齐，保留先冲击、后散开的节奏。

音乐首轮只做一个离散参数 `Context`，约定 Desktop、Study、Story 三个状态。第二轮再增加连续参数 `Tension=0..1`、`Connection=0..1`，分别控制异常纹理与温暖音色；这些声音参数不参与复习调度和羁绊计算。

## 分组、音量与混音

在 FMOD Studio 中建立 Bus：UI、Study、System、Ambience、Music、Voice、StoryFX，并设置对应的音量控制。设置界面先提供总音量、音乐、操作音效、环境音、语音五项；操作音效可共同控制 UI、Study、System 和 StoryFX。

增加 `snapshot:/DialogueFocus`，初始试听时将音乐降低约 4–6 dB、环境降低约 3–6 dB，进出过渡约 150–300 ms。后续确有需求再加专注学习 Snapshot。多来源共用 Snapshot 时集中持有和计数，最后一个来源退出才撤销。

FMOD 声音的设置通过 FMOD Bus/VCA 实现；Godot AudioServer 的总线设置不应被当作 FMOD 音量入口。保存位置建议 `user://audio_settings.cfg`，沿用工程已有的 SaveDirectory 重定向及 UiSettings 的延迟保存方式。滑块静音后仍保留用户原音量，恢复声音时可还原。

重要提示、异常和评分始终保留界面反馈。支持环境声开关、文字音效开关和减少突发音效选项。

## 工程组织与业务连接

建议新增以下模块，保持 Inspector 可编辑的原生 Resource：

```text
src/audio/audio_manager.gd          业务播放入口、并发、状态、音量和生命周期
src/audio/audio_catalog.gd          AudioCatalog Resource 类型
src/audio/audio_cue.gd              AudioCue Resource 类型
scenes/audio/audio_manager.tscn     常驻音频场景与 BankLoader
data/audio/audio_catalog.tres       一个目录，内含 Array[AudioCue] 子资源
assets/Banks/                      FMOD 构建产物
```

目录资源记录业务 ID、事件路径/GUID、所需 Bank、冷却与并发策略；素材随机、音高变化、效果链和音乐过渡放在 Studio。业务代码使用 `study_flip` 等稳定 ID，资源表统一映射 FMOD 事件。

保留插件自带的 FmodManager。在它之后新增 AudioManager 自动加载场景，游戏主场景进入前准备全局音库。当前 App 和 WindowManager 排在 FmodManager 之前，AudioManager 可在就绪后连接它们，并补读初始状态；现有 App 的早期初始化不应依赖尚未加入的音频入口。

| 当前入口 | 建议连接 | 注意点 |
| --- | --- | --- |
| `App.card_answered(rating)` | 评分音。 | 使用已有业务通知，避免按钮和快捷键各播一次。 |
| `App.dialogue_opened/closed` | 音乐 Context、对话 Snapshot。 | 这些信号同时服务教程与剧情，需带出来源或查询可信上下文，区分是否播放 MIRA 提示。 |
| `App.flags_changed` | 更新叙事声音状态。 | 按相关标记变化更新参数，避免每帧读取完整存档。 |
| `WindowManager.app_opened/app_closed` | 窗口开关声。 | 检查真正创建、关闭和未知程序隐藏的语义。`app_focused` 不作为开窗声。 |
| `ManagedWindow.minimized/restored` | 窗口最小化与恢复声。 | 只绑定一次，跟随对应窗口生命周期。 |
| `CardUI` 的翻面成功回调 | 翻面音。 | `request_flip()` 可能失败；`App.card_presented` 也可能因重绘触发，应检查真实状态变化。 |
| `CardUI.study_finished(stats)` | 会话完成音。 | 区分正常完成与提前退出。 |
| `TextAnimationController.effect_triggered` | 文本 shake/glitch 声音。 | 当前 Overlay 尚未连接此信号，可在显示层补接；文字逐字通知仍需另行提供。 |
| `WindowManager.set_app_damage()` | 成功冲击后的破损音。 | 建议补出明确的效果通知；重复赋值、恢复到 0 和被保护的窗口不能误触发。 |
| `DesktopWindowEffects.effect_started` | 完全碎裂音。 | 信号在真实旧 UI 销毁、快照开始运动时发出，优于点击“碎裂”按钮时播放。由桌面或全局音频持有声音，避免随原窗口销毁截断。 |
| `DesktopBootTransition` | 启动音与转场淡出。 | 该转场提前建立桌面；底噪和桌面音乐应在转场完成后进入，避免预加载阶段重复播放。 |

循环音乐、环境与 Snapshot 由统一入口持有，退出状态时明确停止；章节音库在相关声音停止后释放。停止与释放是不同生命周期动作，可参考 [FMOD 2.03 EventInstance API](https://www.fmod.com/docs/2.03/api/studio-api-eventinstance.html)。原生回调若需要修改界面，应通过主线程安全的通知路径处理。

## 分阶段落地与验收

### 先打通一声

构建 `UI/Confirm` 和三个测试 Banks，接常驻 Loader，运行游戏时点击测试按钮。确认 Explorer 和实际游戏都能播放，并检查重复启动、退出和 Windows Debug/Release 导出。编辑器试听、游戏播放和导出播放分别记录结果。

插件当前注册了 `FmodEditorExportPlugin`；实际导出仍须检查 Banks 和匹配的 FMOD DLL 是否随包交付。若检查发现 `.bank` 未包含，再补非资源文件导出过滤；不能仅因 `include_filter` 为空就断言导出缺音库。

### 接桌面与学习

完成统一入口、单个 `.tres` 目录、声音设置及开关窗口、翻面、评分、完成反馈。先测试同一动作只播一次、长时间复习不疲劳、快捷键与鼠标一致、音量保存有效。

### 接叙事与窗口特效

增加一条分层音乐、对话 Snapshot、文本异常、破损和碎裂。实际画面验收声音与特效的起点；特别检查对话队列、帮助窗口、跳过文字、快速重开窗口和原窗口销毁后的尾音。

### 后续配音

在台词与语言结构稳定后，再参考示例的 Audio Table / programmer callback。按当前语言和章节加载语音 Bank，切换或跳过时管理旧实例与音库，处理缺失台词键。

以上为后续验收计划。本次完成文件检查、示例对照、在线文档核对和引擎版本读取；尚未执行本工程 FMOD 实际播放或导出验证。

## 参考资料

- [插件文档入口](https://fmod-gdextension.readthedocs.io/en/latest/)
- [安装指南](https://fmod-gdextension.readthedocs.io/en/latest/user-guide/1-install/)
- [初始化设置](https://fmod-gdextension.readthedocs.io/en/latest/user-guide/2-initialization/)
- [音库加载](https://fmod-gdextension.readthedocs.io/en/latest/user-guide/4-loading-banks/)
- [事件与参数播放](https://fmod-gdextension.readthedocs.io/en/latest/user-guide/5-playing-events/)
- [插件 6.1.0 对应发布](https://github.com/utopia-rise/fmod-gdextension/releases/tag/6.1.0-4.5.0)
- 项目依据：`docs/scenes/ui/desktop.md`、`docs/scenes/ui/settings.md`、`docs/scenes/window_lab.md`、`docs/narrative/narrative_framework.md`、`docs/narrative/gameplay_integration_matrix.md`，并对照当前实现。
