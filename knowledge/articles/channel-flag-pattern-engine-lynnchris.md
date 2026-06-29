# Channel / Flag Pattern Engine：几何结构检测到 Pattern Event

来源：

- Part 62：https://www.mql5.com/en/articles/21443
- Part 69：https://www.mql5.com/en/articles/22503
- 作者：Christian Benjamin（LynnChris）
- 源码：
  - [ParallelChannelGeometry](../../examples/mql5/ParallelChannelGeometry/)
  - [FlagPatternDetector](../../examples/mql5/FlagPatternDetector/)

## 结论

这两篇适合作为“几何结构检测器”收藏。

```text
Swing / ATR / Geometry
  ↓
Channel / Flag Entity
  ↓
Breakout / Invalidation / Retest
  ↓
PatternEvent
```

## Part 62：Parallel Channel

核心不是通道交易，而是 channel data model：

```text
Channel
  ├── anchor points
  ├── slope
  ├── width
  ├── touch count
  ├── score
  ├── type
  └── strength
```

这可以迁移为 feature：

```text
channel_width_atr
channel_slope
channel_score
position_inside_channel
distance_to_upper
distance_to_lower
```

## Part 69：Flag Pattern

核心是 pattern lifecycle：

```text
candidate
  ↓
active flag
  ↓
breakout or invalidation
  ↓
draw / alert / signal
```

值得迁移的不是 flag 规则，而是：

```text
PatternEntity
PatternState
PatternRenderer
PatternEvent
```

## 平台建议

不要把每种形态做成一个大 EA。应统一：

```text
IPatternDetector
  ├── detect()
  ├── update()
  ├── invalidate()
  └── events()
```

事件统一：

```text
PatternEvent(
    pattern_type,
    direction,
    start_time,
    end_time,
    anchor_points,
    confidence,
    breakout_price,
    invalidation_price,
    metadata
)
```

## 与 Meta Labeling 的关系

这些 pattern 不应直接下单。更合理的用法：

```text
Primary Signal
  + Pattern Context
  ↓
Meta Model
  ↓
Trade / Skip / Size
```

特征示例：

```text
near_channel_upper
flag_breakout_recent
channel_touch_count
pattern_age
pattern_strength
```

## 收藏评分

| 模块 | 收藏价值 |
|---|---:|
| Channel data model | 5/5 |
| Pattern lifecycle | 5/5 |
| Visual object grouping | 4/5 |
| 交易规则本身 | 2/5 |

