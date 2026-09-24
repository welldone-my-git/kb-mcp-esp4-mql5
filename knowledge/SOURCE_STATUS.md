# 资料来源与验证状态

本目录以研究摘要和架构笔记为主。源码是否已取得、是否经过编译或运行，需要与文章分析结论分开标记。

## 状态定义

| 状态 | 含义 |
|---|---|
| `summary_only` | 根据已提供的文章内容整理；原文或附件未在本地核对。 |
| `source_linked` | 记录了可访问的原文链接；附件源码未核验。 |
| `source_downloaded` | 附件已下载到本地；尚未整理进 `examples/`，也未验证。 |
| `curated_example` | 已整理到 `examples/`，并附有来源与文件说明；不等于已编译。 |
| `verified` | 明确记录了验证方式和环境；MQL5 项目需注明 MetaEditor/终端版本，Python 项目需注明运行命令与依赖。 |

## 记录要求

文章知识条目建议在元信息中包含：

```yaml
source_url: https://...
source_status: source_linked
code_status: not_verified
checked_at: YYYY-MM-DD
```

源码样例的 README 应说明原文链接、文件来源、整理改动和验证状态。若只完成静态阅读，写 `read_only_review`；不要标记为 `verified`。

## 分发范围

本项目用于个人或内部研究，不对第三方文章正文、附件源码、文档或书籍进行再分发。`download/` 是本机临时收集目录，不属于版本控制或 npm 发布内容。需要分享研究结论时，保留来源链接并使用自有摘要；第三方材料仍按各自权利人的条款处理。
