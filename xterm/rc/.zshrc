# don't put duplicate lines in the history
HISTCONTROL=ignoredups:ignorespace

# for setting history length see HISTSIZE and HISTFILESIZE in bash(1)
HISTSIZE=1000
HISTFILESIZE=2000

# custom PS1
PS1='%F{magenta}%n%f@%F{green}%m%f:%1~%# '

# user default env config
if [ -f ~/.zshenv ]; then
    . ~/.zshenv
fi

# user default profile config
if [ -f ~/.zprofile ]; then
    . ~/.zprofile
fi

# user default run time config
if [ -f ~/.zshrc ]; then
    . ~/.zshrc
fi

# set XDG_RUNTIME_DIR and DBUS_SESSION_BUS_ADDRESS if not set
if [ -z "$XDG_RUNTIME_DIR" ]; then
    uid=$(id -u)
    xdg_runtime_dir="/run/user/$uid"

    if [ -d "$xdg_runtime_dir" ] && [ -O "$xdg_runtime_dir" ] && \
       [ -S "$xdg_runtime_dir/bus" ]; then
        export XDG_RUNTIME_DIR="$xdg_runtime_dir"
        export DBUS_SESSION_BUS_ADDRESS="unix:path=$XDG_RUNTIME_DIR/bus"
    fi

    unset uid xdg_runtime_dir
fi
