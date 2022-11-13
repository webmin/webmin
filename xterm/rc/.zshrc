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
