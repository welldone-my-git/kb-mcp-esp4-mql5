# Engineering Trading Discipline：交易纪律工程化框架

来源：

- 作者：https://www.mql5.com/en/users/lynnchris
- 系列：Engineering Trading Discipline into Code
- 源码目录：[examples/mql5/TradingDisciplineFramework](../../examples/mql5/TradingDisciplineFramework/)

## 收藏结论

收藏价值：★★★★★

这是 LynnChris 最值得收录的系列之一。它不是策略，而是交易治理层：

```text
Trade Governance / DisciplineEngine / Execution Guard
```

## 为什么重要

很多 EA 的风险问题不是信号，而是缺少统一纪律：

- 今天交易次数超限；
- 交易了不该交易的 symbol；
- 新闻时间仍开仓；
- session 外交易；
- 没有 SL/TP；
- R:R 不合格；
- drawdown 后继续交易；
- 多 EA 互相绕过规则。

这个系列把这些规则从“人工习惯”变成可执行约束。

## 系列结构

| Part | 核心模块 | 值得保留 |
|---:|---|---|
| 1 | Structural Discipline Demo | daily trade cap、daily P/L stop 的最小原型 |
| 2 | Daily Trade Limit | `DTL` namespace、dashboard、enforcer |
| 3 | Symbol Whitelist | `SWL` namespace、file config、blocked attempt log |
| 4 | Trading Hours + News | session 文件、news CSV、blackout window |
| 5 | Account-Level Risk | risk percent、SL/TP/R:R 纠偏 |
| 6 | Unified Framework | `CDisciplineEngine` 统一 gate |
| 7 | Equity Governance | drawdown pressure、cooldown、state-driven authorization |

## 最值得抽取：CDisciplineEngine

Part 6 的核心接口：

```text
IsTradeAllowed(symbol)
IsSymbolAllowed(symbol)
IsTradingHoursAllowed()
IsDailyLimitAllowed()
GetDailyLimit()
GetNextSession()
GetNextNews()
```

这就是平台版的：

```text
RiskEngine.can_trade()
```

但平台实现要更进一步，返回原因和审计记录，而不是只返回 bool。

## 建议平台接口

```python
class DisciplineEngine:
    def can_trade(self, context) -> DisciplineResult: ...
    def before_order(self, order, context) -> DisciplineResult: ...
    def after_fill(self, fill, context) -> None: ...
```

结果结构：

```text
allowed
severity
blocked_by
reason
rule_outputs
metadata
```

## 对 quant_platform 的映射

```text
SignalEvent
  ↓
RiskEngine
  ↓
DisciplineEngine
  ├── SymbolWhitelistRule
  ├── DailyTradeLimitRule
  ├── SessionRule
  ├── NewsRule
  ├── AccountRiskRule
  └── EquityGovernanceRule
  ↓
RiskEvent
  ↓
OrderManager
```

## 不应照搬的地方

- 不要让每个规则直接平仓/删单；
- 不要让 dashboard 和 enforcement 强耦合；
- 不要用多个 EA 分散治理逻辑；
- 不要只返回 bool；
- 不要忽略 multi-symbol / multi-magic / netting vs hedging。

更稳健的结构：

```text
Rule evaluates
  ↓
RiskEngine decides
  ↓
ExecutionService acts
  ↓
AuditLog records
```

## 生产升级建议

- 所有 blocked action 写入 DecisionLog；
- 每条规则输出 rule_id；
- 统一 rule priority；
- 支持 warn / reduce / block 三种动作；
- 支持 paper/live/replay 一致评估；
- 规则配置放入 DuckDB/JSON，而不是散落文件。

## 最终判断

这个系列应进入平台架构一线资料。它补的是 OpenAlgo-style 中台中最容易被忽视的一层：

```text
Trade Governance
```

没有这一层，策略越多，风险越不可控。
