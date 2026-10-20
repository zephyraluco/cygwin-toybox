# Minimal Cygwin + Toybox

在 Windows PowerShell 7 中运行：

```powershell
./scripts/install-cygwin.ps1
```

脚本通过 HTTPS 从 Cygwin 官网下载安装器，保留安装器默认的软件包签名验证，安装到
`C:\cygwin`，然后检查 Bash、Zsh、OpenSSL 和时区文件。可用 `-Root`
指定安装目录，`-Mirror` 指定镜像，`-Cache` 指定下载缓存目录。

请求的软件包为 `bash,cygwin,ncurses,terminfo,base-files,tzdata,zsh,libssl3`。
Cygwin 安装器还会安装默认基础包和必要依赖，因此这不是严格只包含八个包的环境。

在 GitHub **Actions → Package minimal Cygwin → Run workflow** 手动打包，
或推送相关修改到 `main` 自动打包。运行成功后，在该次运行页面的
**Artifacts → cygwin-x86_64** 下载压缩包，产物保留 **7 天**。
下载产物内包含 `cygwin-x86_64.tar.gz`，其顶层目录为 `cygwin/`。
请在 Windows 上解压到目标父目录；Cygwin 不是 Linux 可执行环境。

安装器和软件包使用镜像当前版本，未固定版本；不同日期打包结果可能不同。

## Toybox

Actions 使用独立的 `C:\cygwin-build` 安装 `gcc-core,make,patch`，编译
Toybox **0.8.15**（上游 `landley/toybox`，固定提交
`a57b091d05ec366dcd4dd737784c03761cb6a4b1`），再集成到 `C:\cygwin`。
最终压缩包不包含该编译环境；只复制程序及其需要的 Cygwin DLL。

在解压后的 Cygwin Bash 中使用：

```bash
toybox --version
toybox                 # 列出实际启用的命令
toybox ls -l
toybox sha256sum file

# 可选：让当前终端优先使用 Toybox 命令
export PATH=/opt/toybox/bin:$PATH
```

主程序位于 `/usr/local/bin/toybox.exe`，独立命令入口位于
`/opt/toybox/bin/*.exe`，不会覆盖现有 Cygwin 工具。
上游许可、构建配置、版本和命令清单位于 `/opt/toybox/share/`。

`scripts/toybox-cygwin.config` 选择适用于 Cygwin 的命令子集，
`scripts/patches/toybox-cygwin.patch` 提供平台兼容层。
不启用 Linux 内核专用工具或依赖文件通知的工具（如 `tail -f`）。
这是 Cygwin 动态链接程序，需要随包提供的 Cygwin 运行环境，不是独立 Win32 程序。

手动构建时，先检出上述 Toybox 提交，再运行：

```powershell
./scripts/install-cygwin.ps1 -Root C:\cygwin-build -AdditionalPackages 'gcc-core,make,patch,xorg-server,libX11-devel'
./scripts/install-cygwin.ps1 -Root C:\cygwin
# 从项目根目录执行；将 D:\src\toybox 替换为上游源码目录
$build = & C:\cygwin-build\bin\cygpath.exe -u "$PWD/scripts/build-toybox.sh"
& C:\cygwin-build\bin\bash.exe --login $build D:\src\toybox C:\cygwin
$test = & C:\cygwin\bin\cygpath.exe -u "$PWD/scripts/test-toybox.sh"
& C:\cygwin\bin\bash.exe --login $test
```

构建脚本在干净的上游检出目录应用补丁；重复构建请使用新的干净检出目录。

## Minimal Cygwin/X

发布包从独立构建环境中提取 `XWin.exe`、`xkbcomp.exe` 及递归导入的
Cygwin DLL，并保留 XKB 键盘和 X11 locale 数据。不复制完整图形依赖树、
Mesa DRI 驱动、LLVM 或外部字体包。基础包、Zsh、OpenSSL 和 Toybox 保留。

在 Windows 的 Cygwin 终端中运行：

```bash
start-xwin :0 &
export DISPLAY=:0
```

启动器启用多窗口和剪贴板，禁用 GLX/3D 和 TCP 监听，并使用服务器内置字体。
只提供二维 X11 功能；需要 OpenGL/GLX 的程序不在这个精简配置的支持范围内。
`XWin.exe` 仍位于 `/usr/bin/`，直接启动时请使用同样的参数：

```bash
XWin :0 -multiwindow -clipboard -extension GLX -fp built-ins -nolisten tcp
```

CI 通过真实 X11 连接验证窗口创建与绘图，并回归 Toybox 功能后打包。
X 客户端（如 `xterm`）不包含在发布包内。部署清单和上游版本记录位于
`/opt/xwin/share/`；精简 XWin 为提取的运行文件，不声明为完整的
`xorg-server` 包管理器安装。

`install-cygwin.ps1` 安装基础环境；XWin 由 `scripts/integrate-xwin.sh`
从带有完整 `xorg-server` 的独立构建环境中提取。重复部署请使用干净的基础环境，
避免残留先前完整安装的图形软件包。
