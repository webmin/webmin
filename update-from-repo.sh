#!/usr/bin/env bash
#############################################################################
# Update webmin/usermin to the latest develop version  from GitHub repo
# inspired by authentic-theme/theme-update.sh script, thanks qooob
#
# Version 1.3, 2017-12-27
# Kay Marquardt, kay@rrr.de, https://github.com/gandelwartz
#############################################################################

# Get webmin/usermin dir based on script's location
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROD=${DIR##*/} # => usermin or webmin
# where to get source
HOST="https://github.com"
REPO="webmin/$PROD"
ASK="YES"
GIT="git"

# temporary locations for git clone
WTEMP="${DIR}/.~files/webadmin" 
UTEMP="${DIR}/.~files/useradmin" 
TEMP=$WTEMP
[[ "$PROD" == "usermin" ]] && TEMP=$UTEMP
LTEMP="${DIR}/.~lang"

# predefined colors for echo -e
RED='\e[49;0;31;82m'
BLUE='\e[49;1;34;182m'
GREEN='\e[49;32;5;82m'
ORANGE='\e[49;0;33;82m'
PURPLE='\e[49;1;35;82m'
LGREY='\e[49;1;37;182m'
GREY='\e[1;30m'
CYAN='\e[36m'
NC='\e[0m'


# help requested output usage
if [[ "$1" == "-h" || "$1" == "--help" ]] ; then
    echo -e "${NC}${ORANGE}${PROD^}${NC} update script"
    echo "Usage:  ./`basename $0` { [-lang] } { [-repo:yourname/xxxmin] } { [-release] | [-release:number] }"
    exit 0
fi

if [[ "${PROD}" != "webmin" && "${PROD}" != "usermin" ]] ; then
    echo -e "${NC}${RED}error: the current dir name hast to be webmin or usermin, no update possible!${NC}"
    echo -e "possible solution: ${ORANGE}ln -s ${PROD} ../webmini; cd ../webmin${NC} or ${ORANGE}ln -s ${PROD} ../usermin; cd ../webmin ${NC}"
    exit 0
fi

# don't ask -y given
if [[ "$1" == "-y" || "$1" == "-yes" ]] ; then
        ASK="NO"
        shift
fi

# update only lang files
if [[ "$1" == "-l" || "$1" == "-lang" ]] ; then
        LANG="YES"
        shift
fi

################
# lets start
# Clear screen for better readability
[[ "${ASK}" == "YES" ]] && clear

# use path from miniser.conf
echo -en "${CYAN}search minserv.conf ... ${NC}"
if [[ -f "/etc/webmin/miniserv.conf" ]] ; then
	# default location
    MINICONF="/etc/webmin/miniserv.conf"
else
    # possible other locations
    MINICONF=`find /* -maxdepth 6 -name miniserv.conf 2>/dev/null | grep ${PROD} | head -n 1`
    echo  -e "${ORANGE}found: ${MINICONF}${NC} (alternative location)"
fi
[[ "${MINICONF}" != "" ]] && export PATH="${PATH}:`grep path= ${MINICONF}| sed 's/^path=//'`"

# alternative repo given
if [[ "$1" == *"-repo"* ]]; then
        if [[ "$1" == *":"* ]] ; then
          REPO=${1##*:}
          [[ "${REPO##*/}" != "webmin" && "${REPO##*/}" != "usermin" ]] && echo -e "${RED}error: ${ORANGE} ${REPO} is not a valid repo name!${NC}" && exit 0
          [[ "${ASK}" == "YES" ]] && echo -e "${RED}Warning:${NC} ${ORANGE}using alternate repository${NC} $HOST/$REPO ${ORANGE}may break your installation!${NC}"
          shift
        else
          echo -e "${ORANGE}./`basename $0`:${NC} found -repo without parameter"
          exit 0
        fi
fi

# warn about possible side effects because webmins makedist.pl try cd to /usr/local/webmin (and more)
[[ -d "/usr/local/webadmin" ]] && echo -e "${RED}Warning:${NC} /usr/local/webadmin ${ORANGE}exist, update may fail!${NC}"

################
# really update?
REPLY="y"
[ "${ASK}" == "YES" ] && read -p "Would you like to update "${PROD^}" from ${HOST}/${REPO} [y/N] " -n 1 -r && echo

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
   # something different the y entered
   echo -e "${PURPLE}Operation aborted.${NC}"
   exit
fi

################
# here we go
# need to be root and git installed
if [[ $EUID -eq 0 ]]; then
    if type ${GIT} >/dev/null 2>&1
    then

      #################
      # pull source from github
      # remove temporary files from failed run
      rm -rf .~files
      if [[ "$1" == *"-release"* ]]; then
        if [[ "$1" == *":"* ]] && [[ "$1" != *"latest"* ]]; then
          RRELEASE=${1##*:}
        else
          RRELEASE=`curl -s -L https://github.com/${REPO}/blob/master/version  | sed -n '/id="LC1"/s/.*">\([^<]*\).*/\1/p'`
        fi
        echo -e "${CYAN}Pulling in latest release of${NC} ${ORANGE}${PROD^}${NC} $RRELEASE ($HOST/$REPO)..."
        RS="$(${GIT} clone --depth 1 --branch $RRELEASE -q $HOST/$REPO.git "${TEMP}" 2>&1)"
        if [[ "$RS" == *"ould not find remote branch"* ]]; then
          ERROR="Release ${RRELEASE} doesn't exist. "
        fi
      else
        echo -e "${CYAN}Pulling in latest changes for${NC} ${ORANGE}${PROD^}${NC} $RRELEASE ($HOST/$REPO) ..."
        ${GIT} clone --depth 1 --quiet  $HOST/$REPO.git "${TEMP}"
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
        version="`head -c -1 ${TEMP}/version`-`cd ${TEMP}; ${GIT} log -1 --format=%cd --date=format:'%m%d.%H%M'`" 
        if [[ "${LANG}" != "YES" ]]; then
          ###############
          # FULL update
          echo -e "${CYAN}start FULL update for${NC} $PROD ..."
          # create dir,resolve links and some other processing
          mkdir ${TEMP}/tarballs 2>/dev/null
          ( cd ${TEMP}; perl makedist.pl ${version} ) 2>/dev/null

          # check for additional standard modules
          # fixed list better than guessing?
          for module in `ls */module.info`
          do 
            if [[ -f ${TEMP}/${module} && ! -f  "${TEMP}/tarballs/${PROD}-${version}/$module" ]]; then
              module=`dirname $module`
              echo "Adding module $module" && cp -r -L ${TEMP}/$module ${TEMP}/tarballs/${PROD}-${version}/
            fi
          done

          #prepeare unattended upgrade
		  cp "${TEMP}/maketemp.pl" "${TEMP}/tarballs/${PROD}-${version}"
          cp  "${TEMP}/setup.sh" "${TEMP}/tarballs/${PROD}-${version}"
          cp "${temp}/chinese-to-utf-8.pl" .
          echo  -en "${CYAN}search for config dir ... ${NC}"
          config_dir=`grep env_WEBMIN_CONFIG= ${MINICONF}| sed 's/.*_WEBMIN_CONFIG=//'`
          echo  -e "${ORANGE}found: ${config_dir}${NC}"
          atboot="NO"
          makeboot="NO"
          nouninstall="YES"
          #nostart="YES"
          export config_dir atboot nouninstall makeboot nostart
          ${TEMP}/tarballs/${PROD}-${version}/setup.sh ${DIR} | grep -v -e "^$" -e "done$" -e "chmod" -e "chgrp" -e "chown"
        else

          ################
          # LANG only update
          IGNORE="authentic-theme"
          echo -e "${CYAN}start updating LANG files for${NC} ${RPOD} ..."

          [ ! -d "${LTEMP}" ] && mkdir ${LTEMP}
          cp -L -r ${TEMP}/* "${LTEMP}"
          # list all lang singe-files, lang dirs and linked modules here
          FILES=`ls -d lang */lang ulang */ulang */config.info.* */module.info 2>/dev/null | sed '/UTF-8/d'`
          for FILE in $FILES
          do
            MODUL=`dirname $FILE`; SKIP=`echo $MODUL | sed "s/$IGNORE/SKIP/"`
            if [ "$SKIP" == "SKIP" ]; then
                 echo -e "${ORANGE}skipping $MODUL${NC}"
            else

                LANGFILES="${LANGFILES} ${FILE}"
                # output some dots
                [ -d "${TEMP}/${FILE}" ] && echo -n "." && continue
            fi
          done
          ( cd ${LTEMP}; tar -cf - ${LANGFILES} 2>/dev/null ) | tar -xf - 
        fi
        #############
        # postprocessing

        # "compile" UTF-8 lang files
        echo -en "\n${CYAN}compile UTF-8 lang files${NC} ..."
        if [[ `which iconv 2> /dev/null` != '' ]] ; then
            perl "${TEMP}/chinese-to-utf8.pl" . 2>&1 | while read input; do ((line++)); [ ${line} -eq 50 ] && { echo -n "." ; line=0;}; done
        else
            echo -e "${BLUE} iconv not found, skipping lang files!${NC}"
        fi

        # write version to file
        [[ "${LANG}" != "YES" ]] || echo "${version}-LANG" > version
        
        # update authentic, put dummy clear in PATH
        echo -e "#!/bin/sh\necho" > ${TEMP}/clear; chmod +x ${TEMP}/clear
        export PATH="${TEMP}:${PATH}"
        # check if alternatve repo exist
        AUTHREPO=`echo ${REPO} | sed "s/\/.*min$/\/autehtic-theme/"`
        if [[ "${REPO}" != "${AUTHREPO}" ]]; then
           exist=`curl -s -L ${HOST}/${AUTHREPO}`
           [[ "${#exist}" -lt 20 ]] && RREPO="${AUTHREPO}"
        fi
        [[ -x authentic-theme/theme-update.sh ]] && authentic-theme/theme-update.sh ${RREPO}

      else
        # something went wrong
        echo -e "${RED}${ERROR}Updating files, failed.${NC}"
      fi
      ###########
      # we are at the end, clean up

      # remove temporary files
      echo -e "\n${BLUE}clean up temporary files ...${NC}"
      rm -rf .~files .~lang
      # fix permissions, should be done by makedist.pl?
      echo -e "${CYAN}make scripts executable ...${NC}"
      chmod -R -x+X ${DIR}
      chmod +x *.pl *.cgi *.pm *.sh */*.pl */*.cgi */*.pm */*.sh
      
      # thats all folks
      echo -e "\n${CYAN}Updating ${PROD^} to Version `cat version`, done.${NC}"
    else
      echo -e "${RED}Error: Command \`git\` is not installed or not in the \`PATH\`.${NC}";
    fi
else
    echo -e "${RED}Error: This command has to be run under the root user.${NC}"
fi
