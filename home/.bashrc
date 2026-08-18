source .aliases

export PATH="$HOME/go/bin:$PATH"

# ~/.bashrc
fastfetch --logo "~/.config/fastfetch/002.png"
# If not running interactively, don't do anything
[[ $- != *i* ]] && return

# Source global definitions
if [ -f /etc/bash.bashrc ]; then
  . /etc/bash.bashrc
fi

# User specific environment

# User specific aliases and functions

eval "$(zoxide init bash)"

yz() {
  local tmp cwd

  tmp="$(mktemp -t yazi-cwd.XXXXXX)" || return
  yazi "$@" --cwd-file="$tmp"

  if cwd="$(cat "$tmp")" && [ -n "$cwd" ] && [ "$cwd" != "$PWD" ]; then
    cd "$cwd" || return
  fi

  rm -f "$tmp"
}
export PATH="$HOME/.local/bin:$PATH"
