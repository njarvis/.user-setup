#!/usr/bin/env bash
#
# Created by Aurélien Rainone
# github.com/aurelien-rainone/tmux-gitbar
#
# Modified by Neil Jarvis

readonly SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Additional keywords for tmux git status format
readonly BRANCH_KWD="\#{git_branch}"
readonly REMOTE_KWD="\#{git_remote}"
readonly UPSTREAM_KWD="\#{git_upstream}"
readonly FLAGS_KWD="\#{git_flags}"

# Symbols shown in git status string.
NO_REMOTE_TRACKING_SYMBOL="L"
BRANCH_SYMBOL="⎇ "
STAGED_SYMBOL="●"
CONFLICT_SYMBOL="✖"
CHANGED_SYMBOL="✚"
UNTRACKED_SYMBOL="…"
STASHED_SYMBOL="⚑"
CLEAN_SYMBOL="✔"
AHEAD_SYMBOL="↑·"
BEHIND_SYMBOL="↓·"
PREHASH_SYMBOL=":"

# Defaut Tmux format strings for Git bar components.
BRANCH_FMT="#[fg=white]"
UPSTREAM_FMT="#[fg=cyan]"
REMOTE_FMT="#[fg=cyan]"
CLEAN_FMT="#[fg=green,bold]"
STAGED_FMT="#[fg=red,bold]"
CONFLICTS_FMT="#[fg=red,bold]"
CHANGED_FMT="#[fg=blue,bold]"
STASHED_FMT="#[fg=blue,bold]"
UNTRACKED_FMT="#[fg=magenta,bold]"
RESET_FMT="#[fg=default]"

# Delimiter between symbol and numeric value
FLAGS_DELIMITER_FMT=" "
SYMBOL_DELIMITER_FMT=" "
SPLIT_DELIMITER_FMT="| "

# Style for tmux-git-status
readonly TMGS_STYLE='bg=black,fg=white,bright'

# Status line format string definition.
# It controls what tmux-git-status will show in the status line. It accepts
# any keyword or variable Tmux originally accepts, plus these ones:
#
# - #{git_branch}   : local branch name
# - #{git_remote}   : remote tracking branch
# - #{git_upstream} : upstream branch info
# - #{git_flags}    : working tree status flags
#
# See README.md for additional information
readonly TMGS_GIT_STATUS_STRING="#{git_branch} #{git_upstream} #{git_remote} #{git_flags}"

# Find the top-level directory of the current Git working tree
find_git_repo() {

  local is_working_tree=$(git rev-parse --is-inside-work-tree 2> /dev/null)
  if [ "$is_working_tree" == true ]; then
    git_repo="$(git rev-parse --show-toplevel)"
  else
    git_repo=""
  fi
}

# Search branch info and replace with symbols
replace_branch_symbols() {

  local s1; local s2; local s3
  s1="${1//_AHEAD_/${AHEAD_SYMBOL}}"
  s2="${s1//_BEHIND_/${BEHIND_SYMBOL}}"
  s3="${s2//_NO_REMOTE_TRACKING_/${NO_REMOTE_TRACKING_SYMBOL}}"

  echo "${s3//_PREHASH_/${PREHASH_SYMBOL}}"
}

# Read git variables
read_git_info() {

  local -a git_status_fields
  git_status_fields=($("$SCRIPT_DIR/gitstatus.sh" "$git_repo" 2>/dev/null))

  git_branch="$(replace_branch_symbols ${git_status_fields[0]})"
  git_remote="$(replace_branch_symbols ${git_status_fields[1]})"
  git_upstream="${git_status_fields[2]}"
  git_num_staged="${git_status_fields[3]}"
  git_num_conflicts="${git_status_fields[4]}"
  git_num_changed="${git_status_fields[5]}"
  git_num_untracked="${git_status_fields[6]}"
  git_num_stashed="${git_status_fields[7]}"
  git_clean="${git_status_fields[8]}"
}

# Perform keyword interpolation on TMBG_*_STATUS_STRING, defined in the
# configuration file
do_interpolation() {

  # chk_gitvar gitvar expr insert
  # eg: chk_gitvar  'staged' '-ne 0', 'STRING'
  # returns STRING if git_num_staged != 0 or ''
  chk_gitvar() {
    local v
    if [[ "x$2" == "x-n" ]] ; then
      v="$2 \"\$git_$1\""
    elif [[ "x$2" == x-eq* ]] ; then
      v="\$git_$1 $2"
    else
      v="\$git_num_$1 $2"
    fi
    if eval "test $v" ; then
      if [[ $# -lt 2 || "$3" != '-' ]]; then
        echo "${3}"
      else
        echo ""
      fi
    fi
  }

  # Create the 3 branch components
  branch="${BRANCH_FMT}${BRANCH_SYMBOL} ${git_branch}${RESET_FMT}"
  remote="${REMOTE_FMT}${git_remote}${RESET_FMT}"
  upstream="${UPSTREAM_FMT}${git_upstream}${RESET_FMT}"

  # Create the git flags components
  clean_flag=$(chk_gitvar 'clean' '-eq 1' "${CLEAN_FMT}${CLEAN_SYMBOL}${RESET_FMT}${FLAGS_DELIMITER_FMT}")
  staged=$(chk_gitvar 'staged' '-ne 0' "${STAGED_FMT}${STAGED_SYMBOL}${SYMBOL_DELIMITER_FMT}${git_num_staged}${RESET_FMT}${FLAGS_DELIMITER_FMT}")
  conflicts=$(chk_gitvar 'conflicts' '-ne 0' "${CONFLICTS_FMT}${CONFLICT_SYMBOL}${SYMBOL_DELIMITER_FMT}${git_num_conflicts}${RESET_FMT}${FLAGS_DELIMITER_FMT}")
  changed=$(chk_gitvar 'changed' '-ne 0' "${CHANGED_FMT}${CHANGED_SYMBOL}${SYMBOL_DELIMITER_FMT}${git_num_changed}${RESET_FMT}${FLAGS_DELIMITER_FMT}")
  stashed=$(chk_gitvar 'stashed' '-ne 0' "${STASHED_FMT}${STASHED_SYMBOL}${SYMBOL_DELIMITER_FMT}${git_num_stashed}${RESET_FMT}${FLAGS_DELIMITER_FMT}")
  untracked=$(chk_gitvar 'untracked' '-ne 0' "${UNTRACKED_FMT}${UNTRACKED_SYMBOL}${SYMBOL_DELIMITER_FMT}${git_num_untracked}${RESET_FMT}${FLAGS_DELIMITER_FMT}")

  dirty_flags=$(chk_gitvar 'clean' '-eq 0' "${staged}${conflicts}${changed}${stashed}${untracked}")

  flags="${SPLIT_DELIMITER_FMT}${clean_flag}${dirty_flags}"

  # Put it all together
  local in="$1"
  local s1="${in/$BRANCH_KWD/$branch}"
  local s2="${s1/$REMOTE_KWD/$remote}"
  local s3="${s2/$UPSTREAM_KWD/$upstream}"
  local out="${s3/$FLAGS_KWD/$flags}"

  echo "$out"
}

# Reset tmux git status bar to what it was before tmux-git-status touched it
reset_tmux_git_status() {
  # Reset the status string to how it was
  rm -f $HOME/.local/share/tmux/$(hostname -s)/*git.$TMUX_PANE
  tmux refresh-client -S
}

# Update tmux git status, called within PROMPT_COMMAND
update_tmux_git_status() {

  if [[ $git_repo ]]; then

    read_git_info

    # Check if we ignore the repo
    if [[ -f "$git_repo/.tmgsignore" ]]; then
      reset_tmux_git_status
      return
    fi

    # append to current git status format
    local format_string
    format_string="#[$TMGS_STYLE]$(do_interpolation "${TMGS_GIT_STATUS_STRING}")"

    mkdir -p ~/.local/share/tmux/$(hostname -s)
    echo "$format_string " > $HOME/.local/share/tmux/$(hostname -s)/20-git.$TMUX_PANE
    tmux refresh-client -S
  else
    find_git_repo

    if [[ $git_repo ]]; then
      update_tmux_git_status
    else
      reset_tmux_git_status
    fi
  fi
}

