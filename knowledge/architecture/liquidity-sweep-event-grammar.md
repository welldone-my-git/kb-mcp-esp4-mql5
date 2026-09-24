# Liquidity Sweep Event Grammar

把 swing liquidity sweep 当作可观察事件，把确认与风险约束作为后续状态转换 / Gate。研究目标是理解 Episode 的条件结果，不把“扫流动性”直接等同交易信号。

## 状态与事件

```text
IDLE
  → SWING_CONFIRMED
  → SWEEP_OBSERVED
  → RECLAIM_CONFIRMED
  → OB_REGISTERED
  → WAIT_CONFIRMATION
  → STRUCTURE_CONFIRMED
  → QUALITY_ACCEPTED
  → ENTRY / OUTCOME

活动状态 → INVALIDATED | EXPIRED | REJECTED(reason)
```

Swing 需要因果可确认：pivot 只有在右侧确认 bar 已闭合后才可进入可交易状态；事件需保留 pivot identity，不能仅存“当前最近 swing”而丢掉来源。Sweep、reclaim、confirmation 使用 closed-bar 数据，所有时序语义显式记录 bar index / event time。

## 分层 Gate

1. **Structure**：swing 是否确认、是否未消耗、穿越深度是否过最低阈值、是否 reclaim。
2. **Context**：HTF trend、regime、session。只用决策时刻可见的已闭合数据；缺失数据策略显式配置。
3. **Confirmation**：确认方向、close 是否越过被冻结的 OB/body boundary、等待时限、动量/位移定义。
4. **Risk quality**：ATR 风险尺度、sweep extreme buffer、spread 成本和 stop distance。
5. **Execution**：报价、volume step、tick-value conversion、交易权限、broker retcode；通过不等于必然成交。

不同 gate 应分别留 `pass/fail/unknown`、测量值与 `reason_code`。确认以后发生的极端突破应转 `INVALIDATED`，时间超限则为 `EXPIRED`，不可混成同一种失败。

## Episode 数据与 Outcome

至少保存：

```text
episode_id, symbol, timeframe, session, direction
swing_id, swing_time, swing_price
sweep_time, sweep_high/low, sweep_depth_atr, reclaim_distance_atr
ob_high, ob_low, confirmation_time, confirmation_delay
trend_context, volatility_context, spread_context
gate_decisions[], order_id, deal_ids[], position_id
net_pnl, MFE, MAE, time_to_target, exit_reason
```

胜负率是 outcome 摘要，不是概率。拒绝、过期和失效 episode 也必须保留；否则只观察成交策略，会产生选择偏差。模型目标可以是阶段条件概率 `P(next_state | state, episode_history)`、后续 MFE/MAE、失败 hazard 或成本后期望收益，并按时间做 OOS 验证。

## 与现有系统的连接

- 可复用 [Session Episode Grammar](./session-episode-grammar.md) 的 episode/event 结构与 outcome audit。
- 输出 `SweepEvent` / `StructureEvent` 供 State Grammar、Feature Store、Meta Label 与 Projection Gate 使用。
- Projection / Signal Authority 不可跳过账户级 `RiskEngine`；事件识别器不直接下单。
- MQL5 实时层可增量推进 episode；Python Replay 应用同一规则，使用 golden cases 检查逐事件一致性。

## 来源

- [SMC Liquidity Sweep Scalper 源码研究条目](../articles/smc-liquidity-sweep-scalper-event-grammar.md)
- [MQL5 CodeBase 原文](https://www.mql5.com/en/code/77094)
