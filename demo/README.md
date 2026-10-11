# 真实原型与演示 / Prototype & Demo

[在线试玩 / Open Web prototype](https://zhiyuan-xiong.github.io/fandazi/) · [Figma 原型](https://www.figma.com/proto/8wHrD1MYzrA92DJrc4D467/FanDazi?node-id=165-958&starting-point-node-id=165%3A958) · [本地运行](../docs/running.md)

## 浏览器版

使用 Godot 4.7.2 官方单线程 Web 模板，Compatibility / WebGL2。入口可体验食宠导航、明确标注的示例核对、照片导入与确认、日记，以及家园布置。此版本不调用 AI、不接收密钥、不提供正式账号或跨用户同步。原始界面为中文，入口提供中英文说明。

资源与运行时初次下载合计约 121 MB，建议桌面 Chromium 浏览器。照片由浏览器读取，在本地网站存储中保存；不发送到 AI。清除网站数据、存储限制或隐私模式可能使记录丢失，不能当作云备份。

Web demo: local interactions only, with sample artwork and simulated reward days. No live AI, shared API key or cross-user backend. Original app UI remains Chinese. Initial download is approximately 121 MB; browser storage is not a backup.

## 已有真实动态

<img src="otter-home.gif" width="240" alt="原有 Godot 食宠主页动态 / Archived Godot pet animation" />

这段 GIF 来自原项目 QA，不是本次新增视频。完整归档中未找到 MP4，本次没有制作或虚构演示视频。

## 构建与部署

`web/play.html`、`.js`、`.wasm`、`.pck` 为实际导出，`web/index.html` 为演示说明入口；引擎与字体许可位于 `web/THIRD_PARTY_NOTICES.txt`。`play.pck` 81,423,212 字节，使用 Git LFS 管理；其他构建文件均小于 100 MiB。GitHub Actions 先拉取实际 LFS 内容，再上传 Pages artifact，避免向访问者返回 pointer 文本。

不要把 Web 包当作正式移动 App，也不把本次桌面浏览器测试外推为 iOS/Android 兼容性保证。实际检查范围见 [validation.md](../docs/validation.md)。
