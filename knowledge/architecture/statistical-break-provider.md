# StatisticalBreakProvider

## 定位

在 `InformationProvider` 层级中新增 `StatisticalBreak` 分支，将计量经济学的结构断裂检验（CSW、SADF、CUSUM、Bai-Perron 等）统一为可插拔的 Provider，输出与 bull/bear/range 正交的爆炸性/结构性特征。

```text
InformationProvider
├── Price
├── Technical
├── SMC
├── Regime
├── Volatility
├── Liquidity
└── StatisticalBreak      <--- 本文
```

## 设计原则

1. **算法可替换** — 底层实现可来自 MQL5、Python（statsmodels/arch）或任何论文算法，通过统一接口接入
2. **Observation 稳定** — 换算法不换 Observation 字段名（如 `sadf_score` 始终可用）
3. **与 Measurement Pipeline 融合** — 走 `MeasurementType.statistical_break` → `EvidenceObject` → `Measurement` → `Observation` 管线

## 引擎分层

```text
Bar Data (OHLCV)
    ↓
log_prices = np.log(close)
    ↓
┌─────────────────────────────────────────────────┐
│           StructuralBreakEngine                  │
│                                                   │
│  ┌──────────┐  ┌──────────┐  ┌────────────────┐  │
│  │ CSW      │  │ SADF     │  │ CUSUM /        │  │
│  │ Test     │  │ Family   │  │ Bai-Perron /   │  │
│  │          │  │          │  │ Zivot-Andrews  │  │
│  └──────────┘  └──────────┘  └────────────────┘  │
│         │            │               │            │
│         ▼            ▼               ▼            │
│  ┌──────────────────────────────────────────┐     │
│  │        BreakObservation (统一输出层)      │     │
│  │  score / strength / confidence /         │     │
│  │  direction / duration / p_value          │     │
│  └──────────────────────────────────────────┘     │
└─────────────────────────────────────────────────┘
    ↓
Feature Mapping
    ↓
Observation Space
```

## 第一版 Feature 输出

最小落地 3 列 Observation：

| Observation 字段 | 来源 | 含义 |
|---|---|---|
| `stat_break_csw_excess` | CSW stat − critical_value | 正向 = 趋势偏离度 |
| `stat_break_sadf_linear` | SADF linear model | 正值 = 爆炸性上升，负值 = 均值回复 |
| `stat_break_sadf_outlier_ratio` | (sadf − c_adf) / c_dot | 高值 = supremum 由异常窗口驱动 |

### 计算示意

```python
# 输入：log_prices = np.log(df["close"])

# CSW
csw = get_chu_stinchcombe_white_statistics(log_prices, test_type="one_sided")
csw_excess = csw["stat"] - csw["critical_value"]

# SADF
sadf_linear = get_sadf(log_prices, model="linear", lags=1, min_length=20, add_const=True)

# CADF（异常诊断）
cadf = get_cadf(log_prices, model="linear", lags=1, min_length=20, q=0.95)
sadf_outlier_ratio = (sadf_linear - cadf["c_adf"]) / cadf["c_dot"].clip(lower=0.01)
```

## Three-Regime 映射

| SADF 状态 | β | stat_break_sadf_linear | 策略含义 |
|---|---|---|---|
| Steady（平稳） | β < 0 | 负值 | 均值回复策略（布林带、配对交易） |
| Unit-root（单位根） | β ≈ 0 | 接近 0 | 不可预测，降低仓位 |
| Explosive（爆炸） | β > 0 | 正值 | 趋势跟踪，监控回落信号 |

与现有 `bull_prob` / `bear_prob` / `range_prob` 组合示例：

- `bull_prob = 0.91` + `sadf_linear = 很高` → 牛市但进入爆炸阶段 → RL 减仓/提高止盈/增加风险惩罚
- `bull_prob = 0.91` + `sadf_linear ≈ 0` → 健康牛市 → 正常持仓

## 与 Measurement Pipeline 的融合

```text
MeasurementType
├── trend
├── momentum
├── volatility
├── liquidity
├── market_structure
└── statistical_break      <--- 新增

EvidenceObject
    ↓
Measurement (CSW / SADF / CUSUM 等)
    ↓
Observation
    ↓
Feature Mapping → Observation Space
```

优势：
- 算法可替换：SADF ↔ CUSUM ↔ Bai-Perron，Observation 接口不变
- 可扩展：后续 HMM、Markov Switching 也可接入同一 `measurement_type`

## 与 SMC 的组合（进阶）

```text
SMCConfirmationProvider
├── bos
├── fvg
├── ob
├── sweep
├── volatility
├── liquidity
└── sadf                    <--- 新增信号
    ↓
confirmation_score
```

- BOS + SADF↑ → 真趋势启动
- BOS + SADF≈0 → 可能假突破
- Sweep + Break Test + Liquidity → 高置信度入场信号

## 窗口选择

| 时间粒度 | 推荐窗口 L | 说明 |
|---|---|---|
| 日线 | 504 | 两年，覆盖中长周期泡沫 |
| M15 / 小时线 | 256–512 | 短周期滚动，适合交易特征 |
| 全历史 expanding | — | 仅用于长周期泡沫检测（dot-com 级别） |

## 产出资产关系

```text
Econometrics
    ↓
Structural Break Tests (CSW / SADF / CADF / CUSUM / Bai-Perron / Zivot-Andrews)
    ↓
StatisticalBreakProvider
    ↓
BreakObservation
    ↓
Observation Features
    ↓
RegimeAwarePPO
```

## 参考

- [Structural Break Tests (CSW & SADF) — 文章知识条目](../articles/structural-break-tests-csw-sadf.md)
- `afml.structural_breaks` Python 模块（附于原文）
- López de Prado, *Advances in Financial Machine Learning*, Chapter 17
- Phillips, Wu & Yu (2011), *Explosive behavior in the 1990s Nasdaq*
