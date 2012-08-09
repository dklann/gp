# where to keep passphrase files
PASSDIR=~/lib/secrets

# ensure the shell function is loaded when referenced
autoload gp

# do filename completion for the command 'gp'
compctl -f -W ${PASSDIR} gp
