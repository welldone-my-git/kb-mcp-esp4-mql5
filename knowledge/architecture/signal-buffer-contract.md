# Signal Buffer Contract

## 定位

MQL5 中，indicator buffer 可以作为轻量级 `SignalEvent` 传输层。

核心模式：

```text
Indicator / Signal Provider
  ↓ buffers
EA / Signal Adapter
  ↓ event
RiskEngine
  ↓
OrderManager
```

来源样例：

- [FlagSignalBufferEA](../../examples/mql5/FlagSignalBufferEA/)
- [WeekendGapSignalPipeline](../../examples/mql5/WeekendGapSignalPipeline/)
- 文章精华：[Indicator Buffer → EA Execution Contract](../articles/indicator-buffer-ea-execution-contract.md)

## 适用场景

- 指标产生信号，EA 负责执行；
- Python / MQL5 混合架构中，MQL5 需要消费外部或指标端信号；
- Strategy Tester 中需要可回放信号；
- 希望把 signal detection 与 order execution 解耦。

## 基础合约

```text
buffer[0] = long_signal
buffer[1] = short_signal
```

推荐合约：

```text
buffer[0] = long_signal_price
buffer[1] = short_signal_price
buffer[2] = long_take_profit
buffer[3] = long_stop_loss
buffer[4] = short_take_profit
buffer[5] = short_stop_loss
```

如果需要更多字段：

```text
confidence
regime
signal_id
schema_version
```

优先由 adapter 层补全，而不是强行塞入大量 indicator buffers。

## EA 读取规则

默认读取闭合 K 线：

```text
shift = 1
```

不建议默认读取当前 K 线：

```text
shift = 0
```

原因：

- 当前 K 线信号可能消失；
- 容易重复触发；
- 回测与实盘行为不一致；
- 对 ML / Replay 数据污染严重。

## 去重规则

Signal adapter 至少维护：

```text
last_signal_time
last_signal_direction
last_signal_price
```

更稳妥：

```text
signal_id = hash(symbol, timeframe, signal_time, direction, source)
```

## 平台事件映射

```text
buffer values
  ↓
SignalEvent(
    event_id,
    timestamp,
    symbol,
    source,
    direction,
    confidence,
    strength,
    stop_loss,
    take_profit,
    model_name,
    regime,
    metadata
)
```

## 反模式

- EA 和指标重复实现同一套信号检测；
- 指标直接下单；
- buffer 编号没有文档；
- 0 同时表示价格 0 和无信号；
- EA 每 tick 读 shift 0 并重复开仓；
- signal、risk、execution 混在同一个 `OnTick()`。

## 平台实现建议

Python 平台中对应组件：

```text
SignalProvider
IndicatorSignalAdapter
SignalEvent
RiskEngine
OrderManager
BrokerAdapter
```

MQL5 侧可实现：

```text
CIndicatorSignalAdapter
  ├── Init(iCustom handle)
  ├── ReadClosedBar()
  ├── ToSignalRecord()
  └── Deduplicate()
```

长期应把 buffer contract 版本化：

```text
name
version
buffers
shift_policy
units
source
```

