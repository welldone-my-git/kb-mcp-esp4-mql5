# RQA Library：Recurrence Quantification Analysis 完整分析组件

来源：

- MQL5 Article: <https://www.mql5.com/en/articles/22288>
- Title: Recurrence Quantification Analysis (RQA) in MQL5: Building a Complete Analysis Library
- Author: Hammad Dilber
- Date: 2026-05-01
- Category: MetaTrader 5 / Indicators
- Local source: [RQA_Library](../../examples/mql5/RQA_Library/)

## 总体评价

| 项目 | 评分 |
|---|---:|
| 思路价值 | ⭐⭐⭐⭐⭐ |
| 架构设计 | ⭐⭐⭐⭐⭐ |
| 代码质量 | ⭐⭐⭐⭐☆ |
| 可复用程度 | ⭐⭐⭐⭐⭐ |
| 直接交易价值 | ⭐⭐☆☆☆ |
| 基础库收藏 | ⭐⭐⭐⭐⭐ |

一句话总结：

> 这篇不是交易策略，而是一套完整的 nonlinear dynamics / recurrence feature engine。

## 与 TDA 系列的关系

`23037` 做的是：

```text
Price Series
    ↓
Takens Embedding
    ↓
Point Cloud
    ↓
Distance Matrix
```

`22288` 做的是 RQA pipeline：

```text
Price Series
    ↓
Time-delay Embedding
    ↓
Distance / Epsilon
    ↓
Recurrence Matrix
    ↓
Line Structure Counting
    ↓
RQA Metrics
    ↓
Rolling Regime Features
```

它和 TDA 一样都从状态空间重构出发，但目标不是 persistence diagram，而是 recurrence plot 的结构统计。

## 核心架构

文章把库拆成清晰的五层：

```text
RQAMatrix
    ↓
RQAMetrics
    ↓
RQAEpsilon
    ↓
RQAWindow
    ↓
RQA facade
```

这点非常值得收藏。

每个类职责明确：

- `CRQAMatrix`：embedding、distance、binary recurrence matrix；
- `CRQAMetrics`：从 recurrence matrix 计算所有 RQA 指标；
- `CRQAEpsilon`：自动选择 recurrence threshold；
- `CRQAWindow`：滚动窗口分析，输出时间序列；
- `CRQA`：facade，一次性组织完整计算。

## 1. CRQAMatrix

`CRQAMatrix` 是底层核心。

它把原始序列转成 recurrence matrix：

```text
series
    ↓
embedding vectors
    ↓
distance(i, j)
    ↓
distance <= epsilon
    ↓
R[i, j] = true / false
```

内部使用平铺数组：

```text
m_embedded[i * embDim + d]
m_R[i * N + j]
```

这和 `23037` 的 `CTDAPointCloud`、`CTDADistance` 设计一致，适合 MQL5 数值库。

值得保留：

- flattened matrix；
- enum norm；
- `Build()` 接口；
- bounds-checked `Get()`；
- embedding / distance / threshold 的最小闭环。

## 2. CRQAMetrics

`CRQAMetrics` 是最有业务价值的部分。

它从 recurrence matrix 中提取：

- `RR`：Recurrence Rate；
- `DET`：Determinism；
- `LAM`：Laminarity；
- `TT`：Trapping Time；
- `L`：Average diagonal length；
- `Lmax`；
- `Vmax`；
- `ENTR`：diagonal line entropy；
- `DIV`；
- `RATIO`；
- `TREND`；
- `COMPLEXITY`。

这些不是直接交易信号，而是 regime feature。

例如：

- `DET` 高：结构更确定，走势更像规则系统；
- `LAM` 高：市场更容易停滞或盘整；
- `ENTR` 高：确定性结构更复杂；
- `TREND` 高：recurrence density 随时间漂移，可能提示非平稳；
- `RR` 过高或过低：epsilon 可能不合适，或者状态重访结构发生变化。

## 3. SRQAResult

统一结果结构很值得收藏。

```text
SRQAResult
    RR
    DET
    LAM
    TT
    L
    Lmax
    Vmax
    ENTR
    DIV
    RATIO
    TREND
    COMPLEXITY
    Reset()
```

这比返回一堆散乱 double 更适合框架。

后续 EA、Indicator、CSV exporter、Python bridge 都可以读同一个 result struct。

## 4. CRQAEpsilon

epsilon 是 RQA 中最关键的参数。

这篇提供四种方法：

- fixed；
- standard deviation fraction；
- range fraction；
- target recurrence rate；
- target RR 用 bisection search。

这块非常实用，因为固定 epsilon 在不同品种和波动 regime 下很容易失效。

最值得收藏的是：

```text
Threshold Selection 单独成类
```

不要把 epsilon 选择写死在 matrix 或 indicator 里。

## 5. CRQAWindow

`CRQAWindow` 把单次 RQA 变成滚动 feature series。

输出：

```text
SRQAWindowResult[]
    barIndex
    metrics
```

并提供：

```text
ExtractRR()
ExtractDET()
ExtractLAM()
ExtractENTR()
ExtractTREND()
```

这对指标和 EA 都很有价值。

EA 不应该每次自己解析所有 metrics，只需要按需要抽取一个序列。

## 6. CRQA Facade

`CRQA` 是高层入口：

```text
SetEmbedding()
SetNorm()
SetEpsilon()
SetEpsilonAuto()
SetMinDiagLine()
SetMinVertLine()
Compute()
RR()
DET()
LAM()
ENTR()
TREND()
```

这是标准 facade 设计。

它让使用者不需要知道：

- epsilon 怎么选；
- matrix 怎么 build；
- metrics 怎么 count；
- result 怎么填。

这一层适合作为 EA 或脚本的主接口。

## 不足与风险

### 1. 计算复杂度高

recurrence matrix 是 O(N²)。

rolling window 每个窗口都重建 matrix，会进一步放大成本。

对于大窗口、多品种、多周期，MQL5 端会吃力。

### 2. 缺少增量更新

当前 `CRQAWindow` 对每个窗口重新：

```text
slice
build matrix
compute metrics
```

更强版本应考虑：

- rolling embedding；
- incremental distance update；
- sparse recurrence matrix；
- cached line statistics。

### 3. Epsilon RR-target 近似固定 embDim/delay

源码中的 `ApproxRR()` 在 RR-target bisection 中使用简化 embedding 参数。

这在工程上可以接受作为快速近似，但严谨版本应该和实际 `embDim/delay/norm` 保持一致。

### 4. 指标不是策略

`RQA_Indicator.mq5` 只是可视化。

不要把 `DET` 上升或 `LAM` 上升直接当买卖信号。它们应该作为：

- regime filter；
- feature；
- risk adjustment；
- model input。

## 对 Python + MQL5 框架的建议

建议分工：

```text
Python
├── 参数选择
├── 大窗口 RQA
├── sparse / optimized matrix
├── regime labeling
├── alpha evaluation
└── feature export

MQL5
├── 小窗口实时 RQA
├── 读取已验证参数
├── 作为 EA filter
├── 输出 DET / LAM / ENTR / TREND
└── 执行交易
```

在你的框架中，它适合放到：

```text
QuantGeometry/
├── Embedding/
├── Recurrence/
│   ├── RQAMatrix
│   ├── RQAMetrics
│   ├── EpsilonSelector
│   └── RQAWindow
└── Feature/
    ├── Determinism
    ├── Laminarity
    ├── RecurrenceEntropy
    └── RegimeScore
```

## 推荐收藏模块

一级收藏：

- `CRQAMatrix`；
- `CRQAMetrics`；
- `SRQAResult`；
- `CRQAEpsilon`；
- `CRQAWindow`；
- `CRQA` facade；
- rolling metric extractors；
- enum-based configuration。

二级收藏：

- `RQA_Example.mq5`；
- `RQA_Indicator.mq5`；
- `PrintSummary()`；
- `COMPLEXITY = RR * DET` 这类组合指标。

不重点收藏：

- 指标颜色和绘图样式；
- 把 RQA 指标直接做交易规则；
- 固定参数的回测解读。

## 最终结论

这篇是基础库级文章，值得完整收藏。

它的长期价值是把 nonlinear dynamics 特征工程封装成了可复用组件：

```text
Recurrence Matrix
    ↓
Line Structure Metrics
    ↓
Rolling Regime Features
```

后续不管做 RQA、TDA、regime detection、ML feature engineering，都能复用这套设计。

## 标签

```text
RQA
Recurrence Quantification Analysis
Takens Embedding
Recurrence Matrix
DET
LAM
ENTR
TREND
Epsilon Selection
Rolling Window
Regime Feature
MQL5 Quant Library
```
