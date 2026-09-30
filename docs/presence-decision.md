# 形象方案：MetaHuman 还是 2D-to-mesh

## 结论

Phase A 采用 **2D-to-mesh（分层 2.5D）**，在本机渲染。MetaHuman 作为 Phase C 的可选“高保真身体”，走 Pixel Streaming，并且与现有的连续通道契约兼容。

## 为什么不用原生 MetaHuman

| 路线 | 能否在 iPad 上跑 | 代价 |
| --- | --- | --- |
| iPad 本机运行 UE + MetaHuman | 不现实。MetaHuman 面向桌面和主机级 GPU，官方不支持 iOS 实时运行完整的 MetaHuman；移动端 LOD 也需要自己裁剪材质和绑定 | 包体、发热、功耗都无法接受 |
| **Pixel Streaming**（UE 在 Windows 上渲染，WebRTC 推流到 iPad） | 可以 | Windows 端需要常驻 GPU；延迟和网络抖动会直接表现为“她卡了”；断网后身体消失；iPad 变成视频播放器，感知与画面之间多了一跳 |
| Live Link Face | 方向相反 | 它用 iPad 捕捉人脸驱动 UE，不是用来在 iPad 上呈现角色 |

Pixel Streaming 适合作为“客厅大屏”那种高保真身体，但不适合作为 MVP 的主身体。

## 2D-to-mesh 在这里指什么

- 一套 2D 美术包：在同一张画布上导出多层 PNG，也就是 PSD 转图层的常规流程；没有美术包时用内置矢量兜底。
- 每层有一个深度值。陀螺仪视差和 `headYaw`/`headPitch` 让浅层比深层移动得多，平面画面因此呈现出转头的感觉。
- 连续通道驱动各层的形变：
  - 眼睑开合
  - 虹膜注视
  - 嘴的张合与弧度
  - 眉毛
  - 呼吸带动的躯干起伏
  - 头部 roll
  - 光晕和腮红（由 warmth 驱动）
- 本地生命（`LocalLife`）保证在没有网关时，她也在呼吸、眨眼、扫视。

Phase A 用的是逐层仿射变换加程序化五官。真正的网格形变（每层三角网格 + ARAP 或骨骼权重，类似 Live2D）是 Phase B。`AvatarRenderer` 的输入仍然只有 `PresenceChannels`，所以升级渲染器时不需要改契约或网关。

## MetaHuman / Pixel Streaming 的接入方式（Phase C）

1. Windows 端：UE 5 项目 + MetaHuman + Pixel Streaming 插件。把网关的 `/v1/stream` 通道映射到 MetaHuman 的 ARKit 52 blendshape 或 Control Rig（例如 `mouthOpen`→`jawOpen`，`blink`→`eyeBlinkLeft/Right`，`gaze*`→`eyeLook*`）。
2. iPad 端：新增一个 `PixelStreamingAvatarView`（WKWebView 加载 Pixel Streaming 前端，或原生 WebRTC），作为 `CocoaStage` 中 `CocoaAvatarView` 的替代实现，在设置里切换。
3. 本地生命仍在 iPad 端计算，并作为 patch 回传给 UE。这样眨眼节奏和注视焦点（触摸点）由本机感知决定，UE 只负责渲染。
4. 断流时自动回退到 2D 形象，保证她不会“消失”。
