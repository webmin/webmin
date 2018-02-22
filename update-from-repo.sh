#!/usr/bin/env bash
#############################################################################
# Update webmin/usermin to the latest develop version  from GitHub repo
# inspired by authentic-theme/theme-update.sh script, thanks qooob
#
VERS="1.5.4, 2018-02-22"
#
# Kay Marquardt, kay@rrr.de, https://github.com/gandelwartz
#############################################################################
IAM=`basename $0`

# don't ask -y given
ASK="YES"
if [[ "$1" == "-y" || "$1" == "-yes"  || "$1" == "-f" || "$1" == "-force" ]] ; then
        ASK="NO"
        shift
fi

if [[ "$1" == "-nc" ]] ; then
    NCOLOR="YES"
    shift
fi

# predefined colors for echo -e on terminal
if [[ -t 1 && "${NCOLOR}" != "YES" ]] ;  then
    RED='\e[49;0;31;82m'
    BLUE='\e[49;1;34;182m'
    GREEN='\e[49;32;5;82m'
    ORANGE='\e[49;0;33;82m'
    PURPLE='\e[49;1;35;82m'
    LGREY='\e[49;1;37;182m'
    GREY='\e[1;30m'
    CYAN='\e[36m'
    NC='\e[0m'
fi

# Clear screen for better readability
[[ "${ASK}" == "YES" ]] && clear

# Get webmin/usermin dir based on script's location
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROD="webmin" # default
if [[ -r "${DIR}/usermin-init" &&  -r "${DIR}/uconfig.cgi" ]] ; then
    echo -e "${ORANGE}Usermin detected ...${NC}"
    PROD="usermin"
fi
# where to get source
HOST="https://github.com"
REPO="webmin/$PROD"
GIT="git"
BRANCH=""

# temporary locations for git clone
WTEMP="${DIR}/.~files/webadmin" 
UTEMP="${DIR}/.~files/useradmin" 
TEMP=$WTEMP
[[ "$PROD" == "usermin" ]] && TEMP=$UTEMP
LTEMP="${DIR}/.~lang"


# help requested output usage
if [[ "$1" == "-h" || "$1" == "--help" ]] ; then
    echo -e "${NC}${ORANGE}This is the unofficial webmin update script, ${VERS}${NC}"
    echo "Usage:  ${IAM} [-force] [-repo:username/xxxmin] [-branch:xxx] [-release[:number]] [-file file ...]"
    [[ "$1" == "--help" ]] && cat <<EOF

Parameters:
    -force (-yes)
        unattended install, do not ask
    -nc or STDOUT is a pipe (|)
        do not output colors
    -repo
        pull from alternative github repo, format: -repo:username/reponame
        reponame must be "webmin" or "usermin"
        default github repo: webmin/webmin
    -branch
        pull given branch from repository
    -release
        pull a released version, default: -release:latest
    -file
        pull only the given file(s) or dir(s) from repo

Examples:
    ${IAM}
    	uodate everthing from default webmin repository
    ${IAM} -force or ${IAM} -yes
    	same but without asking,
    ${IAM} -force -repo:qooob/webmin
    	updadte from qooobs repository without asking
    ${IAM} -file module/module.info
    	pull module.info for given module
    ${IAM} -file cpan
    	pull everything in cpan
    ${IAM} -file cpan/*
    	pull only already existing files / dirs in cpan
    ${IAM} -file module/lang
    	pull all lang files of a module
    ${IAM} -fore -repo:qooob/webmin -file */lang
    	pull lang files for all existing */lang from qooobs
    	repository without asking

Exit codes:
    0 - success
    1 - abort on error or user request, nothing changed
    2 - not run as root
    3 - git not found
    4 - stage 1: git clone failed
    5 - stage 2: makedist failed
    6 - stage 3: update with setup.sh failed, installation may in bad state!

EOF
    exit 0
fi

# check for required webmin / usermin files in current dir
if [[ ! -r "${DIR}/setup.sh" || ! -r "${DIR}/miniserv.pl" ]] ; then
    echo -e "${NC}${RED}Error: the current dir does not contain a webmin installation, aborting ...${NC}"
    exit 1
fi

# need to be root 
if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}Error: This command has to be run under the root user.${NC}"
    exit 2
fi

# search for config location
echo -en "${CYAN}Search for ${RPOD^} configuration ... ${NC}"
for conf in /etc/${PROD} /var/packages/${PROD}/target/etc
do
    if [[ -r "${conf}/miniserv.conf" ]] ; then
        MINICONF="${conf}/miniserv.conf"
        echo  -e "${ORANGE}found: ${MINICONF}${NC}"
        break
    fi
done

# check for other locations if not in default
if [[ "${MINICONF}" == "" ]] ; then
    MINICONF=`find /* -maxdepth 6 -name miniserv.conf 2>/dev/null | grep ${PROD} | head -n 1`
    echo  -e "${ORANGE}found: ${MINICONF}${NC} (alternative location)"
fi

# add PATH from config to system PATH
if [[ "${MINICONF}" != "" ]] ; then
    export PATH="${PATH}:`grep path= ${MINICONF} | sed 's/^path=//'`"
fi

# check if git is availible
if type ${GIT} >/dev/null 2>&1 ; then
    true
else
    echo -e "${RED}Error: Command \`git\` is not installed or not in the \`PATH\`.${NC}"
    exit 3
fi


################
# lets start

# alternative repo given
if [[ "$1" == *"-repo"* ]]; then
        if [[ "$1" == *":"* ]] ; then
          REPO=${1##*:}
          [[ "${REPO##*/}" != "webmin" && "${REPO##*/}" != "usermin" ]] && echo -e "${RED}Error: ${REPO} is not a valid repo name!${NC}" && exit 1
          shift
        else
          echo -e "${ORANGE}./`basename $0`:${NC} Missing argument for parameter -repo. aborting ..."
          exit 1
        fi
fi

# alternative branch given
if [[ "$1" == *"-branch"* ]]; then
        if [[ "$1" == *":"* ]] ; then
          BRANCH=" --branch ${1##*:}"
          shift
        else
          echo -e "${ORANGE}./`basename $0`:${NC} Missing argument for parameter -branch aborting ..."
          exit 1
        fi
fi

# warn about possible side effects because webmins makedist.pl try cd to /usr/local/webmin (and more)
[[ -d "/usr/local/webadmin" ]] && echo -e "${ORANGE}Warning: Develop dir /usr/local/webadmin exist, update may fail!${NC}"

################
# really update?
REPLY="y"

if [ "${ASK}" == "YES" ] ; then
    if [[ "$1" != "-release"* ]] ; then
        echo -e "${RED}Warning:${NC} ${ORANGE}update from non release repository${NC} ${HOST}/${REPO}${BRANCH} ${ORANGE}may break your installation!${NC}"
    fi
    read -p "Would you like to update "${PROD^}" from ${HOST}/${REPO}${BRANCH} [y/N] " -n 1 -r
    echo
fi

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
   # something different the y entered
   echo -e "${PURPLE}Operation aborted.${NC}"
   exit 1
fi

################
# here we go

  # remove temporary files from failed run
  rm -rf .~files
  # pull source from github
  if [[ "$1" == *"-release"* ]]; then
        if [[ "$1" == *":"* ]] && [[ "$1" != *"latest"* ]]; then
          RRELEASE=${1##*:}
        else
          RRELEASE=`curl -s -L https://github.com/${REPO}/blob/master/version  | sed -n '/id="LC1"/s/.*">\([^<]*\).*/\1/p'`
        fi
        shift
        echo -e "${CYAN}Pulling in latest release of${NC} ${ORANGE}${PROD^}${NC} $RRELEASE ($HOST/$REPO)..."
        RS="$(${GIT} clone --depth 1 --branch $RRELEASE -q $HOST/$REPO.git "${TEMP}" 2>&1)"
        if [[ "$RS" == *"ould not find remote branch"* ]]; then
          ERROR="Release ${RRELEASE} doesn't exist. "
        fi
  else
        echo -e "${CYAN}Pulling in latest changes for${NC} ${ORANGE}${PROD^}${NC} $RRELEASE (${HOST}/${REPO}${BRANCH}) ..."
        ${GIT} clone --depth 1 --quiet  ${BRANCH} $HOST/$REPO.git "${TEMP}"
  fi
  # on usermin!! pull also webmin to resolve symlinks later!
  WEBMREPO=`echo ${REPO} | sed "s/\/usermin$/\/webmin/"`
  if [[ "${REPO}" != "${WEBMREPO}" ]]; then
        echo -e "${CYAN}Pulling in latest changes for${NC} ${ORANGE}Webmin${NC} ($HOST/$WEBMREPO) ..."
        ${GIT} clone --depth 1 --quiet  $HOST/$WEBMREPO.git "${WTEMP}"
  fi

  # Check for possible errors
  if [ $? -eq 0 ] && [ -f "${TEMP}/version" ]; then

    ####################
    # start processing pulled source
	# add latest changeset date to original version, works with git 1.7+
    version="`head -c -1 ${TEMP}/version``cd ${TEMP}; date -d @$(${GIT} log -n1 --format='%at') '+%m%d%H%M'`" 
    DOTVER=`echo ${version} | sed 's/-/./'`
    TARBALL="${TEMP}/tarballs/${PROD}-${DOTVER}"
    ###############
    # start update
    echo -en "${CYAN}Start update for${NC} ${PROD^} ${version}..."
    # create missing dirs, simulate authentic present
    mkdir ${TEMP}/tarballs ${TEMP}/authentic-theme 
    cp authentic-theme/LICENSE ${TEMP}/authentic-theme
    # put dummy clear and tar in PATH
    echo -e "#!/bin/sh\necho" > ${TEMP}/clear; chmod +x ${TEMP}/clear
    echo -e "#!/bin/sh\necho" > ${TEMP}/tar; chmod +x ${TEMP}/tar
    export PATH="${TEMP}:${PATH}"
    # run makedist.pl
    ( cd ${TEMP}; perl makedist.pl ${DOTVER} 2>&1) | while read input; do echo -n "."; done
    echo -e "\n"
    if [[ ! -f "${TARBALL}.tar.gz" ]] ; then
        echo -e "${RED}Error: makedist.pl failed! ${NC}aborting ..."
        rm -rf .~files
        exit 5
    fi
    rm -rf ${TEMP}/tar

    # check for additional standard modules not in default dist
    for module in `ls */module.info`
    do 
        if [[ -f ${TEMP}/${module} && ! -f  "${TARBALL}/$module" ]]; then
          module=`dirname $module`
          echo -e "${CYAN}Adding nonstandard${NC} ${ORANGE}$module${NC} to ${PROD^}" && cp -r -L ${TEMP}/${module} ${TARBALL}/
        fi
    done

    # insert perl path
    config_dir=`grep env_WEBMIN_CONFIG= ${MINICONF}| sed 's/.*_WEBMIN_CONFIG=//'`
    perl=`cat $config_dir/perl-path`
    echo  -e "${CYAN}Insert perl path${NC} ${perl} ..."
    ( cd ${TARBALL}; sed -i --follow-symlinks "1 s|#\!/.*$|#!${perl}|" `find . -name '*.cgi' ; find . -name '*.pl'` )

	####
	# copy all or only given files ...
    if [[ "$1" != "-file" ]] ; then
        # prepeare unattended upgrade
        echo "${version}" >"${TARBALL}/version"
        cp "${WTEMP}/chinese-to-utf8.pl" .
        atboot="NO"
        makeboot="NO"
        nouninstall="YES"
        [[ -x "${perl}" ]] && noperlpath="YES"
        #nostart="YES"
        export config_dir atboot nouninstall makeboot nostart noperlpath
        ( cd ${TARBALL}; ./setup.sh ${DIR} ) | grep -v -e "^$" -e "done$" -e "chmod" -e "chgrp" -e "chown"
        if [[ "${TARBALL}/version" -nt "${MINICONF}" ]] ; then
            echo -e "${RED}Error: update failed, ${PROD} may in a bad state! ${NC}aborting ..."
            rm -rf .~files
            exit 6
        fi

        #############
        # postprocessing

        # "compile" UTF-8 lang files
        echo -en "\n${CYAN}Compile UTF-8 lang files${NC} ..."
        if [[ `which iconv 2> /dev/null` != '' ]] ; then
            perl "${TEMP}/chinese-to-utf8.pl" . 2>&1 | while read input; do echo -n "."; done
        else
            echo -e "${BLUE} iconv not found, skipping lang files!${NC}"
        fi

        # check if alternatve repo exist
        AUTHREPO=`echo ${REPO} | sed "s/\/.*min$/\/autehtic-theme/"`
        if [[ "${REPO}" != "${AUTHREPO}" ]]; then
             exist=`curl -s -L ${HOST}/${AUTHREPO}`
             [[ "${#exist}" -lt 20 ]] && RREPO="${AUTHREPO}"
        fi
        # run authenric-thme update, possible unattended
        if [[ -x authentic-theme/theme-update.sh ]] ; then
            if [[ "${ASK}" == "YES" ]] ; then
                authentic-theme/theme-update.sh ${RREPO}
            else
                yes | authentic-theme/theme-update.sh ${RREPO}
            fi
        fi
    else
        # pull specifed files only
        shift
        FILES="$*"
        for file in ${FILES}
        do
            if [[ -d "${TEMP}/tarballs/webmin-${DOTVER}/${file}" ]] ; then
                echo -e "${BLUE}Copy dir ${ORANGE}${file}${NC} from ${ORANGE}${REPO}${NC} to ${PROD^} ..."
                dest=${file%%/*}
                [[ "${dest}" == "${file}" ]] && dest="."
                cp -r -v "${TEMP}/tarballs/webmin-${DOTVER}/${file}" "${dest}" | sed 's/^.*\/tarballs\///'
            else
                echo -e "${CYAN}Copy file ${ORANGE}${file}${NC} from ${ORANGE}${REPO}${NC} to ${PROD^} ..."
                mv "${file}" "${file}.bak"
                cp "${TEMP}/tarballs/webmin-${DOTVER}/${file}" "${file}"
                rm -rf "${file}.bak"
            fi
        done
    fi
  else
        # something went wrong
        echo -e "${RED}${ERROR} Error: update failed:${NC}${ORANGE} ${GIT} clone ${BRANCH} $RRELEASE $HOST/$REPO.git ${NC}"
        exit 4
  fi

  ###########
  # we are at the end, clean up

  # remove temporary files
  echo -e "\n${CYAN}Clean up temporary files ...${NC}"
  rm -rf .~files 
  # fix permissions, should be done by makedist.pl?
  echo -e "${CYAN}Make scripts executable ...${NC}"
  chmod -R -x+X ${DIR}
  chmod +x *.pl *.cgi *.pm *.sh */*.pl */*.cgi */*.pm */*.sh
      
  # thats all folks
  echo -e "\n${CYAN}Updating ${PROD^} ${ORANGE}${FILES}${NC} to Version `cat version`, done.${NC}"

# update success
exit 0
