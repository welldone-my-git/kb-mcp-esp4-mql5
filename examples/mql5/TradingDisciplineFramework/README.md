# Trading Discipline Framework：Engineering Trading Discipline into Code

来源：

- 作者：https://www.mql5.com/en/users/lynnchris
- 作者：Christian Benjamin
- 系列：Engineering Trading Discipline into Code

## 收录文章

| Part | 文章 | 链接 | 核心 |
|---:|---|---|---|
| 1 | Creating Structural Discipline in Live Trading with MQL5 | https://www.mql5.com/en/articles/21273 | daily trade cap、daily profit/loss stop 的最小 demo |
| 2 | Building a Daily Trade Limit Enforcer for All Trades in MQL5 | https://www.mql5.com/en/articles/21313 | daily trade limit include + dashboard + enforcer |
| 3 | Enforcing Symbol-Level Trading Boundaries with a Whitelist System in MQL5 | https://www.mql5.com/en/articles/21493 | symbol whitelist、dashboard、`OnTradeTransaction` enforcer |
| 4 | Enforcing Trading Hours and News Disabling in MQL5 | https://www.mql5.com/en/articles/21515 | session file、news CSV、trading-hours/news blocker |
| 5 | Account-Level Risk Enforcement in MQL5 | https://www.mql5.com/en/articles/21995 | account risk, SL/TP/R:R, equity risk correction |
| 6 | Building a Unified Discipline Framework in MQL5 | https://www.mql5.com/en/articles/22560 | `CDisciplineEngine` 统一 symbol/session/news/daily-limit |
| 7 | Automating Equity Protection Through Governance Logic | https://www.mql5.com/en/articles/22833 | equity drawdown governance、cooldown、state-driven protection |

## 定位

```text
Trade Governance / DisciplineEngine / Pre-Trade and Post-Trade Guard。
```

这不是交易策略系列。真正价值是把交易纪律从“人工自觉”变成可执行的系统约束。

## 目录说明

```text
Part01_StructuralDiscipline/
Part02_DailyTradeLimit/
Part03_SymbolWhitelist/
Part04_TradingHoursNews/
Part05_AccountRisk/
Part06_UnifiedFramework/
Part07_EquityGovernance/
```

## 核心设计提炼

### 1. Daily Trade Limit

Part 2 使用 `DTL` namespace 管理：

- daily state；
- trade count；
- amber zone；
- `IsTradingAllowed()`；
- dashboard；
- enforcer。

关键点：通过 `OnTradeTransaction()` 监听真实交易事件，而不是只统计 EA 自己的信号。

### 2. Symbol Whitelist

Part 3 使用 `SWL` namespace 管理：

- `SaveWhitelist()`；
- `LoadWhitelist()`；
- `ParseWhitelist()`；
- `IsSymbolAllowed()`；
- blocked attempt logging。

关键点：symbol universe 是配置，不应散落在策略代码里。

### 3. Trading Hours + News

Part 4 使用文件配置：

- `TradingSessions.txt`；
- `NewsEvents.csv`；
- session permission；
- news blackout；
- dashboard + enforcer。

这与前面收录的 CalendarEngine / NewsFilter 可以合并升级。

### 4. Account-Level Risk

Part 5 关注：

- risk percent；
- R:R；
- SL/TP 校验；
- equity-based exposure；
- 自动纠偏。

它应放在 `RiskEngine`，而不是 strategy。

### 5. Unified Discipline Engine

Part 6 是系列核心：

```text
CDisciplineEngine
├── IsTradeAllowed(symbol)
├── IsSymbolAllowed(symbol)
├── IsTradingHoursAllowed()
├── IsDailyLimitAllowed()
├── GetNextSession()
└── GetNextNews()
```

这是可迁移到平台的主模板。

### 6. Equity Governance

Part 7 把 equity protection 做成 governance logic：

- drawdown pressure；
- cooldown；
- trade authorization；
- state-driven risk control。

## 平台迁移建议

建议抽象为：

```text
DisciplineEngine
├── SymbolWhitelistRule
├── DailyTradeLimitRule
├── SessionRule
├── NewsRule
├── AccountRiskRule
├── EquityGovernanceRule
├── CanTrade(context)
├── BeforeOrder(order, context)
├── AfterFill(fill, context)
└── AuditLog
```

Python / OpenAlgo-style 平台对应：

```text
trading/risk.py
trading/execution.py
storage/decision_log.py
storage/trade_log.py
core/events.py
```

## 生产注意

- Enforcer 会主动取消订单/平仓，实盘必须谨慎；
- 文件配置需要版本化与审计；
- `OnTradeTransaction()` 逻辑要区分 manual / EA / broker generated events；
- 多 EA / 多 magic / netting / hedging 需要单独设计；
- dashboard 与 enforcement 应解耦。

## 收藏结论

这是 LynnChris 目前最值得收藏的系列之一。它的长期价值是 Trade Governance Framework，而不是某个具体限制规则。
