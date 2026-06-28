# Statistical Diagnostics：策略与特征统计诊断层

参考来源：

- [Rolling Sharpe](../articles/rolling-sharpe-statistical-significance-bands.md)
- [Linear Regression Prediction Channels](../articles/linear-regression-prediction-channels.md)

## 目标

不要只看单点指标，要看统计不确定性：

```text
metric
  ↓
standard error / interval
  ↓
confidence / coverage
  ↓
decision
```

## 第一批诊断组件

### 1. Rolling Sharpe + Confidence Band

用途：

- 策略近期稳定性；
- regime 下绩效漂移；
- 判断 Sharpe 是否显著大于 0；
- 避免把短窗口噪声当 alpha。

### 2. Regression Prediction Channels

用途：

- 趋势斜率；
- residual volatility；
- prediction interval width；
- channel breach frequency；
- empirical coverage test。

## 平台建议

```text
research/diagnostics/
├── rolling_sharpe.py
├── regression_channel.py
├── coverage_test.py
├── drawdown_diagnostics.py
└── feature_stability.py
```

## 输出到 DecisionLog

每次策略决策可记录：

```text
rolling_sharpe
sharpe_ci_lower
sharpe_ci_upper
reg_slope
prediction_width
coverage_error
diagnostic_flags
```

## 原则

统计诊断不是交易信号本身。它更适合用于：

- risk scaling；
- strategy disable / enable；
- model monitoring；
- walk-forward report；
- live drift detection。
