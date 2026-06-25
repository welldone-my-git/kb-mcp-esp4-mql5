# RQA Library

Source:

- MQL5 Article: <https://www.mql5.com/en/articles/22288>
- Title: Recurrence Quantification Analysis (RQA) in MQL5: Building a Complete Analysis Library

Positioning:

```text
Nonlinear dynamics feature library, not a trading strategy.
```

## Files

- `RQAMatrix.mqh` - Takens embedding, distance calculation, and binary recurrence matrix construction.
- `RQAMetrics.mqh` - RQA metric engine: RR, DET, LAM, TT, L, Lmax, Vmax, ENTR, DIV, RATIO, TREND, COMPLEXITY.
- `RQAEpsilon.mqh` - epsilon selection strategies, including fixed, standard deviation fraction, range fraction, and target recurrence rate.
- `RQAWindow.mqh` - rolling RQA engine and metric series extractors.
- `RQA.mqh` - facade that chains epsilon selection, matrix construction, and metrics.
- `RQA_Example.mq5` - script usage example.
- `RQA_Indicator.mq5` - indicator example plotting RR, DET, LAM, ENTR, and TREND.

## Core Takeaways

- The library is organized as a bottom-up pipeline: matrix, metrics, epsilon, window, facade.
- `SRQAResult` is the central result struct for all recurrence metrics.
- `CRQAEpsilon` separates threshold selection from metric computation.
- `CRQAWindow` turns one-shot RQA into a time series of regime features.
- The facade `CRQA` provides a clean one-call API for experiments and EA integration.

## Reuse Targets

This is useful as a feature engine for:

- market regime detection;
- determinism and laminarity filters;
- non-stationarity diagnostics;
- recurrence entropy features;
- Python + MQL5 research pipelines.

The expensive parts are matrix construction and rolling recomputation. For larger windows, move heavy analysis to Python or add incremental/sparse approximations.
