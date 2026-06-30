# Bikeen：Market Structure / Price Action Engine 路线图

作者：

- Bikeen / Chukwubuikem Okeke
- 主页：https://www.mql5.com/en/users/bikeen

## 总体定位

Bikeen 的价值集中在 Price Action / Market Structure / SMC 工程实现。

他不是机器学习作者，也不是统计研究作者；更适合归类为：

```text
Market Structure Engine
├── Swing Detection
├── HH / HL / LH / LL
├── BOS
├── CHOCH
├── Support / Resistance
└── Liquidity / Structure Break
```

## 收藏价值

| 方向 | 评级 | 是否收藏 |
|---|---:|---|
| Market Structure | ★★★★★ | 是 |
| BOS / CHOCH | ★★★★★ | 是 |
| Swing Detection | ★★★★★ | 是 |
| Support / Resistance | ★★★★☆ | 是 |
| Price Action Engine | ★★★★☆ | 是 |
| EA 策略 | ★★★☆☆ | 选择 |
| Machine Learning | ★☆☆☆☆ | 否 |
| Python | ★☆☆☆☆ | 否 |

## S 级：Building the Market Structure Sentinel Indicator

来源：

- https://www.mql5.com/en/articles/22249

定位：

```text
Market Structure Sentinel
    = Swing + Structure State + BOS + CHOCH
```

推荐拆解：

```text
SwingEngine
    ↓
StructureEngine
    ↓
BOSEngine
    ↓
CHOCHEngine
```

收藏点：

- swing high / swing low 检测；
- HH / HL / LH / LL 状态更新；
- BOS 作为趋势延续事件；
- CHOCH 作为潜在结构反转事件；
- 结构事件应输出统一 event，而不是直接交易。

## A 级：Support & Resistance Sentinel

来源：

- https://www.mql5.com/en/code/69219

推荐拆解：

```text
SupportResistanceEngine
├── candidate level
├── validation
├── monitor
├── invalidation
└── replacement
```

这类模块以后可以服务：

- liquidity pool；
- retest event；
- breakout event；
- feature distance；
- Meta Label context。

## A 级：Liquidity / Structure Sweep

来源：

- https://www.mql5.com/en/articles/22140

推荐拆解：

```text
LiquiditySweepEngine
├── prior level
├── sweep
├── rejection / reclaim
└── confirmation
```

这和 LynnChris 的 Liquidity Sweep、ORB、BOS/CHOCH 可以合并为统一 `StructureEvent`。

## 平台化设计

Bikeen 的文章不应以独立指标保存，而应吸收到平台基础组件：

```text
MarketData
    ↓
SwingEngine
    ↓
StructureEngine
    ├── BOSEngine
    ├── CHOCHEngine
    ├── SupportResistanceEngine
    ├── LiquiditySweepEngine
    ├── OrderBlockEngine
    └── FVGEngine
```

统一输出：

```text
StructureEvent
├── event_type
├── direction
├── level_price
├── swing_id
├── confirmation_time
├── confidence
└── metadata
```

## 和 LynnChris 的区别

| 作者 | 更强方向 |
|---|---|
| LynnChris | 事件流水线、Indicator Buffer → EA、Geometry / Object integration |
| Bikeen | Swing / BOS / CHOCH / Support-Resistance 的核心结构算法 |

二者应该合并，而不是二选一：

```text
Bikeen = structure detector core
LynnChris = execution / buffer / event integration
```

## 不建议收藏的部分

- 某个具体开仓规则；
- 参数优化结果；
- 直接把 BOS/CHOCH 当买卖信号；
- 指标可视化细节。

## 结论

Bikeen 应作为 `Market Structure Engine` 专题作者收藏。

他的文章适合补齐：

```text
SwingEngine
StructureEngine
SupportResistanceEngine
```

这些模块后续可以被：

- Replay；
- FeatureEngine；
- Meta Labeling；
- RegimeEngine；
- Paper / Live execution；

共同复用。

