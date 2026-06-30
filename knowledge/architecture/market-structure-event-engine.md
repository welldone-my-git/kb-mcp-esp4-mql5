# Market Structure Event Engine

## 定位

统一 BOS、ChoCH、Liquidity Sweep、Opening Range Breakout 等结构事件。

```text
Market Data
  ↓
Structure Detector
  ↓
StructureEvent
  ↓
Feature / Regime / Signal
```

来源样例：

- [FractalReactionBOS](../../examples/mql5/FractalReactionBOS/)
- [LiquiditySweep](../../examples/mql5/LiquiditySweep/)
- [OpeningRangeBreakout](../../examples/mql5/OpeningRangeBreakout/)
- Bikeen Market Structure Sentinel：https://www.mql5.com/en/articles/22249
- Bikeen Support & Resistance Sentinel：https://www.mql5.com/en/code/69219

## 引擎分层

Market Structure 不应写成一个大指标。建议拆成四层：

```text
SwingEngine
    ↓
StructureEngine
    ↓
StructureEventEngine
    ↓
Feature / Signal / Regime
```

### SwingEngine

职责：

```text
detect swing high / swing low
assign swing id
estimate swing strength
```

### StructureEngine

职责：

```text
Swing sequence
    ↓
HH / HL / LH / LL
    ↓
structure state
```

### StructureEventEngine

职责：

```text
BOS
CHOCH
LIQUIDITY_SWEEP
RANGE_BREAKOUT
SUPPORT_RESISTANCE_BREAK
```

### Downstream

结构事件只负责描述市场，不负责执行交易：

```text
StructureEvent
    ↓
FeatureEngine / MetaLabel / Regime
    ↓
RiskEngine
```

## 事件类型

```text
BOS
CHOCH
LIQUIDITY_SWEEP
RANGE_DEFINED
RANGE_BREAKOUT
RANGE_RETEST
SUPPORT_TOUCH
SUPPORT_BREAK
RESISTANCE_TOUCH
RESISTANCE_BREAK
```

## 事件 schema

```text
StructureEvent
  ├── event_id
  ├── timestamp
  ├── symbol
  ├── timeframe
  ├── event_type
  ├── direction
  ├── level_price
  ├── source
  ├── confidence
  └── metadata
```

## 设计规则

1. 使用闭合 K 线确认结构事件。
2. 不在 detector 内直接下单。
3. 所有事件必须可落库和 replay。
4. 结构事件可作为 Feature，也可作为 Primary Signal。
5. 风控和执行必须由下游 RiskEngine / OrderManager 决定。

## Python 平台映射

```text
research/structure/
  swings.py
  structure_state.py
  fractals.py
  bos_choch.py
  liquidity_sweep.py
  support_resistance.py
  opening_range.py
  events.py
```

## Feature 输出

```text
last_structure_event
bars_since_event
distance_to_event_level
structure_direction
structure_regime
swing_strength
distance_to_last_swing
distance_to_support
distance_to_resistance
```

## 作者来源分工

```text
Bikeen
    = Swing / Structure / BOS / CHOCH core detector

LynnChris
    = Structure event pipeline, buffer integration, execution adapter
```

二者应合并进同一 `MarketStructureEventEngine`，不要为每个作者各建一套不兼容结构。
