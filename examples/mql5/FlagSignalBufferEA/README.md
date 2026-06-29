# Flag Signal Buffer EA

来源：

- 文章：https://www.mql5.com/en/articles/22607
- 标题：Price Action Analysis Toolkit Development (Part 70): Turning Flag Pattern Signals into Automated Trade Execution
- 作者：Christian Benjamin（LynnChris）
- 发布日期：2026-05-26

## 定位

```text
Indicator Buffer → EA Execution Contract
```

这组源码的价值不在于 Flag 策略本身，而在于它演示了 MQL5 中一个可复用的信号交付模式：

```text
Indicator
  ├── 检测形态
  ├── 确认 breakout
  ├── 写入 Buy / Sell / Metadata buffers
  ↓
EA
  ├── iCustom() 获取 indicator handle
  ├── CopyBuffer() 读取闭合 K 线信号
  ├── 做过滤和执行
  └── 管理持仓
```

## 文件

| 文件 | 作用 |
|---|---|
| [Flag_Pattern_Detector.mq5](./MQL5/Indicators/Flag_Pattern_Detector.mq5) | 指标端形态检测与信号 buffer 输出 |
| [FlagSignalEA.mq5](./MQL5/Experts/FlagSignalEA.mq5) | EA 端通过 `iCustom` / `CopyBuffer` 消费指标信号并下单 |
| [DisciplineDashboard.mq5](./MQL5/Indicators/DisciplineDashboard.mq5) | 纪律/状态展示辅助指标 |

## 可收藏点

1. 指标与 EA 解耦

   指标负责检测和发布信号，EA 不重复实现形态检测逻辑。EA 只消费稳定的 buffer contract。

2. Buffer schema

   `Flag_Pattern_Detector.mq5` 暴露 3 个 buffer：

   ```text
   0 = buy signal
   1 = sell signal
   2 = pole height / metadata
   ```

   这相当于 MQL5 版本的 `SignalEvent` schema。

3. 闭合 K 线读取

   EA 读取 `buf[1]` 而不是 `buf[0]`，避免在当前未收盘 K 线上重复交易或重绘。

4. 启动补扫

   EA 启动时扫描最近若干 bar，处理 EA 刚挂载时已出现但未执行的信号。这适合 Replay / Live 切换场景。

5. 执行层独立

   EA 端额外加入趋势过滤、成交量过滤、动态 SL/TP、EMA exit。检测逻辑仍留在指标端。

## 可迁移到平台的设计

```text
MQL5 Indicator Buffer
  ↓
IndicatorSignalAdapter
  ↓
SignalEvent
  ↓
RiskEngine
  ↓
OrderManager
  ↓
BrokerAdapter
```

在 Python 平台里，对应关系是：

```text
model.predict_proba()
  ↓
SignalEvent
  ↓
RiskEvent / OrderEvent / FillEvent
```

因此，这份源码应归类为“信号接口与执行契约”，而不是“Flag 策略”。

## 不建议直接复用的部分

- Flag 形态规则本身缺少跨市场统计验证；
- 固定 lot 不是生产级资金管理；
- EA 内过滤逻辑仍偏 demo；
- 指标路径依赖终端安装位置，生产环境需要统一 adapter 或 wrapper。

