# Repository Pattern：交易数据访问抽象

参考来源：

- [Repository Pattern in MQL5](../articles/repository-pattern-testable-ea-analytics.md)
- 源码：[examples/mql5/RepositoryPattern](../../examples/mql5/RepositoryPattern/)

## 目标

将数据访问与统计/策略逻辑分离：

```text
History API / Broker API / DuckDB / Mock
        ↓
Repository Interface
        ↓
Analytics / Risk / Portfolio
```

## 为什么需要

直接在 analytics 里调用 broker/history API 会导致：

- 无法离线测试；
- 无法构造边界案例；
- replay/paper/live 数据源不一致；
- 统计逻辑和平台状态耦合；
- 后续切 DuckDB / Parquet 需要大改。

## 最小接口

```python
class TradeRepository:
    def get_trades(self, start, end, symbol=None) -> list[TradeRecord]: ...
    def get_orders(self, start, end, symbol=None) -> list[OrderRecord]: ...
    def get_fills(self, start, end, symbol=None) -> list[FillRecord]: ...
```

不要把复杂统计放进 repository。Repository 只负责读取和转换 canonical records。

## 推荐实现

```text
Repositories
├── MT5HistoryRepository
├── PaperRepository
├── ReplayRepository
├── DuckDBRepository
└── MockRepository
```

## Canonical Records

平台应先统一：

```text
OrderRecord
FillRecord
TradeRecord
PositionRecord
PortfolioSnapshot
```

这样 analytics、risk、API、dashboard 不需要知道底层来自 MT5、PaperBroker 还是 Replay。

## 设计原则

```text
Repository 不做交易决策。
Repository 不直接调用 Strategy。
Repository 不保存全局状态。
Repository 输出 canonical data。
```

## 与平台模块关系

| 模块 | Repository 用途 |
|---|---|
| `trading/portfolio.py` | 读取历史 fills / positions 做恢复 |
| `storage/trade_log.py` | 提供 DuckDB-backed trade records |
| `api/main.py` | 查询 orders / trades / positions |
| `research` | 离线分析历史成交 |
| `tests` | 用 MockRepository 构造确定性样本 |
