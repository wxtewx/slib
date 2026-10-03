# slib.sh

> A pure POSIX‑shell utility library for Linux shell installer / TUI interactive scripts.
> 一套纯 Shell 脚本工具库，面向 Linux 安装脚本、终端交互式 TUI，兼容 bash / dash。

## 📜 简介

**slib.sh** 整合终端环境探测、ANSI 彩色输出、分级日志库、spinner 旋转加载动画、任务执行封装(`run`)、原生终端 TUI 交互组件、系统发行版识别、FQDN主机名校验、交换文件自动管理、防火墙端口放行、包管理器初始化等底层基础设施函数。

该库没有独立二进制，以 **shell include( sourcing )** 的方式嵌入业务安装脚本。

> 原始子模块来源（改造整合）：
> - `scolors`：终端颜色探测与色彩常量
> - `slog`：分级日志（支持中文日志标签，输出stdout+落盘日志文件）
> - `spinner`：后台旋转加载指示器
> - `run_ok`：封装命令执行+spinner动画+彩色OK/ER状态标记
> - 自研原生TUI组件 `task`：不需要dialog/ncurses；直接读写 `/dev/tty`
> - `swap_*` 系列：事务化swap文件管理，支持ext4/xfs/btrfs，fstab+systemd drop‑in
> - `get_distro`：多发行版识别（含国产openEuler、openKylin、Anolis等）

## ✨ 主要特性

### 🎨 终端 & 颜色层
- 自动探测 `TERM`；终端异常时自动回退备选终端类型(`xterm‑256color`…`dumb`)
- 自动识别8‑color /16‑color /256‑color；tput 提取颜色；tput缺失时自动禁用全部色彩
- 导出前景、背景、粗体、反显、暗淡、下划线常量 `$RED $GREEN $CYAN ...`
- `mk_underline()`：自适应终端宽度绘制Unicode水平分隔线

### 📋 日志子系统 (`slog`)
- 日志级别：`DEBUG / INFO / SUCCESS / WARNING / ERROR`
- 可分别配置**标准输出级别阈值**(`LOG_LEVEL_STDOUT`)、**日志文件落盘级别阈值**(`LOG_LEVEL_LOG`)
- 设置环境变量 `LOG_PATH=/var/log/install.log` 即可开启磁盘日志持久化
- 日志输出自动汉化标签：`[调试] [信息] [成功] [警告] [错误]`
- `prepare_log_for_nonterminal()`：过滤ANSI转义序列，用于日志落盘；剥离终端控制字符
- 快捷日志函数：`log_debug()` `log_info()` `log_success()` `log_warning()` `log_error()`

### ⏳ Spinner & 任务执行
- `spinner()`：后台旋转加载动画；父进程消失自动退出；支持ASCII fallback（Unicode不可用时）
- `run ok|set "shell_command" "task description"`
  - 启动后台spinner；执行shell命令；结束在77列位置渲染✅/❌（ASCII模式回退OK/ER）
  - 内置任务日志写入 `RUN_LOG`；支持全局 `RUN_ERRORS_FATAL` 开启失败即终止
  - `run set` 模式支持自动统计总任务数并渲染进度 `[i/N]`

### 🖥️ 原生TUI交互组件（`task`，**不依赖dialog**）
> 直接读写 `/dev/tty`；捕获原始键盘；支持Vim风格快捷键(j/k/h/l)

交互模式列表：
1. `task info "提示文本"` ——普通单行文本输入
2. `task secret "输入密码"` ——密码掩码输入（屏幕显示`*`），支持光标左右移动、中间插入删除
3. `task select_updown [keep|clear|fullclear] "标题" "opt1|opt2|opt3"` —竖向单选菜单（↑↓ / j k）
4. `task multiselect [keep|clear|fullclear] "标题" "opt1|opt2|opt3"` —竖向多选菜单
    - `空格`切换勾选；`a`全选；`n`取消全选；回车确认；返回值使用`|`分隔多个选中项存入全局变量 `reply`
5. `task select "标题" "opt1|opt2"` —横向单行单选菜单（←→ / h l；实心●空心○标记）

配套上层封装：
- `yesno()`：Y/N行式确认；识别 `skipyesno` / `NONINTERACTIVE` 非交互模式阻断
- `task_select_yesno() { yes‑callback no‑callback prompt }`：TUI横向是/否选择框
- `password()`：交互式设置强密码；强制≥8位，必须包含大小写、数字、特殊符号；二次确认
- `MainMenu()`：批量数字索引选择菜单；支持多列排版
- `title()`：清屏后居中输出标题；`ComputingColumn()` 中文宽度辅助计算；`clear_menu()`向上回退清除菜单输出

### 🛠️ 系统基础设施工具函数
- `detect_ip()`：自动检测服务器本机IP（优先默认路由网卡；兼容Linux/FreeBSD；IPv4+IPv6；识别失败允许手动输入网卡）
- `is_fully_qualified()`：FQDN域名/IP合法性校验；拦截`localhost.localdomain`、`*.internal`
- `set_hostname()`：设置主机名；同步`/etc/hostname` & `/etc/hosts`；适配cloud‑init防止主机名被云平台重置；最多3次重试输入
- `set_domain()`：交互式设置FQDN域名；重试校验
- `get_distro()`：识别操作系统发行版、主版本、CPU架构；支持国产系统识别；可输出字段 `real / type / version / major / pretty / arch / id`；返回id用于区分debian/rhel/alpine软件家族
- `init_package_manager()`：自动探测 `dnf/yum/apt‑get`；导出一整套包管理变量（在线安装、离线安装、卸载、升级、下载rpm/deb包、repo配置管理）；自动处理sudo/root身份前缀
- `check_install()`：批量检测并安装软件包；支持在线(OLI)/离线(OFI)安装模式
- `setfr()`：防火墙批量放行端口；自动识别ufw/firewalld；支持语法 `80/tcp,53/udp,443/all`；校验端口范围
- `disable_selinux()`：永久禁用SELinux（修改配置，需重启）
- `tarzip()`：自动识别后缀解压 tar/tgz/bz2/xz/zip；基于`run`带动画执行解压
- `runtime()`：脚本运行耗时统计（基于毫秒时间戳 `date +%s%3N`）
- `phase()`：彩色方块阶段进度指示器，用于安装脚本多阶段展示

### 💾 Swap 文件事务管理模块（SLIB_SWAP_API=2）
> 完整事务模型；失败自动回滚；支持Btrfs独立子卷swapfile（`/swap.local/swapfile`）与传统`/swap.vm`；校验休眠resume冲突；systemd drop‑in调整启动顺序；fstab原子更新；flock排他锁防止并发swap变更

导出函数：
- `swap_plan()`：只读预检；输出计划动作(create/resize/reuse/remove)，填充`swap_*`变量与`swap_error`；不修改磁盘
- `swap_plan_message()`：生成面向用户的变更提示文本（人类可读容量）
- `swap_size_planned()`：兼容旧调用；返回计划swap大小KiB；0代表无变更
- `swap_setup(disk_gb)`：执行swap事务（创建/扩容/缩小/删除交换文件）；内部子shell隔离；事务回滚；flock锁；systemctl daemon‑reload
- `memory_ok(min_kib,disk_gb)`：先执行swap_setup，然后校验内存+swap总容量最低阈值；不达标返回失败；适合安装脚本前置硬件校验

### 🚪 脚本生命周期 & trap 清理
- `restore_cursor()`：恢复光标可见
- `cleanup(exit_code)`：统一退出清理钩子；trap捕获 `INT(^C),QUIT,TERM,EXIT`；杀死spinner动画子进程；清理临时`*_INSTALL_TEMPDIR`目录；恢复终端stty回显；输出`操作已取消`提示（交互模式）

## 🧩 使用方式

### 引入库（sourcing）
```bash
#!/bin/sh
# 在业务脚本头部引入 slib.sh
. ./slib.sh

# 开启日志落盘
LOG_PATH="/var/log/my-install.log"
RUN_LOG="./run.log"

# 示例调用TUI组件
task info "请输入服务器主机名"
echo "your input: $reply"
