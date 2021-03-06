#!/bin/zsh

# Note: this script uses git, and presumes that a git repo exists in ${dir}
# Note: this script explicitly reads /dev/tty for input

function gp() {
  # set up some defaults
  local RECIPIENT=${USER:-${LOGNAME:-"dklann"}}
  local dir=${PASSFILEDIR:-~/lib/p4ss}
  local APPEND= DIFF= EDIT= LOG= NEW= PULL= PUSH= REMOVE= REGEX= STATUS=
  local PASSFILE=
  local USEAGENT="--use-agent"
  local -a commands
  VISUAL=${VISUAL:-vi}

  zmodload zsh/datetime

  case "_$(uname -s)" in
    _Linux) GETOPT=getopt ;;
    _Darwin) GETOPT=/usr/local/bin/getopt ;;
    _*) GETOPT=getopt ;;
  esac

  ################## BEGIN shell commands used in this function. ##################
  # This function uses these 10 external commands.
  # Look for them in their upper case, parameter expanded form.
  typeset -a our_commands
  our_commands=( cat chmod git gpg ls mv pcregrep rm sed touch )
  # Find the executables we need; this uses a little old fashioned shell and
  # a ZSH trick -- the (U) in the eval(1) says to evaluate the parameter as
  # all upper case letters. We will use the command names in upper case as
  # variables by which to call the external commands used in this function.
  for C in "${our_commands}" ; do
    for D in "${path}" ; do
      [[ -x "${D}/${C}" ]] && { eval "${(U)C//-/_}"="${D}/${C}" ; break }
    done
    [[ -x $(eval print \$${(U)C//-/_}) ]] || { print "Cannot find ${C}! Done."; return 1 }
  done
  ################### END shell commands used in this function. ###################

  TEMP=$(${GETOPT} -o adenglprs --long append,diff,edit,log,new,no-agent,pull,push,remove,status -n "${0:t}" -- "${@}")
  if (( ${?} != 0 )) ; then echo "Terminating..." >&2 ; return 1 ; fi
  # Note the quotes around ${TEMP}: they are essential!
  eval set -- "${TEMP}"
  while :
  do
    case "${1}" in
      -a|--app*) APPEND=1 ; shift ;;
      -e|--edi*) EDIT=1 ; shift ;;
      -d|--dif*) DIFF=1 ; PASSFILE=none ; shift ;;
      -n|--new*) NEW=1 ; shift ;;
      -g|--no-*) USEAGENT="--no-use-agent" ; shift ;;
      -l|--pul*) PULL=1 ; PASSFILE=none ; shift ;;
      -p|--pus*) PUSH=1 ; PASSFILE=none ; shift ;;
      -r|--rem*) REMOVE=1 ; shift ;;
      -s|--sta*) STATUS=1 ; PASSFILE=none ; shift ;;
      --log) LOG=1 ; PASSFILE=none ; shift ;;
      --) shift ; break ;;
      *) echo "Internal error!" ; return 1 ;;
      esac
  done

  PASSFILE=${PASSFILE:-${1:?"Really? You want to work on a password file without saying which one?"}}
  TEMPFILE=/tmp/gp-X0-pass${$}
  TEMPFILE2=/tmp/gp-X1-pass${$}
  trap "${RM} -f ${TEMPFILE} ${TEMPFILE2}; return" 0

  if (( NEW == 1 ))
  then
    if test -f ${dir}/${PASSFILE:t}
    then
      echo "${PASSFILE:t} exists. Overwrite? \c"
      until test -n "${answer}"
      do
	read -q answer
	case "${answer}" in
	  y) REPLACE=1 ;;
	  n) REPLACE=0 ;;
	esac
	test ${REPLACE} -eq 0 && return
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

  elif (( APPEND == 1 ))
  then

    if ${GPG} --quiet ${USEAGENT} < ${dir}/${PASSFILE:t} > ${TEMPFILE}
    then
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

  elif (( DIFF == 1 ))
  then

    (
      cd -q ${dir}
      ${GIT} diff
    )

  elif (( EDIT == 1 ))
  then

    if ${GPG} --quiet ${USEAGENT} < ${dir}/${PASSFILE:t} > ${TEMPFILE}
    then

      # purge headers (first expression) and the blank separator line (second expression)
      ${SED} -e '/^X-.*:[[:space:]]/d' -e 1,1d < ${TEMPFILE} > ${TEMPFILE2} && ${MV} ${TEMPFILE2} ${TEMPFILE}
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

  elif (( LOG == 1 ))
  then

    (
      cd -q ${dir}
      ${GIT} log --name-status
    )

  elif (( PULL == 1 ))
  then

    (
      cd -q ${dir}
      ${GIT} pull
    )

  elif (( PUSH == 1 ))
  then

    (
      cd -q ${dir}
      ${GIT} push
    )

  elif (( REMOVE == 1 ))
  then

    until expr match "${confirm}" '[yn]' > /dev/null
    do
      read -q confirm\?"Really remove ${PASSFILE:t}? "
      case "${confirm}" in
	y) break ;;
      esac
      echo
    done
    if [ "${confirm}" = 'y' ]
    then
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

  elif (( STATUS == 1 ))
  then

    (
      cd -q ${dir}
      ${GIT} status
    )

  else

    # simply dump the contents of the file, and (optionally)
    # search the output for the string in ARGV[1]
    REGEX=${2}
    until [ "${PASSFILE:t}" -a -f "${dir}/${PASSFILE:t}" ]
    do
      tries=( $( ${LS} -1 ${dir}/*${PASSFILE:t}* ) )
      if (( ${#tries} > 0 ))
      then
	for PASSFILE in ${tries}
	do
	  read -q confirm\?"Do you mean ${PASSFILE:t}? "
	  case "${confirm}" in
	      y) break 2
	    ;;
	  esac
	  echo
	done
      fi

      read PASSFILE\?"No matches. Try another password file name: "
    done

    if [ -n "${REGEX}" ]
    then
      ${GPG} --quiet ${USEAGENT} < ${dir}/${PASSFILE:t} 2>/dev/null | ${PCREGREP} -i "${REGEX}"
    else
      ${GPG} --quiet ${USEAGENT} < ${dir}/${PASSFILE:t} 2>/dev/null
    fi

  fi

  # clean up
  for C in ${commands}
  do
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
