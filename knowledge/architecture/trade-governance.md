# Trade Governance：交易纪律与执行前治理层

参考来源：

- [Engineering Trading Discipline：交易纪律工程化框架](../articles/trading-discipline-framework-lynnchris.md)

## 目标

在订单进入执行层之前，统一评估：

```text
这个交易现在是否允许？
如果不允许，原因是什么？
如果允许，是否需要降仓或附加条件？
```

## 位置

```text
SignalEvent
  ↓
RiskEngine
  ↓
TradeGovernance
  ↓
RiskEvent
  ↓
OrderManager
```

## 核心规则

```text
SymbolWhitelistRule
DailyTradeLimitRule
SessionRule
NewsRule
AccountRiskRule
EquityGovernanceRule
ExposureRule
CooldownRule
```

## 标准输出

```text
DisciplineResult
├── allowed
├── action          # allow / warn / reduce / block
├── blocked_by
├── reason
├── severity
├── adjusted_size
└── metadata
```

不要只返回 bool。生产系统必须知道“为什么不能交易”。

## 与 RiskEngine 的关系

RiskEngine 负责风险计算：

```text
position size
stop distance
exposure
drawdown
```

TradeGovernance 负责规则授权：

```text
symbol allowed?
session open?
news blackout?
daily count ok?
equity state ok?
```

两者可以在 MVP 中合并，但架构上应分清。

## 日志要求

每次阻断或降仓必须进入：

```text
DecisionLog
AuditLog
```

字段至少包括：

```text
timestamp
symbol
signal_id
rule_id
action
reason
metadata
```

## 原则

```text
Strategy 不直接绕过治理层。
Broker 不负责解释规则。
Governance 不直接下单。
```
