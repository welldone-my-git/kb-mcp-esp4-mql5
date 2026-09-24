# Session Quality Layer

Session Quality 是按经纪商、品种和可交易时间片刻画机会/成本/路径质量的描述与门控层。它不预测方向，不把“波动大”视作 Alpha，也不替代策略的 entry setup、Projection Gate 或 RiskEngine。

## 架构位置

```text
Broker Market Data (M1 / Tick / Costs)
                ↓
      Session Profile Builder
                ↓
Opportunity + Directionality + Liquidity + Cost
                ↓
          SessionQuality
                ↓
Strategy / Execution Gate
                ↓
       RiskEngine → Broker
```

核心原则是同一 `broker × symbol × time bucket` 上同时衡量可动空间和交易成本。基础量 `Movement/Spread` 可作为诊断因子，但不是净收益估计，更不是单独的交易信号。

## Feature Contract

每个 profile point 至少包含：

```text
broker_id, symbol, timezone, weekday, hour/session, regime
sample_start/end, observed_days, bar_count, tick_count, coverage
movement_proxy, realized_vol, median_spread, spread_p90
signed_net_move, path_length, path_efficiency, direction_persistence
zero_tick_ratio, jump_stats, commission/slippage estimates
quality components, uncertainty, profile_version
```

分别暴露 Opportunity、Path/Directionality、Liquidity、TransactionCost 与 Uncertainty，不把它们过早压成单个 score。若下游确需 `SessionQuality`，保留 component breakdown、样本数与版本便于审计。

## 时间、样本与数据约束

- MQL5 server time、UTC、用户本地时区要显式标注；时区转换使用具备 DST 规则的 timezone database，固定整数 offset 只适合明确声明为固定偏移的场景。
- 记录 M1 bar 覆盖率与交易日数。缺小时可代表休市，也可代表数据缺失；不可把它自动算作“零 spread 的好小时”。
- Opportunity 与 spread 应尽可能使用一致时段和可比样本；M1 spread 字段和 tick-level spread 分布要区分。
- Profile 必须 point-in-time：某时点 Gate 只能查询此前形成的训练 profile，不能由全样本统计回填历史交易。
- 分桶越细，估计方差越高；展示样本计数/区间，对稀疏切片做层级回退或 shrinkage，不用单个最优时段进行过拟合。

## Gate 与验证

Gate API 可返回 `ALLOW / REDUCE / BLOCK / UNKNOWN`，并附带各 component、阈值、profile version 和 reason code。`UNKNOWN` 的 fail-open / fail-closed 必须由治理策略显式决定。将 Gate 作为可选策略过滤器做 walk-forward ablation，比较交易覆盖率、成本后收益、drawdown、MAE/MFE 和低质量时段的失败概率；同步分析被拒交易的反事实结果，避免只看已成交样本的选择偏差。

对 Good Morning Ultimate，可在已有日本时间窗口中先做固定 baseline，再依次加入 movement/cost、path efficiency、spread percentile。时间窗口转本地时区后进行 DST 正确映射。若新增 Gate 的样本外收益/风险改善不稳定，就只保留为诊断报告，不升级成执行约束。

## 来源

- [Gold Hour Profile 研究条目](../articles/gold-hour-profile-session-quality.md)
- [MQL5 CodeBase 原文](https://www.mql5.com/en/code/77073)
