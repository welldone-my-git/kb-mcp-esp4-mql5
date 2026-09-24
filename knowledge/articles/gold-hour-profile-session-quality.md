# Gold Hour Profile：从 Movement / Spread 到 Session Quality

```yaml
source_url: https://www.mql5.com/en/code/77073
source_title: Gold Hour Profile - when gold moves, and when the spread eats it
author: Petr Kostal
published: 2026-09-07
updated: 2026-09-15
source_status: source_downloaded
code_status: read_only_review
checked_at: 2026-09-24
local_attachment: download/77073.zip (ignored; not redistributed)
```

## 定位

这是只读历史数据的时段质量分析脚本，不下单。它的问题不是“哪个小时波动最大”，而是“按该经纪商该品种的报价记录，一个小时的典型价格活动相对 spread 成本有多大”。适合归入 Session Quality / Execution Opportunity Gate，而不是 Alpha 策略。

## 源码实际计算

脚本无论运行在哪个图表周期都调用 `CopyRates(symbol, PERIOD_M1, from, to, rates)`，默认回看 90 天，按 `InpHourShift` 调整后的 24 个 server-hour 分桶。对 `high > low` 的 M1 bar，累积：

\[
MeanM1Range_h = \frac{\sum_i (High_i-Low_i)/Point}{N_h}
\]

随后定义：

\[
Movement_h = 60 \times MeanM1Range_h,\quad
Spread_h = Mean(positive\ M1\ spread_h),\quad
Ratio_h = Movement_h / Spread_h
\]

CSV 每个 symbol-hour 输出有效 M1 bar 数、`movement_points_per_hour`、平均 spread、ratio 和占日 movement 的比例。页面也说明这些统计依赖自己的 broker；示例中不同品种的 rollover spread 与缺失小时差异明显。[CodeBase 页面与作者样例结果](https://www.mql5.com/en/code/77073)

## 解读限制：Ratio 是 profile proxy，不是可实现净收益

- `60 × 平均 M1 high-low` 是一分钟平均区间的线性外推，不是对每个自然小时 `max(high)-min(low)` 的直接测量，也不是净可执行移动距离。
- M1 range 会重叠/来回，不能当成可捕获方向性位移；Range/Spread 高也可能对应剧烈但无方向的噪声。
- movement 使用所有非平 bar；spread 只取 `spread > 0` 的 bar，二者有效样本可能不同。spread 字段是 M1 bar 记录值，不是完整 tick 级时间加权成本。
- 未计 commission、slippage、market impact、成交方向和策略持有时间；对非 scalping 目标，ratio 与策略实际成本收益关联可能很弱。
- 分桶只有 `hour`，未细分 weekday / season / regime；`InpHourShift` 是固定小时偏移，不会自动处理 DST。
- 回看区间从 `TimeCurrent()` 往回减固定天数；最低 1440 根 M1 bar 不等于完整覆盖样本期，休市/缺行情的覆盖需要另外审计。

因此，保留的是“Opportunity 与 Transaction Cost 同时做 broker-specific profiling”的设计，不把特定 broker 的 XAUUSD 最佳小时结论迁移成通用规则。

## 升级为 Session Quality Layer

```text
MT5 M1 / Tick
     ↓
Symbol × Broker × Timezone-aware time buckets
     ↓
Opportunity features + Cost / Liquidity features
     ↓
SessionQuality profile (带样本数与置信区间)
     ↓
Strategy Gate（只作过滤/风险约束）
```

在原有 `movement/spread` 之外，可加入 `realized_vol`、`median/p90 spread`、`tick_count`、`zero_tick_ratio`、`signed_net_move`、`path_length`、`path_efficiency = |net_move|/path_length`、`direction_persistence`、jump/gap、commission、slippage。高 ratio 但低 path efficiency 表示活动多、方向性弱；这正是原脚本无法区分的两类市场。

分组建议为 `broker × symbol × weekday × local session/hour × regime`，但高维切片会降低样本量。每个分组必须同时输出 observations、覆盖天数和不确定区间；小样本回退到较粗分组/整体先验，可用 shrinkage 避免偶然极值主导 Gate。使用 timezone-aware 转换处理 DST，不仅加一个固定 offset。

## GMU 可验证实验

针对已有的日本时间 04:00–08:00 窗口，在相同策略、相同数据和成本假设下逐层比较：

1. Baseline：仅固定时段；
2. Gate A：Baseline + `Movement/Spread` 历史分位；
3. Gate B：Gate A + `PathEfficiency`；
4. Gate C：Gate B + spread percentile / max cost。

特征 profile 只用训练期/过去数据构建，门槛只能在训练/验证窗选择，然后在后续 OOS 窗口评估。报告交易覆盖率和拒绝样本的反事实结果，除 Trades / expectancy / PF / Sharpe / DD / MAE / MFE 外，重点检验 `P(SL hit | low quality)` 对比 `P(SL hit | high quality)`，并纳入真实手续费、spread 与滑点。若 Gate 只减少交易而没有稳定风险/净收益改善，不应保留。

## 来源与附件状态

- [MQL5 CodeBase 原文](https://www.mql5.com/en/code/77073)
- 附件 ZIP 含 `GoldHourProfile.mq5` 与预览图；源码下载到本机忽略目录并静态阅读，未提交进仓库，也未在 MetaEditor / MT5 运行验证。
