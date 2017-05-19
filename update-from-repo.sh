#!/usr/bin/env bash
#############################################################################
# Update webmin/usermin to the latest develop version  from GitHub repo
# inspired by authentic-theme/theme-update.sh script, thanks qooob
#
# Version 1.0, 2017-05-19
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
      if [[ "$1" == *"-release"* ]]; then
        if [[ "$1" == *":"* ]] && [[ "$1" != *"latest"* ]]; then
          RRELEASE=${1##*:}
        else
          RRELEASE=`curl -s -L https://raw.githubusercontent.com/$REPO/master/version`
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
          mkdir ${TEMP}/tarballs
          ( cd ${TEMP}; perl makedist.pl ${version} ) 2>/dev/null

          #prepeare unattended upgrade
          config_dir=/etc/${PROD}
          atboot="NO"
          makeboot="NO"
          nouninstall="YES"
          nostart="YES"
          export config_dir atboot nouninstall makeboot nostart
          ${TEMP}/tarballs/${PROD}-${version}/setup.sh ${DIR} | grep -v -e "^$" -e "done$"

        else
          ################
          # LANG only update
          IGNORE="authentic-theme"
          echo -e "${GREEN}start updating LANG files for${NC} ${RPOD} ... ${LGREY}.=dir s=symlink S=dir symlink${NC}"

          # list all lang singe-files, lang dirs and linked modules here
          for FILE in `ls -d lang */lang ulang */ulang */config.info.* */module.info filemin 2>/dev/null`
          do
            MODUL=`dirname $FILE`; SKIP=`echo $MODUL | sed "s/$IGNORE/SKIP/"`
            if [ "$SKIP" == "SKIP" ]; then
                 echo -e "${LGREY}skipping $MODUL ...${NC}"
            else
                # real files and dirs
                [ -f "${TEMP}/${FILE}" ] && [ -f "$DIR/$FILE" ] && cp "${TEMP}/${FILE}" "$DIR/$FILE" && continue
                [ -d "${TEMP}/${FILE}" ] && [ -d "$DIR/$FILE" ] && cp -r "${TEMP}/${FILE}" "$DIR/$MODUL" && \
                         echo -n "." && continue
                # to webmin symlinked files and dirs
                if [ -h "${TEMP}/${FILE}" ]; then
                    # get real symlink source
                    SOURCE=`readlink .~files/$FILE | sed 's/.*web.*min\///'`
                    [ -f "$DIR/$FILE" ] && cp "${WTEMP}/"$DIR/$FILE"${FILE}" "$DIR/$SOURCE" && echo -n "s" && continue
                    [ -d "$DIR/$FILE" ] && cp -r "${WTEMP}/$SOURCE" "$DIR/$MODUL" && echo  -n "S"
                fi
            fi
          done
          # write version to file
          echo "${version}-LANG" > version
        fi

        echo -e "\n${GREEN}Updating ${PROD^} to Version `cat version`, done.${NC}"

        # update authentic, put dummy clear in PATH
	echo -e "#!/bin/sh\necho" > ${TEMP}/clear; chmod +x ${TEMP}/clear
        export PATH="${TEMP}:${PATH}"
        [[ -x authentic-theme/theme-update.sh ]] && authentic-theme/theme-update.sh

      else
        # something went wrong
        echo -e "${RED}${ERROR}Updating files, failed.${NC}"
      fi
      ###########
      # we are at the end
      # remove temporary files
      rm -rf .~files
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
