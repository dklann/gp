gp
==

<<<<<<< HEAD
Create and maintain a passphrase repository with a single ZSH function.

This Z Shell function allows you to create and maintain a directory of GNU Privacy Guard (GPG) encrypted files. The files can contain anything you want, but I use them to track all my collected passwords and passphrases.

The shell function includes some git functionality. I use these to track revisions and to create a "master" copy of the encrypted files on a remote system. With this, I can keep multiple copies of the files and a simple 'gp --pull' refreshes the local copy with respect to the remote (master).

Usage

In order to ensure that the shell function is available in a shell session add this to your ~/.zshrc

<code>
autoload gp
compctl -f -W ${PASSDIR} gp
</code>

where $PASSDIR is the directory in which you keep your encrypted files.

Then simply run 'gp <name>' to decrypt the file and display its cleartext contents to STDOUT.

Options

      -a|--append:       append to an existing file
      -e|--edit:         edit an existing file with ${EDITOR}
      -d|--diff:         run 'git diff' on the whole repo
      -n|--new:          create a new encrypted file
      -g|--no-use-agent: do not use the GPG agent
      -l|--pull:         run 'git pull'
      -p|--push:         run 'git push'
      -r|--remove:       remove a file from the password repository
      -s|--status:       run 'git status'
      --log:             run 'git log --name-status'
=======
Create and maintain a passphrase repository with a single ZSH function.
>>>>>>> f915db22d2b77ec4972109914193a823428c57e3
