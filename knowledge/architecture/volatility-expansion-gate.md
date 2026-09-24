# Volatility Expansion Gate

将波动状态作为已有方向 setup 的条件变量，而非让波动模型直接预测涨跌。Gate 回答的是“这个 setup 当前的波动环境是否符合其假设”，不替代 Market State、Setup、Projection 或最终 RiskEngine。

## 位置与职责

```text
State / Episode Grammar
          ↓
Directional Setup → SetupEvent
          ↓
VolatilityContext
          ↓
VolatilityGate → PASS | REDUCE | BLOCK + diagnostics
          ↓
Projection / Meta Gate
          ↓
RiskEngine → Execution
```

Gate 应记录原始测量值和版本化判定依据，而不只输出 bool：`forecast_sigma`、`realized_sigma`、`expansion_ratio`、所用窗口、模型参数、setup 类型、阈值、decision、reason code 和 closed-bar timestamp。没有有效波动估计时默认 `BLOCK/UNKNOWN` 或交由明确配置处理，不静默当作低风险。

## 可比较的候选变量

- `GARCHExpansion = conditional_sigma / rolling_realized_sigma`
- `ATRExpansion = ATR_fast / ATR_slow`
- `RealizedVolExpansion = RV_fast / RV_slow`
- `RangeExpansion = range_fast / range_slow`

这些特征可能高度相关。分别保存，不急于融合成一个复合分数。GARCH 参数估计、固定参数递推、不同 RV 采样规则应作为不同 feature/model version 管理。

## 与 Signal Authority 的边界

- Volatility Gate 是**setup 条件层**：过滤某种 setup 所需的环境条件。
- Signal Authority Gate 是**候选信号使用授权层**：接受、减弱或拒绝 producer 信号。
- Projection Gate 是**Episode/投影有效性层**：确认结构链与投影条件。
- RiskEngine 是账户/组合级硬约束，始终保有最终否决权。

同一个实现框架可复用，但日志语义和目标不可混淆。Gate 不得因为 LSTM/模型输出高分就绕过 setup 条件或风险约束。

## 增量价值验证协议

1. 固定时间切分和候选 setup 样本，先建立 setup-only baseline。
2. 对 GARCH、ATR、RV、range expansion 分别做增量实验，确保输入只来自决策时点可见数据。
3. 比较 gating 前后的样本数、拒绝样本反事实结果、净成本收益、MFE/MAE、回撤、校准与不确定区间。
4. 再测组合变量与模型；对参数搜索使用 nested/walk-forward 评估，避免在同一 forward 区间挑门槛。
5. 以简单基线可重复、多个 OOS 窗口稳定、跨品种/Regime 有解释力为保留条件。模型未证明增量就删除。

与 `State × SignedNetMove` 的研究连接，可先检验 `State × SignedNetMove × VolatilityExpansion → FutureRecovery/MFE`，并在控制 ATR/range/RV 后测 GARCH 的条件增量。不要因 GARCH 数学形式更复杂而预先赋予更高权重。

## 来源

- [Defining your Edge Part 5：GARCH Variance and Volatility-Scaled LSTM](../articles/garch-volatility-gate-volscaled-lstm.md)
- [MQL5 原文](https://www.mql5.com/en/articles/24357)
