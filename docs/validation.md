# 本次仓库副本验证｜2026-10-11

## 检查结果与证据

| 检查 | 结果 | 证据 |
|---|---|---|
| Godot 4.7.2 导入 | 通过，无 GDScript 解析错误 | 全部场景及资源完成导入 |
| 场景与目标 | 55 个场景、457 个目标通过 | [smoke.log](evidence/current/smoke.log) |
| 核心流程 | 49 项通过，隔离合成数据，live_ai=false | [core_flow_result.json](evidence/current/core_flow_result.json)、[core.log](evidence/current/core.log) |
| Python 服务 | 11 项单元测试通过，模拟传输 | [service.log](evidence/current/service.log) |
| Web 导出 | 成功，官方单线程模板；包 81,423,212 字节，WASM 39,514,754 字节 | [导出预设](../godot-demo/export_presets.cfg)、demo/web/ |
| 本机桌面浏览器 | 实际渲染主页、导航日记、示例餐食、浏览器文件选择、照片确认/保存、重新打开后日记读取；自由布置、第 32 天领取 30 件、沙发放置/拖动/保存/重载 | Chromium / Codex in-app browser，演示图片，无真实用户数据 |
| 中英文文档 | 同一结构、同一图片顺序与核心数字；人工核对研究/实现边界 | README.md / README_EN.md |
| 有效入口 | 中英文作品集、Figma 原型均通过浏览器访问 | 作品集真实 `/zh/work/fandazi/` 与 `/en/work/fandazi/` |

历史与本次报告分开放置。`historical/archive_pack_result.json` 是原归档导出包的 49 项检查；本次将同一驱动改为写入隔离 `user://publication-qa`，针对发布副本源码重跑，模式明确为 `headless-source-publication-copy`。32 项为逐件家具纹理检查，不能解释成 49 个不同产品功能。

首次在受限账户运行时出现系统根证书存储访问提示；使用实际用户、同样隔离的测试配置重跑后无该提示，55/457 与 49 项均通过。没有读取真实 API 配置或使用真实用户存档。11 项服务测试没有付费网络请求。

## 不在本轮结论内

- 全部 63 个设计逐页人工验收；新版 11 页仍是 Figma only。
- 真实 AI 权限、识别准确率、油量/营养可靠性、生成贴纸质量与实际收费。
- 正式账号、跨用户同步、真实通知、共享计划协作、生产备份和多端冲突。
- 手机浏览器、iOS/Android 原生体验、无障碍完整测试与长期性能。
- 用户留存、健康改善或效率提升比例；本轮工程检查不是用户研究。

## 发布前文件检查

当前候选文件与既有 Git 历史 blob 扫描常见 API Key、GitHub Token、AWS Key 和私钥特征；未发现真实密钥。测试连接令牌是固定演示值，不授予真实服务访问。未带入真实 `.env`、bridge/settings、私人聊天或第三方角色参考。Figma MCP 原始上下文/临时资源链接不公开。

素材权利按作者确认与 Noto OFL 分开记录，不自行授予原创资产商用许可。所有 README 相对链接、图片及资源来源索引在最终提交前检查；自动扫描不是对所有权利或安全问题的绝对保证。
