# Flag Pattern Detector

来源：

- 文章：https://www.mql5.com/en/articles/22503
- 标题：Price Action Analysis Toolkit Development (Part 69): Flag Pattern Detection
- 作者：Christian Benjamin（LynnChris）
- 源码：[Flag_Pattern_Detector.mq5](./Flag_Pattern_Detector.mq5)

## 定位

```text
Pattern Detector / Geometry Visualizer
```

这是 Part 70 Buffer EA 的前置形态检测器。当前版本重点是检测和绘图，后续 Part 70 增加了 buffer 输出和 EA 执行链路。

## 可收藏点

- `DrawnFlag` / `ActiveFlag` 区分历史绘制对象和正在发展的形态；
- 使用 ATR 过滤 flagpole；
- 限制 retracement 与 flag duration；
- active flag 持续更新，直到 breakout 或 invalidation；
- 用 trendline、rectangle、arrow、label 组合表达一个 pattern entity；
- 对 bullish / bearish flag 使用同一套状态结构。

## 平台映射

```text
PatternDetector
  ↓
PatternEntity
  ↓
ConfirmedPatternEvent
  ↓
SignalBuffer / SignalEvent
```

可扩展到：

- wedge；
- triangle；
- pennant；
- rectangle；
- channel；
- SMC structure pattern。

## 不建议直接复用的部分

- pattern 规则本身需要严谨统计验证；
- 当前版本没有完整 signal buffer contract；
- 视觉对象和检测逻辑仍在同一文件；
- 应抽象成 `PatternDetector` + `PatternRenderer` + `SignalAdapter`。

