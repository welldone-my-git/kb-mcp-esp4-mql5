# Repository Pattern：Trade History Access Abstraction

来源：

- 文章：https://www.mql5.com/en/articles/22958
- 标题：The Repository Pattern in MQL5: Abstracting Trade History Access for Testable EA Logic
- 作者：Ushana Kevin Iorkumbul
- 发布日期：2026-06-17

## 定位

```text
Data Access Layer / Testable Analytics / Repository Pattern。
```

这份源码不是策略，而是把 MT5 History API 从 analytics 逻辑中隔离出来，使统计模块可以用 live history 或 mock dataset 测试。

## 文件

| 文件 | 作用 |
|---|---|
| `TradeRecord.mqh` | `STradeRecord` 统一交易记录结构 |
| `ITradeRepository.mqh` | repository 抽象接口 |
| `LiveTradeRepository.mqh` | 基于 `HistorySelect()` / `HistoryDealsTotal()` / `HistoryDealGet*()` 的 live 实现 |
| `MockTradeRepository.mqh` | 固定内存数据集，用于 deterministic offline testing |
| `AnalyticsEngine.mqh` | 只依赖 `ITradeRepository*` 的统计引擎 |
| `EquityCurvePanel.mqh` | 使用 repository 数据绘制 equity curve |
| `RepositoryPatternEA.mq5` | demo EA，演示 live/mock repository 互换 |

## 值得抽取的模块

### 1. Canonical Trade Record

`STradeRecord` 将 MT5 deals/history 转换成统一 trade record：

```text
open_time
close_time
open_price
close_price
volume
profit
commission
swap
symbol
direction
```

这一步非常关键：上层 analytics 不应该直接依赖 `HistoryDealGet*()`。

### 2. Repository Interface

`ITradeRepository` 提供统一查询接口：

```text
GetTradeCount()
GetClosedTrade(index)
GetDailyPnL(date)
GetWinRate()
GetTotalProfit()
GetMaxDrawdown()
GetAverageTrade()
GetRepositoryType()
```

Live 和 Mock 都实现同一接口。

### 3. Analytics Dependency Injection

`CAnalyticsEngine` 构造时接收：

```text
ITradeRepository *repo
```

因此 analytics 层不知道数据来自：

- MT5 live history；
- mock dataset；
- CSV；
- DuckDB；
- replay log。

## 平台迁移建议

Python / OpenAlgo 风格平台中应升级为：

```text
TradeRepository
├── LiveBrokerRepository
├── PaperRepository
├── ReplayRepository
├── DuckDBRepository
└── MockRepository

AnalyticsEngine
├── win_rate()
├── pnl()
├── drawdown()
├── exposure()
└── trade_distribution()
```

## 注意事项

当前源码中部分统计方法仍在 repository 内部计算。平台版建议进一步拆分：

```text
Repository = 只负责取数据
Analytics = 只负责计算指标
```

否则 repository 会膨胀成 data access + business logic 混合层。
