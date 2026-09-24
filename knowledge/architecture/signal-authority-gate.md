# Signal Authority Gate

Signal Authority Gate 是位于预测/信号生成之后、风险检查之前的独立决策组件。它回答“当前是否授权这个候选信号进入交易流程，以及授权强度是多少”，不负责预测方向、不下单，也不能覆盖账户级风险限制。

## 在平台中的位置

```text
Market / Feature / Episode
          ↓
Signal Producer(s)
          ↓ SignalEvent
AuthorityObservation + outcome history
          ↓
SignalAuthorityGate
  ACCEPT | REDUCE_AUTHORITY | REJECT
          ↓
RiskEngine → OrderManager → Broker
```

Gate 与 Projection Gate 可共享评估基础设施，但语义不同：Projection Gate 判断结构化 Episode 是否满足投影条件；Signal Authority Gate 判断候选信号是否应被采用以及采用到什么程度。某个信号先通过结构 Gate，仍须通过 Authority Gate 和最终 RiskEngine。

## 数据契约草案

```python
@dataclass(frozen=True)
class AuthorityObservation:
    decision_id: str
    signal_id: str
    timestamp: datetime
    symbol: str
    producer: str
    producer_version: str
    confidence: float | None
    uncertainty: float | None
    regime: str | None
    episode_state: str | None
    recent_performance: dict[str, float]
    features: dict[str, float | str | bool | None]

@dataclass(frozen=True)
class GateDecision:
    decision_id: str
    signal_id: str
    action: Literal["ACCEPT", "REDUCE_AUTHORITY", "REJECT"]
    authority_multiplier: float
    reason_codes: tuple[str, ...]
    policy_version: str
    timestamp: datetime
```

Gate 不修改原始 SignalEvent；DecisionLog 同时保存输入快照、输出和策略版本。`authority_multiplier` 表示候选信号的授权系数，不等同于最终 lot size，也不能把仓位乘数提高到基础风险预算之上。

## 结果回填与学习闭环

```text
decision_id / signal_id
      ↓ join
Order → Fill → Position lifecycle
      ↓ after outcome is known
OutcomeEvent (net PnL, MFE, MAE, costs, failure reason)
      ↓
Calibration / Gate Evaluation
      ↓ offline policy update
```

每次决策必须独立存储其 observation、action 与 outcome 关联，不能使用一个可被后续信号覆盖的全局 `last_action`。结果应包含费用后的收益和风险指标；方向判断正确率可以是一个诊断项，但不能替代 PnL、概率校准或风险调整评估。

## 评估和上线约束

1. **确定性基线优先**：先比较 always-accept、固定阈值、规则型 Gate；RL 只有在样本外证明增益后才增加。
2. **时间顺序验证**：使用 walk-forward；在重叠标签场景采用 purging/embargo，避免未来 outcome 泄漏进 observation。
3. **校准单独测量**：对概率输出使用 Brier、log loss、reliability curve / ECE；近期胜率与置信度校准分开。
4. **影子与回放**：新 policy 先 shadow，不影响下单；同一历史输入必须确定性地重现相同决策。
5. **安全单调性**：Gate 只能接受、减弱或拒绝策略授权；不能取消 RiskEngine 的限额、治理规则或 Broker 校验。
6. **探索隔离**：epsilon-greedy 等在线探索不得直接控制 Live 订单。在线学习先写入候选模型，经过离线验证、版本审核和回滚机制后再发布。
7. **拒绝也留痕**：所有被拒信号都写 DecisionLog，后续观察反事实结果，避免只对已成交样本评估导致选择偏差。

## 与相关架构的边界

- **Producer / Model**：生成候选方向、置信度、止损/目标和模型版本。
- **Projection Gate**：对 Episode 的结构完整性、失效条件和目标几何作判断。
- **Signal Authority Gate**：评估候选信号当前的使用权限及折减程度。
- **RiskEngine**：验证账户、组合、品种暴露、日损、保证金、交易时段等硬约束并确定最终风险。
- **OrderManager / Broker**：转换获准决策并执行，不重新解释预测置信度。

## 来源

- [MQL5 Article 21182：How to Create and Adapt an RL Agent with an LLM and Quantum Encoding for Algorithmic Trading in MQL5](https://www.mql5.com/en/articles/21182)
- [文章研究条目](../articles/llm-rl-signal-authority-gate.md)
