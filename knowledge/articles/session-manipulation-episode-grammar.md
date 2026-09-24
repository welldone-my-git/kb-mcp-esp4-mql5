# Session Manipulation and Algorithmic Reaction Tracker：Session Episode Grammar

## 来源与核验

- **类型**：MQL5 CodeBase 指标，不执行交易
- **名称**：Session Manipulation and Algorithmic Reaction Tracker（S.M.A.R.T. ICT/SMC V3）
- **作者**：IronHawk Capital LLC（CodeBase 发布者 IronHawkLLC）
- **页面**：<https://www.mql5.com/en/code/77071>
- **源码**：页面提供 `SMART_Session_Manipulation.mq5`；本机副本位于被 Git 忽略的 `download/`，不纳入仓库发布
- **页面版本**：2026-09-07 发布，2026-09-15 更新
- **源码状态**：`source_downloaded`；完成静态阅读，未在 MetaEditor 编译或运行

## 核心流程

它把已完成的 Asia / London Session Range 与后续价格反应连接成一个 Episode：

```text
已完成 Session Range
  → Sweep
  → 收盘突破 Sweep 前已确认 Swing（MSS）
  → MSS K 线满足 displacement 门槛
  → 同方向三 K 线 FVG
  → 后续 K 线回测 FVG，并收盘越过 midpoint
  → Projection + 历史结果审计
```

Sweep 单独不构成最终 setup。源码使用闭合 K 线；FVG 形成 K 线不能确认自己的 retest；MSS 之后再次穿越冻结的 sweep extreme 会使候选失效。未完成或失败的候选进入 Watch 记录，不输出有效 Projection。

## 源码中的实际状态表达

实现没有为上述每个语义阶段各建一个 enum。`SMART_PHASE` 只有 `NONE`、`SWEEP`、`WAIT_FVG`、`RETEST`。Session 完成状态保存在日历 Range 结构中；MSS 由 `IsMarketStructureShift()` 判断，且该函数把 swing close-break 与最小实体位移 ATR 条件合并。若 MSS 同一根 K 线也形成 FVG，候选会直接进入 `RETEST`；由于 `retest_index > fvg_index` 的约束，该 FVG K 线不能自我确认回测。

所以可迁移的设计重点是“显式 Episode + 有序转换 + 不变量”，不必照抄源代码的 enum 粒度。

## Projection 与评分

- 入场参考：有效 FVG retest K 线的收盘价。
- 止损：冻结的 sweep extreme 外加 ATR buffer，并执行结构风险上下限校验。
- TP1：默认 1.20R。
- TP2：指向对侧 Session 流动性，最高 2.00R；至少要求 1.50R 空间。
- Quality Score：由 Session、Sweep、MSS、Displacement、FVG、Retest、Tick Volume 组件组成，完整 setup 的页面说明分数为 80–100。
- 分数是该规则链内部的 confluence，不是胜率或校准概率。

历史审计只从确认 K 线之后开始；遇到同一根 OHLC bar 同时触及 stop 与 target 时，先检查 stop 并按 stop-first 处理。这为回测歧义提供了保守约定，但它仍是 bar 级审计，不等价于 tick 级成交模拟。

## 可提取特征

保留状态转换前后的原子观测，不把总分当成唯一 Alpha：

```text
session_type, direction, sweep_depth_atr, sweep_duration,
swing_distance_atr, mss_delay, mss_displacement_atr,
fvg_size_atr, fvg_delay, retest_delay, retest_depth_atr,
retest_close_position, tick_volume_ratio, structural_risk_atr,
transition_outcome, episode_duration, MFE, MAE, time_to_MFE
```

建议对每个阶段记录 event time、bar index、输入阈值和结束原因，以便复现样本并估计 transition probability、失败率与 failure hazard。

## 工程观察与限制

- 该指标默认 M5、最多三品种，闭合 K 线处理，并按 Timer 轮换处理品种。
- 每次发现新闭合 K 线时，会重新装载并分析最多 `InpHistoryBars` 根历史数据；它适合确定性重建和有限历史审计，但不是增量 O(1) 的在线 Episode Store。
- 实现用一个活动候选承载当前 symbol 的 Episode；若扩展为多候选并行，需明确去重键、状态隔离和资源上限。
- 经济日历只显示宏观上下文，不参与方向、评分或验证条件。
- 参数默认值和结构组件是研究假设，需通过样本外和跨品种检验；页面 dashboard 比率不是独立验证集上的胜率。

## 结论

适合抽取为 Session Episode Grammar 的规则级参考：事件规范化、状态推进、失败归因、Projection Gate 与保守结果审计。策略表现尚未由该指标页面证明；这里没有将其总分视作预测概率。
