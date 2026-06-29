# Manual Chart Object Sync：把手动画线变成事件源

来源：

- Part 64：https://www.mql5.com/en/articles/21704
- Part 67：https://www.mql5.com/en/articles/21961
- 作者：Christian Benjamin（LynnChris）
- 源码：
  - [ManualTrendlineSync](../../examples/mql5/ManualTrendlineSync/)
  - [SupportResistanceMonitor](../../examples/mql5/SupportResistanceMonitor/)

## 结论

这两篇的价值不是“画线突破交易”，而是：

```text
Manual Chart Object
  ↓
Object Sync
  ↓
Event Monitor
  ↓
Geometry Feature / Signal
```

它把人工分析对象接入程序化系统。

## 为什么值得收

很多交易员仍然依赖手动画线、水平位、通道和区域。问题是 EA 不理解这些对象。

这组源码提供了一个可复用方向：

```text
ObjectsTotal / ObjectName / ObjectGet*
  ↓
Object Registry
  ↓
State Tracking
  ↓
Touch / Breakout / Retest
```

## 可迁移设计

### 1. Object Registry

把 chart object 纳入内部数组：

```text
name
type
price / anchors
last_side
alert_state
breakout_state
```

### 2. Event State

避免每 tick 重复触发：

```text
approaching
touch
breakout
retest
reset
```

### 3. Manual Object Adapter

平台中建议抽象为：

```text
ManualObjectAdapter
  ├── scan()
  ├── sync()
  ├── update()
  └── emit_events()
```

## 对研究框架的价值

手动画线不应直接变成交易命令，而应变成特征：

```text
distance_to_manual_trendline
distance_to_support
distance_to_resistance
touch_count
last_breakout_age
retest_flag
```

这些可以进入 Meta Labeling 或 Regime Filter。

## 反模式

- 画线突破立即下单；
- alert / UI / detector / execution 混在同一文件；
- 没有统一 event schema；
- 不记录 object version 或用户修改时间；
- 不区分人工对象和 EA 自己创建的对象。

## 平台归档

归类到：

```text
Architecture / Chart Object Event Monitor
Geometry Layer
Feature Engineering
```

