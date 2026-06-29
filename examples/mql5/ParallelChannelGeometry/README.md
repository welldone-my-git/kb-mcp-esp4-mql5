# Parallel Channel Geometry

来源：

- 文章：https://www.mql5.com/en/articles/21443
- 标题：Price Action Analysis Toolkit Development (Part 62): Parallel Channel
- 作者：Christian Benjamin（LynnChris）
- 源码：[CHANNEL.mq5](./CHANNEL.mq5)

## 定位

```text
Swing Points → Channel Geometry → Breakout / Retest Events
```

这份源码属于自动几何检测。收藏点是 channel entity 与 breakout event，不是通道突破策略。

## 可收藏点

- `SwingPoint` 抽象；
- `Channel` 结构保存 high anchors、low anchors、slope、width、touch count、score；
- 根据 slope 分类 ascending / descending / horizontal；
- 用 ATR 过滤过窄 channel；
- 计算通道上下轨；
- 绘制 breakout zone；
- 保存 breakout record，并支持 retest 检测；
- `FindBestChannel()` 通过评分选择最佳 channel。

## 可迁移特征

```text
channel_slope
channel_width
channel_score
touch_count
distance_to_upper
distance_to_lower
channel_position
breakout_direction
retest_after_breakout
```

这些比“突破就买/卖”更适合进入 ML / Meta Labeling。

## 不建议直接复用的部分

- 每 tick 重建大量图表对象成本较高；
- breakout 交易规则需要统计验证；
- signal 主要以图表对象/alert 表达，没有统一 buffer contract；
- 生产框架应拆分 Detector、Geometry、Event、Visual 四层。

