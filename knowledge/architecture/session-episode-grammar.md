# Session Episode Grammar

将 Session Sweep 到 Projection 的多步确认链建模为可回放、可审计的 Episode Engine。MQL5 指标只作为规则来源；Python 研究层保存事件与结果样本，执行层消费通过 Gate 的 Projection。

## 分层

```text
ClosedBar / SessionRange
        ↓
Event Detector
        ↓
Episode Store
        ↓
Grammar State Machine
        ↓
Acceptance / Failure Gate
        ↓
Projection Gate
        ↓
Outcome Audit → Feature Store
```

## 事件与 Episode

建议统一事件：

```text
SessionRangeCompleted
LiquiditySweepDetected
MarketStructureShiftConfirmed
DisplacementQualified
FairValueGapFormed
FvgRetestAccepted
EpisodeInvalidated
EpisodeExpired
ProjectionCreated
OutcomeObserved
```

`Episode` 保存 `episode_id`、symbol、session、direction、状态、各事件时间/bar index、sweep extreme、swing level、FVG bounds、ATR snapshot、超时计数、失效原因和特征快照。事件都来自已闭合 bar，且具备稳定去重键，支持同一输入重复回放而不重复生成 Projection。

## 状态语法

```text
IDLE
  → SESSION_READY
  → SWEEPED
  → MSS_CONFIRMED
  → FVG_CONFIRMED
  → RETEST_ACCEPTED
  → PROJECTED

任一活动状态 → INVALIDATED | EXPIRED
```

规则不变量：

1. `SESSION_READY` 必须引用已结束且数据完整的 session range。
2. MSS 必须突破 Sweep 发生前已经确认的 swing；Swing 的确认规则应固定，不能使用未来 bar。
3. Displacement 是独立观测字段；若定义要求它与 MSS 同 bar，则将其作为 MSS 转换条件并保留测量值。
4. FVG 必须晚于或与 MSS 同 bar；retest 必须严格晚于 FVG bar。
5. MSS 后越过冻结的 sweep extreme 会使 episode 失效。
6. 每个转换有最大等待 bars；超时产生带 reason code 的 `EXPIRED`，不静默丢样本。
7. Score 是特征/规则 confluence，不是 calibrated probability；交易决策使用明确 Gate 与独立校准结果。

## Projection Gate 与审计

Projection 先检查 stop 距离、结构风险上限、对侧流动性方向、最小 RR 和目标几何关系。通过后输出 entry reference、stop、targets 与所需风险参数；由 Risk Engine 决定仓位，不由指标评分直接决定交易量。

Outcome Audit 从 projection/entry 之后的观测开始，记录 MFE、MAE、first-passage、time-to-target 和 episode 结束原因。同一 OHLC bar 同时命中止损与目标时采用显式 ambiguity policy（保守默认 stop-first）；tick 数据可用时保存 tick 级判定结果，不能将 bar 审计称为 tick 级成交仿真。

## 在线与研究模式

- **Replay/研究**：允许确定性地重建历史 episode；输出每个候选的完整事件链和失败阶段。
- **Live**：以新闭合 bar 增量推进状态，只更新受影响的 session/episode；为重启恢复持久化 state snapshot 与最后处理 bar。
- **特征分析**：保留阶段条件下的转移分母，估计 `P(next_state | current_state, episode_history)`，并按时间做样本外评估。

原指标每次更新会重扫有限历史，便于复现但重复计算较多。Production 版本可用相同规则与 Golden Replay 对照，改为增量更新，并定期执行全量重建校验。

## 来源

- [Session Manipulation and Algorithmic Reaction Tracker（MQL5 CodeBase）](https://www.mql5.com/en/code/77071)
- [研究摘要](../articles/session-manipulation-episode-grammar.md)
