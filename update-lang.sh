#!/usr/bin/env bash

############################################################################
# Update webmin/usermin to the latest lang and info files from GitHub repo #
# idea stolen from authentic-theme theme-update script                     #
############################################################################

# Get webmin/usermin dir based on script's location
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROD=${DIR##*/}
CURRENT=$PWD
HOST="https://github.com"
REPO="webmin/$PROD"
ASK="YES"

# help requested output usage
if [[ "$1" == "-h" || "$1" == "--help" ]] ; then
    echo -e "\e[0m\e[49;0;33;82m ${PROD^} \e[0m update script"
    echo "Usage:  ./`basename $0` { [-repo:yourname/xxxmin] [-beta] | [-release] | [-release:number] }"
    exit 0
fi

# dont ask -y given
if [[ "$1" == "-y" || "$1" == "--yes" ]] ; then
        ASK="NO"
        shift
fi

# if we are on usermin, webmin must be also installed
if [[ "$PROD" == "usermin" && ! -d "$DIR/../webmin" ]]; then
        echo -e "\e[49;0;31;82mWebmin has to be installed to update ${PROD^}\e[0m"
        exit 0
fi

# Clear the screen for better readability
[[ "${ASK}" == "YES" ]] && clear


# alternative repo given
if [[ "$1" == *"-repo"* ]]; then
        if [[ "$1" == *":"* ]] ; then
          REPO=${1##*:}
          [[ "${ASK}" == "YES" ]] && echo -e "\e[49;0;31;82mWarning: using alternate repository <$HOST/$REPO> may break your installation!\e[0m"
          shift
        else
          echo "./`basename $0`: found -repo without parameter"
          exit 0
        fi
fi


# Ask user to confirm update operation
REPLY="y"
[ "${ASK}" == "YES" ] && read -p "Would you like to update files for "${PROD^}" from ${HOST}/${REPO} [y/N] " -n 1 -r && echo

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
   echo -e "\e[49;1;35;82mOperation aborted.\e[0m"

else
  # OK lets update!
  # Require privileged user to run the script
  if [[ $EUID -ne 0 ]]; then
    echo -e "\e[49;0;31;82mError: This command has to be run under the root user.\e[0m"
  else

    # Require `git` command availability
    if type git >/dev/null 2>&1
    then
      # on usermin, update webmin module lang FIRST!
      WEBMREPO=`echo ${REPO} | sed "s/\/usermin$/\/webmin/"`
      if [[ "${REPO}" != "${WEBMREPO}" ]]; then
          echo -e "\e[49;1;34;182mPulling Webmin files first\e[0m"
          ( cd ../webmin; $0 --yes -repo:$WEBMREPO $*)
      fi
      # remove old temporary files
      rm -rf "$DIR/.~files" "$DIR/.git"
      # Pull latest changes
      if [[ "$1" == *"-release"* ]]; then
        if [[ "$1" == *":"* ]] && [[ "$1" != *"latest"* ]]; then
          RRELEASE=${1##*:}
        else
          RRELEASE=`curl -s -L https://raw.githubusercontent.com/$REPO/master/version.txt`
        fi
        echo -e "\e[49;1;34;182mPulling in latest release of\e[0m \e[49;1;37;182m ${PROD^}\e[0m $RRELEASE ($HOST/$REPO)..."
        RS="$(git clone --depth 1 --branch $RRELEASE -q $HOST/$REPO.git "$DIR/.~file" 2>&1)"
        if [[ "$RS" == *"ould not find remote branch"* ]]; then
          ERROR="Release ${RRELEASE} doesn't exist. "
        fi
      else
      echo -e "\e[49;1;34;182mPulling in latest changes for\e[0m \e[49;1;37;182m ${PROD^} files\e[0m $RRELEASE ($HOST/$REPO) ..."
        git clone --depth 1 --quiet  $HOST/$REPO.git "$DIR/.~files"
fi

      # Checking for possible errors
      if [ $? -eq 0 ] && [ -f "$DIR/.~files/version" ]; then

        # we got it! start updating
        IGNORE="authentic-theme"
        echo -e "\e[49;32;5;82mstart copying files ...\e[0m .=dir s=symlink S=dir symlink"

        # list all lang singe-files, lang dirs and linked modules here
        for FILE in `ls -d */lang */ulang */config.info.* */module.info filemin 2>/dev/null`
        do
            MODUL=`dirname $FILE`; SKIP=`echo $MODUL | sed "s/$IGNORE/SKIP/"`
            if [ "$SKIP" == "SKIP" ]; then
                 echo -e "\e[49;3;37;182mskipping $MODUL ...\e[0m"
            else
                # real files and dirs
                [ -f .~files/$FILE ] && [ -f $DIR/$FILE ] && cp .~files/$FILE $DIR/$FILE && continue
                [ -d .~files/$FILE ] && [ -d $DIR/$FILE ] && cp -r .~files/$FILE $DIR/$MODUL && \
                         echo -n "." && continue
                # to webmin symlinked files and dirs
                if [ -h .~files/$FILE ]; then
                    # get real symlink source
                    SOURCE=`readlink .~files/$FILE | sed 's/.*web.*min\///'`
                    [ -f $DIR/$FILE ] && cp $DIR/../webmin/$FILE $DIR/$SOURCE && echo -n "s" && continue
                    [ -d $DIR/$FILE ] && cp -r $DIR/../webmin/$SOURCE $DIR/$MODUL && echo  -n "S"
                fi
            fi
        done


        echo -e "\n\e[49;32;5;82mUpdating to lastest files from `cd .~files;git log -1 --format=%cd`, done.\e[0m"

        # Restart Webmin/Usermin in case it's running
        if [[ "${ASK}" == "YES" ]] && [ "$2" != "-no-restart" ]; then
          if ps aux | grep -v grep | grep $PROD/miniserv.pl > /dev/null
          then
            echo -e "\e[49;3;37;182mRestarting "${PROD^}"..\e[0m"
            service $PROD restart >/dev/null 2>&1
          fi
        fi
      else
        # Post fail commands
        echo -e "\e[49;0;31;82m${ERROR}Updating files, failed.\e[0m"
      fi

      # remove temporary files
      rm -rf "$DIR/.~files" "$DIR/.git"
    else
      echo -e "\e[49;0;33;82mError: Command \`git\` is not installed or not in the \`PATH\`.\e[0m";
    fi

  fi

fi
