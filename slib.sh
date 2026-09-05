#!/bin/sh
# shellcheck disable=SC3043 disable=SC2086 disable=SC2059 disable=SC2039 disable=SC2034 disable=SC2154

underline="________________________________________________________________"

##################################################################################################
# 函数名：restore_cursor
# 功能：恢复终端光标显示（使用tput命令将光标设置为正常可见状态）
# 全局变量: 无
# 选项说明: 无
# 返回值: 无
# 依赖：tput终端控制工具
##################################################################################################
restore_cursor() {
  tput cnorm
}

##################################################################################################
# 函数名：cleanup
# 功能：脚本退出收尾清理，恢复终端设置、杀死动画子进程、清理临时目录，根据退出码退出
# 全局变量: allpids
# 选项说明: 接收1个参数exit_code作为最终退出码
# 返回值: 无
# 依赖：restore_cursor
##################################################################################################
cleanup() {
  exit_code=$1
  stty echo 1>/dev/null 2>&1
  echo
  # 务必清理所有加载动画子进程
  # 这个问题很棘手，至今不清楚为什么动画进程会残留
  if [ -n "$allpids" ]; then
    for pid in $allpids; do
      kill "$pid" 1>/dev/null 2>&1
    done
    tput sgr0
  fi
  restore_cursor
  # 清理临时环境目录
  env | grep '_INSTALL_TEMPDIR=' | while IFS='=' read -r var temp_dir; do
    [ -z "$temp_dir" ] && continue
    prefix="${var%%_INSTALL_TEMPDIR}"
    if [ -d "$temp_dir" ] && echo "$temp_dir" | grep -iq "${prefix}-"; then
      rm -rf "$temp_dir"
    fi
  done

  if [ "$exit_code" -ne 0 ]; then
    echo
  fi

  exit $exit_code
}

# 检测是否为交互式 Shell
INTERACTIVE_MODE="on"
[ -z "${NONINTERACTIVE-}" ] && NONINTERACTIVE=0 # 仅当变量未定义时进行赋值
if [ ! -t 0 ] && [ -z "${PS1-}" ]; then
  INTERACTIVE_MODE="off"
  [ -z "${NONINTERACTIVE-}" ] && NONINTERACTIVE=1 # 仅当变量未定义时进行赋值
fi

# 捕获各类退出事件，包括正常退出以及强制终止（例如 Ctrl‑C）
if [ "$INTERACTIVE_MODE" != "off" ]; then
  trap 'cleanup 2' INT
  trap 'cleanup 3' QUIT
  trap 'cleanup 15' TERM
  trap 'cleanup 0' EXIT
fi

# scolors - 颜色常量定义
# 原始来源 http://github.com/swelljoe/scolors

# 检测终端是否受支持；如果终端类型不支持，则将 TERM 设置为一个受支持的值
##################################################################################################
# 函数名：is_term_supported
# 功能：检测指定终端类型是否可用，优先tput探测，失败则使用infocmp兜底
# 全局变量: 无
# 选项说明: 接收1个参数term，终端类型名称
# 返回值: 0=支持，1=不支持
# 依赖：tput、infocmp
##################################################################################################
is_term_supported() {
  term=$1
  [ -n "$term" ] || term=dumb # 防止终端类型为空
  # 使用 tput 工具探测终端有效性
  if command -pv tput >/dev/null 2>&1; then
    tput -T "$term" cols >/dev/null 2>&1 && return 0 || return 1
  fi
  # 使用 infocmp 工具探测终端有效性
  if command -pv infocmp >/dev/null 2>&1; then
    infocmp "$term" >/dev/null 2>&1 && return 0 || return 1
  fi
  return 1
}
FALLBACK_TERMS='xterm-256color xterm-color xterm vt220 ansi dumb'
if ! is_term_supported "$TERM"; then
  OLDTERM=$TERM
  # 遍历备选终端类型
  for alt in $FALLBACK_TERMS; do
    if is_term_supported "$alt"; then
      TERM=$alt
      export TERM
      echo "[信息] 终端类型 '$OLDTERM' 不受支持；已切换为 '$TERM'"
      break
    fi
  done
fi

# 检查系统是否安装 tput 命令
if command -pv 'tput' >/dev/null; then
  # 检查当前是否在终端环境中运行
  if [ -t 1 ]; then
    # 检测终端支持的颜色数量
    ncolors=$(tput colors)
    if [ "$ncolors" -ge 8 ]; then
      # 基础8色配置
      BLACK="$(tput setaf 0)" # 黑色前景
      RED=$(tput setaf 1)     # 红色前景
      GREEN=$(tput setaf 2)   # 绿色前景
      YELLOW=$(tput setaf 3)  # 黄色前景
      ORANGE=$(tput setaf 3)  # 橙色前景（8色模式复用黄色编号）
      BLUE=$(tput setaf 4)    # 蓝色前景
      MAGENTA=$(tput setaf 5) # 洋红色前景
      CYAN=$(tput setaf 6)    # 青色前景
      WHITE=$(tput setaf 7)   # 白色前景

      REDBG=$(tput setab 1)     # 红色背景
      GREENBG=$(tput setab 2)   # 绿色背景
      YELLOWBG=$(tput setab 3)  # 黄色背景
      ORANGEBG=$(tput setab 3)  # 橙色背景（8色模式复用黄色编号）
      BLUEBG=$(tput setab 4)    # 蓝色背景
      MAGENTABG=$(tput setab 5) # 洋红色背景
      CYANBG=$(tput setab 6)    # 青色背景
      WHITEBG=$(tput setab 7)   # 白色背景

      # 检查是否支持16色（含亮色）
      if [ "$ncolors" -ge 16 ]; then
        WHITE=$(tput setaf 15)   # 亮白色前景
        WHITEBG=$(tput setab 15) # 亮白色背景
      fi

      # 检查是否支持256色（更丰富的颜色选择）
      if [ "$ncolors" -ge 256 ]; then
        # 使用更精确的256色值
        RED=$(tput setaf 124)    # 深红色前景
        GREEN=$(tput setaf 34)   # 鲜艳绿色前景
        YELLOW=$(tput setaf 186) # 柔和的黄色前景
        ORANGE=$(tput setaf 202) # 鲜艳橙色前景
        BLUE=$(tput setaf 25)    # 深蓝色前景
        MAGENTA=$(tput setaf 90) # 深洋红色前景
        CYAN=$(tput setaf 45)    # 明亮青色前景
        WHITE=$(tput setaf 255)  # 纯白色前景

        REDBG=$(tput setab 160)    # 鲜艳红色背景
        YELLOWBG=$(tput setab 186) # 柔和黄色背景
        ORANGEBG=$(tput setab 166) # 中等橙色背景
        BLUEBG=$(tput setab 25)    # 深蓝色背景
        MAGENTABG=$(tput setab 90) # 深洋红色背景
        CYANBG=$(tput setab 45)    # 明亮青色背景
        WHITEBG=$(tput setab 231)  # 256色模式纯白色背景（补齐原版缺失）
      fi

      # 文本样式控制
      BOLD=$(tput bold)      # 粗体
      DIM=$(tput dim)        # 暗淡/弱化亮度模式
      REV=$(tput rev)        # 反显模式：交换前景色与背景色
      UNDERLINE=$(tput smul) # 下划线（许多终端不支持）
      NORMAL=$(tput sgr0)    # 重置：清除所有颜色、样式，恢复终端默认
    fi
  fi
else
  # tput 不可用时的回退方案
  echo "未找到 tput 命令，彩色输出功能已禁用。"
  # 清空所有前景颜色变量
  BLACK=''
  RED=''
  GREEN=''
  YELLOW=''
  ORANGE=''
  BLUE=''
  MAGENTA=''
  CYAN=''
  WHITE=''
  # 清空所有背景颜色变量
  REDBG=''
  GREENBG=''
  YELLOWBG=''
  ORANGEBG=''
  BLUEBG=''
  MAGENTABG=''
  CYANBG=''
  WHITEBG=''
  # 清空文本样式变量
  BOLD=''
  DIM=''
  REV=''
  UNDERLINE=''
  NORMAL=''
fi

# slog — 日志工具库
# 原始来源 http://github.com/swelljoe/slog

# LOG_PATH - 在你的脚本中定义 $LOG_PATH 变量，日志就会写入指定文件；
#            如果不定义，则日志直接输出到标准输出(STDOUT)。

# LOG_LEVEL_STDOUT - 用于设定标准输出的日志级别阈值；
#                    高于该级别才会打印到标准输出。
# 默认配置：所有级别的日志全部输出到标准输出。
LOG_LEVEL_STDOUT="INFO"

# LOG_LEVEL_LOG - 设置写入日志文件的日志级别阈值。
# 高于该级别的日志才会写入 LOG_PATH 指定的文件。
# 默认配置：所有级别的日志都会写入日志文件。
LOG_LEVEL_LOG="INFO"

# 可供外部脚本引用的实用全局变量
SCRIPT_ARGS="$*"                  # 脚本接收到的全部命令行参数
SCRIPT_NAME="$0"                  # 获取脚本自身执行路径/名称
SCRIPT_NAME="${SCRIPT_NAME#\./}"  # 移除开头的 ./ 前缀（例如 ./run.sh → run.sh）
SCRIPT_NAME="${SCRIPT_NAME##/*/}" # 剥离路径，只保留脚本文件名（例如 /opt/bin/run.sh → run.sh）

#--------------------------------------------------------------------------------------------------
# 日志模块开始
if [ "$INTERACTIVE_MODE" = "off" ]; then
  # 非交互模式运行，日志不需要颜色
  LOG_DEFAULT_COLOR="" # 日志默认颜色
  LOG_ERROR_COLOR=""   # 错误日志颜色
  LOG_INFO_COLOR=""    # 信息日志颜色
  LOG_SUCCESS_COLOR="" # 成功日志颜色
  LOG_WARN_COLOR=""    # 警告日志颜色
  LOG_DEBUG_COLOR=""   # 调试日志颜色
else
  LOG_DEFAULT_COLOR=$(tput sgr0)    # 日志默认样式，重置所有终端样式
  LOG_ERROR_COLOR=$(tput setaf 1)   # 错误日志：红色前景
  LOG_INFO_COLOR=$(tput setaf 6)    # 信息日志：青色前景
  LOG_SUCCESS_COLOR=$(tput setaf 2) # 成功日志：绿色前景
  LOG_WARN_COLOR=$(tput setaf 3)    # 警告日志：黄色前景
  LOG_DEBUG_COLOR=$(tput setaf 4)   # 调试日志：蓝色前景
fi

# 该函数用于清除彩色输出中包含的各类终端控制字符
# 设计用途：对需要处理的文本做管道过滤，经过处理后，
# 输出内容将剔除所有控制转义序列。
##################################################################################################
# 函数名：prepare_log_for_nonterminal
# 功能：清除文本里ANSI颜色/控制转义字符，输出纯净文本，用于日志落盘、管道处理
# 全局变量: 无
# 选项说明: 无，从标准输入读取文本
# 返回值: 过滤后的纯净文本输出到stdout
# 依赖：sed、tr
##################################################################################################
prepare_log_for_nonterminal() {
  # 核心作用：剥离日志中所有用于颜色显示的终端控制字符
  sed -E 's/\x1B\[[0-9;]*[mK]//g; s/\x1B\([A-Za-z]//g' | tr -d '[:cntrl:]'
}

##################################################################################################
# 函数名：log_date
# 功能：生成带时间、日志级别的日志前缀字符串
# 全局变量: 无
# 选项说明: 接收1个参数log_date_level，日志级别标识
# 返回值: 格式化时间前缀字符串
# 依赖：date
##################################################################################################
log_date() {
  local log_date_level="$1"
  echo "[$(date +"%Y-%m-%d %H:%M:%S %Z")] [$log_date_level] "
}

##################################################################################################
# 函数名：log
# 功能：日志核心输出函数，支持分级过滤、彩色终端输出、日志文件写入、中英文级别翻译
# 全局变量: LOG_LEVEL_STDOUT、LOG_LEVEL_LOG、LOG_PATH、LOG_DEFAULT_COLOR、LOG_*_COLOR
# 选项说明: $1=日志文本，$2=日志级别，$3=日志颜色
# 返回值: 0
# 依赖：log_date、prepare_log_for_nonterminal
##################################################################################################
log() {
  local log_text="$1"
  local log_level="$2"
  local log_color="$3"

  # 日志级别数值，用于级别过滤判断
  local LOG_LEVEL_DEBUG=0
  local LOG_LEVEL_INFO=1
  local LOG_LEVEL_SUCCESS=2
  local LOG_LEVEL_WARNING=3
  local LOG_LEVEL_ERROR=4

  # 默认日志级别为 INFO
  [ -z "${log_level}" ] && log_level="INFO"
  [ -z "${log_color}" ] && log_color="${LOG_INFO_COLOR}"

  # 校验日志级别配置变量，防止非法值
  case $LOG_LEVEL_STDOUT in
  DEBUG | INFO | SUCCESS | WARNING | ERROR) ;;
  *)
    LOG_LEVEL_STDOUT=INFO
    ;;
  esac
  case $LOG_LEVEL_LOG in
  DEBUG | INFO | SUCCESS | WARNING | ERROR) ;;
  *)
    LOG_LEVEL_LOG=INFO
    ;;
  esac

  log_lang() {
    if [ "${log_level}" = DEBUG ]; then
      log_level=调试
    elif [ "${log_level}" = INFO ]; then
      log_level=信息
    elif [ "${log_level}" = SUCCESS ]; then
      log_level=成功
    elif [ "${log_level}" = WARNING ]; then
      log_level=警告
    elif [ "${log_level}" = ERROR ]; then
      log_level=错误
    fi
  }

  # 判断本条日志是否输出到标准输出
  eval log_level_int="\$LOG_LEVEL_${log_level}"
  eval log_level_stdout="\$LOG_LEVEL_${LOG_LEVEL_STDOUT}"
  # shellcheck disable=SC2154
  if [ "$log_level_stdout" -le "$log_level_int" ]; then
    # 标准输出打印
    log_lang
    printf "%s[%s]%s %s\\n" "$log_color" "$log_level" "$LOG_DEFAULT_COLOR" "$log_text"
  fi
  # 判断本条日志是否写入日志文件
  eval log_level_log="\$LOG_LEVEL_${LOG_LEVEL_LOG}"
  # shellcheck disable=SC2154
  if [ "$log_level_log" -le "$log_level_int" ]; then
    # 写入文件的日志去除颜色控制符
    if [ -n "$LOG_PATH" ]; then
      log_lang
      today=$(date +"%Y-%m-%d %H:%M:%S %Z")
      printf "[%s] [%s] %s\\n" "$today" "$log_level" "$log_text" >>"$LOG_PATH"
    fi
  fi

  return 0
}

##################################################################################################
# 函数名：log_info
# 功能：INFO级别快捷日志封装
# 全局变量: 无
# 选项说明: $@ 透传给log函数
# 返回值: log函数返回值
# 依赖：log
##################################################################################################
log_info() { log "$@"; }

##################################################################################################
# 函数名：log_success
# 功能：SUCCESS级别快捷日志封装
# 全局变量: LOG_SUCCESS_COLOR
# 选项说明: $1=日志文本
# 返回值: log函数返回值
# 依赖：log
##################################################################################################
log_success() { log "$1" "SUCCESS" "${LOG_SUCCESS_COLOR}"; }

##################################################################################################
# 函数名：log_error
# 功能：ERROR级别快捷日志封装
# 全局变量: LOG_ERROR_COLOR
# 选项说明: $1=日志文本
# 返回值: log函数返回值
# 依赖：log
##################################################################################################
log_error() { log "$1" "ERROR" "${LOG_ERROR_COLOR}"; }

##################################################################################################
# 函数名：log_warning
# 功能：WARNING级别快捷日志封装
# 全局变量: LOG_WARN_COLOR
# 选项说明: $1=日志文本
# 返回值: log函数返回值
# 依赖：log
##################################################################################################
log_warning() { log "$1" "WARNING" "${LOG_WARN_COLOR}"; }

##################################################################################################
# 函数名：log_debug
# 功能：DEBUG级别快捷日志封装
# 全局变量: LOG_DEBUG_COLOR
# 选项说明: $1=日志文本
# 返回值: log函数返回值
# 依赖：log
##################################################################################################
log_debug() { log "$1" "DEBUG" "${LOG_DEBUG_COLOR}"; }

# 日志模块结束
#--------------------------------------------------------------------------------------------------
# spinner - 为长时间运行的任务提供终端旋转加载动画
# 原始来源 http://github.com/swelljoe/spinner
# 配置变量：在脚本引入完成后修改这些变量，即可改变运行行为。
SPINNER_COLORNUM=2                # 使用哪一种颜色；COLORCYCLE=1 时该参数无效。
SPINNER_COLORCYCLE=1              # 是否开启颜色循环切换。
SPINNER_DONEFILE="stopspinning"   # 用于停止动画的文件路径/文件名。
SPINNER_SYMBOLS="WIDE_ASCII_PROG" # 存放动画符号序列的变量名称。
SPINNER_CLEAR=1                   # 动画结束时清空当前行。

##################################################################################################
# 函数名：spinner
# 功能：终端加载动画，长任务进度指示器，支持字符集切换、颜色循环、父进程存活检测
# 全局变量: SPINNER_COLORNUM、SPINNER_COLORCYCLE、SPINNER_DONEFILE、SPINNER_SYMBOLS、SPINNER_CLEAR
# 选项说明: 无
# 返回值: 0
# 依赖：restore_cursor、tput、ps、sleep
##################################################################################################
spinner() {
  # 设置信号捕获：脚本正常结束或被强制终止时，确保停止旋转动画并恢复光标显示
  trap 'restore_cursor; exit' INT QUIT TERM EXIT
  # 最兼容的动画符号，完全不需要 Unicode 支持
  local WIDE_ASCII_PROG="[>-] [->] [--] [--]"
  local WIDE_UNI_GREYSCALE2="▒▒▒ █▒▒ ██▒ ███ ▒██ ▒▒█ ▒▒▒"
  local SPINNER_NORMAL
  SPINNER_NORMAL=$(tput sgr0)
  eval SYMBOLS=\$${SPINNER_SYMBOLS}
  # 获取父进程 PID
  SPINNER_PPID=$(ps -p "$$" -o ppid=)
  while :; do
    tput civis # 隐藏终端光标
    for c in ${SYMBOLS}; do
      if [ $SPINNER_COLORCYCLE -eq 1 ]; then
        if [ $SPINNER_COLORNUM -eq 7 ]; then
          SPINNER_COLORNUM=1
        else
          SPINNER_COLORNUM=$((SPINNER_COLORNUM + 1))
        fi
      fi
      local SPINNER_COLOR
      SPINNER_COLOR=$(tput setaf ${SPINNER_COLORNUM})
      printf "\033[77G" # 将光标移动到第77列位置
      env printf "${SPINNER_COLOR}${c}${SPINNER_NORMAL}"
      # 检测停止文件是否存在
      if [ -f "${SPINNER_DONEFILE}" ]; then
        if [ ${SPINNER_CLEAR} -eq 1 ]; then
          tput el # 清空光标所在行剩余内容
        fi
        rm -f ${SPINNER_DONEFILE}
        break 2 # 跳出 for、while 两层循环
      fi
      # 此处存在兼容性问题：并非所有环境都支持小数秒 sleep；
      # 不支持小数时也不会直接报错崩溃
      env sleep .2
      # 校验父进程是否仍然存活，处理父进程挂掉/被杀死的场景
      if [ -n "$SPINNER_PPID" ]; then
        # ps 在输出ppid时会前置空格，处理不当会引发 ps “无效参数”报错
        # XXX：ps输出格式异常会产生潜在坑点
        # shellcheck disable=SC2086
        SPINNER_PARENTUP=$(ps --no-headers $SPINNER_PPID)
        if [ -z "$SPINNER_PARENTUP" ]; then
          break 2 # 父进程已消失，直接退出动画
        fi
      fi
    done
  done
  restore_cursor # 恢复光标显示
  return 0
}

# run_ok - 用于执行命令或函数，启动加载动画，并在完成后打印确认提示标记
# 原始来源 - http://github.com/swelljoe/run_ok
RUN_LOG="run.log"

# 检测 Shell 是否支持 Unicode
# 这个函数写法比较特殊，但可以正常工作。检测逻辑：能否将 Unicode 字符
# 写入文件，并且能够原样读取回来。
##################################################################################################
# 函数名：shell_has_unicode
# 功能：检测当前Shell环境是否正常支持Unicode字符
# 全局变量: 无
# 选项说明: 无
# 返回值: 0=支持，1=不支持
# 依赖：printf、read、rm
##################################################################################################
shell_has_unicode() {
  # 将一个 Unicode 字符写入临时文件，再读取回来，判断环境能否正确处理该字符
  env printf "\\u2714" >unitest.txt
  read -r unitest <unitest.txt
  rm -f unitest.txt
  if [ ${#unitest} -le 3 ]; then
    return 0 # 环境支持 Unicode
  else
    return 1 # 环境不支持 Unicode
  fi
}

# 根据预设参数配置旋转加载动画
SPINNER_COLORCYCLE=0
SPINNER_COLORNUM=6
if shell_has_unicode; then
  SPINNER_SYMBOLS="WIDE_UNI_GREYSCALE2"
else
  SPINNER_SYMBOLS="WIDE_ASCII_PROG"
fi
SPINNER_CLEAR=0 # 不清除当前行，用于让成功对勾/失败叉号可以直接覆盖原有内容

##################################################################################################
# 函数名：count_pattern
# 功能：统计脚本文件内匹配指定pattern的有效行数，排除注释、函数自身匹配行
# 全局变量: script_path
# 选项说明: $1=匹配正则pattern
# 返回值: 匹配数量
# 依赖：read
##################################################################################################
count_pattern() {
  pattern=$1
  count=0
  while IFS= read -r line; do
    case "$line" in
    *$pattern*)
      # 排除函数定义行和统计命令行
      case "$line" in
      *count_pattern* | *number=* | *#*) continue ;;
      *) count=$((count + 1)) ;;
      esac
      ;;
    esac
  done <"$script_path"
  echo "$count"
}

# 执行指定操作、输出日志；执行完毕打印彩色对勾(成功)或叉号(失败)
# 执行成功返回0；执行失败返回原命令的退出码 $?
##################################################################################################
# 函数名：run
# 功能：执行外部命令，自动启动 spinner 加载动画，彩色展示✅/❌结果，输出日志到 RUN_LOG
# 全局变量: GREEN、NORMAL、YELLOW、allpids、SPINNER_DONEFILE、RUN_LOG、RUN_ERRORS_FATAL、INTERACTIVE_MODE
# 选项说明: $1=模式(ok/set)，$2=待执行命令，$3=任务描述文本
# 返回值: 被执行命令原始退出码
# 依赖：log_date、spinner、shell_has_unicode、prepare_log_for_nonterminal
##################################################################################################
run() {
  # Shell字符串传递处理，保留原始命令不提前展开
  local cmd="${2}"
  local msg="${3}"
  local log_pref
  log_pref="$(log_date "信息")"

  case $1 in
  ok)
    printf "%s" "${GREEN}$3${NORMAL}"
    printf "\033[K"   # 清除光标所在行从光标位置到行尾的所有内容
    printf "\033[77G" # 将光标移动到第77列的位置
    ;;
  set)
    number=$(count_pattern "run set")
    set_i=$((set_i + 1)) || true

    # 构建 setnum 字符串并计算其长度
    setnum="${GREEN}[${NORMAL}${YELLOW}${set_i}${NORMAL}/${GREEN}${number}${NORMAL}${GREEN}] ${NORMAL}"

    # 输出格式化字符串
    printf "%s%s" "${setnum}" "${GREEN}$3${NORMAL}"
    printf "\033[K"   # 清除光标所在行从光标位置到行尾的所有内容
    printf "\033[77G" # 将光标移动到第77列的位置
    ;;
  esac

  CHECK='\u2714'
  BALLOT_X='\u2718'
  if [ "$INTERACTIVE_MODE" != "off" ]; then
    stty -echo 1>/dev/null 2>&1
    spinner &
    spinpid=$!
    allpids="$allpids $spinpid"
    echo "$log_pref 动画进程 PID: $spinpid" >>${RUN_LOG}
  fi
  eval "${cmd}" 1>>${RUN_LOG} 2>&1
  local res=$?
  touch ${SPINNER_DONEFILE}
  env sleep .4 # 防止标准输出和动画抢占输出导致内容错乱
  # 兜底强制杀死残留动画进程
  if [ "$INTERACTIVE_MODE" != "off" ]; then
    stty echo 1>/dev/null 2>&1
    pidcheck=$(ps --no-headers ${spinpid})
    if [ -n "$pidcheck" ]; then
      echo "$log_pref 走到这里了，原因未知？" >>${RUN_LOG}
      kill $spinpid 2>/dev/null
      rm -rf ${SPINNER_DONEFILE} 2>/dev/null 2>&1
      restore_cursor
    fi
  fi
  # 记录本次执行任务描述（去除颜色字符）
  msg_safe=$(echo "$msg" | prepare_log_for_nonterminal)
  printf "$log_pref ${msg_safe}: " >>${RUN_LOG}
  if shell_has_unicode; then
    if [ $res -eq 0 ]; then
      printf "$log_pref 执行成功。\\n" >>${RUN_LOG}
      printf "\033[77G\033[K" # 定位并清空位置
      env printf "${GREENBG}${WHITE} ${CHECK} ${NORMAL}\\n"
      return 0
    else
      printf "$log_pref 执行失败，错误码: ${res}\\n" >>${RUN_LOG}
      printf "\033[77G\033[K"
      env printf "${REDBG}${WHITE} ${BALLOT_X} ${NORMAL}\\n"
      if [ "$RUN_ERRORS_FATAL" ]; then
        echo
        log_fatal "执行出错，即将退出。"
        log_fatal "最近的日志内容如下："
        tail -17 "${RUN_LOG}" | head -15
        exit 1
      fi
      return ${res}
    fi
  else
    if [ $res -eq 0 ]; then
      printf "$log_pref 执行成功。\\n" >>${RUN_LOG}
      printf "\033[77G\033[K"
      env printf "${GREENBG} OK ${NORMAL}\\n"
      return 0
    else
      printf "$log_pref 执行失败，错误码: ${res}\\n" >>${RUN_LOG}
      printf "\033[77G\033[K"
      env printf "${REDBG} ER ${NORMAL}\\n"
      if [ "$RUN_ERRORS_FATAL" ]; then
        log_fatal "上一条命令执行异常，即将退出。"
        exit 1
      fi
      return ${res}
    fi
  fi
}

##################################################################################################
# 函数名：ComputingColumn
# 功能：计算终端可用显示列宽，兼容中文字符宽度差异，适配交互式/非交互模式
# 全局变量: INTERACTIVE_MODE、msg
# 选项说明: 无
# 返回值: 写入全局变量COL、columns
# 依赖：tput、tr、wc
##################################################################################################
ComputingColumn() {
  # 终端列宽设置逻辑
  if [ "${INTERACTIVE_MODE}" != "off" ]; then
    columns=$(tput cols)
    [ "$columns" -ge 80 ] && columns=79
  else
    columns=79
  fi

  # 计算各类字符宽度
  msg_cn=$(printf '%s' "$msg" | tr -d '[:alnum:][:space:][:punct:]')
  num_cn=$(printf '%s' "$msg_cn" | wc -c)
  width_cn=$((num_cn * 2 / 3)) # 中文UTF-8: 3字节=1字，宽度2

  # 其他字符直接计算长度
  other_chars=$(printf '%s' "$msg" | tr -d "$msg_cn")
  width_other=$(printf '%s' "$other_chars" | wc -c)

  # 统一计算列宽
  COL=$((columns - width_cn - width_other - 3))
}

##################################################################################################
# 函数名：task
# 功能：终端交互式输入处理，支持普通输入、密码隐藏输入、数字选择、退格/删除/方向键处理
# 全局变量: GREEN、CYAN、YELLOW、NORMAL、prompt、Index
# 选项说明: $1=模式(enter/error/secret/info)，$2=提示文本(secret/info模式)
# 返回值: 输入内容存入全局变量reply
# 依赖：stty、dd
##################################################################################################
task() {
  charcount='0'
  reply=''
  input_prompt=""
  case $1 in
  enter)
    input_prompt="${GREEN}${prompt} ${CYAN}[1${YELLOW}-${CYAN}${Index}]${YELLOW}:${NORMAL}"
    printf "%s" "$input_prompt"
    ;;
  error)
    input_prompt="${YELLOW}请输入数字 ${CYAN}[1]${YELLOW} 到 ${CYAN}[$Index]${YELLOW}:${NORMAL} "
    printf "\n%s" "$input_prompt"
    ;;
  domain_erro)
    input_prompt="${YELLOW}请输入域名 (例子: www.abc.com):${NORMAL} "
    printf "\n%s" "$input_prompt"
    ;;
  secret)
    prompt="${GREEN}${2}:${NORMAL} "
    input_prompt="$prompt"
    printf "%s$input_prompt"
    ;;
  info)
    issue="${GREEN}${2}:${NORMAL} "
    input_prompt="$issue"
    printf "%s$input_prompt"
    ;;
  esac

  cur_pos=$charcount

  while :; do
    char=$(
      stty cbreak -echo
      dd if=/dev/tty bs=1 count=1 2>/dev/null
      stty -cbreak echo
    )

    if [ "$char" = "$(printf '\0')" ]; then
      break
    fi

    case $char in
    "$(printf '\b')" | "$(printf '\177')")
      if [ $cur_pos -gt 0 ]; then
        printf '\b \b'
        if [ "$cur_pos" -eq 1 ]; then
          head=""
        else
          head=$(printf "%s" "$reply" | cut -c 1-$((cur_pos - 1)))
        fi
        tail=$(printf "%s" "$reply" | cut -c $((cur_pos + 1))-)
        reply="${head}${tail}"
        charcount=$((charcount - 1))
        cur_pos=$((cur_pos - 1))

        printf '\r'
        case $1 in
        secret)
          printf "%s" "$input_prompt"
          i=0
          while [ $i -lt $charcount ]; do
            printf '*'
            i=$((i + 1))
          done
          ;;
        *)
          printf "%s%s" "$input_prompt" "$reply"
          ;;
        esac
        printf '\033[K'
        j=$charcount
        while [ $j -gt $cur_pos ]; do
          printf '\033[D'
          j=$((j - 1))
        done
      fi
      ;;

    "$(printf '\033')")
      esc_buf=""
      while :; do
        c=$(
          stty cbreak -echo
          dd if=/dev/tty bs=1 count=1 2>/dev/null
          stty -cbreak echo
        )
        esc_buf="${esc_buf}${c}"
        case "$c" in
        '[' | 0* | 1* | 2* | 3* | 4* | 5* | 6* | 7* | 8* | 9* | '~') continue ;;
        *) break ;;
        esac
      done

      case "$esc_buf" in
      '[A' | '[B') ;;
      '[D')
        if [ $cur_pos -gt 0 ]; then
          printf '\033[D'
          cur_pos=$((cur_pos - 1))
        fi
        ;;
      '[C')
        if [ $cur_pos -lt $charcount ]; then
          printf '\033[C'
          cur_pos=$((cur_pos + 1))
        fi
        ;;
      '[3~')
        if [ $cur_pos -lt $charcount ]; then
          if [ "$cur_pos" -eq 0 ]; then
            head=""
          else
            head=$(printf "%s" "$reply" | cut -c 1-"$cur_pos")
          fi
          tail=$(printf "%s" "$reply" | cut -c $((cur_pos + 1))-)
          reply="${head}${tail}"
          charcount=$((charcount - 1))

          printf '\r'
          case $1 in
          secret)
            printf "%s" "$input_prompt"
            i=0
            while [ $i -lt $charcount ]; do
              printf '*'
              i=$((i + 1))
            done
            ;;
          *)
            printf "%s%s" "$input_prompt" "$reply"
            ;;
          esac
          printf '\033[K'
          j=$charcount
          while [ $j -gt $cur_pos ]; do
            printf '\033[D'
            j=$((j - 1))
          done
        fi
        ;;
      esac
      ;;

    *)
      if [ "$cur_pos" -eq 0 ]; then
        head=""
      else
        head=$(printf "%s" "$reply" | cut -c 1-"$cur_pos")
      fi
      tail=$(printf "%s" "$reply" | cut -c $((cur_pos + 1))-)
      reply="${head}${char}${tail}"
      charcount=$((charcount + 1))

      printf '\r'
      case $1 in
      secret)
        printf "%s" "$input_prompt"
        i=0
        while [ $i -lt $charcount ]; do
          printf '*'
          i=$((i + 1))
        done
        ;;
      info | enter | error | domain_erro)
        printf "%s%s" "$input_prompt" "$reply"
        ;;
      esac
      printf '\033[K'
      cur_pos=$((cur_pos + 1))
      ;;
    esac
  done
  printf '\n' >&2
}

##################################################################################################
# 函数名：yesno
# 功能：交互式 Y/N 确认输入，支持全局变量自动跳过交互；skipyesno启用时直接确认，NONINTERACTIVE启用时报错退出
# 全局变量: skipyesno、VIRTUALMIN_NONINTERACTIVE、NONINTERACTIVE、YELLOW、CYAN、NORMAL
# 选项说明: 无
# 返回值: 0=确认(yes)，1=拒绝(no) / 非交互环境阻断
# 依赖：stty、read、printf
##################################################################################################

# 询问是/否问题
# 若 skipyesno 为 1，直接默认选 Y（是）
# 若环境变量 NONINTERACTIVE 为 1，直接返回1并输出提示，提示使用 --force 参数
yesno() {
  # XXX skipyesno 是由调用脚本设置的全局变量
  # shellcheck disable=SC2154
  if [ "$skipyesno" = "1" ]; then
    return 0
  fi
  if [ "$NONINTERACTIVE" = "1" ]; then
    echo "检测到非交互式终端。脚本可能需要交互提问，无法继续执行。"
    echo "如果您在其他脚本中运行并希望使用默认选项安装，请添加 '--force' 参数。"
    return 1
  fi
  stty echo 1>/dev/null 2>&1
  while read -r line; do
    stty -echo 1>/dev/null 2>&1
    case $line in
    y | Y | Yes | YES | yes | yES | yEs | YeS | yeS)
      return 0
      ;;
    n | N | No | NO | no | nO)
      return 1
      ;;
    *)
      stty echo 1>/dev/null 2>&1
      printf "\\n${YELLOW}请输入 ${CYAN}[y]${YELLOW} 或 ${CYAN}[n]${YELLOW}:${NORMAL} "
      ;;
    esac
  done
  stty -echo 1>/dev/null 2>&1
}

##################################################################################################
# 函数名：testmkdir
# 功能：目录不存在则递归创建
# 全局变量: 无
# 选项说明: $1=目标目录路径
# 返回值: mkdir返回码
# 依赖：mkdir
##################################################################################################
testmkdir() {
  if [ ! -d "$1" ]; then
    mkdir -p "$1"
  fi
}

##################################################################################################
# 函数名：testcp
# 功能：仅当目标路径不存在时执行复制，不会覆盖已存在的文件/目录；支持批量源、目录递归复制
# 全局变量: 无
# 参数说明: $1=源文件/源目录(支持通配符), $2=目标存放目录
# 返回值: cp 命令执行返回码
# 依赖：cp、log_debug
##################################################################################################
# 目标不存在才执行复制，跳过已存在对象
testcp() {
  for item in $1; do
    dest_path="$2/$(basename "$item")"
    if [ ! -e "$dest_path" ]; then
      if [ -d "$item" ]; then
        cp -r "$item" "$2"
        log_debug "目录 $item 已复制到 $2。"
      else
        cp "$item" "$2"
        log_debug "文件 $item 已复制到 $2。"
      fi
    fi
  done
}

##################################################################################################
# 函数名：setconfig
# 功能：修改Webmin类配置文件，匹配指令则sed替换，不存在则追加一行
# 全局变量: 无
# 选项说明: $1=完整配置行，$2=配置文件路径
# 返回值: sed/echo返回码
# 依赖：grep、sed
##################################################################################################
setconfig() {
  sc_config="$2"
  sc_value="$1"
  sc_directive=$(echo "$sc_value" | cut -d'=' -f1)
  if grep -q "$sc_directive $2"; then
    sed -i -e "s#$sc_directive.*#$sc_value#" "$sc_config"
  else
    echo "$1" >>"$2"
  fi
}

# 检测本机主IP地址
# 可在大多数 Linux 系统运行，也有可能兼容 FreeBSD
##################################################################################################
# 函数名：detect_ip
# 功能：自动检测服务器主IP（优先默认路由网卡），兼容Linux/FreeBSD、IPv4/IPv6，识别失败则手动输入网卡
# 全局变量: RUN_LOG、address
# 选项说明: 无
# 返回值: 0成功，全局变量address写入IP；失败直接fatal退出
# 依赖：ip、ifconfig、log_warning、log_debug
##################################################################################################
detect_ip() {
  # 获取默认路由对应的网卡设备
  defaultdev=$(ip ro ls 2>>"${RUN_LOG}" | grep default | head -1 | sed -e 's/.*\sdev\s//g' | awk '{print $1}')

  # 是否仅存在 IPv6 默认路由
  if [ -z "$defaultdev" ]; then
    defaultdev=$(ip -6 ro ls 2>>"${RUN_LOG}" | grep default | head -1 | sed -e 's/.*\sdev\s//g' | awk '{print $1}')
  fi

  # 完全没有默认路由：本机为隔离环境或仅内网主机
  if [ -z "$defaultdev" ]; then
    log_warning "未检测到默认路由，无法识别主网卡设备。"
    log_warning "正在提取第一个非回环、状态为启用的网卡！"
    defaultdev=$(ip -o link show 2>>"${RUN_LOG}" | awk -F': ' '/state UP/ && !/LOOPBACK/ {print $2}' | head -1)
  fi

  # 提取该网卡的 IPv4 地址
  primaryaddr=$(ip -f inet addr show dev "$defaultdev" 2>>"${RUN_LOG}" | grep 'inet ' | awk '{print $2}' | head -1 | cut -d"/" -f1 | cut -f1)

  # 如果没有IPv4，则尝试获取IPv6地址
  if [ -z "$primaryaddr" ]; then
    primaryaddr=$(ip -f inet6 addr show dev "$defaultdev" 2>>"${RUN_LOG}" | grep 'inet6 ' | awk '{print $2}' | head -1 | cut -d"/" -f1 | cut -f1)
  fi

  if [ "$primaryaddr" ]; then
    log_debug "检测到本机主地址：$primaryaddr"
    address=$primaryaddr
    return 0
  else
    log_warning "无法自动获取主网卡的 IP 地址。"
    echo "请手动输入主网卡的设备名称： "
    stty echo 1>/dev/null 2>&1
    read -r primaryinterface
    stty -echo 1>/dev/null 2>&1

    # 根据用户输入网卡提取IPv4地址
    primaryaddr=$(/sbin/ip -f inet -o -d addr show dev "$primaryinterface" 2>>"${RUN_LOG}" | head -1 | awk '{print $4}' | head -1 | cut -d"/" -f1)

    # 无IPv4，尝试IPv6
    if [ -z "$primaryaddr" ]; then
      primaryaddr=$(/sbin/ip -f inet6 -o -d addr show dev "$primaryinterface" 2>>"${RUN_LOG}" | head -1 | awk '{print $4}' | head -1 | cut -d"/" -f1)
    fi

    if [ "$primaryaddr" = "" ]; then
      # FreeBSD 系统获取 IPv4（使用 ifconfig）
      primaryaddr=$(/sbin/ifconfig "$primaryinterface" 2>>"${RUN_LOG}" | grep 'inet' | awk '{ print $2 }')
      # FreeBSD 无IPv4时尝试IPv6
      if [ -z "$primaryaddr" ]; then
        primaryaddr=$(/sbin/ifconfig "$primaryinterface" 2>>"${RUN_LOG}" | grep 'inet6' | awk '{ print $2 }')
      fi
    fi

    if [ "$primaryaddr" ]; then
      log_debug "检测到本机主地址：$primaryaddr"
      address=$primaryaddr
    else
      fatal "无法读取所选网卡的 IP 地址，脚本不能继续执行。"
    fi
    return 0
  fi
}

# 修改 cloud‑init 配置，开启主机名保留选项
##################################################################################################
# 函数名：set_hostname_cloud
# 功能：cloud-init环境配置preserve_hostname=true，避免cloud-init覆盖主机名
# 全局变量: 无
# 选项说明: 无
# 返回值: sed返回码
# 依赖：grep、sed
##################################################################################################
set_hostname_cloud() {
  # 如果系统安装了 cloud‑init，则保留已设置的主机名
  if [ -f "/etc/cloud/cloud.cfg" ]; then
    if grep "^preserve_hostname: false" /etc/cloud/cloud.cfg >/dev/null; then
      log_debug "正在修改 /etc/cloud/cloud.cfg，将 preserve_hostname 设置为 true"
      sed -i "s/^preserve_hostname: false/preserve_hostname: true/" /etc/cloud/cloud.cfg
    fi
  fi
}

# 设置系统主机名
##################################################################################################
# 函数名：set_hostname
# 功能：校验并设置合格FQDN主机名，同步/etc/hostname、hosts，兼容cloud-init，最多重试3次
# 全局变量: address
# 选项说明: $1可选，强制指定主机名
# 返回值: 0成功，失败调用fatal退出
# 依赖：is_fully_qualified、detect_ip、set_hostname_cloud、hostname、hostnamectl
##################################################################################################
set_hostname() {
  local i=0
  local forcehostname
  # 如果传入参数，则使用指定主机名
  if [ -n "$1" ]; then
    forcehostname=$1
  fi
  # 最多循环尝试 4 次输入
  while [ $i -le 3 ]; do
    if [ -z "$forcehostname" ]; then
      local name
      name=$(hostname -f)
      log_error "当前系统主机名 $name 不是完整FQDN域名格式。"
      printf "请输入完整限定主机名（示例：host.example.com）： "
      stty echo 1>/dev/null 2>&1
      read -r line
      stty -echo 1>/dev/null 2>&1
    else
      log_debug "正在将主机名设置为 $forcehostname"
      line=$forcehostname
    fi
    # 校验是否为完整FQDN主机名
    if ! is_fully_qualified "$line"; then
      i=$((i + 1))
      log_warning "主机名 $line 不是完整限定域名格式。"
      # 4次全部失败，致命退出
      if [ "$i" = "4" ]; then
        fatal "无法设置合法的完整限定主机名。"
      fi
    else
      # 设置主机名
      hostname "$line"
      echo "$line" >/etc/hostname
      hostnamectl set-hostname "$line" 1>/dev/null 2>&1
      # 适配云服务器 cloud‑init，防止主机名被云平台覆盖
      set_hostname_cloud
      # 重新检测本机IP
      detect_ip
      # 截取主机短名（去掉域名部分，host.example.com → host）
      shortname=$(echo "$line" | cut -d"." -f1)
      # 判断 /etc/hosts 内是否已有该IP的记录
      if grep "^$address" /etc/hosts >/dev/null; then
        log_debug "/etc/hosts 中已存在IP $address 的记录。"
        log_debug "正在更新为新的主机名。"
        sed -i "s/^$address.*/$address $line $shortname/" /etc/hosts
      else
        log_debug "向 /etc/hosts 添加新记录：IP:$address 主机名:$line 短名:$shortname"
        printf "%s\\t%s\\t%s\\n" "$address" "$line" "$shortname" >>/etc/hosts
      fi
      # 成功，跳出while循环
      i=4
    fi
  done
}

##################################################################################################
# 函数名：set_domain
# 功能：设置完整合格域名；支持传入参数强制指定域名，无参数则交互式提示用户输入；最多4次校验重试
# 全局变量: IPADDR
# 参数说明: $1(可选)：强制设置的域名，提供该参数则跳过交互输入
# 返回值: 无返回值；校验失败达到最大重试次数调用fatal终止脚本；成功后赋值至全局变量IPADDR
# 依赖：is_fully_qualified、log_error、log_warning、log_debug、fatal、stty、read
##################################################################################################
set_domain() {
  local i=0
  local forcedomain
  if [ -n "$1" ]; then
    forcedomain=$1
  fi
  while [ $i -le 3 ]; do
    if [ -z "$forcedomain" ]; then
      local name
      name=$IPADDR
      log_error "您的域名 $name 不完全符合。"
      printf "请输入完全符合的域名（例如：www.abc.com）： "
      stty echo 1>/dev/null 2>&1
      read -r line
      stty -echo 1>/dev/null 2>&1
    else
      log_debug "将域名设置为 $forcedomain"
      line=$forcedomain
    fi
    if ! is_fully_qualified "$line"; then
      i=$((i + 1))
      log_warning "域名 $line 不完全符合."
      if [ "$i" = "4" ]; then
        fatal "无法设置完全符合的域名."
      fi
    else
      IPADDR=$line
      i=4
    fi
  done
}

##################################################################################################
# 函数名：is_fully_qualified
# 功能：校验字符串是否为合法FQDN/IPv4/IPv6，拦截localhost、*.localdomain、*.internal等非法域名
# 全局变量: 无
# 选项说明: $1=待校验字符串
# 返回值: 0=合法，1=非法
# 依赖：grep
##################################################################################################
is_fully_qualified() {
  # 检查是否是有效的IPv4地址
  if echo "$1" | grep -Eq '^([0-9]{1,3}\.){3}[0-9]{1,3}$'; then
    log_debug "输入是有效的IPv4地址: $1"
    return 0
  fi

  # 检查是否是有效的IPv6地址（简化验证）
  if echo "$1" | grep -Eq '^([0-9a-fA-F]{1,4}:){7}[0-9a-fA-F]{1,4}$'; then
    log_debug "输入是有效的IPv6地址: $1"
    return 0
  fi

  case $1 in
  localhost.localdomain)
    log_warning "域名不能是 localhost.localdomain。"
    return 1
    ;;
  *.localdomain)
    log_warning "域名不能是 *.localdomain。"
    return 1
    ;;
  *.internal)
    log_warning "域名不能是 *.internal。"
    return 1
    ;;
  *.*.*)
    if echo "$1" | grep -qE '^([a-zA-Z0-9-]+\.)+[a-zA-Z]{2,}$'; then
      log_debug "主机名完全符合 $1 条件"
      return 0
    else
      return 1
    fi
    ;;
  esac
  return 1
}

##################################################################################################
# 函数名：get_distro
# 功能：识别操作系统发行版、版本、架构，标准化os_type/os_real/os_version/os_major_version/arch_type变量，支持国产系统、主流Linux、FreeBSD初步判断
# 全局变量: os_type、os_version、os_major_version、os_real、os_pretty、arch_type
# 选项说明: $1可选，指定输出字段：real/type/version/major/pretty/arch/id
# 返回值: 0识别成功，1识别失败；传参时直接打印对应值
# 依赖：uname、/etc/os-release、各类*-release文件
##################################################################################################
get_distro() {
  if ! uname -o | grep -iq linux; then
    printf "${RED}未能检测到受支持的操作系统。${NORMAL}\\n"
    return 1
  fi

  # 优先检查 /etc/os-release
  if [ -f /etc/os-release ]; then
    # 加载系统版本文件
    # shellcheck disable=SC1091
    . /etc/os-release
    # shellcheck disable=SC2153
    os_real="$NAME"
    os_pretty="$PRETTY_NAME"
    os_type="$ID"
    os_version="$VERSION_ID"

    # 特殊处理国产操作系统
    case "$ID" in
    "openEuler" | "openeuler")
      os_real="openEuler"
      os_type="openeuler"
      ;;
    "opencloudos")
      os_real="OpenCloudOS"
      os_type="opencloudos"
      ;;
    "anolis")
      os_real="Anolis"
      os_type="anolis"
      ;;
    "tencentos" | "tlinux")
      os_real="TencentOS"
      os_type="tencentos"
      ;;
    "openkylin")
      os_real="openKylin"
      os_type="openkylin"
      ;;
    "kylin")
      if [ -f /etc/kylin-release ] || [ -f /etc/kylin-version/kylin-system-version.conf ]; then
        os_real="Kylin"
        os_type="kylin"
      fi
      ;;
    esac

    # 特殊处理基于 Debian/Ubuntu 的系统
    if [ -f /etc/debian_version ]; then
      case "$ID" in
      "ubuntu" | "zorin" | "pop")
        os_type="ubuntu"
        ;;
      "deepin")
        os_real="Deepin"
        os_type="deepin"
        ;;
      "linuxmint")
        os_real="Linux Mint"
        os_type="linuxmint"
        ;;
      "kali")
        os_real="Kali"
        os_type="kali"
        ;;
      "raspbian")
        os_real="Raspberry Pi OS"
        os_type="raspbian"
        ;;
      esac
    fi

    # 处理系统版本（特殊格式）
    if [ -z "$os_version" ]; then
      if [ -f /etc/debian_version ]; then
        # 从 /etc/debian_version 获取 Debian 版本
        os_version=$(cat /etc/debian_version | cut -d '.' -f1)
      elif [ -f /etc/openEuler-release ]; then
        os_version=$(grep -o '[0-9\.]*' /etc/openEuler-release | head -n1)
      elif [ -f /etc/opencloudos-release ]; then
        os_version=$(grep -o '[0-9\.]*' /etc/opencloudos-release | head -n1)
      fi
    fi

  elif [ -f /etc/openEuler-release ]; then
    # 华为 openEuler
    os_string=$(cat /etc/openEuler-release)
    os_real="openEuler"
    os_pretty="$os_string"
    os_type="openeuler"
    os_version=$(echo "$os_string" | grep -o '[0-9\.]*' | head -n1)

  elif [ -f /etc/hce-release ]; then
    # 华为云 EulerOS
    os_string=$(cat /etc/hce-release)
    os_real="Huawei Cloud EulerOS"
    os_pretty="$os_string"
    os_type="hce"
    os_version=$(echo "$os_string" | grep -o '[0-9\.]*' | head -n1)

  elif [ -f /etc/opencloudos-release ]; then
    # OpenCloudOS
    os_string=$(cat /etc/opencloudos-release)
    os_real="OpenCloudOS"
    os_pretty="$os_string"
    os_type="opencloudos"
    os_version=$(echo "$os_string" | grep -o '[0-9\.]*' | head -n1)

  elif [ -f /etc/tlinux-release ]; then
    # TencentOS
    os_string=$(cat /etc/tlinux-release)
    os_real="TencentOS"
    os_pretty="$os_string"
    os_type="tencentos"
    os_version=$(echo "$os_string" | grep -o '[0-9\.]*' | head -n1)

  elif [ -f /etc/anolis-release ]; then
    # Anolis OS
    os_string=$(cat /etc/anolis-release)
    os_real="Anolis"
    os_pretty="$os_string"
    os_type="anolis"
    os_version=$(echo "$os_string" | grep -o '[0-9\.]*' | head -n1)

  elif [ -f /etc/kylin-release ] || [ -f /etc/kylin-version/kylin-system-version.conf ]; then
    # 麒麟系统
    if [ -f /etc/kylin-release ]; then
      os_string=$(cat /etc/kylin-release)
    else
      # 新版本麒麟使用配置文件
      os_string=$(grep 'Kylin' /etc/kylin-version/kylin-system-version.conf | head -n1)
    fi
    if echo "$os_string" | grep -iq "openkylin"; then
      os_real="openKylin"
      os_type="openkylin"
    else
      # 区分桌面版和服务器版
      if echo "$os_string" | grep -iq "desktop"; then
        os_real="Kylin Desktop"
        os_type="kylindesktop"
      else
        os_real="Kylin Server"
        os_type="kylinserver"
      fi
    fi
    os_pretty="$os_string"
    os_version=$(echo "$os_string" | grep -o '[0-9\.]*' | head -n1)

  elif [ -f /etc/cloudlinux-release ]; then
    # CloudLinux
    os_string=$(cat /etc/cloudlinux-release)
    os_real="CloudLinux"
    os_pretty="$os_string"
    os_type="cloudlinux"
    os_version=$(echo "$os_string" | grep -o '[0-9\.]*')

  elif [ -f /etc/oracle-release ]; then
    # Oracle Linux
    os_string=$(cat /etc/oracle-release)
    os_real="Oracle Linux"
    os_pretty="$os_string"
    os_type="ol"
    os_version=$(echo "$os_string" | grep -o '[0-9\.]*')

  elif [ -f /etc/redhat-release ]; then
    # RHEL/CentOS/AlmaLinux/Rocky
    os_string=$(cat /etc/redhat-release)

    # 更精确的识别
    if echo "$os_string" | grep -iq 'Red Hat Enterprise Linux'; then
      os_real='RHEL'
    elif echo "$os_string" | grep -iq 'CentOS Stream'; then
      os_real='CentOS Stream'
    elif echo "$os_string" | grep -iq 'Rocky Linux'; then
      os_real='Rocky'
    elif echo "$os_string" | grep -iq 'AlmaLinux'; then
      os_real='AlmaLinux'
    elif echo "$os_string" | grep -iq 'Fedora'; then
      os_real='Fedora'
    elif echo "$os_string" | grep -iq 'Scientific Linux'; then
      os_real='Scientific Linux'
    elif echo "$os_string" | grep -iq 'CentOS'; then
      os_real='CentOS'
    else
      os_real=$(echo "$os_string" | cut -d' ' -f1)
    fi

    os_pretty="$os_string"
    os_type=$(echo "$os_real" | tr '[:upper:]' '[:lower:]' | tr ' ' '_')
    os_version=$(echo "$os_string" | grep -o '[0-9\.]*')

  else
    # 特殊系统检测
    if [ -f /etc/alpine-release ]; then
      os_real="Alpine"
      os_pretty="Alpine Linux $(cat /etc/alpine-release)"
      os_type="alpine"
      os_version=$(cat /etc/alpine-release)
    elif [ -f /etc/arch-release ]; then
      os_real="Arch"
      os_pretty="Arch Linux"
      os_type="arch"
      os_version="rolling"
    elif [ -f /etc/manjaro-release ]; then
      os_real="Manjaro"
      os_pretty="Manjaro Linux"
      os_type="manjaro"
      os_version="rolling"
    elif [ -f /etc/gentoo-release ]; then
      os_real="Gentoo"
      os_pretty="Gentoo Linux"
      os_type="gentoo"
      os_version="rolling"
    else
      printf "${RED}未找到可识别的系统版本文件，该操作系统可能不受支持。${NORMAL}\\n"
      printf "${YELLOW}已检测到以下系统文件：${NORMAL}\\n"
      ls -la /etc/*-release /etc/*release /etc/*version 2>/dev/null || true
      return 1
    fi
  fi

  # 获取处理器架构
  local arch
  arch=$(uname -m)
  case "$arch" in
  x86_64)
    arch_type="x86_64"
    ;;
  aarch64)
    arch_type="ARM64"
    ;;
  armv7l)
    arch_type="ARMv7"
    ;;
  armv8l)
    arch_type="ARMv8_32"
    ;;
  armv6l)
    arch_type="ARMv6"
    ;;
  armv5tel)
    arch_type="ARMv5"
    ;;
  ppc64le)
    arch_type="ppc64le"
    ;;
  s390x)
    arch_type="s390x"
    ;;
  *)
    arch_type="$arch"
    ;;
  esac

  # 提取主版本号
  if [ -n "$os_version" ] && [ "$os_version" != "rolling" ]; then
    os_major_version=$(echo "$os_version" | cut -d '.' -f1)
  else
    os_major_version="$os_version"
  fi

  # 返回请求的信息
  if [ -n "$1" ]; then
    case $1 in
    real)
      echo "$os_real"
      ;;
    type)
      echo "$os_type"
      ;;
    version)
      echo "$os_version"
      ;;
    major)
      echo "$os_major_version"
      ;;
    pretty)
      echo "$os_pretty"
      ;;
    arch)
      echo "$arch_type"
      ;;
    id)
      # 返回标准化ID，用于软件包管理判断
      case "$os_type" in
      debian | ubuntu | deepin | linuxmint | kali | raspbian | openkylin)
        echo "debian"
        ;;
      rhel | centos | rocky | almalinux | oracle | fedora | anolis | tencentos | openeuler | opencloudos | kylin*)
        echo "rhel"
        ;;
      arch | manjaro)
        echo "arch"
        ;;
      alpine)
        echo "alpine"
        ;;
      gentoo)
        echo "gentoo"
        ;;
      *)
        echo "unknown"
        ;;
      esac
      ;;
    *)
      printf "${RED}未知的参数。可用参数：real, type, version, major, pretty, arch, id${NORMAL}\\n"
      return 1
      ;;
    esac
  fi

  return 0
}

##################################################################################################
# 函数名：memory_ok
# 功能：检查系统总内存(物理内存+交换)是否满足最低要求，内存不足时可交互式创建/swap.vm交换文件扩容
# 全局变量: RUN_LOG
# 参数说明: $1 min_mem - 最低所需总内存(单位KB)；$2 disk_space_required - 安装所需额外磁盘空间(单位GB)
# 返回值: 0-内存充足/用户选择不新建交换继续；1-用户选择终止安装；2-btrfs不支持交换文件；3-根盘空间不足；4-创建交换文件失败；5-启用交换文件失败
# 依赖：swapon、awk、grep、df、dd、mkswap、tput、yesno、log_debug/log_error/log_warning/log_fatal 日志函数
##################################################################################################
memory_ok() {
  min_mem=$1
  disk_space_required=$2
  # 如果尚未设置 Virtualmin swap，请尝试设置
  is_swap=$(swapon -s | grep /swap.vm)
  if [ -n "$is_swap" ]; then
    if [ -z "$min_mem" ]; then
      min_mem=1048576
    fi
    # 检查可用 RAM 和交换区
    mem_total=$(awk '/MemTotal/ {print $2}' /proc/meminfo)
    swap_total=$(awk '/SwapTotal/ {print $2}' /proc/meminfo)
    all_mem=$((mem_total + swap_total))
    swap_min=$((1286144 - all_mem))

    if [ "$swap_min" -lt '262144' ]; then
      swap_min=262144
    fi

    min_mem_h=$((min_mem / 1024))
    if [ "$all_mem" -gt "$min_mem" ]; then
      log_debug "内存大于 ${min_mem_h} MB，应该足够了。"
      return 0
    else
      log_error "内存低于 ${min_mem_h} MB。 可能无法进行完整安装。"
    fi

    # 我们需要交换，所以询问并打开一些。
    swap_min_h=$((swap_min / 1024))
    echo
    echo "  您的系统的可用内存和交换空间少于 ${min_mem_h} MB。"
    echo "  安装可能会失败，特别是在 Debian/Ubuntu 系统上（安"
    echo "  装大量软件包时 apt-get 会变得非常大）。 你可以退出"
    echo "  您可以退出并使用 --minimal 标志重新安装，以安装更紧凑的软件包选择"
    echo "  或者我们可以尝试为您创建一个交换文件。要创建交换文件，除了用于安装软件包的"
    echo "  $disk_space_required GB 可用空间之外"
    echo "  您还需要 ${swap_min_h} MB 可用磁盘空间。"
    echo
    echo "  你想继续吗？ 如果继续"
    printf "  您将可以选择创建交换文件。 (y/n) "
    if ! yesno; then
      return 1 # 当该函数返回 1 时应退出
    fi
    echo
    echo "  您想让我尝试创建一个交换文件吗？"
    echo "   除了用于安装的 $disk_space_required GB 之外，这还需要至少 ${swap_min_h} MB 的"

    printf "  可用空间。 (y/n) "
    if ! yesno; then
      log_warning "继续而不创建交换文件。 安装可能会失败。"
      return 0
    fi

    # 检查 btrfs，因为它无法安全地托管交换文件。
    root_fs_type=$(grep -v "^$\\|^\\s*#" /etc/fstab | awk '{print $2 " " $3}' | grep "/ " | cut -d' ' -f2)
    if [ "$root_fs_type" = "btrfs" ]; then
      log_fatal "您的根文件系统似乎正在运行 btrfs。"
      log_fatal "在 btrfs 文件系统上创建交换文件是不安全的。"
      log_fatal "您需要使用 --minimal 安装或手动创建交换文件（在某些其他文件系统上）。"
      return 2
    fi

    # 检查是否有足够的空间。
    root_fs_avail=$(df / | grep -v Filesystem | awk '{print $4}')
    if [ "$root_fs_avail" -lt $((swap_min + 358400)) ]; then
      root_fs_avail_h=$((root_fs_avail / 1024))
      log_fatal "根文件系统只有 $root_fs_avail_h MB 可用，这太小了。"
      log_fatal "您需要使用 --minimal 安装向 '/' 添加更多空间。"
      return 3
    fi

    # Create a new file
    if ! dd if=/dev/zero of=/swap.vm bs=1024 count=$swap_min 1>>${RUN_LOG} 2>&1; then
      log_fatal "创建交换文件 /swap.vm 失败。"
      return 4
    fi
    chmod 0600 /swap.vm 1>>${RUN_LOG} 2>&1
    mkswap /swap.vm 1>>${RUN_LOG} 2>&1
    if ! swapon /swap.vm 1>>${RUN_LOG} 2>&1; then
      log_fatal "启用交换文件失败。 如果这是虚拟机，您的提供商可能会禁止它。"
      return 5
    fi
    echo "/swap.vm          swap            swap    defaults        0 0" >>/etc/fstab
  fi
  return 0
}

##################################################################################################
# 函数名：password
# 功能：交互式设置密码，强制密码复杂度校验（不少于8位，包含数字、大小写字母、特殊符号），二次确认密码
# 全局变量: password
# 选项说明: 无
# 返回值: 无，成功后全局变量password保存最终密码
# 依赖：task secret、颜色常量（RED/GREEN/CYAN/NORMAL/underline）
##################################################################################################
password() {
  printf "${underline}\n"
  printf "设置密码\n"
  printf "${CYAN}注意:密码不得少于8位、必须包含数字、大小写字母、特殊符号${NORMAL}\n"

  while :; do
    # 获取第一次密码输入
    task secret "请输入密码"
    pwd1=$reply
    [ -z "$pwd1" ] && printf "${RED}密码不能为空，请重新输入${NORMAL}\n" && continue

    # 密码复杂度检查
    num=${#pwd1}                                   # 密码复杂度检查
    digit=$(echo "$pwd1" | grep -o '[[:digit:]]')  # 检查是否包含数字
    lower=$(echo "$pwd1" | grep -o '[[:lower:]]')  # 检查是否包含小写字母
    upper=$(echo "$pwd1" | grep -o '[[:upper:]]')  # 检查是否包含大写字母
    alnum=$(echo "$pwd1" | grep -o '[^[:alnum:]]') # 检查是否包含特殊字符

    if [ "$num" -lt 8 ] || [ -z "$digit" ] || [ -z "$lower" ] || [ -z "$upper" ] || [ -z "$alnum" ]; then
      printf "${RED}密码不得少于8位、必须包含数字、大小写字母、特殊符号，请重新输入${NORMAL}\n"
      continue
    fi

    # 获取确认密码
    task secret "请确认密码"
    pwd2=$reply
    [ -z "$pwd2" ] && printf "${RED}密码不能为空，请重新输入${NORMAL}\n" && continue

    # 检查两次密码是否一致
    if [ "$pwd1" = "$pwd2" ]; then
      password=$pwd2
      printf "\n密码设置 ${GREEN}成功${NORMAL} !\n${underline}\n"
      break
    else
      printf "${RED}您两次输入的密码不一致，请重新输入${NORMAL}\n"
    fi
  done
}

##################################################################################################
# 函数名：setfr
# 功能：自动识别防火墙类型（ufw/firewalld），开放指定端口，支持端口/协议格式（如53/tcp、53/udp、53/all）
# 全局变量: 无
# 选项说明: 参数支持格式：端口/tcp、端口/udp、端口/all（all代表同时放行tcp+udp），可传入多个
# 返回值: 无
# 依赖：log_debug、sudo、ufw、firewall-cmd
##################################################################################################
setfr() {
  local fw_type real_port proto
  if [ -x /usr/sbin/ufw ]; then
    fw_type="ufw"
    ufwstatus=$(sudo ufw status | awk 'NR==1' | awk -F ': ' '{print $2}')
    if [ "$ufwstatus" = inactive ]; then
      log_debug "开启 UFW 防火墙"
      echo y | sudo ufw enable >/dev/null 2>&1
    fi
  elif [ -x /usr/bin/firewall-cmd ]; then
    fw_type="firewalld"
  else
    log_debug "未识别支持的防火墙，跳过端口配置"
    return
  fi

  # 公共执行函数，无数组
  do_rule() {
    case $fw_type in
    ufw)
      log_debug "开始配置 $proto:$real_port 端口"
      sudo ufw allow "${real_port}/$proto"
      log_debug "配置 $proto:$real_port 端口完成"
      ;;
    firewalld)
      log_debug "开始配置 $proto:$real_port 端口"
      firewall-cmd --zone=public --add-port="${real_port}/$proto" --permanent
      log_debug "配置 $proto:$real_port 端口完成"
      ;;
    esac
  }

  for port in "$@"; do
    case $port in
    */all)
      real_port="${port%/all}"
      proto="tcp"
      do_rule
      proto="udp"
      do_rule
      ;;
    */tcp)
      real_port="${port%/tcp}"
      proto="tcp"
      do_rule
      ;;
    */udp)
      real_port="${port%/udp}"
      proto="udp"
      do_rule
      ;;
    *)
      real_port="$port"
      proto="tcp"
      do_rule
      ;;
    esac
  done

  case $fw_type in
  firewalld) firewall-cmd --reload ;;
  esac
}

##################################################################################################
# 函数名：MainMenu
# 功能：生成可自定义列数的交互式选择菜单，接收用户选择并将选中项写入指定变量
# 全局变量: COL（依赖 ComputingColumn 函数赋值）
# 选项说明: $1=菜单提示文本，$2=接收结果的变量名，$3=每行展示选项数量，后续参数为菜单选项列表
# 返回值: 无，选中值存入 $2 指定变量
# 依赖：ComputingColumn、task enter、task error、颜色常量 NORMAL
##################################################################################################
MainMenu() {
  local prompt="$1"
  local name="$2"
  local val_number="$3"
  local Index=0
  shift 3
  for i in "$@"; do
    msg="$i"
    ComputingColumn
    Index=$((Index + 1))
    val=$((Index % val_number))
    printf "${NORMAL}(%1d) %-${COL}s${NORMAL}" "${Index}" "${msg}"
    if [ ${val} -eq 0 ]; then
      printf "\n"
    fi
  done
  printf "\n"
  task enter
  while :; do
    index=$reply
    if [ -n "$reply" ]; then
      if [ "$reply" -le "$Index" ]; then
        reply=writing
      fi
    fi
    case $reply in
    writing)
      set -- "$@"
      shift "$((index - 1))"
      eval "${name}='$1'"
      break
      ;;
    *)
      task error
      ;;
    esac
  done
}

##################################################################################################
# 函数名：title
# 功能：清屏并居中打印黄色标题文本
# 全局变量: COL（依赖ComputingColumn函数赋值）
# 选项说明: $1=标题文字
# 返回值: 无
# 依赖：ComputingColumn、颜色常量YELLOW/NORMAL
##################################################################################################
title() {
  clear
  local TITLECOL
  msg="$1"
  ComputingColumn
  TITLECOLL=$((COL / 2))
  printf "%${TITLECOLL}s""${YELLOW}$msg${NORMAL}\n"
}

##################################################################################################
# 函数名：disable_selinux
# 功能：修改SELinux配置文件，永久禁用SELinux（需重启系统生效）
# 全局变量: 无
# 选项说明: 无
# 返回值: 无
# 依赖：perl
##################################################################################################
disable_selinux() {
  seconfigfiles="/etc/selinux/config /etc/sysconfig/selinux"
  for i in $seconfigfiles; do
    if [ -e "$i" ]; then
      perl -pi -e 's/^SELINUX=.*/SELINUX=disabled/' "$i"
    fi
  done
}

##################################################################################################
# 函数名：tarzip
# 功能：根据文件后缀自动识别压缩格式，调用 run 执行解压，支持tar/gz/bz2/Z/xz/zip
# 全局变量: install_path
# 选项说明: $1=压缩包文件路径
# 返回值: run命令返回值
# 依赖：run、全局变量 install_path
##################################################################################################
tarzip() {
  file_ext=${1##*.}

  case $file_ext in
  tar) cmd="tar -xvf" ;;
  gz | tgz) cmd="tar -xzvf" ;;
  bz2) cmd="tar -xjvf" ;;
  Z) cmd="tar -xZvf" ;;
  xz) cmd="tar -Jxvf" ;;
  zip) cmd="unzip" ;;
  esac

  case $file_ext in
  zip) run ok "$cmd $1 -d $install_path/" "正在解压 $1" ;;
  *) run ok "$cmd $1 -C $install_path/" "正在解压 $1" ;;
  esac
}

##################################################################################################
# 函数名：init_package_manager
# 功能：自动识别系统包管理器(dnf/yum/apt-get)，批量初始化包管理相关全局命令变量
# 全局变量: pm、cmd_prefix、install_cmd、install、offline_install、remove、upgrade、update、offline_update、offline_info、install_info、offline_down、install_config_manager
# 选项说明: 无
# 返回值: 识别失败直接exit退出，成功导出包管理相关全局变量
# 依赖：id
##################################################################################################
init_package_manager() {
  cmd_prefix=$([ "$(id -u)" -eq 0 ] && echo "" || echo "sudo ")
  if [ -x /usr/bin/dnf ]; then
    pm="dnf"
  elif [ -x /usr/bin/yum ]; then
    pm="yum"
  elif [ -x /usr/bin/apt-get ]; then
    pm="apt-get"
  else
    printf "${RED}无法识别此操作系统/版本.无法继续.${NORMAL}\n"
    exit 1
  fi

  case "$pm" in
  dnf | yum)
    install_cmd="$pm"
    install="${cmd_prefix} $install_cmd -y install"
    offline_install="${cmd_prefix} $install_cmd -y install --disablerepo='*' --enablerepo=offline"
    remove="${cmd_prefix} $install_cmd -y autoremove"
    upgrade="$install_cmd -y update"
    update="${cmd_prefix} $install_cmd clean all ; $install_cmd makecache -y"
    offline_update="${cmd_prefix} $install_cmd clean all ; $install_cmd makecache --disablerepo='*' --enablerepo=offline"
    offline_info="${cmd_prefix} $install_cmd info --quiet --disablerepo='*' --enablerepo=offline"

    if [ "$pm" = "dnf" ]; then
      install_info="${cmd_prefix} $install_cmd info --quiet"
      offline_down="${cmd_prefix} $install_cmd download --alldeps --resolve --destdir"
      install_config_manager="${cmd_prefix} $install_cmd config-manager"
    else
      install_info="${cmd_prefix} $install_cmd info"
      offline_down="${cmd_prefix} repotrack --download_path"
      install_config_manager="${cmd_prefix} yum-config-manager"
    fi
    ;;
  apt-get)
    install_cmd=apt-get
    install="${cmd_prefix} $install_cmd -q -y install"
    remove="${cmd_prefix} $install_cmd autoremove --assume-yes --purge"
    update="${cmd_prefix} $install_cmd -y update"
    install_info="${cmd_prefix} apt-cache policy"
    offline_down="${cmd_prefix} $install_cmd install -y --download-only"
    ;;
  esac
}

##################################################################################################
# 函数名：check_install
# 功能：批量检查软件包安装状态，未安装则执行安装；支持在线OLI/离线OFI两种模式，兼容apt/dnf/yum包管理器
# 全局变量: menu install_cmd install_info install offline_info offline_install DEBIAN_FRONTEND
# 参数说明: $@ 需要检测/安装的软件包列表
# 返回值: 无返回值；不支持的包管理器直接返回0
# 依赖：run、log_debug、grep
##################################################################################################
check_install() {
  DEBIAN_FRONTEND="noninteractive"
  local package installed cmd
  # 内部函数：获取检查字符串
  get_check_str() {
    case "$1" in
    apt | apt-get) echo "(none)" ;;
    dnf | yum) echo "Available Packages" ;;
    *) echo "" ;;
    esac
  }
  # 获取检查字符串
  local check_str
  check_str=$(get_check_str "$install_cmd")
  [ -z "$check_str" ] && return 0 # 完全不支持的包管理器，直接返回
  for package in "$@"; do
    installed=""
    cmd=""
    # 确定命令
    case "$menu:$install_cmd" in
    "OLI:"*)
      installed=$(LC_ALL=C LANG=C $install_info "${package}" 2>/dev/null)
      cmd="$install $package"
      ;;
    "OFI:dnf" | "OFI:yum")
      installed=$(LC_ALL=C LANG=C eval "$offline_info \"$package\"" 2>/dev/null)
      cmd="$offline_install $package"
      ;;
    "OFI:apt" | "OFI:apt-get")
      installed=$(LC_ALL=C LANG=C $install_info "${package}" 2>/dev/null)
      cmd="$install $package"
      ;;
    *) continue ;;
    esac
    # 检查并执行
    if [ -z "$installed" ]; then
      log_debug "无法获取 $package 的安装信息"
    elif echo "$installed" | grep -qE "$check_str"; then
      [ -n "$cmd" ] && run ok "$cmd" "安装 $package"
    else
      log_debug "$package 已安装"
    fi
  done
}

##################################################################################################
# 函数名：runtime
# 功能：计算并格式化输出脚本运行耗时；依赖全局变量 start_time（脚本起始时间戳，秒）
# 全局变量: start_time
# 参数说明: 无入参
# 返回值: 无返回值，直接控制台打印格式化后的耗时字符串
# 依赖：date
##################################################################################################
runtime() {
  # 获取脚本结束执行的时间戳（精确到秒）
  end_time=$(date +%s)
  # 计算脚本执行时长（秒）
  duration_sec=$((end_time - start_time))
  # 计算天数、小时数、分钟数和秒数
  days=$((duration_sec / 86400))
  hours=$((duration_sec % 86400 / 3600))
  minutes=$((duration_sec % 3600 / 60))
  seconds=$((duration_sec % 60))
  # 根据时长选择输出格式，并添加秒之后的单位
  if [ $duration_sec -ge 31536000 ]; then
    years=$((duration_sec / 31536000))
    echo "消耗时间：$years 年 $((duration_sec % 31536000 / 86400)) 天 $hours 小时 $minutes 分钟 $seconds 秒"
  elif [ $duration_sec -ge 86400 ]; then
    echo "消耗时间：$days 天 $hours 小时 $minutes 分钟 $seconds 秒"
  elif [ $duration_sec -ge 3600 ]; then
    echo "消耗时间：$hours 小时 $minutes 分钟 $seconds 秒"
  elif [ $duration_sec -ge 60 ]; then
    echo "消耗时间：$minutes 分钟 $seconds 秒"
  else
    echo "消耗时间：$seconds 秒"
  fi
}

##################################################################################################
# 函数名：phase
# 功能：输出安装阶段进度条，带彩色方块标记；支持普通阶段输出与完成(done)收尾输出
# 全局变量: GREEN YELLOW CYAN NORMAL phases_total(可选，总阶段数，默认3)
# 参数说明: $1=阶段描述文本；$2=当前阶段序号
# 返回值: 无返回值，控制台输出彩色进度，同时写入调试日志
# 依赖：printf、seq、log_debug
##################################################################################################
phase() {
  phases_total="${phases_total:-3}"
  phase_description="$1"
  phase_number="$2"
  if [ "$phase_description" = "done" ]; then
    # 打印已完成阶段（绿色）
    printf "${GREEN}"
    for i in $(seq 1 "$phases_total"); do
      printf "▣"
    done
    printf "${NORMAL} 清理\n"
  else
    # 打印已完成阶段（绿色）
    printf "${GREEN}"
    for i in $(seq 1 $((phase_number - 1))); do
      printf "▣"
    done
    # 打印当前阶段（黄色）
    printf "${YELLOW}▣"
    # 打印剩余阶段（青色）
    for i in $(seq $((phase_number + 1)) "$phases_total"); do
      printf "${CYAN}◻"
    done
    log_debug "第 ${phase_number} 阶段，共 ${phases_total} 阶段: ${phase_description}"
    printf "${NORMAL} 第 ${YELLOW}${phase_number}${NORMAL} 阶段，共 ${GREEN}${phases_total}${NORMAL} 阶段: ${phase_description}\n"
  fi
}
