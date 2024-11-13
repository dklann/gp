#!/bin/zsh

# Note: this script uses git, and presumes that a git repo exists in ${dir}
# Note: this script explicitly reads /dev/tty for input
# Note: this script uses an anonymous function to display usage info

function gp {
  # set up some defaults
  local RECIPIENT=${USER:-${LOGNAME:-"dklann"}}
  local dir=${PASSFILEDIR:-~/lib/p4ss}
  local APPEND= DIFF= EDIT= LOG= NEW= PULL= PUSH= REMOVE= REGEX= STATUS=
  local PASSFILE=
  local USEAGENT="--use-agent"
  local -i COPY_TO_CLIPBOARD=0
  local -a commands
  VISUAL=${VISUAL:-vi}

  zmodload zsh/datetime

  case "_$(uname -s)" in
    _Linux) GETOPT=getopt ;;
    _Darwin) GETOPT=/usr/local/bin/getopt ;;
    _*) GETOPT=getopt ;;
  esac

  ############ BEGIN external shell commands used in this function. ############
  # This function uses these 14 external commands.
  # Look for them in their upper case, parameter expanded form.
  our_commands=( awk cat chmod date find git gpg grep mv rm sed touch tr xclip )
  # Find the executables we need; this uses some basic shell and a ZSH trick:
  # the (U) in the eval says to evaluate the parameter as all upper case
  # letters. This snippet generates shell parameters representing the upper case
  # equivalent of the command names and sets the parameter values to the full path
  # of the commands.
  # Refresh this segment in Emacs by marking the appropriate region (or the whole
  # buffer with C-xH) and replacing it with C-uM-|mk-ourCommands --func (shell-command-on-region).
  local C D
  # SC2048: shellcheck overly aggressive quote recommendation.
  # shellcheck disable=SC2048
  for C in ${our_commands[*]} ; do
    # shellcheck disable=SC2154 # ZSH: ${path} is set by the shell.
    for D in ${path} ; do
      # shellcheck disable=SC2140,SC2086,SC2296 # we need the quotes, ZSH-specific expansion
      [[ -x "${D}/${C}" ]] && { eval "${(U)C//-/_}"="${D}/${C}" ; break ; }
    done
    # shellcheck disable=SC2296,SC2312 # ZSH-specific expansion
    [[ -x $(eval print \$"${(U)C//-/_}") ]] || { print "Cannot find ${C}! Done."; return 1 ; }
  done
  unset our_commands C D
  ############# END external shell commands used in this function. #############

  TEMP=$(${GETOPT} -o ac:dehnglprs --long append,clip:,copy:,diff,edit,help,log,new,no-agent,pull,push,remove,status -n "${0:t}" -- "${@}")
  if (( ${?} != 0 )) ; then echo "Terminating..." >&2 ; return 1 ; fi
  eval set -- "${TEMP}"
  while : ; do
    case "${1}" in
      -a|--app*) APPEND=1 ; shift ;;
      -c|--clip|--copy) COPY_TO_CLIPBOARD="${2}" ; shift 2 ;;
      -e|--edi*) EDIT=1 ; shift ;;
      -d|--dif*) DIFF=1 ; PASSFILE=none ; shift ;;
      -n|--new*) NEW=1 ; shift ;;
      -g|--no-*) USEAGENT="--no-use-agent" ; shift ;;
      -l|--pul*) PULL=1 ; PASSFILE=none ; shift ;;
      -p|--pus*) PUSH=1 ; PASSFILE=none ; shift ;;
      -r|--rem*) REMOVE=1 ; shift ;;
      -s|--sta*) STATUS=1 ; PASSFILE=none ; shift ;;
      --log) LOG=1 ; PASSFILE=none ; shift ;;
      -h|--help) function {
		 local my_name="${1}"
		 ${CAT} <<EOF >&2
${1}: [ --append (-a) ] [ --edit (-e) ] [ --diff (-d) ]
    [ --clip (-c) <Field_Number> | --copy <Field_Number> ]
    [ --log ]
    [ --new (-n) ]
    [ --no-use-agent (-g) ]
    [ --pull (-l) ] [ --push (-p) ]
    [ --remove (-r) ]
    [ --status (-s) ]
    [ --help ]

EOF
	       } "${0:t}" ; return ;;
      --) shift ; break ;;
      *) echo "Internal error!" ; return 1 ;;
    esac
  done

  # Added 2024-01-19: this section checks the recipient's encryption keys for
  # pending expiration and warns, or exits if any of them are expiring soon.
  typeset today=$(strftime -r '%s' ${EPOCHSECONDS})
  typeset -a expiration_data
  typeset oIFS="${IFS}"
  IFS=$'\n'
  expiration_data=( $(${GPG} --list-secret-key "${RECIPIENT}" 2>/dev/null | ${GREP} "expires") )
  for key in "${expiration_data[@]}" ; do
    # Get the expiration date only for encryption keys ("[E]").
    [[ "${key}" =~ .*\[E\].* ]] || continue
    key_expiration_date=$(echo "${key}" | ${AWK} -F': |]' '{print $3}')
    key_expiration_date_seconds=$(${DATE} --date="${key_expiration_date}" '+%s')
    # Warn them if this key expires in less than 30 days.
    if (( (key_expiration_date_seconds - today) < 30 )) ; then
      printf '%s: WARNING key %s expires in less than 30 days!\n' "${0:t}" "${key}" >&2
    fi
    # Panic (quit) if this key expires in less than 5 days.
    if (( (key_expiration_date_seconds - today) < 5 )) ; then
      printf '%s: WARNING key %s expires in less than 5 days! Cannot proceed!\n' "${0:t}" "${key}" >&2
      return 5
    fi
  done
  IFS="${oIFS}"
  unset oIFS

  PASSFILE=${PASSFILE:-${1:?"Really? You want to work on a password file without saying which one?"}}
  TEMPFILE=/tmp/gp-X0-pass${$}
  TEMPFILE2=/tmp/gp-X1-pass${$}
  trap "${RM} -f ${TEMPFILE} ${TEMPFILE2}; return" 0

  if (( NEW == 1 )) ; then
    if [[ -f ${dir}/${PASSFILE:t} ]] ; then
      echo "${PASSFILE:t} exists. Overwrite? \c"
      until [[ -n "${answer}" ]] ; do
	read -q answer
	case "${answer}" in
	  [Yy]) REPLACE=1 ;;
	  [Nn]) return ;;
	esac
      done
      unset REPLACE answer
    fi
    trap "${RM} -f ${dir}/${PASSFILE:t}; return" 1 2 11 15
    ${TOUCH} ${dir}/${PASSFILE:t}
    ${CHMOD} 600 ${dir}/${PASSFILE:t}
    ${CAT} >! ${TEMPFILE} <<EOF
X-Password-File: ${PASSFILE:t}
X-Created: $(strftime '%X on %d %B %Y' ${EPOCHSECONDS}) on $(uname -n)

EOF
    echo "enter information to be encrypted"
    ${CAT} >> ${TEMPFILE} < /dev/tty
    ${GPG} --encrypt --armor -r ${RECIPIENT} < ${TEMPFILE} >! ${dir}/${PASSFILE:t}
    trap 1 2 11 15 > /dev/null
    ${CHMOD} 400 ${dir}/${PASSFILE:t}
    (
      cd -q ${dir}
      ${GIT} add ${PASSFILE:t}
      ${GIT} commit ${PASSFILE:t}
      ${GIT} push
    )
  elif (( APPEND == 1 )) ; then
    if ${GPG} --quiet ${USEAGENT} < ${dir}/${PASSFILE:t} > ${TEMPFILE} ; then
      ${CAT} >> ${TEMPFILE} <<EOF

X-Appended: $(strftime '%X on %d %B %Y' ${EPOCHSECONDS})

EOF
      echo "enter additional information to be encrypted"
      ${CAT} >> ${TEMPFILE} < /dev/tty
      echo >> ${TEMPFILE}
      # move things around and encrypt the appended file
      ${CHMOD} 600 ${dir}/${PASSFILE:t}
      ${GPG} --encrypt --armor -r ${RECIPIENT} < ${TEMPFILE} >! ${dir}/${PASSFILE:t}
      ${CHMOD} 400 ${dir}/${PASSFILE:t}
      # commit the changes
      (
	cd -q ${dir}
	${GIT} add ${PASSFILE:t}
	# Note: this will open an editor to enable adding a commit log entry
	${GIT} commit ${PASSFILE:t}
	# push the changes to the master server (see .git/config)
	${GIT} push
      )
    else
      echo "cannot decrypt existing ${PASSFILE:t} - I quit"
      return
    fi
  elif (( DIFF == 1 )) ; then
    (
      cd -q ${dir}
      ${GIT} diff
    )
  elif (( EDIT == 1 )) ; then
    if ${GPG} --quiet ${USEAGENT} < ${dir}/${PASSFILE:t} > ${TEMPFILE} ; then

      # purge select headers (first expression) and the blank separator line (second expression)
      # first expression modified 2024-11-13 after realizing the previous expression deletes _all_ "headers"
      # second expression modified 2024-11-13 after reading and understanding sed(1)
      ${SED} -E -e '/^X-(Password-File|Created):[[:space:]]/d' -e '1,/^$/d' < ${TEMPFILE} > ${TEMPFILE2} && ${MV} ${TEMPFILE2} ${TEMPFILE}
      # edit the file
      ${VISUAL} ${TEMPFILE}
      # prepend new headers to the edited file
      ${CAT} >! ${TEMPFILE2} <<EOF
X-Password-File: ${PASSFILE:t}
X-Created: $(strftime '%X on %d %B %Y' ${EPOCHSECONDS}) on $(uname -n)

$(${CAT} ${TEMPFILE})
EOF
      # move things around and encrypt the edited file
      ${MV} ${TEMPFILE2} ${TEMPFILE}
      ${CHMOD} 600 ${dir}/${PASSFILE:t}
      ${GPG} --encrypt --armor -r ${RECIPIENT} < ${TEMPFILE} >! ${dir}/${PASSFILE:t}
      ${CHMOD} 400 ${dir}/${PASSFILE:t}
      # commit the changes
      (
	cd -q ${dir}
	${GIT} add ${PASSFILE:t}
	# Note: this will open an editor to enable adding a commit log entry
	${GIT} commit ${PASSFILE:t}
	# push the changes to the master server (see .git/config)
	${GIT} push
      )
    else
      echo "cannot decrypt existing ${PASSFILE:t} - I quit"
      return
    fi
  elif (( LOG == 1 )) ; then
    (
      cd -q ${dir}
      ${GIT} log --name-status
    )
  elif (( PULL == 1 )) ; then
    (
      cd -q ${dir}
      ${GIT} pull
    )
  elif (( PUSH == 1 )) ; then
    (
      cd -q ${dir}
      ${GIT} push
    )
  elif (( REMOVE == 1 )) ; then
    typeset confirm
    until [[ "${confirm}" =~ [YyNn] ]] ; do
      read -q confirm\?"Really remove ${PASSFILE:t}? "
      case "${confirm}" in
	y) break ;;
      esac
      echo
    done
    if [[ "${confirm}" = 'y' ]] ; then
      (
	cd -q ${dir}
	${CHMOD} 600 ${dir}/${PASSFILE:t}
	${GIT} rm ${PASSFILE:t}
	# Note: this will open an editor to enable adding a commit log entry
	${GIT} commit ${PASSFILE:t}
	# push the changes to the master server (see .git/config)
	${GIT} push
      )
    else
      echo "OK. Not removing ${PASSFILE:t}."
    fi

  elif (( STATUS == 1 )) ; then

    (
      cd -q ${dir}
      ${GIT} status
    )
  else
    # simply dump the contents of the file, and (optionally)
    # search the output for the string in ARGV[1] (aka ${2}).
    # With "--clip (-c) Field_Number", place 'field number' in
    # the X clipboard.
    REGEX="${2}"
    until [[ -f "${dir}/${PASSFILE:t}" ]] ; do
      typeset -a tries
      tries=( $(${FIND} ${dir} -maxdepth 1 -iname "*${PASSFILE:t}*") )
      if (( ${#tries} > 0 )) ; then
	for PASSFILE in ${tries[*]} ; do
	  read -q confirm\?"Do you mean ${PASSFILE:t}? "
	  case "${confirm}" in
	    [Yy]) break 2 ;;
	  esac
	  echo
	done
      fi
      read -r PASSFILE\?"No matches. Try another password file name: " < /dev/tty
    done
    if [[ -n "${REGEX}" ]] ; then
      if ((COPY_TO_CLIPBOARD)) ; then
	${GPG} --quiet ${USEAGENT} < ${dir}/${PASSFILE:t} 2>/dev/null | ${GREP} -P -i "${REGEX}" | ${AWK} "{print \$${COPY_TO_CLIPBOARD}}" | ${TR} -d '\n' | ${XCLIP} -selection clipboard
      else
	${GPG} --quiet ${USEAGENT} < ${dir}/${PASSFILE:t} 2>/dev/null | ${GREP} -P -i "${REGEX}"
      fi
    else
      ${GPG} --quiet ${USEAGENT} < ${dir}/${PASSFILE:t} 2>/dev/null
    fi
  fi

  # clean up
  for C in ${commands} ; do
    unset `eval echo ${(U)C}`
  done
  unset APPEND DIFF EDIT LOG NEW PULL PUSH REMOVE REGEX STATUS
  unset C D confirm dir f PASSFILE RECIPIENT TEMPFILE tries USEAGENT
}
# Local Variables: ***
# mode:shell-script ***
# indent-tabs-mode: f ***
# sh-indentation: 2 ***
# sh-basic-offset: 2 ***
# sh-indent-for-do: 0 ***
# sh-indent-after-do: + ***
# sh-indent-comment: t ***
# sh-indent-after-case: + ***
# sh-indent-after-done: 0 ***
# sh-indent-after-else: + ***
# sh-indent-after-if: + ***
# sh-indent-after-loop-construct: + ***
# sh-indent-after-open: + ***
# sh-indent-after-switch: + ***
# sh-indent-for-case-alt: + ***
# sh-indent-for-case-label: + ***
# sh-indent-for-continuation: + ***
# sh-indent-for-done: 0 ***
# sh-indent-for-else: 0 ***
# sh-indent-for-fi: 0 ***
# sh-indent-for-then: 0 ***
# End: ***
