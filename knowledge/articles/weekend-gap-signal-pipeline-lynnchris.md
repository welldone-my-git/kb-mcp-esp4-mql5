# Weekend Gap Signal Pipeline：从对象状态机到 EA Buffer 执行

来源：

- Part 71：https://www.mql5.com/en/articles/22796
- Part 72：https://www.mql5.com/en/articles/22884
- Part 73：https://www.mql5.com/en/articles/22993
- Part 74：https://www.mql5.com/en/articles/23015
- 作者：Christian Benjamin（LynnChris）
- 源码：
  - [WeekendGapIndicator](../../examples/mql5/WeekendGapIndicator/)
  - [WeekendGapSignalPipeline](../../examples/mql5/WeekendGapSignalPipeline/)

## 结论

这个系列应该作为“完整信号流水线”收藏，而不是作为 Weekend Gap 策略收藏。

```text
Part 71 = Object Framework / State Machine
Part 72 = Gap Fill Indicator / Basic Buffers
Part 73 = Multi Signal / TP-SL Buffers
Part 74 = EA reads buffers and executes
```

## 工程价值

完整链路：

```text
Market Structure
  ↓
Entity / State Machine
  ↓
Visual Layer
  ↓
Signal Buffers
  ↓
iCustom / CopyBuffer
  ↓
EA Execution
```

这正好对应平台设计：

```text
Detector
  ↓
SignalProvider
  ↓
SignalEvent
  ↓
RiskEngine
  ↓
OrderManager
```

## 最值得收藏的部分

### 1. Entity + State Machine

Gap 不只是矩形，而是带状态的 entity：

```text
fresh
partial
reaction
filled
historical
```

这个写法可以迁移到：

- FVG；
- Order Block；
- Supply / Demand；
- Session Range；
- Liquidity Zone。

### 2. Visual Layer 与 Signal Layer 分离

图表对象负责审查和解释，indicator buffer 负责机器读取。

```text
Chart Objects = human audit
Buffers       = machine contract
```

### 3. 多 buffer 输出

Part 73 / 74 把 entry、TP、SL 都放入 buffers，使 EA 可以独立执行。

### 4. 历史信号可回放

指标重建历史 gaps 和历史 signals，Strategy Tester 可以看到过去的 signal path。

### 5. EA 只做执行

Part 74 EA 的合理职责：

- 读取 buffer；
- 判断是否是新信号；
- 校验 SL/TP；
- 检查持仓；
- 下单；
- 管理 breakeven。

## 不应过度收藏的部分

- Weekend Gap Alpha 本身；
- 固定仓位；
- 简单 gap fill 假设；
- chart object 绘图细节；
- alert 文本和 UI 参数。

## 对 Python + MT5 平台的建议

抽象成：

```text
StructureDetector
StateMachine
SignalContract
SignalAdapter
ExecutionService
```

对于研究层，应输出：

```text
gap_size
gap_direction
time_since_gap
gap_state
distance_to_midpoint
distance_to_fill
signal_type
tp
sl
```

这些比“看到 gap 就交易”更有价值。

## 收藏评分

| 模块 | 收藏价值 |
|---|---:|
| Object Framework | 5/5 |
| State Machine | 5/5 |
| Buffer Contract | 5/5 |
| EA Execution Adapter | 4/5 |
| Gap 策略本身 | 2/5 |

