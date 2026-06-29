# Weekend Gap Signal Pipeline

来源：

- Part 72：https://www.mql5.com/en/articles/22884
- Part 73：https://www.mql5.com/en/articles/22993
- Part 74：https://www.mql5.com/en/articles/23015
- 作者：Christian Benjamin（LynnChris）

相关前置：

- Part 71 Weekend Gap Object Framework 已收录于 [WeekendGapIndicator](../WeekendGapIndicator/)

## 定位

```text
Detection → Indicator → Signal Buffers → EA Execution
```

这组源码展示了 Weekend Gap 从图形对象框架进一步走向可交易信号接口的过程。收藏价值主要是工程链路，不是 Weekend Gap Alpha。

## 文件

| 目录 | 文件 | 作用 |
|---|---|---|
| [Part72_GapFillIndicator](./Part72_GapFillIndicator/) | `WeekendGapSignalIndicator.mq5` | Gap fill 检测、对象绘制、4-buffer 信号输出 |
| [Part72_GapFillIndicator](./Part72_GapFillIndicator/) | `WeekendGapSignalTestEA.mq5` | 最小 `iCustom` / `CopyBuffer` 消费示例 |
| [Part73_MultiSignalIndicator](./Part73_MultiSignalIndicator/) | `WeekendGapMultiSignal.mq5` | 多信号记录、TP/SL buffer、信号去重 |
| [Part74_BufferEA](./Part74_BufferEA/) | `WeekendGapMultiSignal.mq5` | 与 EA 配套的 6-buffer 指标版本 |
| [Part74_BufferEA](./Part74_BufferEA/) | `Gap_Trading_EA.mq5` | 从指标 buffer 读取 entry / TP / SL 并执行交易 |

## Buffer 演进

Part 72：

```text
0 = Buy signal
1 = Sell signal
2 = Gap state
3 = Fill price
```

Part 73 / 74：

```text
0 = Buy arrow
1 = Sell arrow
2 = Buy TP
3 = Buy SL
4 = Sell TP
5 = Sell SL
```

这已经接近一套完整的 `SignalEvent` 合约：

```text
direction
entry reference
take_profit
stop_loss
state / metadata
signal_time
```

## 可收藏点

1. Indicator 负责业务检测，EA 负责执行

   Gap 检测、状态更新、TP/SL 计算在指标侧完成；EA 只读取 buffer、校验并执行。

2. 信号去重

   源码中使用 `signalPublished`、`lastSignalBarTime` 等字段避免同一根 bar 或同一个 gap 重复触发。

3. 闭合 bar 语义

   EA 读取已收盘 bar，指标也围绕已确认 bar 更新，适合严肃回测与 live 一致性。

4. 可回测 buffer

   历史信号被写回 indicator buffers，使 Strategy Tester 能够重放信号，不只依赖实时 alert。

5. 执行前验证

   Part 74 EA 在下单前检查 SL/TP、broker stop distance、重复信号、已有持仓等条件。

6. 视觉层与信号层并存

   图形对象用于人工审查，buffers 用于机器执行。两者不应混为一层。

## 平台映射

```text
WeekendGapMultiSignal
  ↓
IndicatorSignalAdapter
  ↓
SignalEvent(direction, stop_loss, take_profit, metadata)
  ↓
RiskEngine
  ↓
OrderManager
```

对于 Python + MT5 平台，建议把 Weekend Gap 逻辑拆成：

```text
GapDetector
GapStateMachine
SignalBufferContract
IndicatorSignalAdapter
ExecutionEA / BrokerAdapter
```

## 不建议直接复用的部分

- Gap fill 交易逻辑缺少足够统计验证；
- 固定 lot 和单品种执行不适合作为生产模板；
- buffer 编号是隐式约定，生产环境需要显式版本号和 schema 文档；
- chart object 视觉逻辑较多，研究框架应把 visual layer 与 signal layer 分开。

