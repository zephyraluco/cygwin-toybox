# Minimal Cygwin + Toybox

在 Windows PowerShell 7 中运行：

```powershell
./scripts/install-cygwin.ps1
```

脚本通过 HTTPS 从 Cygwin 官网下载安装器，保留安装器默认的软件包签名验证，安装到
`C:\cygwin`，然后检查 Bash、Zsh、OpenSSL 和时区文件。可用 `-Root`
指定安装目录，`-Mirror` 指定镜像，`-Cache` 指定下载缓存目录。

请求的软件包为 `bash,cygwin,ncurses,terminfo,base-files,tzdata,zsh,libssl3,openssh,openssl,xauth`。
Cygwin 安装器还会安装默认基础包和必要依赖，因此这不是严格只包含八个包的环境。

在 GitHub **Actions → Package minimal Cygwin → Run workflow** 手动打包，
或推送相关修改到 `main` 自动打包。运行成功后，在该次运行页面的
**Artifacts → cygwin-x86_64** 下载压缩包，产物保留 **7 天**。
下载产物内包含 `cygwin-x86_64.tar.gz`，其顶层目录为 `cygwin/`。
打包前直接删除 `/usr/share/doc`、`/usr/share/info` 和 `/usr/share/man`，不另行备份或复制其中的文件。
`/usr/share/locale` 仅保留 `locale.alias`，删除翻译文件；`/usr/share/X11/locale` 保留。
打包前删除 CI 遗留的 `/home/runneradmin` 用户目录。

推送 `v*` tag 会在构建和测试成功后自动发布 GitHub Release。
在 Release 的 Assets 中直接下载 `cygwin-x86_64.tar.gz` 及其 `.sha256` 校验文件，
不需要解开 Actions 下载时附加的 ZIP 包装。不要将自动生成的 Source code 压缩包
误当作运行环境。Actions 产物保留 7 天；Release 附件持续保留，直到手动删除。
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
./scripts/install-cygwin.ps1 -Root C:\cygwin-build -AdditionalPackages 'gcc-core,make,patch,xorg-server,libX11-devel,libGL-devel,dri-drivers'
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
Cygwin DLL，并保留 XKB 键盘和 X11 locale 数据。恢复 `cygnativeGLthunk.dll`、
Mesa `swrast_dri.so`、GL 客户端库及其递归 DLL 依赖。
Mesa 使用 Cygwin 官方源包和补丁重新构建，显式设置 `llvm=disabled`，使用
Gallium softpipe；发布包不包含 LLVM DLL。官方二进制 Mesa 仅用于构建环境的
引导依赖，发布时复制自行构建的 `libGL1` 兼容库和软件驱动。
只复制所需驱动，不包含其他 DRI 驱动或外部字体包。基础包、Zsh、OpenSSL 和 Toybox 保留。

支持二维 X11 和不依赖 LLVM 的间接 GLX 软件渲染。
`XWin.exe` 位于 `/usr/bin/`，直接启动与 SSH 转发步骤见下节。

CI 从官方安装器已验证签名的缓存索引读取 Mesa 源包地址和 SHA-512，校验源包后
用 cygport 应用 Cygwin 补丁、Meson/Ninja 构建。构建参数记录在
`/opt/mesa/share/`。CI 检查 LLVM 被禁用、发布目录无 LLVM DLL，并强制
间接 GLX 使用 softpipe 创建上下文、绘制颜色及读回像素，然后回归 Toybox 功能并打包。
X 客户端（如 `xterm`）不包含在发布包内。部署清单和上游版本记录位于
`/opt/xwin/share/`；精简 XWin 为提取的运行文件，不声明为完整的
`xorg-server` 包管理器安装。

`install-cygwin.ps1` 安装基础环境；XWin 由 `scripts/integrate-xwin.sh`
从带有完整 `xorg-server` 的独立构建环境中提取。重复部署请使用干净的基础环境，
避免残留先前完整安装的图形软件包。

## 远程主机 X11 转发

发布包包含 Cygwin OpenSSH 客户端、`xauth` 和 OpenSSL，不提供额外启动包装脚本。

在 Cygwin Bash 中先准备认证数据并启动 XWin：

```bash
export DISPLAY=:0
export XAUTHORITY="${XAUTHORITY:-$HOME/.Xauthority}"
umask 077
mkdir -p "$(dirname "$XAUTHORITY")"
touch "$XAUTHORITY"
chmod 600 "$XAUTHORITY"
# 如果已有该 display 的 cookie，复用它，避免影响正在运行的 XWin。
if [ -z "$(xauth list "$DISPLAY")" ]; then
  xauth add "$DISPLAY" MIT-MAGIC-COOKIE-1 "$(openssl rand -hex 16)"
fi
XWin "$DISPLAY" -multiwindow -clipboard +iglx -nowgl -fp built-ins \
  -nolisten tcp -auth "$XAUTHORITY" &
```

然后连接可信远程主机：

```bash
ssh -Y -o XAuthLocation=/usr/bin/xauth 用户名@远程主机
# 自定义端口：ssh -Y -p 2222 -o XAuthLocation=/usr/bin/xauth 用户名@远程主机
```

在其他终端中连接时，也要设置相同的 `DISPLAY` 和 `XAUTHORITY`。
XWin 使用内置字体、多窗口和剪贴板；`+iglx` 允许间接 GLX，`-nowgl` 使用 Mesa softpipe 软件渲染，TCP 监听仍关闭。
不要使用 `-ac` 或 `xhost +` 关闭认证。

在远程会话中：

```bash
echo "$DISPLAY"  # 通常类似 localhost:10.0，由 SSH 自动设置
xterm &          # 或运行远端已安装的其他二维 X11 应用
```

远程主机需要安装 SSH 服务端、`xauth` 和目标 X11 应用，并在 sshd 配置中启用
`X11Forwarding yes`。远端 `XAuthLocation` 应指向其实际 `xauth` 路径；
修改 sshd 配置后由管理员检查配置并重新加载服务。不要把远端 `DISPLAY`
手动设为 `:0`，也不需要开放本机的 6000 端口；X11 流量经 SSH 隧道传输。

`-Y` 仅连接可信主机。需要限制远端权限时可以尝试 `ssh -X`，其兼容性受
X11 SECURITY 扩展及远端应用影响。

远端程序需要显式选择间接 GLX 时，可以在远端会话中设置：

```bash
export LIBGL_ALWAYS_INDIRECT=1
# Qt/XCB 程序按需使用 GLX，避免其选择 EGL 后端
export QT_XCB_GL_INTEGRATION=xcb_glx
你的图形程序
```

间接 GLX 的 OpenGL 版本和扩展受 XWin/Mesa 限制，不能保证所有现代核心配置
OpenGL、EGL 或 Vulkan 应用可用。恢复 GLX 不意味着远端应用一定停止探测 EGL/DRI3，
这还取决于其图形后端配置。

softpipe 不使用 LLVM JIT，体积较小，但渲染性能通常低于 llvmpipe。

CI 验证 SSH 的 X11 转发选项，以及使用认证 cookie 的本地 X11 连接、窗口、绘图和间接 GLX 像素读回。
实际远程登录与转发还取决于目标主机的 SSH 配置、账号授权和应用；CI 不持有你的远端凭据。
