#!/usr/bin/env bash

eap73FolderPattern="eap73*"

setup_colors() {
  NOFORMAT='\033[0m' RED='\033[0;31m' GREEN='\033[0;32m' ORANGE='\033[0;33m' BLUE='\033[0;34m' PURPLE='\033[0;35m' CYAN='\033[0;36m' YELLOW='\033[1;33m'
}

msg() {
  echo >&2 -e "${1-}"
}

setup_colors

for d in */ ; do
    folderName=$(basename $d)
    if [[ $folderName == $eap73FolderPattern ]]; then
        msg "${YELLOW}matched folder name: $folderName. ${NOFORMAT}"
        mvn -Ptemplate-validation-tests clean install -f $folderName/pom.xml
    fi
done
