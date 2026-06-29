# Support Resistance Monitor

来源：

- 文章：https://www.mql5.com/en/articles/21961
- 标题：Price Action Analysis Toolkit Development (Part 67): Support Resistance Tool
- 作者：Christian Benjamin（LynnChris）
- 源码：[SupportResistanceMonitor.mq5](./SupportResistanceMonitor.mq5)

## 定位

```text
Horizontal Line → Support / Resistance Event Monitor
```

这份源码与 Manual Trendline Sync 属于同一类：把人工对象转成机器可处理事件。

## 可收藏点

- 扫描 `OBJ_HLINE`；
- 将水平线分类为 support / resistance；
- `SMonitoredLine` 保存状态；
- 监控 touch、bounce、breakout、retest；
- 使用按钮触发 sync / clear；
- 对 breakout 之后的 retest 做状态跟踪。

## 平台映射

```text
OBJ_HLINE
  ↓
SupportResistanceEntity
  ↓
Touch / Breakout / Retest Event
  ↓
Feature / Signal
```

适合作为 SMC / ICT 基础组件：

- liquidity level；
- session high / low；
- previous day high / low；
- supply / demand 边界；
- manual level audit。

## 不建议直接复用的部分

- arrow / alert 只是 demo；
- support / resistance 类型依赖人工按钮选择；
- 没有输出 indicator buffer；
- 更适合做 event / feature，不适合直接下单。

