#!/usr/bin/env bash

set -uo pipefail

readonly HEADER_REGEX='^([a-z]+)(\(([a-z0-9][a-z0-9._/-]*)\))?: (.+)$'
readonly CLOSING_ISSUES_REGEX='^(Closes|Fixes|Resolves) #[0-9]+(, #[0-9]+)*$'
readonly TRAILER_TOKEN_REGEX='^[A-Za-z][A-Za-z0-9-]*( [A-Za-z0-9-]+)*:[[:space:]]+[^[:space:]]'
readonly ISSUE_TRAILER_REGEX='^([Cc][Ll][Oo][Ss][Ee][Ss]|[Ff][Ii][Xx][Ee][Ss]|[Rr][Ee][Ss][Oo][Ll][Vv][Ee][Ss]|[Rr][Ee][Ff][Ss]?)([[:space:]]|$)'

readonly -a ALLOWED_TYPES=(
  feat fix docs style refactor perf test build ci chore revert
)

readonly -a ACTION_PREFIXES=(
  新增 添加 修复 修改 优化 更新 移除 增加 删除 实现 调整 重构
  提升 降低 减少 支持 完善 补充 迁移 回滚 恢复 启用 禁用 替换
  清理 修正 统一 简化 改进 升级 降级 格式化 同步 引入 采用 改用
  合并 拆分 扩展 限制 增强 适配 兼容 对齐 规范 校验 验证 记录
  防止 处理 部署 发布
)

readonly -a CONTEXT_PREFIXES=(基于 使用 通过 针对 为了 为 将)

declare -a ERRORS=()
declare -a WARNINGS=()
declare -a EXPLICIT_FOOTERS=()
HEADER=
BODY=
MESSAGE_FILE=
HEADER_SET=0
BODY_SET=0

print_usage() {
  cat <<'EOF'
用法:
  validate_commit_message.sh MESSAGE_FILE
  validate_commit_message.sh -
  validate_commit_message.sh --header HEADER [--body BODY] [--footer FOOTER]...

校验 git-commit-cn Skill 生成的 Commit Message。

参数:
  MESSAGE_FILE       UTF-8 提交信息文件；- 表示标准输入
  --header HEADER    Header 内容
  --body BODY        Body 内容
  --footer FOOTER    Footer 内容，可重复指定
  -h, --help         显示帮助
EOF
}

die_usage() {
  printf '[ERROR] %s\n' "$1" >&2
  printf '使用 --help 查看用法。\n' >&2
  exit 2
}

add_error() {
  local candidate=$1
  local existing
  for existing in "${ERRORS[@]}"; do
    [[ $existing == "$candidate" ]] && return
  done
  ERRORS+=("$candidate")
}

is_allowed_type() {
  local candidate=$1
  local allowed
  for allowed in "${ALLOWED_TYPES[@]}"; do
    [[ $candidate == "$allowed" ]] && return 0
  done
  return 1
}

contains_action() {
  local subject=$1
  local action
  local context

  for action in "${ACTION_PREFIXES[@]}"; do
    [[ $subject == "$action"* ]] && return 0
  done

  for context in "${CONTEXT_PREFIXES[@]}"; do
    [[ $subject == "$context"* ]] || continue
    for action in "${ACTION_PREFIXES[@]}"; do
      [[ $subject == *"$action"* ]] && return 0
    done
  done
  return 1
}

validate_footer() {
  local footer=$1
  local remainder

  if [[ $footer == 'BREAKING CHANGE: '* ]]; then
    remainder=${footer#'BREAKING CHANGE: '}
    [[ -n ${remainder//[[:space:]]/} ]] || \
      add_error 'Footer 的 BREAKING CHANGE: 后必须包含说明'
    return
  fi
  if [[ $footer == 'BREAKING CHANGE:'* ]]; then
    add_error 'Footer 的 BREAKING CHANGE: 后必须保留一个空格并填写说明'
    return
  fi
  if [[ $footer =~ $CLOSING_ISSUES_REGEX ]]; then
    return
  fi
  add_error 'Footer 只能使用 BREAKING CHANGE: 或关闭 Issue 的语句'
}

is_footer_candidate() {
  local block=$1
  local first_line=${block%%$'\n'*}
  [[ $first_line == 'BREAKING CHANGE'* ]] || \
    [[ $first_line =~ $TRAILER_TOKEN_REGEX ]] || \
    [[ $first_line =~ $ISSUE_TRAILER_REGEX ]]
}

ensure_runtime() {
  local charmap
  ((BASH_VERSINFO[0] >= 4)) || die_usage '需要 Bash 4 或更高版本'
  charmap=$(locale charmap 2>/dev/null || true)
  charmap=${charmap,,}
  [[ $charmap == 'utf-8' || $charmap == 'utf8' ]] || \
    die_usage '需要 UTF-8 locale 才能准确校验中文与 Unicode 标点'
}

require_value() {
  local option=$1
  local remaining=$2
  ((remaining >= 2)) || die_usage "$option 缺少参数值"
}

parse_args() {
  while (($# > 0)); do
    case $1 in
      -h|--help)
        print_usage
        exit 0
        ;;
      --header)
        require_value "$1" "$#"
        HEADER=$2
        HEADER_SET=1
        shift 2
        ;;
      --body)
        require_value "$1" "$#"
        BODY=$2
        BODY_SET=1
        shift 2
        ;;
      --footer)
        require_value "$1" "$#"
        EXPLICIT_FOOTERS+=("$2")
        shift 2
        ;;
      --)
        shift
        (($# <= 1)) || die_usage '只支持一个消息文件'
        if (($# == 1)); then
          [[ -z $MESSAGE_FILE ]] || die_usage '只支持一个消息文件'
          MESSAGE_FILE=$1
        fi
        break
        ;;
      -)
        [[ -z $MESSAGE_FILE ]] || die_usage '只支持一个消息文件'
        MESSAGE_FILE=$1
        shift
        ;;
      -*)
        die_usage "未知参数：$1"
        ;;
      *)
        [[ -z $MESSAGE_FILE ]] || die_usage '只支持一个消息文件'
        MESSAGE_FILE=$1
        shift
        ;;
    esac
  done
}

build_message() {
  local message
  local footer

  if ((HEADER_SET)); then
    [[ -z $MESSAGE_FILE ]] || die_usage '不能同时使用消息文件和 --header'
    message=$HEADER
    if ((BODY_SET)); then
      message+=$'\n\n'"$BODY"
    fi
    for footer in "${EXPLICIT_FOOTERS[@]}"; do
      message+=$'\n\n'"$footer"
    done
    printf '%s' "$message"
    return
  fi

  ((BODY_SET == 0 && ${#EXPLICIT_FOOTERS[@]} == 0)) || \
    die_usage '--body 和 --footer 必须与 --header 一起使用'
  [[ -n $MESSAGE_FILE ]] || die_usage '请提供消息文件，或使用 --header'

  if [[ $MESSAGE_FILE == '-' ]]; then
    cat
    return
  fi
  [[ -f $MESSAGE_FILE && -r $MESSAGE_FILE ]] || \
    die_usage "无法读取消息文件 '$MESSAGE_FILE'"
  cat -- "$MESSAGE_FILE"
}

validate_message() {
  local message=$1
  local normalized
  local header_line
  local commit_type
  local subject
  local last_char
  local index
  local run_start
  local current_block
  local block
  local footer_seen=0
  local -a lines=()
  local -a blocks=()

  normalized=${message//$'\r\n'/$'\n'}
  normalized=${normalized//$'\r'/$'\n'}
  while [[ $normalized == *$'\n' ]]; do
    normalized=${normalized%$'\n'}
  done

  if [[ -z $normalized ]]; then
    add_error 'Commit Message 不能为空'
    return
  fi

  mapfile -t lines <<<"$normalized"
  header_line=${lines[0]}
  if [[ $header_line =~ $HEADER_REGEX ]]; then
    commit_type=${BASH_REMATCH[1]}
    subject=${BASH_REMATCH[4]}
    is_allowed_type "$commit_type" || \
      add_error 'type 必须是以下类型之一：build, chore, ci, docs, feat, fix, perf, refactor, revert, style, test'
    if [[ ${subject:0:1} == [[:space:]] || ${subject: -1} == [[:space:]] ]]; then
      add_error 'subject 首尾不能包含空白字符'
    fi
    [[ $subject =~ [一-龥] ]] || add_error 'subject 必须包含中文描述'
    if [[ $subject =~ [一-龥] ]] && ! contains_action "$subject"; then
      add_error 'subject 必须使用明确的中文动作表达'
    fi
    last_char=${subject: -1}
    [[ $last_char == [[:punct:]] ]] && \
      add_error 'subject 结尾不能使用标点符号'
    if ((${#subject} > 50)); then
      WARNINGS+=("subject 建议控制在 50 个字符以内（当前 ${#subject} 个）")
    fi
  else
    add_error 'Header 必须使用 <type>(<scope>): <subject> 格式'
  fi

  if ((${#lines[@]} > 1)) && [[ -n ${lines[1]} ]]; then
    add_error 'Header 与 Body 或 Footer 之间必须保留一个空行'
  fi

  index=1
  while ((index < ${#lines[@]})); do
    if [[ -n ${lines[index]} ]]; then
      ((index += 1))
      continue
    fi
    run_start=$index
    while ((index < ${#lines[@]})) && [[ -z ${lines[index]} ]]; do
      ((index += 1))
    done
    if ((index - run_start > 1)); then
      add_error '各内容块之间必须且只能保留一个空行'
      break
    fi
  done

  current_block=${lines[0]}
  for ((index = 1; index < ${#lines[@]}; index += 1)); do
    if [[ -z ${lines[index]} ]]; then
      blocks+=("$current_block")
      current_block=
    else
      [[ -z $current_block ]] || current_block+=$'\n'
      current_block+=${lines[index]}
    fi
  done
  blocks+=("$current_block")

  for ((index = 1; index < ${#blocks[@]}; index += 1)); do
    block=${blocks[index]}
    if is_footer_candidate "$block"; then
      footer_seen=1
      validate_footer "$block"
    elif ((footer_seen)); then
      add_error 'Footer 必须位于 Commit Message 的末尾'
      break
    fi
  done
}

main() {
  local message
  local message_status
  local footer
  local warning
  local error

  parse_args "$@"
  ensure_runtime
  message=$(build_message)
  message_status=$?
  ((message_status == 0)) || return "$message_status"
  validate_message "$message"
  for footer in "${EXPLICIT_FOOTERS[@]}"; do
    validate_footer "$footer"
  done

  if ((${#ERRORS[@]} > 0)); then
    for error in "${ERRORS[@]}"; do
      printf '[ERROR] %s\n' "$error" >&2
    done
    return 1
  fi

  for warning in "${WARNINGS[@]}"; do
    printf '[WARN] %s\n' "$warning" >&2
  done
  printf '[OK] Commit Message 校验通过\n'
}

main "$@"
