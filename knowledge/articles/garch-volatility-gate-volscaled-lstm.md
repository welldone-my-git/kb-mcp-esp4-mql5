# Defining your Edge Part 5：GARCH 波动门控与 Volatility-Scaled LSTM

```yaml
source_url: https://www.mql5.com/en/articles/24357
source_title: Defining your Edge (Part 5): Using GARCH Variance and Volatility-Scaled LSTM in an Expert Advisor
author: Stephen Njuki
published: 2026-09-17
source_status: source_downloaded
code_status: read_only_review
checked_at: 2026-09-24
local_attachment: download/24357.zip (ignored; not redistributed)
```

## 收藏判断

**高价值研究设计，重点收藏 GARCH Volatility Gate 与模型增量检验，不是 LSTM 实现或某组参数。**文章把交易拆成可分离的方向 setup、波动环境 Gate、可选 LSTM 打分和入场阈值。它体现的研究纪律是：复杂模型必须在简单基线之上证明增量；证明不了就移除。

```text
Price / ATR / Bands / Price Action
              ↓
    Directional Setup Score
              ↓
      GARCH Expansion Gate
              ↓
       Optional LSTM Blend
              ↓
       Entry Threshold
```

## 文章机制

七种 Setup Mode 分别覆盖 breakout expansion、squeeze release、band re-entry、mid-band impulse、band walk、pullback continuation、range breakout。模式各自计算方向分数，GARCH 和 LSTM 并不单独创造 setup。Long/Short 条件依次要求 GARCH expansion 过门槛、原始方向分数越过 raw gate、最终分数越过 entry threshold。

波动率条件方差使用 GARCH(1,1) 形式：

\[
h_t=\omega+\alpha\epsilon_{t-1}^2+\beta h_{t-1},\qquad
ExpansionRatio_t=\frac{\sqrt{h_t}}{\sigma_{rolling}}
\]

此处适合把 GARCH 理解为 setup 的**环境条件 / 过滤器**，而非方向预测器。源码实现层面的细节：alpha、beta 是输入的固定参数，omega 由滚动样本方差和 persistence 构造，递推以滚动方差初始化；它没有在该模块中对 GARCH 参数做似然估计。因此若研究参数估计版 GARCH，应视为一个新模型变体，而不是原代码等价复刻。

## 实验结果与证据边界

原文对 GBPJPY H4 的 SignalMode=2（外轨 re-entry）作 algorithm-only 与 algorithm+LSTM 对照。作者报告的 forward 样本中，baseline 为 22 笔、净利约 $11,897、PF 2.88、Sharpe 3.53、Recovery 3.24、DD 14.50%；加入 LSTM 后为 21 笔、净利约 $10,438、PF 2.73、Sharpe 3.11、Recovery 3.02、DD 14.58%。作者指出 LSTM 过滤掉一笔对 baseline 有贡献的盈利空单，并认为当前配置没有显示可测量的 LSTM 增量。

这是**作者报告的初步结果**，不是独立复现。forward 只有 22/21 笔交易，证据很弱；文章也明确称样本初步。对照的交易执行还使用 pending limit orders，且选定测试参数描述为无止损，所以结果不能直接解释为可部署策略的风险回报表现。更合理的结论是：在该实验设计和样本中，LSTM 尚未证明优于 GARCH + setup 基线，而不是“LSTM 普遍无效”。

## 静态源码审阅

- 附件为 `05.mq5` 与 `05-SignalGARCHVolScaledLSTM_.mqh`；仅作静态审阅，未在 MetaEditor 编译或 MT5 Tester 执行。
- wrapper 默认值与文章最终对比配置不同。文章测试使用 SignalMode=2、ATR 35、Bands 10/2、lookback 18、GARCH 240 / alpha 0.10 / beta 0.73、omega scale 1.25、MinExpansion 1.05、RawGate 0.12、EntryThreshold 0.65；LSTM sequence 4、hidden 2、samples 128、horizon 3、weight 0.15。不能用文件默认值冒充报告测试值。
- LSTM 输入包含 sigma-scaled return、ATR/sigma、Band position、Band width/ATR、GARCH expansion、ATR change；其中多项与已有 ATR/Bollinger/GARCH 结构重叠，存在增量信息不足的合理解释。
- 核心实验价值是三个阶段都可单独开关/比较，而非参数或历史收益数字可直接照搬。

## 面向本平台的研究改写

```text
State Grammar / Episode
          ↓
Directional Setup（先定义候选集合）
          ↓
Volatility Gate（GARCH / ATR / RV / Range）
          ↓
Projection / Meta Filter
          ↓
RiskEngine → Execution
```

结合现有 `State × SignedNetMove`，可检验：

\[
State\times SignedNetMove\times VolatilityExpansion
\rightarrow FutureRecovery/MFE
\]

第一轮不要预设 GARCH 必须胜出。并列生成 `GARCHExpansion`、`ATRExpansion`、`RealizedVolExpansion`、`RangeExpansion`，固定相同 setup 样本，对比：

1. Setup-only baseline；
2. Setup + 各单一波动变量 / Gate；
3. Setup + 多波动变量；
4. Setup + LSTM（仅在前面基线稳定后加入）。

观察各 regime / episode stage 下的 OOS MFE、MAE、future recovery、失败率和净成本后收益。连续特征增量应在控制 ATR、range、RV 等变量后评估（例如增量 OOS loss/IC、分层效果或 conditional test），而不是只比较一个优化出的阈值。使用 walk-forward；样本少时报告区间与不确定性，不用单个 Sharpe 结论定型。

## 来源

- [MQL5 原文](https://www.mql5.com/en/articles/24357)
- 附件在 MQL5 页面标为 `05.mq5` 和 `05-SignalGARCHVolScaledLSTM_.mqh`。本地 ZIP 仅用于个人静态研究，未复制进仓库。
