# TDA Takens Embedding：时间序列到几何对象的基础库

来源：

- MQL5 Article: <https://www.mql5.com/en/articles/23037>
- Title: Shape of Price: An Introduction to TDA and Takens Embedding in MQL5
- Author: Hammad Dilber
- Date: 2026-06-18
- Category: MetaTrader 5 / Trading
- Local source: [TDA_TakensEmbedding](../../examples/mql5/TDA_TakensEmbedding/)

## 总体评价

| 项目 | 评分 |
|---|---:|
| 思路价值 | ⭐⭐⭐⭐⭐ 9.5/10 |
| 代码质量 | ⭐⭐⭐⭐⭐ 9/10 |
| 直接用于交易 | ⭐⭐☆☆☆ 4/10 |
| 基础库收藏 | ⭐⭐⭐⭐⭐ 10/10 |

一句话总结：

> 这篇不是交易策略，而是在构建 TDA 系列后续算法依赖的底层几何库。

## 它在完整 TDA Pipeline 中的位置

完整流程大致是：

```text
价格序列
    ↓
Takens Embedding
    ↓
Point Cloud
    ↓
Distance Matrix
    ↓
Rips Complex
    ↓
Persistent Homology
    ↓
Persistence Entropy
    ↓
Market Regime
```

这篇只完成前两层：

```text
Price Series
    ↓
Point Cloud
    ↓
Distance Matrix
```

真正产生可交易特征要到后续 persistence、entropy、regime 层。

## Takens Embedding 的价值

Takens embedding 的本质是：

```text
时间序列 → 高维状态空间
```

例如一维 close 序列：

```text
100, 101, 102, 101, 99
```

在 `embDim=3, delay=1` 下变成：

```text
(100, 101, 102)
(101, 102, 101)
(102, 101, 99)
```

这一步不只服务 TDA。它本身就是一种 feature engineering。

后续可以接：

- PCA；
- manifold learning；
- recurrence analysis；
- DBSCAN / HDBSCAN；
- graph features；
- RQA；
- TDA；
- transformer patch embedding。

## 1. CTDAPointCloud

`CTDAPointCloud` 只做一件事：

```text
1D Series → Takens embedded point cloud
```

它不做距离计算，不做图，不做 persistence。

这是优秀库设计：

```text
职责单一
输入明确
输出明确
下游可复用
```

关键接口：

```text
Build(series, seriesLen, embDim, delay)
Size()
Dim()
Delay()
Get(idx, coords[])
GetCoord(idx, d)
GetRaw(out[])
```

`Build()` 设计比构造函数塞参数更适合 EA：

- 对象可复用；
- 可以重复构建；
- 减少频繁 `new/delete`；
- 失败时返回 `false`。

## 2. Flattened Point Storage

作者没有使用二维数组，而是用平铺数组：

```text
m_points[i * embDim + d]
```

这是正确选择。

优点：

- cache-friendly；
- MQL5 中更自然；
- 传递给后续距离矩阵更方便；
- 避免二维动态数组限制；
- 适合未来导出到 Python / GPU。

这类布局可以作为 MQL5 数值库模板收藏。

## 3. CTDADistance

`CTDADistance` 只负责：

```text
Point Cloud → Pairwise Distance Matrix
```

它与 point cloud 解耦。

以后可以替换为：

- approximate distance；
- KDTree；
- BallTree；
- kNN distance；
- GPU distance；
- radius graph；
- sparse matrix。

而 `CTDAPointCloud` 不需要改。

这就是正确的分层。

## 4. Distance Matrix

距离矩阵同样采用平铺数组：

```text
m_D[i * N + j]
```

并利用对称性：

```text
D[i][j] = D[j][i]
D[i][i] = 0
```

当前复杂度：

```text
Time: O(N^2 * dim)
Memory: O(N^2)
```

对 50 到 200 根 K 线的窗口可以接受。对 1000 以上点数会成为瓶颈。

## 5. ENUM_TDA_NORM

范数选择用 enum：

```text
TDA_NORM_MAX
TDA_NORM_EUCLIDEAN
TDA_NORM_MANHATTAN
```

这比传 `0/1/2` 清晰。

未来可扩展：

- cosine；
- Mahalanobis；
- DTW；
- correlation distance；
- learned metric。

## 不足与升级方向

### 1. Distance Matrix 复杂度高

完整矩阵是 O(N²)。这对 TDA 的 Rips filtration 有意义，但不是所有下游算法都需要完整矩阵。

后续可升级：

- kNN graph；
- radius graph；
- sparse distance；
- approximate nearest neighbor；
- OpenCL / GPU。

### 2. Embedding 参数需要自动估计

当前 `embDim` 和 `delay` 由用户输入。

Takens 系列更完整的做法：

- delay 用 mutual information；
- embedding dimension 用 false nearest neighbors；
- 按资产和周期做验证。

### 3. 缺少增量更新

当前每次 `Build()` 都重建完整 cloud。

EA 实时场景可以升级为：

```text
Rolling Embedding
    Push(new close)
    Drop(old close)
    Update latest vector
```

### 4. Distance 可进一步抽象

建议拆成：

```text
MetricEngine
    Euclidean
    Manhattan
    Chebyshev
    Cosine
    DTW
```

让 distance matrix 只负责存储和调度。

## 对 Python + MQL5 框架的价值

这篇非常适合放到混合量化架构的底层：

```text
core/
├── Embedding/
│   ├── DelayEmbedding
│   ├── SlidingWindow
│   ├── PatchEmbedding
│   └── WaveletEmbedding
├── Geometry/
│   ├── DistanceMatrix
│   ├── KDTree
│   └── RadiusGraph
├── Topology/
│   ├── Rips
│   └── Persistence
├── Graph/
│   ├── MST
│   ├── KNN
│   └── Radius
└── Feature/
    ├── Entropy
    ├── Fractal
    └── Recurrence
```

MQL5 可以负责轻量实时 embedding 和距离特征，Python 负责更重的 persistence、clustering、参数选择和统计验证。

## 推荐收藏模块

一级收藏：

- Takens embedding 思想；
- `CTDAPointCloud`；
- flattened point array；
- `CTDADistance`；
- flattened NxN distance matrix；
- `ENUM_TDA_NORM`；
- `Build()` 接口模式。

二级收藏：

- `TDA_Demo.mq5` 作为最小调用样例；
- bounds check；
- `GetCoord()` 避免频繁分配数组；
- distance symmetry fill。

不重点收藏：

- Demo 输出；
- 把 TDA 当直接交易策略；
- 手动固定参数作为默认结论。

## 最终结论

这篇适合作为基础库收藏。

它的长期价值不是 TDA 名词，而是把：

```text
时间序列
    ↓
状态空间轨迹
    ↓
几何对象
```

封装成了 MQL5 可复用组件。

对于后续 RQA、TDA、Graph、Clustering、Manifold、Transformer 特征工程，这三份源码都值得保留。

## 标签

```text
TDA
Takens Embedding
Point Cloud
Distance Matrix
Feature Engineering
Geometry
Flattened Array
MQL5 Quant Library
```
