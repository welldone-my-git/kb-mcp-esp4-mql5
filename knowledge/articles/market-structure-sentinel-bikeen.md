# Market Structure Sentinel：Swing / BOS / CHOCH 结构引擎

来源：

- Building the Market Structure Sentinel Indicator: https://www.mql5.com/en/articles/22249
- 作者主页：https://www.mql5.com/en/users/bikeen
- 作者地图：[Bikeen Market Structure Engine Map](./bikeen-market-structure-engine-map.md)

## 定位

这篇文章的长期价值不是指标显示，而是 Market Structure Engine 的核心骨架。

```text
Price Series
    ↓
Swing Detection
    ↓
Structure State
    ↓
BOS / CHOCH
    ↓
StructureEvent
```

## 必收藏组件

### 1. SwingEngine

职责：

```text
detect swing high / swing low
filter noise
assign swing id
emit swing event
```

建议输出：

```text
SwingPoint
├── swing_id
├── timestamp
├── price
├── direction
├── strength
├── left_bars
├── right_bars
└── metadata
```

### 2. StructureEngine

职责：

```text
Swing sequence
    ↓
HH / HL / LH / LL
    ↓
market structure state
```

建议状态：

```text
UP_STRUCTURE
DOWN_STRUCTURE
TRANSITION
RANGE
UNKNOWN
```

### 3. BOSEngine

BOS 应定义为结构延续事件：

```text
current structure direction
    +
break of relevant swing level
    =
BOS
```

输出：

```text
StructureEvent(type=BOS, direction=...)
```

### 4. CHOCHEngine

CHOCH 应定义为潜在结构变化事件：

```text
existing structure
    +
break against current structure
    =
CHOCH
```

输出：

```text
StructureEvent(type=CHOCH, direction=...)
```

## 和平台事件模型的关系

不要让 detector 直接下单。

正确链路：

```text
SwingEngine
    ↓
StructureEngine
    ↓
StructureEvent
    ↓
FeatureEngine / SignalEngine / MetaLabel
    ↓
RiskEngine
```

## 可转成的 Feature

```text
last_swing_high
last_swing_low
bars_since_last_swing
distance_to_last_swing_high
distance_to_last_swing_low
last_structure_event
bars_since_bos
bars_since_choch
structure_direction
structure_confidence
```

## 反模式

避免：

- BOS 出现就直接 Buy；
- CHOCH 出现就直接反向；
- 当前未闭合 K 线确认结构；
- Swing detection 和交易执行混在一个函数里；
- 只画图，不输出结构化事件。

## 结论

这篇适合收录为：

```text
Market Structure Core Algorithm
```

它补齐的是结构检测底层，不是完整交易系统。

