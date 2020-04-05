[ -z "$TMUX"  ] && { tmux -S /tmp/tmux-${UID}/default attach || exec tmux -S /tmp/tmux-${UID}/default new-session && exit;}
