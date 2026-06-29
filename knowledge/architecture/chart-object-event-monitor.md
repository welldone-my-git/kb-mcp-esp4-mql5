# Chart Object Event Monitor

## 定位

把 MQL5 图表对象变成平台事件源。

```text
Chart Object
  ↓
Object Adapter
  ↓
State Tracker
  ↓
GeometryEvent
  ↓
Feature / Signal / Alert
```

来源样例：

- [ManualTrendlineSync](../../examples/mql5/ManualTrendlineSync/)
- [SupportResistanceMonitor](../../examples/mql5/SupportResistanceMonitor/)
- [ChartObjectDetector](../../examples/mql5/ChartObjectDetector/)
- [GeometryInteraction](../../examples/mql5/GeometryInteraction/)

## 需要解决的问题

人工画线本质上是隐式数据。如果没有 adapter，EA 只能看到 chart object，无法进入研究和执行管线。

目标是将对象转成结构化事件：

```text
TrendlineTouched
TrendlineBroken
SupportRetested
ResistanceSwept
ChannelBreakout
```

## 推荐结构

```text
CChartObjectMonitor
  ├── Scan()
  ├── Sync()
  ├── Update()
  ├── DeleteMissing()
  └── EmitEvents()
```

对象状态：

```text
object_id
object_name
object_type
anchors
last_side
last_touch_time
last_breakout_time
event_state
metadata
```

## 事件模型

```text
GeometryEvent
  ├── event_id
  ├── timestamp
  ├── symbol
  ├── object_id
  ├── object_type
  ├── event_type
  ├── price
  ├── distance
  └── metadata
```

后续可转换为：

```text
Feature
SignalEvent
RiskEvent
Alert
```

## 设计规则

1. 人工对象与 EA 对象分离

   使用 prefix / owner / metadata 区分用户画线和程序生成对象。

2. 事件去重

   touch / breakout / retest 必须有状态锁，不能每 tick 重复触发。

3. 不在 monitor 内交易

   monitor 只 emit event。交易由 RiskEngine / OrderManager 处理。

4. 记录对象变化

   用户拖动对象后，应重新计算 anchors 和 geometry。

5. 可回放

   如果用于研究，必须把 object snapshot 或 derived features 写入 storage。

## Python 平台映射

```text
geometry/
  object_adapter.py
  monitor.py
  events.py
  feature_generator.py
```

MQL5 负责实时对象读取；Python 负责历史研究和特征评估。

