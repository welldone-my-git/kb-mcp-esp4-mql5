# Indicator Buffer → EA Execution Contract

来源：

- Price Action Analysis Toolkit Development Part 70：https://www.mql5.com/en/articles/22607
- Price Action Analysis Toolkit Development Part 74：https://www.mql5.com/en/articles/23015
- 作者：Christian Benjamin（LynnChris）
- 相关源码：
  - [FlagSignalBufferEA](../../examples/mql5/FlagSignalBufferEA/)
  - [WeekendGapSignalPipeline](../../examples/mql5/WeekendGapSignalPipeline/)

## 结论

这类文章真正值得收藏的是 MQL5 的信号交付架构：

```text
Indicator owns detection.
EA owns execution.
Buffers are the contract.
```

它不是某个 Flag / Gap 策略，而是“指标如何把确定性信号交给 EA”的标准模板。

## 为什么重要

传统 EA 常见问题：

```text
OnTick()
  ├── 检测信号
  ├── 画图
  ├── 过滤
  ├── 下单
  ├── 管仓
  └── 日志
```

结果是策略、视觉、执行、风控全部耦合。

Buffer contract 改成：

```text
Indicator
  ├── 只负责检测
  ├── 输出 buffers
  └── 可视化辅助

EA
  ├── 通过 iCustom() 获取 handle
  ├── 通过 CopyBuffer() 读取闭合 bar
  ├── 校验信号
  ├── 调用 Risk / Order / Broker
  └── 记录执行
```

这与平台中的事件模型一致：

```text
Indicator Buffer ≈ SignalEvent
```

## 推荐的 Buffer Schema

最低限度：

```text
0 = long_signal
1 = short_signal
```

更实用：

```text
0 = long_signal_price
1 = short_signal_price
2 = long_take_profit
3 = long_stop_loss
4 = short_take_profit
5 = short_stop_loss
```

生产级建议额外提供：

```text
signal_id
signal_time
confidence
regime
schema_version
```

MQL5 indicator buffer 只能承载 double，因此复杂字段需要通过：

- 约定 buffer 编号；
- GlobalVariable；
- 文件 / SQLite；
- EA 侧二次查询；
- 或统一 adapter 转换。

## 必须遵守的工程约束

1. 只消费闭合 bar

   EA 默认读取 shift 1，不读取 shift 0，除非明确支持实时变动信号。

2. 明确 EMPTY_VALUE 语义

   无信号必须写 `EMPTY_VALUE`，不要用 0 混用无信号和值。

3. 信号去重

   至少记录：

   ```text
   last_signal_bar_time
   last_signal_id
   ```

4. Indicator 不直接交易

   指标可以画图、报警、写 buffer，但不应调用交易接口。

5. EA 不重复检测业务规则

   EA 可以做风控和执行校验，但不应复制 indicator 的完整检测逻辑。

6. Schema 文档化

   每个 buffer 编号、含义、shift 语义、单位都必须写进 README。

## 平台迁移

MQL5：

```text
iCustom()
CopyBuffer()
SignalAdapter
```

Python：

```text
feature_engine
model.predict_proba
SignalEvent
```

统一后：

```text
SignalProvider
  ↓
SignalEvent
  ↓
RiskEngine
  ↓
OrderManager
```

这样 Replay / Paper / Live 可以复用同一套下游管线。

## 收藏判断

| 维度 | 评分 |
|---|---:|
| 策略 Alpha | 低 |
| MQL5 工程价值 | 高 |
| 平台迁移价值 | 高 |
| 是否应收录 | 是 |

归档到：

```text
Architecture Knowledge / Signal Buffer Contract
```

