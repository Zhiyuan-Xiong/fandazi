# 饭搭子

饮食记录、食宠与 AI 照片工作流的 UX 原型，进行中。

**[完整设计案例](https://xiongzhiyuan-portfolio.pages.dev/zh/works/?project=fandazi) · [求职作品总入口](https://github.com/Zhiyuan-Xiong/xiongzhiyuan-portfolio)**

<p align="center"><img src="previews/otter-home.gif" alt="饭搭子" width="350"></p>

## 项目目标

项目进行中。完成后补充问题定义、用户流程与原型。

## 我的贡献

用户体验、界面与原型设计；整理 AI 照片记录工作流。

**项目进行中。** 本仓库展示现有设计与可编辑原型；完整商业产品、真实共享服务与付费 AI 质量尚待继续验证。

## AI 与制作工作流

### 1. UX 结构与 Figma 原型

围绕记录饮食、查看日记、今日计划、食宠互动与搭子体验建立用户路径，保留页面和组件状态。

### 2. AI 食物识别

照片、补充信息与结构化约束进入食物识别流程，用户核对食物与份量后再保存。

### 3. 同风格贴纸生成

以餐食照片为内容、现有 Figma 食物插画为风格参考，生成透明 PNG，并检查透明通道与结果状态。

### 4. 人工确认与降级

未配置密钥时可以保存照片；用户手动核对识别信息，生成失败保留已有记录，原型中的示例数据明确标注。

### 5. 当前状态

UX 原型进行中。仓库提供 Godot 原型、本机 Python 服务和设计资料；真实付费 AI 调用的端到端质量尚未验证。

## 仓库内容

| 内容 | 入口 |
| --- | --- |
| Figma 图层与 Godot 原型 | [prototype/design/](prototype/design/)、[prototype/scenes/](prototype/scenes/) |
| 交互与状态代码 | [prototype/scripts/](prototype/scripts/) |
| AI 服务与结构化数据 | [prototype/ai_service/](prototype/ai_service/) |
| 页面与动效预览 | [previews/](previews/) |

## 运行与范围

用 Godot 4.7.2 导入 `prototype/project.godot`。AI 服务使用本机 Python，依赖见 `prototype/ai_service/requirements.txt`，启动程序见 `prototype/ai_service/start.ps1`。真实 AI 使用需要使用者自己的配置，密钥与个人照片不随仓库发布。

照片估算需人工核对；原型中的示例数据和实际照片记录流程应分别理解。模型权限、端到端质量和外部共享仍待验证。

## 署名与使用

作品素材用于个人设计展示。协作项目以案例中的职责说明为准；字体、引擎和第三方资料遵循各自授权。未经许可，不将作品素材用于转载或商业用途。
