# 网关契约（iPad 端视角）

这份契约与 `Celestia/Core/GatewayModels.swift` 中的数据结构一一对应。`HTTPGateway` 实现了真实连接，`MockGateway` 用进程内的方式实现了同一套契约。

## 公共请求头

```
Authorization: Bearer <token>      令牌为空时不发送
X-Device-Id:   ipad-xxxxxxxx       首次启动时生成并持久保存
X-Device-Type: tablet | ipad
```

所有数值都是 JSON number，时间使用 Unix 秒（浮点数）。

## HTTP 接口

| 方法 | 路径 | 请求体 | 响应 |
| --- | --- | --- | --- |
| GET | `/v1/health` | – | `{"status":"ok","version":"1.2.0"}` |
| GET | `/v1/state` | – | `{"activeBody":"pc-main","speaking":false,"channels":{…},"tokensVersion":"7"}` |
| GET | `/v1/design-tokens` | – | 见下方“设计令牌” |
| POST | `/v1/presence/claim` | `{"deviceId","deviceType","capabilities":[…]}` | `{"granted":true,"leaseSeconds":15,"activeBody":"ipad-…"}` |
| POST | `/v1/presence/heartbeat` | `{"deviceId","focused":true}` | 与 claim 响应相同 |
| POST | `/v1/perception` | `{"deviceId","events":[{"kind":"touch","at":…,"values":{"x":0.1,"y":0.3}}]}` | 2xx |
| POST | `/v1/chat` | `{"message","deviceId"}`，`Accept: text/event-stream` | SSE 流，见下方 |

- 401 会提示“令牌被网关拒绝”，其他非 2xx 状态会显示状态码。
- 心跳间隔为 `leaseSeconds / 3`，限制在 2 到 30 秒之间。
- claim 或 heartbeat 返回 `granted:false` 时，iPad 进入 standby：她仍然活着，但注意力下降、不张嘴。状态栏会显示她在哪具身体上。

目前上报的感知事件（`kind`）：

- `touch`：`x`、`y` 取值 -1…1，y 轴向上，面部中心约为 (0,0)。
- `focus`：`foreground` 为 0 或 1。

## WebSocket `/v1/stream`

地址由 base URL 换成 ws 协议得到（`http`→`ws`，`https`→`wss`）。握手时带上公共请求头。服务端推送 JSON 文本帧：

```json
{"type":"channels","values":{"mouthOpen":0.4,"warmth":0.7},"ease":0.05}
{"type":"presence","activeBody":"pc-main"}
{"type":"tokens","tokens":{…DesignTokens…}}
{"type":"ping"}
```

- 未知的 `type` 和未知的通道名都会被忽略，所以网关可以先于身体端升级。
- 流断开时会指数退避重连（1、2、4……最长 30 秒）。

## 连续通道

脸部没有离散的情绪状态机，网关只发送数值。每个 patch 可以只包含部分通道，`ease`（秒）可选，用来覆盖默认的缓动时间常数。

| 通道 | 范围 | 默认缓动 | 说明 |
| --- | --- | --- | --- |
| `breath` | 0…1 | – | 由本机生成，网关的值会被忽略；呼吸速度受 `energy` 影响 |
| `blink` | 0…1 | 0.02s | 取本机眨眼与网关值的较大者 |
| `gazeX` / `gazeY` | -1…1 | 0.09s | 叠加本机扫视；`attention` 越高，扫视越少 |
| `mouthOpen` | 0…1 | 0.045s | 用于口型，建议 15–30 Hz |
| `mouthSmile` | -1…1 | 0.25s | |
| `browRaise` | -1…1 | 0.25s | |
| `headYaw` / `headPitch` / `headRoll` | -1…1 | 0.35s | 叠加本机待机摆动 |
| `energy` | 0…1 | 0.8s | 调节呼吸、眨眼的节奏和动作幅度 |
| `warmth` | 0…1 | 0.8s | 腮红、光晕 |
| `attention` | 0…1 | 0.8s | 看向观看者（触摸点）的程度 |

网关超过 2.5 秒没有推送 patch 时，目标值会逐渐回到中性，避免断线后她定格在说话的姿态。

## 对话 SSE

服务端推送的事件：

```
event: delta
data: {"text":"你"}

event: channels
data: {"values":{"mouthOpen":0.6},"ease":0.04}

event: done
data: {}

event: error
data: {"message":"…"}
```

每个事件只用**一行** `data:`。iOS 的 `bytes.lines` 会丢掉空行，所以客户端在每个 data 行之后就结束当前事件。

## 设计令牌

```json
{"version":"7","accent":"#F2B880","stageTop":"#1A1420","stageBottom":"#07060A",
 "glassFill":0.07,"glassStroke":0.28,"cornerRadius":30}
```

客户端会把数值钳制在合理范围内；颜色解析失败时回退到内置值。
