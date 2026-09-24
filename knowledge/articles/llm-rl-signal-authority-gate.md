# LLM + RL Signal Authority Gate：从预测器转向信号授权

```yaml
source_url: https://www.mql5.com/en/articles/21182
source_title: How to Create and Adapt an RL Agent with an LLM and Quantum Encoding for Algorithmic Trading in MQL5
author: Yevgeniy Koshtenko
source_status: source_downloaded
code_status: read_only_review
checked_at: 2026-09-24
local_attachment: download/ai_trader_SEAL_with_RL_MINIMAL_21182.py (ignored; not redistributed)
```

## 核心判断

对本平台最有价值的不是“量子 + LLM + DQN”堆叠，而是把预测器与授权决策分开：预测器提出候选信号，独立 Gate 决定接受、降低其影响或拒绝。它与现有的 Projection / Failure Gate、Episode History 和交易治理层相邻，适合沉淀为 **Signal Authority** 概念。

```text
Producer / Model
       ↓ candidate SignalEvent
Authority Observation
       ↓
Authority Gate
  ACCEPT | REDUCE_AUTHORITY | REJECT
       ↓
RiskEngine（最终风险否决权）
       ↓
Order / Execution
```

## 文章中应区分的两个学习器

源码将两个不同职责的模块放在同一系统中，不能混为一谈：

1. `QuantumDQNAgent` 是方向/持仓动作模型，面向 long、short、hold、close 等动作值。
2. `LightweightRLAgent` 是轻量 Q-learning 元决策器，状态由量子熵、LLM confidence、最近胜率分箱构成，动作是 USE、SKIP、REDUCE。它才是本项目 Signal Authority Gate 的直接概念来源。

因此，“DQN → Regime-aware PPO”是面向自有平台的替代设计建议，不是对文章模块的一一对应。将来若采用 PPO，也应把它看作 Gate policy 的一种实现，先与简单、可解释的规则 Gate 对照。

## 可迁移思想

- **预测与授权解耦**：任何 RSI、ADX、ML、LLM 或几何 Episode 都可成为 Producer；Gate 不负责重新预测方向。
- **信号不确定性进入决策上下文**：模型置信度、状态不确定性、近期表现、Regime 与 Episode 阶段可作为观测特征，但必须保留各自定义和时间戳。
- **Episode 结果反馈**：把 Signal/Projection 与之后的 outcome 用稳定 ID 关联，记录收益、MFE/MAE、失效类型和成本，再离线评估 Gate。
- **动作表达授权而非方向**：ACCEPT、REDUCE_AUTHORITY、REJECT 控制信号能否进入后续流程；最终仓位仍由 RiskEngine 根据账户和组合约束决定。

## 源码静态审阅要点与限制

- 文章把“最近 20 笔交易方向是否判断正确”的比例作为 `recent_win_rate`，它不是严格意义上的概率校准。置信度校准应另用可靠性分箱、Brier score、log loss 等方法测量。
- `confidence`、`quantum_entropy`、近期方向胜率是不同量纲的观测，不应直接视作同一种“真实信心”。先定义来源、尺度、可用时间和缺失值策略。
- 被审阅的实现把 `last_state` / `last_action` 放在 Trainer 级别；若多个预测尚未结算而结果异步返回，可能把奖励记给错误动作。平台实现必须按 `decision_id` 保存每次决策的状态、动作和 outcome join key。
- `REDUCE` 在示例中是把 confidence 乘以 0.7，并非风险预算的直接 0.7 倍。建议 Gate 返回明确的 authority multiplier / reason code；RiskEngine 再将其映射到风险预算，并可单调收紧而不能越权放宽。
- 若没有 Qiskit，附件使用随机数生成 pseudo-quantum 特征；这不是可用的生产 fallback。量子编码应保持可选，必须通过 classical baseline、消融实验和确定性回放证明增益。
- 页面一处称架构尚未测试，后文又给出回测表现；结果证据存在内部不一致。文中绩效数字只能视为作者报告，不能视为独立复现或验证。
- 本地附件仅做静态阅读，没有执行或验证；附件受其权利人条款约束，不纳入仓库分发。

## 对本知识库的结论

收录“Signal Authority / Gate”架构，不把量子特征、BIP39/hash 编码或文章中自报绩效直接收录为可用 Alpha。建议先实现确定性规则 Gate 和离线评估，再决定是否需要 bandit/RL policy。
