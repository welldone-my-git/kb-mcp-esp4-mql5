# Structural Break Tests: CSW & SADF (A 级推荐)

## 元信息

- **文章**: Feature Engineering for ML (Part 9): Structural Break Tests in Python
- **作者**: Patrick Murimi Njoroge
- **来源**: https://www.mql5.com/en/articles/23158
- **日期**: 2026-07-03
- **评级**: A — 提供可抽象为 `StatisticalBreakProvider` 的统计检验架构入口
- **源码**: `/en/articles/download/23158/structural_breaks.py` (附于原文附件 ZIP)

## 解决的问题

不是又一个技术指标（RSI/MACD/ATR），而是**计量经济学 Feature Engineering**。回答两类问题：

1. **CSW（Chu-Stinchcombe-White）**: "这里是不是发生了结构变化？" — 检测均值/趋势的结构性断裂
2. **SADF（Supremum Augmented Dickey-Fuller）**: "市场是不是开始进入泡沫/爆炸阶段？" — 检测爆炸性过程

## 核心算法

### CSW — CUSUM 型结构断裂检验

```
S_n,t = (y_t - y_n) / (σ_n * sqrt(t - n))
```

- 零假设：无趋势（E\_{t-1}\[Δy_t\] = 0）
- 对 log-price 做 supremum scan，取所有 n ∈ \[1, t\] 的最大值
- 输出：`csw["stat"] - csw["critical_value"]`（超过拒绝边界的余量）

### SADF — Supremum Augmented Dickey-Fuller

- 在每个时间点 t 做 backward-expanding window 的 ADF 检验
- 对所有 (t₀, t) 组合取 supremum
- 必须输入 **log price**（非 raw price），否则嵌入结构性异方差假设
- 支持 6 种回归模型：`linear`, `quadratic`, `sm_poly_1`, `sm_poly_2`, `sm_exp`, `sm_power`

### CADF / QADF — SADF 的稳健化变体

- QADF：用高分布分位数替代 supremum，对异常窗口更稳健
- CADF：条件均值（条件于超过 q 分位数），检测 supremum 是否由单一窗口驱动
- 输出 `outlier_ratio = (sadf_linear - c_adf) / c_dot` 诊断指标

## 生产化问题

文章重点指出书本源码的三处缺陷：

1. CSW 内层循环 O(T²) 的 Pandas `.loc` 查询 → 应预计算 NumPy 数组 + cumsum
2. SADF 内层循环重复构建 DataFrame → 应一次构建 X/y 后传切片
3. `getBetas` 参数顺序与 sklearn 相反 → 易静默出错

优化后达到 **32–50× 加速**。建议使用 rolling window（L=504 日线，L=256/512 分钟线）而非 expanding window 以获得实时策略信号。

## 架构价值

### Three-Regime 映射

| SADF 状态 | β 取值 | 策略含义 |
|---|---|---|
| Steady（平稳） | β < 0 | 均值回复策略有效（布林带、配对交易） |
| Unit-root（单位根） | β ≈ 0 | 不可预测，降低仓位等待 |
| Explosive（爆炸） | β > 0 | 趋势跟踪，监控 SADF 回落信号 |

这为 `RegimeAwarePPO` 提供了第三维状态信息，与传统 bull/bear/range 正交。

### 与现有架构的契合点

```text
Econometrics
    ↓
Structural Break Tests (CSW / SADF / CADF / CUSUM / Bai-Perron ...)
    ↓
StatisticalBreakProvider           <--- 新增 Provider
    ↓
BreakObservation
    ↓
Feature Mapping → Observation Space
    ↓
RegimeAwarePPO
```

### 推荐 Feature 接入方案

第一版仅输出 3 列 Observation：

- `stat_break_csw_excess` — CSW stat − critical_value（趋势偏离度）
- `stat_break_sadf_linear` — 线性 SADF（爆炸性得分）
- `stat_break_sadf_outlier_ratio` — (sadf − c_adf) / c_dot（异常窗口诊断）

### 与 SMC 的组合潜力

- BOS + SADF↑ → 真趋势启动
- BOS + SADF≈0 → 假突破
- Sweep + Break Test + Liquidity → `SMCConfirmationProvider` 的综合 `confirmation_score`

## 产出资产清单

| 路径 | 类型 | 说明 |
|---|---|---|
| `knowledge/articles/structural-break-tests-csw-sadf.md` | 文章摘要 | 本文 |
| `knowledge/architecture/statistical-break-provider.md` | 架构设计 | StatisticalBreakProvider 规范 |

## 扩展路线

- 后续可接入：CUSUM、Bai-Perron、Zivot-Andrews、Markov Switching、HMM
- 统一通过 `MeasurementType.statistical_break` → `EvidenceObject` → `Measurement` → `Observation` 管线管理
