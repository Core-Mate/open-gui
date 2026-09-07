# OpenGUI Codex 独立插件

仅支持 macOS arm64/x64 上的本地 Codex，用截图驱动 Android 操作并提供只读设备墙。
当前是候选源码包，不代表已发布或通过公开目录审核。

- 与生产 DSH 完全分开维护源码、依赖、版本和发布流程，不改动或重载 DSH。
- 首次使用原生弹窗确认下载固定 Node 运行时，校验后保存在独立目录；不改系统 PATH。
- 最多冻结四台测试设备；只读监控不占控制锁。
- 发送、发布、购买、删除需要对话确认和原生单次确认。
- 取消/关闭清理会话截图；空闲会话 30 分钟过期，空闲守护进程 5 分钟退出。

## 普通用户安装

正式发布后，从对应 [Codex Release](https://github.com/Core-Mate/OpenGUI/releases) 下载
`opengui-codex-版本-install.command` 及其 `.sha256`，在下载目录校验后运行：

```sh
shasum -a 256 -c opengui-codex-0.1.0-install.command.sha256
bash opengui-codex-0.1.0-install.command
```

安装器自动下载并校验预构建包、准备私有 Node、注册独立插件来源。需要带插件管理功能的
Codex CLI，不需要 Git、pnpm、Xcode 或源码构建。完成后新开对话，选择 OpenGUI，先说
“列出已连接手机，不操作手机”。USB 授权仍需在手机上批准。

也可让 Agent 使用仓库的 [安装 Skill](../../skills/opengui-plugin-install/SKILL.md)，
说“帮我安装 OpenGUI Codex 插件”。它会自动查找匹配的正式版本并校验安装文件。
当前尚未正式发布；没有完整 Release 时会明确停止，不会偷偷转为源码构建。

升级前结束旧任务。同名插件冲突会提示，不会自动移除。旧包和配置备份保存在
`~/.codex/opengui-codex/packages`，使用 `CODEX_HOME` 时跟随该目录。回退可运行旧版本安装器。

维护者测试候选包：`bash scripts/install-macos.command --archive /绝对路径/opengui-codex-0.1.0.tar.gz`，
同目录需有归档的 `.sha256` 文件。

## 开发者构建

开发时在本目录运行 `pnpm install --frozen-lockfile --ignore-scripts`、
`pnpm check` 和 `pnpm package`。打包产物位于 `.artifacts/`。
原仓库 marketplace 保持原样，安装器自动使用独立来源，不要求用户自行搭建 marketplace。

会话操作使用宿主提供的 `CODEX_THREAD_ID` 绑定当前任务，缺少该身份时拒绝执行。
会话列表仅返回当前任务的会话；设备墙令牌也按会话隔离。此机制防止任务间误操作，
不防御能伪造环境变量或读取本地文件的同用户恶意进程。动作失败后必须重新观察，
旧截图凭据不可重用；同一手机重连后保留身份。协议已升级为 2，旧守护进程须先
完成会话并退出，再使用新版。

首次使用运行 `sh scripts/opengui --setup`，随后运行 `--doctor`。
ADB 服务不存在时，`--setup-adb-server` 在原生确认后启动；已有服务不兼容时拒绝，
不会自动重启。ADB 和手机仍是共享资源，不能保证跨宿主互斥，
因此不要在生产 DSH 主机或正在被其他程序控制的手机上验收。

完整使用方法、异常恢复和回退步骤见 [English README](README.md)；
数据边界见 [隐私说明](docs/privacy.md)。自动化检查、真机验收、GitHub Release、
提交审核、审核通过和正式上架须分别确认。
