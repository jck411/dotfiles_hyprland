#
# ~/.bashrc
#

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

alias ls='ls --color=auto'
alias grep='grep --color=auto'

# Dotfiles management
alias dotfiles='cd ~/REPOS/dotfiles_hyprland'
alias dotfiles-sync='~/REPOS/dotfiles_hyprland/sync.sh'
alias dotfiles-status='~/REPOS/dotfiles_hyprland/sync.sh status'
alias dotfiles-edit='code-insiders ~/REPOS/dotfiles_hyprland'

# ChatGPT via Brave app mode (lightweight, no browser chrome)
alias chatgpt='brave --app=https://chat.openai.com --profile-directory=ChatGPT --disable-extensions --disable-background-networking --disable-sync --no-first-run'

# Gemini via Brave app mode
alias gemini='brave --app=https://gemini.google.com/app --profile-directory=Gemini --disable-extensions --disable-background-networking --disable-sync --no-first-run'
PS1='[\u@\h \W]\$ '
export MOZ_ENABLE_WAYLAND=1
export MOZ_ACCELERATED=1

. "$HOME/.local/bin/env"
bash ~/.config/scripts/check-updates.sh
export PATH="/opt/Antigravity:$PATH"
