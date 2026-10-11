# 饭搭子计划｜公开仓库项目交接

核对日期：2026-10-11。以九份项目交接、最新完整 UX Handoff、实际工程和测试为依据。完整本地归档继续保存；此仓库是可审阅、可运行的精选发布副本。

## 从这里开始

1. 阅读 README.md / README_EN.md，了解角色、产品目标、成果与边界。
2. 阅读 docs/research.md 与 workflow/README.md，区分研究观察、设计判断与 AI 执行。
3. 按 docs/running.md 导入 godot-demo/project.godot；不要运行旧快照重建脚本覆盖场景。
4. 看 docs/technical.md、docs/validation.md 和 screenshots/ui/index.json 核对实现、验证与 Figma-only 页面。
5. 后续修改在同一仓库提交；同步更新 docs/evidence/ 与中英文 README，勿公开真实研究数据或密钥。

## 核心规范与项目决策

- 四主导航：食宠、日记、计划、健康；记录为突出入口，不是第五 Tab。
- 用户确认前是候选；保存后才成为记录。未知营养不能补零；没有 AI 也可照片记录。
- 角色表达、本人感受、照片估算三者分开；不是健康诊断。
- 个人闭环独立成立；两人各自记录，分享可选，不替对方确认。
- 奶油/低饱和绿与原水獭识别一致；角色不随技术简化而替换。
- 贴纸为可选回顾素材，不能阻塞记录；家具中断不收回，草稿与持久化分开。

## 功能架构与交付状态

| 层 | 范围 | 当前状态 |
|---|---|---|
| 记录 | 导入、候选、份量/标题/餐次、确认、日记、汇总 | 本地核心实现；相机模拟，完整食材编辑与云备份未实现 |
| 理解 | 角色、原因、心情、健康、下一餐计划 | 角色动作/部分本地汇总；生理映射与真实个性化规划未验证 |
| 关系 | 邀请、分享、关心、伙伴空间、隐私 | Figma 与本地模拟；无账号关系、通知和同步后端 |
| 家园 | 32 件家具、奖励、图鉴、My/Partner 布置 | 同机模拟天数与保存/取消/重载已实现 |
| Health 3.0 | 感受、共同食谱、历史计划、食材准备、记录不足 | 新增 11 页 Figma only，320:1003–1013 |
| AI 产品服务 | normalize/analyze/sticker/config | 接口与模拟单测；真实模型与生成效果待验证 |

## 素材实际路径

| 路径 | 用途 |
|---|---|
| godot-demo/assets/figma/ | 原名运行资源；不要随意改名、移动或断开场景引用 |
| godot-demo/assets/fonts/ | Noto Sans SC 与 OFL |
| godot-demo/design/ | 快照、Figma ID、路由、变量、家具与资源映射 |
| screenshots/ui/ | 63 个 UI 导出与节点 ID；不是 `.fig` 原文件 |
| screenshots/runtime/ | 归档真实 Godot 运行截图，使用演示素材 |
| screenshots/process/ | 实际生成与眼睛规范修订对照 |
| assets/previews/ | 食宠、贴纸、家具精选展示；不替代工程原资源 |
| workflow/evidence/ | 精选真实提示词 |
| docs/evidence/ | 历史和本次检查、素材校验/来源 |
| demo/ | 原有动态 GIF 与 Web 导出 |

## 交接来源

本次检查 00_START_HERE、01_APP_MASTER_HANDOFF、02_COMPLETE_FUNCTION_SPEC、03_USER_FLOWS_AND_ARCHITECTURE、04_FIGMA_AND_UI_HANDOFF、05_GODOT_TECHNICAL_HANDOFF、06_ASSETS_AND_VISUAL_SYSTEM、07_PROJECT_STATUS_AND_ITERATION、08_WEBSITE_AND_GITHUB_HANDOFF，以及 20261011 完整 Handoff 可读副本。原文留在本地，公开版避免传播私人记录和失效的本机路径。

## 跨 Codex 会话最简指令

> 克隆 https://github.com/Zhiyuan-Xiong/fandazi，先读 PROJECT_HANDOFF.md、docs/validation.md 与 docs/running.md，再检查 godot-demo/project.godot；按真实代码区分已实现、Figma-only 和待验证功能。不要公开密钥、私人研究记录或覆盖原始归档。
