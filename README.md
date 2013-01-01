gp
==

Create and maintain a passphrase repository with a single ZSH function.

This Z Shell function allows you to create and maintain a directory of GNU Privacy Guard (GPG) encrypted files. The files can contain anything you want, but I use them to track all my collected passwords and passphrases.

The shell function includes some git functionality. I use these to track revisions and to create a "master" copy of the encrypted files on a remote system. With this, I can keep multiple copies of the files and a simple 'gp --pull' refreshes the local copy with respect to the remote (master).

Initialization

You&rsquo;ll need to create the the <tt>${PASSFILEDIR}</tt> directory and run <tt>git init</tt> in that directory. Initialization of the remote &ldquo;master&rdquo; repository is beyond the scope of this little project (and also not required).

Usage

In order to ensure that the shell function is available in a shell session add this to your <tt>~/.zshrc</tt>

<code>autoload gp</code><br />
<code>compctl -f -W ${PASSFILEDIR} gp</code>

where <tt>${PASSFILEDIR}</tt> is the directory in which you keep your encrypted files.

Then simply run <tt>gp &lt;name&gt;</tt> to decrypt the file &ldquo;name&rdquo; and display its cleartext contents to STDOUT.

Options

      -a|--append:       append to an existing file
      -e|--edit:         edit an existing file with ${EDITOR}
      -d|--diff:         run 'git diff' on the whole repo
      -n|--new:          create a new encrypted file
      -g|--no-use-agent: do not use the GPG agent
      -l|--pull:         run 'git pull'
      -p|--push:         run 'git push'
      -r|--remove:       remove a file from the password repository
      -s|--search:       search the named file for the regular expression
      			 following the filename (watch special characters!)
      -t|--status:       run 'git status'
         --log:          run 'git log --name-status'
