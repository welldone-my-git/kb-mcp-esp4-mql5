# Manual Trendline Sync

来源：

- 文章：https://www.mql5.com/en/articles/21704
- 标题：Price Action Analysis Toolkit Development (Part 64): Manual Trendline Sync
- 作者：Christian Benjamin（LynnChris）
- 源码：[TrendlineMonitor_EA.mq5](./TrendlineMonitor_EA.mq5)

## 定位

```text
Manual Chart Object → Event Monitor
```

这份源码的价值不是“趋势线突破策略”，而是把人工画出的 `OBJ_TREND` 转成可监控对象。

## 可收藏点

- `OnChartEvent()` 监听按钮和对象删除；
- 扫描图表中的趋势线并纳入监控列表；
- `SMonitoredLine` 保存对象名、side、alert state 和触发状态；
- 计算价格相对趋势线的位置；
- 检测 approaching / touch / breakout / retest；
- 用 prefix 管理 EA 自己创建的按钮、面板和标记对象。

## 平台映射

```text
Manual Chart Object
  ↓
ObjectMonitor
  ↓
GeometryEvent
  ↓
SignalEvent / Feature
```

适合迁移为：

```text
ChartObjectEventMonitor
TrendlineFeatureGenerator
ManualObjectSignalAdapter
```

## 不建议直接复用的部分

- 直接把突破当交易信号；
- UI 按钮和 alert 逻辑与事件检测耦合；
- 未形成统一事件 schema；
- 未接入 RiskEngine / OrderManager。

