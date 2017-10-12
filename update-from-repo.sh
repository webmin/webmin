#!/usr/bin/env bash
#############################################################################
# Update webmin/usermin to the latest develop version  from GitHub repo
# inspired by authentic-theme/theme-update.sh script, thanks qooob
#
# Version 1.1, 2017-07-27
# Kay Marquardt, kay@rrr.de, https://github.com/gandelwartz
#############################################################################

# Get webmin/usermin dir based on script's location
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROD=${DIR##*/} # => usermin or webmin
# where to get source
HOST="https://github.com"
REPO="webmin/$PROD"
ASK="YES"

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
NC='\e[0m'


# help requested output usage
if [[ "$1" == "-h" || "$1" == "--help" ]] ; then
    echo -e "${NC}${ORANGE}${PROD^}${NC} update script"
    echo "Usage:  ./`basename $0` { [-lang] } { [-repo:yourname/xxxmin] } { [-release] | [-release:number] }"
    exit 0
fi

# dont ask -y given
if [[ "$1" == "-y" || "$1" == "-yes" ]] ; then
        ASK="NO"
        shift
fi

# update onyl lang files
if [[ "$1" == "-l" || "$1" == "-lang" ]] ; then
        LANG="YES"
        shift
fi

################
# lets start
# Clear screen for better readability
[[ "${ASK}" == "YES" ]] && clear

# alternative repo given
if [[ "$1" == *"-repo"* ]]; then
        if [[ "$1" == *":"* ]] ; then
          REPO=${1##*:}
          [[ "${REPO##*/}" != ${PROD} ]] && echo -e "${ORANGE}./`basename $0`:${NC} ${REPO} does not end with /${PROD}" && exit 0
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
    if type git >/dev/null 2>&1
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
        echo -e "${BLUE}Pulling in latest release of${NC} ${GREY}${PROD^}${NC} $RRELEASE ($HOST/$REPO)..."
        RS="$(git clone --depth 1 --branch $RRELEASE -q $HOST/$REPO.git "${TEMP}" 2>&1)"
        if [[ "$RS" == *"ould not find remote branch"* ]]; then
          ERROR="Release ${RRELEASE} doesn't exist. "
        fi
      else
        echo -e "${BLUE}Pulling in latest changes for${NC} ${GREY}${PROD^}${NC} $RRELEASE ($HOST/$REPO) ..."
        git clone --depth 1 --quiet  $HOST/$REPO.git "${TEMP}"
      fi
      # on usermin!! pull also webmin to resolve symlinks later!
      WEBMREPO=`echo ${REPO} | sed "s/\/usermin$/\/webmin/"`
      if [[ "${REPO}" != "${WEBMREPO}" ]]; then
        echo -e "${BLUE}Pulling in latest changes for${NC} ${GREY}Webmin${NC} ($HOST/$WEBMREPO) ..."
        git clone --depth 1 --quiet  $HOST/$WEBMREPO.git "${WTEMP}"
      fi

      # Check for possible errors
      if [ $? -eq 0 ] && [ -f "${TEMP}/version" ]; then

        ####################
        # start processing pulled source
        version="`head -c -1 ${TEMP}/version`.`cd ${TEMP}; git log -1 --format=%cd --date=format:'%m%d.%H%M'`" 
        if [[ "${LANG}" != "YES" ]]; then
          ###############
          # FULL update
          echo -e "${GREEN}start FULL update for${NC} $PROD ..."
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
          [[ ! -f "${TEMP}/tarballs/${PROD}-${version}/setup.sh" ]] && \
                   cp  "${TEMP}/setup.sh" "${TEMP}/tarballs/${PROD}-${version}/setup.sh"
          config_dir=/etc/${PROD}
          atboot="NO"
          makeboot="NO"
          nouninstall="YES"
          #nostart="YES"
          export config_dir atboot nouninstall makeboot nostart
          ${TEMP}/tarballs/${PROD}-${version}/setup.sh ${DIR} | grep -v -e "^$" -e "done$"
        else

          ################
          # LANG only update
          IGNORE="authentic-theme"
          echo -e "${GREEN}start updating LANG files for${NC} ${RPOD} ..."

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
        # "compile" UTF-8 lang files
        echo -en "\n${GREEN}compile UTF-8 lang files${NC} ..."
        perl "${TEMP}/chinese-to-utf8.pl" . 2>&1 | while read line; do echo -n "."; done


        # write version to file
        [[ "${LANG}" != "YES" ]] || echo "${version}-LANG" > version
        

        echo -e "\n${GREEN}Updating ${PROD^} to Version `cat version`, done.${NC}"

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
      # we are at the end
      # remove temporary files
      rm -rf .~files .~lang
      # fix permissions, should be done by makedist.pl?
      chmod -R -x+X ${DIR}
      find ${DIR} \( -iname "*.pl" -o -iname "*.cgi" -o -iname "*.pm" -o -iname "*.sh" \) -a ! -iname "config*info" | \
              xargs chmod +x 
    else
      echo -e "${RED}Error: Command \`git\` is not installed or not in the \`PATH\`.${NC}";
    fi
else
    echo -e "${RED}Error: This command has to be run under the root user.${NC}"
fi
