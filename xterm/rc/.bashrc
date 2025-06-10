# don't put duplicate lines in the history
HISTCONTROL=ignoredups:ignorespace

# append to the history file, don't overwrite it
shopt -s histappend

# for setting history length see HISTSIZE and HISTFILESIZE
HISTSIZE=1000
HISTFILESIZE=2000

# check the window size after each command and, if necessary,
# update the values of LINES and COLUMNS.
shopt -s checkwinsize

# enable color support of ls and also add handy aliases
if [ -x /usr/bin/dircolors ]; then
    alias ls='ls --color=auto'
    alias dir='dir --color=auto'
    alias vdir='vdir --color=auto'

    alias grep='grep --color=auto'
    alias fgrep='fgrep --color=auto'
    alias egrep='egrep --color=auto'
    
    alias ip='ip --color=auto'
fi

# custom PS1
if [ "$(id -u)" -eq 0 ]; then
	PS1='\[\033[1m\033[38;5;196m\]\u\[\033[1;39m\]@\[\033[38;5;82m\]\h:\[\033[38;5;213m\]\w\[\033[1;37m\]\$\[\033[0m\] '
else
	PS1='\[\033[1m\033[38;5;208m\]\u\[\033[1;39m\]@\[\033[38;5;82m\]\h:\[\033[38;5;213m\]\w\[\033[1;37m\]\$\[\033[0m\] '
fi

# user default run time config
if [ -f ~/.bashrc ]; then
    . ~/.bashrc
fi

# user default profile config
if [ -f ~/.bash_profile ]; then
    . ~/.bash_profile
elif [ -f ~/.profile ]; then
    . ~/.profile
fi

# user specific aliases and functions
if [ -d ~/.bashrc.d ]; then
    for rc in ~/.bashrc.d/*; do
        if [ -f "$rc" ]; then
            . "$rc"
        fi
    done
fi
unset rc
