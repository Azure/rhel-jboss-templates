#!/usr/bin/env bash

set -e

OFFER_PATH_PATTERN="eap74*"

setup_colors() {
  NOFORMAT='\033[0m' RED='\033[0;31m' GREEN='\033[0;32m' ORANGE='\033[0;33m' BLUE='\033[0;34m' PURPLE='\033[0;35m' CYAN='\033[0;36m' YELLOW='\033[1;33m'
}

msg() {
  echo >&2 -e "${1-}"
}

setup_colors

if [ -z "$1" ]; then
    MVN_TARGETS="clean install"
else
    MVN_TARGETS="clean"
fi

for d in */ ; do
    folderName=$(basename $d)
    if [[ $folderName == $OFFER_PATH_PATTERN ]]; then
        msg "${YELLOW}matched folder name: $folderName. ${NOFORMAT}"
        mvn -Pbicep -Passembly -Ptemplate-validation-tests ${MVN_TARGETS} -f $folderName/pom.xml
    fi
done
