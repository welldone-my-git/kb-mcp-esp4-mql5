# SMC Liquidity Sweep Scalper：从 EA 规则还原为事件语法

```yaml
source_url: https://www.mql5.com/en/code/77094
source_title: SMC Liquidity Sweep Scalper (Order Block EA with Live Win-Rate Tracking)
author: Ali Rajput
published: 2026-09-07
updated: 2026-09-15
source_status: source_downloaded
code_status: read_only_review
checked_at: 2026-09-24
local_attachment: download/77094.zip (ignored; not redistributed)
```

## 结论

值得收录为一个小型、机械化的 Liquidity Sweep → Confirmation 案例。最值得借鉴的是“先观测 sweep，再等待独立确认，并将质量条件分层记录”的流程；不是把 SMC 标签或历史胜率当成 Alpha。源码自述是 Phase 1/1.5 MVP，只保留一个最新 swing high/low、单一 pending setup、单个活动仓位，并假设净额账户和单 EA 管理单品种。

## 源码精确流程

```text
闭合 K 线更新确认 swing
        ↓
未被 sweep 的最近 swing 被刺穿且收盘 reclaim
        ↓
冻结 sweep candle body / wick extreme
        ↓
随后最多 N 根闭合 bar 等待 close 突破 body
        ↓
confirmation range、spread、SL/ATR、SL/spread 检查
        ↓
当前 Ask/Bid 市价单 + 固定 R 倍 TP + 风险百分比手数
```

### 1. Swing 更新

`UpdateSwingPoints()` 每根新 bar 复制 OHLC，取 `pivot = InpSwingLookback + 1`，检查 pivot 两侧各 `InpSwingLookback` 根 bar 的 high/low。代码用非严格比较（相邻值相等时也可能接受 pivot），只保留最近的一个 high 和一个 low，并分别维护 `swept` 标志；不是完整 swing 结构树。

### 2. Sweep 与方向

- 看空候选：`high[1] > lastSwingHigh + MinSweepATRMult * ATR[1]` 且 `close[1] < lastSwingHigh`。
- 看多候选：`low[1] < lastSwingLow - MinSweepATRMult * ATR[1]` 且 `close[1] > lastSwingLow`。
- 被刺穿的 swing 立即标记 swept。只有此时 HTF 趋势过滤器允许该方向，才创建 pending setup。
- Order Block 区域是 sweep bar 的实体 `[min(open,close), max(open,close)]`；SL 参考的是该 bar 的 wick extreme。

### 3. Confirmation / 超时

后续新 bar 才进入 `CheckConfirmationAndEnter()`，递增等待计数；超过 `InpMaxConfirmationBars` 就过期。看多要求闭合 close 高于 sweep candle body high，看空要求低于 body low。确认 bar 的**全振幅 `high-low`** 必须至少为 `InpMinConfirmRangeATRMult * ATR`；这不是实体大小/方向性 displacement 的检验。confirmation 本身与 sweep 不能是同一根 bar。

通过结构确认后依次做：最大 spread；基于 sweep extreme 和 ATR buffer 的 SL；`SL distance >= ATR floor` 且 `SL distance >= spread multiple`（等价于需超过两个下限中的较大者）；风险金额按 balance × risk% 计算 lot；TP 为固定 `RewardRatio × SL distance`。订单以当前新 bar 的 Ask/Bid 市价发送，而不是回填到确认 bar 的 close。

## Gate 清单与语义

| 阶段 | 代码条件 | 建议作为事件/特征记录 |
|---|---|---|
| Session | 可选 server-time hour filter，只在寻找新 sweep 时调用 | session id、server-time window |
| Swing | 最近一个 pivot high/low、单一 swept 标志 | pivot time/price、pivot strength、age |
| Sweep | ATR 最小穿透 + close reclaim | side、depth/ATR、wick/body、reclaim distance |
| Trend | HTF price vs EMA | HTF timeframe、close/EMA、是否 closed bar |
| Confirm | N bars 内 close 穿过 sweep body | delay、body break distance、bar range/ATR |
| Execution quality | spread 上限、SL/ATR、SL/spread | spread、ATR、结构风险、tick value source |
| Outcome | 仓位关闭后按净 deal PnL 记 WIN/LOSS | fees、net PnL、MFE/MAE、exit reason |

逻辑可以概括为：

\[
Entry = Sweep \land Confirmation \land TrendGate \land MomentumGate \land VolatilityRiskGate \land ExecutionGate
\]

但源码没有真正的多阶段模型分数或概率输出；`Scorecard` 只是按 bullish/bearish 方向累计本 EA 已结束交易的 win rate。

## 重要实现边界 / 研究风险

- **HTF 过滤用未完成 bar**：`TrendAllowsBuy/Sell()` 调用 `iClose(..., 0)` 和 EMA buffer shift 0。实时值会随高周期当前 bar 变化；严格无重绘研究版应对齐并使用已闭合 HTF bar，同时处理时间对齐。
- **Trend filter fail-open**：EMA buffer 尚不可用时返回 `true`，即缺数据反而放行。生产 Gate 通常应 `UNKNOWN/BLOCK`，或通过明确配置选择 fail-open。
- **Session 只在 sweep 检测时检查**：setup 可在 session 结束后才确认并入场；若意图限制实际入场时段，需要在下单前再检查一次。
- **Pending setup 无 sweep-extreme 失效规则**：等确认期间若价格继续越过 frozen extreme，代码没有立即产生 invalidation；只等待确认或超时。研究版应显式区分 INVALIDATED 与 EXPIRED。
- **在线 Scorecard 不是概率模型**：仅按 bullish/bearish 汇总二元胜负，样本数可能很小，不分 symbol、regime、session、setup quality；重启后计数重置。图上的历史 win rate 也不是当前候选的校准概率。
- **执行/账户假设**：代码明确提示 netting、单品种、单仓位约束。多 EA/手工仓位或 hedging 账户需重新设计 ticket、position identifier 和交易归属。
- **仓位风险换算需加强**：代码用 `SYMBOL_TRADE_TICK_VALUE`，没有区分 LOSS/PROFIT tick value；`NormalizeDouble(lot, 2)` 也不保证适配任意 volume step。应复用平台的 broker-aware RiskEngine，并核验实际成交 retcode、止损限制与费用。
- **验证证据弱**：页面列出的不同品种交易数低（例如 USDCNH 7 笔），结果跨品种差异大。作者也标明 early build；不能视为稳健策略或可直接部署的参数。

## 转为 Liquidity Sweep Event Grammar

```text
SWING_CONFIRMED
  → LIQUIDITY_TAKEN
  → RECLAIM_CONFIRMED
  → OB_REGISTERED
  → WAIT_STRUCTURE_CONFIRM
  → STRUCTURE_CONFIRMED
  → QUALITY_GATES_PASSED
  → ENTRY_SUBMITTED
  → OUTCOME_OBSERVED

WAIT_STRUCTURE_CONFIRM → INVALIDATED | EXPIRED
任一入场前阶段        → REJECTED(reason_code)
```

为每个 episode 保存 `episode_id`、swing identity、方向、事件 bar/time、sweep depth、冻结 extreme、OB bounds、confirmation delay、所有 gate observation/reason、下单/成交关联和 outcome。将 Gate 拆成事件字段，而非提前压成 `score`：研究 `SWEEP→RECLAIM`、`RECLAIM→CONFIRM`、`CONFIRM→OUTCOME` 的条件转移、失败原因、MFE/MAE 与成本后收益。

建议特征包括 `sweep_depth_atr`、`wick_ratio`、`reclaim_distance_atr`、`confirmation_bars`、`confirmation_range_atr`、`HTF_EMA_distance/slope`、`ATR_percentile`、`session`、`spread/ATR`、`SignedNetMove`、`PathEfficiency`、`distance_to_VWAP`。胜率或概率只能在有足够样本、时间外验证和校准后报告。

## 来源

- [MQL5 CodeBase 原文与结果说明](https://www.mql5.com/en/code/77094)
- 源码附件：`SMC_LiquiditySweepScalper.mq5`。本机下载到忽略目录并静态阅读；没有复制到仓库，也没有在 MetaEditor 编译或 MT5 Tester 执行。
