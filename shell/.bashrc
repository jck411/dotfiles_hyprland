#
# ~/.bashrc
#

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

alias ls='ls --color=auto'
alias grep='grep --color=auto'
PS1='[\u@\h \W]\$ '
export MOZ_ENABLE_WAYLAND=1
export MOZ_ACCELERATED=1

. "$HOME/.local/bin/env"
bash ~/.config/scripts/check-updates.sh
export PATH="/opt/antigravity:$PATH"
