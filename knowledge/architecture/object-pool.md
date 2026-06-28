# Object Pool：热路径对象生命周期管理

参考来源：

- [Generic Object Pool in MQL5](../articles/generic-object-pool-high-frequency-mql5.md)
- 源码：[examples/mql5/ObjectPool](../../examples/mql5/ObjectPool/)

## 目标

在高频路径减少动态分配：

```text
Preallocate
  ↓
Acquire
  ↓
Use
  ↓
Reset
  ↓
Release
```

## 适用场景

适合：

- TickEvent / BarEvent 高频对象；
- temporary signal payload；
- chart object wrapper；
- 高频 indicator state；
- replay 中大量短生命周期对象。

不适合：

- 低频 EA；
- 生命周期不清晰对象；
- reset 成本高或容易漏字段的对象；
- 需要无限动态扩容的集合。

## 平台接口建议

```python
class ObjectPool:
    def acquire(self): ...
    def release(self, obj): ...
    def active_count(self) -> int: ...
    def free_count(self) -> int: ...
```

Python MVP 阶段可以不实现对象池。对象池应留到 profiling 证明 `new/delete` 或 GC 成为瓶颈后再加。

## MQL5 侧约束

MQL5 更容易受频繁 `new/delete` 影响，因此在 MQL5 高频组件中对象池价值更高。

最低要求：

- fixed capacity；
- double-release protection；
- payload reset；
- pool owns lifecycle；
- benchmark 验证收益。

## 风险

对象池会增加复杂度。错误的 reset 会产生更隐蔽的脏状态 bug。

原则：

```text
先清晰，后池化。
只池化热路径。
```
