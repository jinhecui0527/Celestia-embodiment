# Celestia · 可可的具身终端（iPadOS）

iPad 是可可（Cocoa）的另一具身体，不是一个独立的聊天机器人。
她的大脑、记忆和日程都在 Windows 网关上，iPad 只负责三件事：

- **Presence（存在）**：她在屏幕中央，一直在呼吸、眨眼、看向你。
- **Perception（感知）**：触摸、设备姿态、前台状态，上报给网关。
- **Link（连接）**：按网关契约连接，接收连续通道，认领 presence。

App 里不内置人格提示词，也不接 OpenAI。Mock 模式下的回复只是明确标注的回声。

## 当前状态（Phase A MVP）

| 部分 | 状态 |
| --- | --- |
| `Celestia/Core`：连续通道、本地生命、通道混合、网关模型、SSE 解析、Mock 网关 | 在 Linux（Swift 6.0.3）上编译通过，`swift test` 16 个测试全部通过 |
| 应用层：SwiftUI、Canvas 渲染、CoreMotion、Keychain、URLSession | 已写完，**只做过语法检查**（开发机是 Linux，没有 iOS SDK）。第一次在 Xcode 中构建可能要做少量类型修正 |
| `Celestia.xcodeproj` | 手写的 Xcode 16 工程（文件夹同步组），已用 pbxproj 解析器校验结构和引用 |

## 运行

需要 macOS 和 **Xcode 16 或更高版本**（工程使用 objectVersion 77 的文件夹同步组），目标系统 iPadOS 17+。

1. `open Celestia.xcodeproj`
2. 选择任意 iPad 模拟器，按 ⌘R 运行。
3. 默认连的是 **Mock 网关**：左上角显示“可可在这里”，她自己呼吸、眨眼、扫视，Mock 按约 15 Hz 推送缓慢漂移的通道。
4. 触摸屏幕，她会看向你的手指。点底部 ornament 上的对话按钮发一句话，能看到逐字字幕，嘴型也跟着动。
5. 主页按钮（六边形网格）→“身体”，可以实时看到全部 13 个通道的数值。

在真机上运行：在 Signing & Capabilities 里选择你的 Team。陀螺仪视差只在真机上有效。

### 连接 Windows 网关

主页 →“连接”→ 选择“Windows 网关”，填写地址（例如 `http://192.168.1.10:8787`）和 Bearer 令牌，然后点“保存并重新连接”。

- 令牌存放在钥匙串（Keychain）中，其余设置存在 UserDefaults。
- ATS 已允许局域网内的明文 HTTP（`NSAllowsLocalNetworking`），首次连接时系统会请求局域网权限。
- 所有请求都会带上 `Authorization: Bearer …`、`X-Device-Id`（首次启动时生成）和 `X-Device-Type: tablet`（可在设置中切换为 `ipad`）。

完整接口见 [docs/gateway-contract.md](docs/gateway-contract.md)。

## 形象方案：2D-to-mesh，不用原生 MetaHuman

结论：Phase A 采用**分层 2D 形象，每层带深度（2.5D）**，由连续通道驱动。MetaHuman 作为后续可选路线，走 Pixel Streaming。

原因：MetaHuman 不能在 iPad 上原生运行，唯一可行的方式是在 Windows 端用 UE 渲染，再通过 WebRTC 推流到 iPad。这需要 GPU 常驻、网络延迟敏感，还会把“她在 iPad 上的身体”变成一段视频。分层 2D 在本机以 60 fps 渲染，离线时也保持活着，美术成本也低得多。

详细取舍和 MetaHuman 接入路径见 [docs/presence-decision.md](docs/presence-decision.md)。

### 导入美术包

在 `Assets.xcassets` 里建一个 `cocoa` 文件夹，放入同尺寸画布导出的 PNG 图层：`hair_back`、`body`、`face`、`eyes_open`、`eyes_closed`、`brows`、`mouth_closed`、`mouth_open`、`bangs`。

缺哪层就用内置矢量画哪层，所以可以一层一层替换。画布映射见 `AvatarPack.canvas`。

## 目录结构

```
Celestia/
  App/            入口、scene 生命周期
  Core/           与平台无关的核心（同时作为 SwiftPM 目标被测试）
    Channels.swift        13 个连续通道 + 部分更新（patch）
    LocalLife.swift       呼吸 / 眨眼（含双眨）/ 扫视 / 待机摆动
    ChannelMixer.swift    网关目标 + 本地生命 + 观看者焦点 → 最终通道；网关静默 2.5 秒后回归中性
    GatewayModels.swift   契约数据结构
    Gateway.swift         Gateway 协议、请求头、ws 地址
    SSEParser.swift       text/event-stream 解析器
    MockGateway.swift     进程内的 Mock 网关
  Link/           HTTPGateway（HTTP + SSE + WebSocket）、LinkController（会话 / 重连 / 心跳 / 感知上报）、设置、Keychain
  Presence/       PresenceEngine、AvatarRenderer（分层 Canvas）、AvatarPack、MotionParallax
  DesignSystem/   GlassWindow、Ornament、AppHoneycomb、Theme（来自网关 design tokens）
  Stage/          CocoaStage（她始终在中央）以及对话 / 连接 / 感知 / 身体面板
Tests/CelestiaCoreTests/
Package.swift     只用于在 macOS / Linux 上测试 Core
```

UI 是 visionOS 风格的玻璃效果，但**不用毛玻璃模糊**：淡色半透明填充，加上高光顶边和渐变描边，她始终清晰地透过面板可见。

## 测试

```bash
swift test
```

测试覆盖以下内容：

- 通道值的钳制和未知键
- 呼吸周期和眨眼频率
- 固定随机种子下结果可复现
- 混合器的缓动、网关静默后回归中性、看向触摸点
- SSE 解析
- 请求头和 ws 地址
- Mock 网关的推流、对话和 presence 认领
