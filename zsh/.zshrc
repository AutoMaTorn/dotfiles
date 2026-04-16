export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="agnoster"
plugins=(git zsh-autosuggestions)
source $ZSH/oh-my-zsh.sh

fastfetch

export PATH="$PATH:/sbin:/usr/sbin"

if [ -f "$HOME/.local/bin/env" ]; then
    . "$HOME/.local/bin/env"
fi
