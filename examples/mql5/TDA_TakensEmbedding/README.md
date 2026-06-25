# TDA Takens Embedding

Source:

- MQL5 Article: <https://www.mql5.com/en/articles/23037>
- Title: Shape of Price: An Introduction to TDA and Takens Embedding in MQL5

Positioning:

```text
Quant research foundation library, not a trading strategy.
```

## Files

- `TDAPointCloud.mqh` - converts a 1D price series into a Takens delay-embedded point cloud.
- `TDADistance.mqh` - builds a full pairwise distance matrix from a point cloud.
- `TDA_Demo.mq5` - script example that loads close prices, builds the cloud, and prints sample distances.

## Core Takeaways

- Treat Takens embedding as feature engineering: time series to state-space trajectory.
- Keep point cloud construction separate from distance computation.
- Store point clouds and distance matrices as flattened arrays for cache-friendly access.
- Use `Build()` methods so objects can be reused without repeated allocation through constructors.
- Expose distance norms with an enum instead of magic integers.

## Reuse Targets

This component can feed:

- TDA / persistent homology;
- recurrence analysis;
- clustering;
- graph construction;
- manifold learning;
- regime detection;
- Python-side research pipelines.

The current implementation is a foundation layer. It does not generate alpha by itself.
