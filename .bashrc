# ~/.bashrc: executed by bash(1) for non-login shells.
# 非交互式直接退出
[[ $- != *i* ]] && return || true

# ------------------------------------------------------
# 历史记录增强
# ------------------------------------------------------
HISTFILE="$HOME/.bash_history"
HISTSIZE=20000
HISTFILESIZE=50000
HISTCONTROL=ignoreboth
HISTTIMEFORMAT="%F %T "
shopt -s histappend cmdhist checkwinsize
shopt -s autocd cdspell histverify
shopt -s globstar

# ------------------------------------------------------
# 编辑器
# ------------------------------------------------------
export EDITOR='vim'

# ------------------------------------------------------
# cd 栈 相关变量
# ------------------------------------------------------
CD_STACK="/tmp/bashrc_dstack_$$"

# ------------------------------------------------------
# 函数定义
# ------------------------------------------------------
# 命令计时（>3s 才显示）
timing_start() {
    [ $in_init -eq 1 ] && return 0
    cmd_start=$(date +%s%N)
    in_timing=1
}

timing_show() {
    local retval=${1:-$?}
    [ -z "$cmd_start" ] && return $retval
    local elapsed_ms=$(( ( $(date +%s%N) - cmd_start ) / 1000000 ))
    unset cmd_start in_timing
    if [ $elapsed_ms -gt 3000 ]; then
        local sec=$(( elapsed_ms / 1000 ))
        local frac=$(( (elapsed_ms % 1000) / 100 ))
        if [ $retval -eq 0 ]; then
            printf "\033[1;32m%d.%ds\033[m\n" "$sec" "$frac"
        else
            printf "\033[1;31m%d.%ds (exit %d)\033[m\n" "$sec" "$frac" "$retval"
        fi
    fi
    return $retval
}

# git 状态检测
git_status() {
    git rev-parse --git-dir >/dev/null 2>&1 || return
    local branch tagged
    if branch="$(git symbolic-ref --quiet HEAD 2>/dev/null)"; then
        branch="${branch#refs/heads/}"
        tagged=$'\e[38;2;219;90;107m'    # 海棠红
    else
        branch="$(git rev-parse --short HEAD 2>/dev/null)" || return
        tagged=$'\e[38;2;240;194;57m'    # 缃色
    fi
    local st untracked staged modified ahead behind out
    st="$(git status --porcelain 2>/dev/null)"
    untracked=$(printf '%s\n' "$st" | grep -c '^??' || true)
    staged=$(printf '%s\n' "$st" | grep -cE '^(M|A|D|R|C|T)' || true)
    modified=$(printf '%s\n' "$st" | grep -cE '^.([MD])' || true)
    if git rev-parse --verify --quiet @{upstream} >/dev/null 2>&1; then
        local counts
        counts=()
        while IFS=$'\t' read -r l r; do
            [ -n "$l" ] && counts+=("$l" "$r")
        done < <(git rev-list --left-right --count @{upstream}...HEAD 2>/dev/null)
        ahead=${counts[1]:-0}
        behind=${counts[0]:-0}
    else
        ahead=0
        behind=0
    fi
    [ "$untracked" -eq 0 ] && untracked=
    [ "$staged" -eq 0 ] && staged=
    [ "$modified" -eq 0 ] && modified=
    [ "$ahead" -eq 0 ] && ahead=
    [ "$behind" -eq 0 ] && behind=

    printf '%s⎇ %s' "$tagged" "$branch"
    if [ -z "$staged" ] && [ -z "$modified" ] && [ -z "$untracked" ]; then
        printf ' \e[38;2;120;146;98m✓\e[m '   # 竹青
    else
        [ -n "$staged" ]   && printf ' \e[38;2;219;90;107m✚%s\e[m'   "$staged"     # 海棠红
        [ -n "$modified" ] && printf ' \e[38;2;201;192;174m~%s\e[m'  "$modified"   # 米色
        [ -n "$untracked" ]&& printf ' \e[38;2;120;146;98m?%s\e[m'   "$untracked"  # 竹青
        [ -n "$ahead" ]    && printf ' \e[38;2;240;194;57m↑%s\e[m'   "$ahead"      # 缃色
        [ -n "$behind" ]   && printf ' \e[38;2;74;66;102m↓%s\e[m'    "$behind"     # 黛
        printf ' '
    fi
}

# 命令行耗时+退出码+终端标题 的处理（PROMPT_COMMAND 用）
post_exec() {
    local retval=$?
    timing_show "$retval"
    # 输入命令与实际执行不一致时，显示实际执行的命令
    if [ "${preexec:-0}" = 1 ] && [ -n "${preexec_actual:-}" ]; then
        local typed
        typed="$(history 1 | sed -E 's/^[[:space:]]*[0-9]+([[:space:]]*[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2})?[[:space:]]*//')"
        typed="${typed#"${typed%%[![:space:]]*}"}"
        typed="${typed%"${typed##*[![:space:]]}"}"
        case "$typed" in
            '') typed= ;;   # 空命令不显示
        esac
        if [ -n "$typed" ] && [ "$typed" != "$preexec_actual" ]; then
            printf '\e[38;2;140;140;150m  ↳ %s\e[m\n' "$preexec_actual"
        fi
    fi
    history -a
    if [ -z "$set_title" ]; then
        printf '\033]0;bash\007'
    fi
    if [ $retval -eq 0 ]; then
        local mark="\[\e[38;2;124;216;201m\]"   # 鸭卵青（亮）
    else
        local mark="\[\e[38;2;219;90;107m\]✗$retval "   # 海棠红
    fi
    local gits="$(git_status)"
    PS1=$'\[\e[38;2;74;66;102m\]┌─\[\e[m\]'
    PS1+=$'[\[\e[38;2;219;90;107m\]\u\[\e[m\]@\[\e[38;2;240;194;57m\]\h\[\e[m\] \[\e[38;2;201;192;174m\]\D{%H:%M:%S}\[\e[m\]] '
    PS1+=$'\[\e[38;2;188;230;114m\]\w\[\e[m\] '
    PS1+="$gits"
    PS1+=$'\n\[\e[38;2;74;66;102m\]└─\[\e[m\] '
    PS1+="$mark\$> \[\e[m\] "
    in_init=0
    unset preexec
    return $retval
}

# trap DEBUG：命令执行前设标题、起计时
pre_exec() {
    [ $in_init -eq 1 ] && return 0
    [ -n "$preexec" ] && return 0
    case "$BASH_COMMAND" in
        post_exec) return 0 ;;   # 提示符刷新不参与捕获
    esac
    preexec=1
    preexec_actual="$BASH_COMMAND"
    if [ -z "$set_title" ] && [ "$BASH_COMMAND" != "" ]; then
        printf '\033]0;%s\007' "$BASH_COMMAND"
    fi
    timing_start
}

# 手动设置终端标题（设置后 pre_exec/post_exec 不再自动覆盖）
title() {
    set_title=1
    printf '\033]0;%s\007' "$*"
}

# 恢复自动标题
untitle() {
    unset set_title
    printf '\033]0;bash\007'
}

# 简化版 cd：成功时记录 OPWD 到栈，供 uncd 撤回
cd() {
    if builtin cd "$@"; then
        local prev="$OLDPWD"
        local last
        last=$(tail -n 1 "$CD_STACK" 2>/dev/null)
        if [ "$last" != "$prev" ]; then
            printf '%s\n' "$prev" >> "$CD_STACK"
        fi
        return 0
    fi
    return $?
}

# cd 撤回（来自 bydbash 思路）
uncd() {
    if [ ! -s "$CD_STACK" ]; then
        echo "cd stack is empty!" >&2
        return 1
    fi
    local target
    target=$(tail -n 1 "$CD_STACK")
    echo "Uncd to: $target"
    builtin cd "$target"
    sed -i '$d' "$CD_STACK"
}

# ------------------------------------------------------
# 目录相关函数
# ------------------------------------------------------
mkcd() { mkdir -p -- "$1" && cd -- "$1"; }

# ------------------------------------------------------
# 提示符
# ------------------------------------------------------
export PROMPT_DIRTRIM=3

# ------------------------------------------------------
# bind 补全增强（来自 bydbash）
# ------------------------------------------------------
bind 'set show-all-if-ambiguous on'
bind '"\t": menu-complete'
bind '"\e[Z": menu-complete-backward'
bind 'set colored-stats on'
bind 'set colored-completion-prefix on'
bind 'set menu-complete-display-prefix on'

# ------------------------------------------------------
# 别名
# ------------------------------------------------------
if [ -x /usr/bin/dircolors ]; then
    test -r ~/.dircolors && eval "$(dircolors -b ~/.dircolors)" || eval "$(dircolors -b)"
    alias ls='ls --color=auto -v -p -CF'
    alias dir='dir --color=auto'
    alias vdir='vdir --color=auto'
    alias grep='grep --color=auto'
    alias fgrep='fgrep --color=auto'
    alias egrep='egrep --color=auto'
fi

# 安全/常用
alias cp='cp -i'
alias mv='mv -i'
alias rm='rm -I --preserve-root'
alias mkdir='mkdir -p'
alias ll='ls -alF'
alias la='ls -A'
alias lf='ls -alFA --color=auto'
alias lt='tree'
alias ip='command ip -color=auto'
alias l='ls -lh'

# 导航
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'

# pacman 快捷（Arch）
alias update='sudo pacman -Syu'
alias install='sudo pacman -S'
alias remove='sudo pacman -Rns'
alias searchpkg='pacman -Ss'

# git 快捷
alias gs='git status'
alias ga='git add'
alias gc='git commit -m'
alias gp='git push'
alias gl='git pull'
alias gd='git diff'
alias gco='git checkout'

if [ $UID -ne 0 ]; then
    alias sus='sudo -s '
    alias sudo='sudo '
    alias _='sudo '
fi

# ------------------------------------------------------
# 用户别名
# ------------------------------------------------------
if [ -f ~/.bash_aliases ]; then
    . ~/.bash_aliases
fi

# ------------------------------------------------------
# 补全
# ------------------------------------------------------
if ! shopt -oq posix; then
    if [ -f /usr/share/bash-completion/bash_completion ]; then
        . /usr/share/bash-completion/bash_completion
    elif [ -f /etc/bash_completion ]; then
        . /etc/bash_completion
    fi
fi

# ------------------------------------------------------
# 启动
# ------------------------------------------------------
history -a
in_init=1
PROMPT_COMMAND=('post_exec')
trap 'pre_exec' DEBUG
trap '[ -f "$CD_STACK" ] && rm -f "$CD_STACK"' EXIT

