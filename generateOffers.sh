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

for d in */ ; do
    folderName=$(basename $d)
    if [[ $folderName == $OFFER_PATH_PATTERN ]]; then
        msg "${YELLOW}matched folder name: $folderName. ${NOFORMAT}"
        if [[ $folderName == "eap74-rhel8-payg-multivm" ]]; then
          mvn -Pbicep -Passembly clean install -Ptemplate-validation-tests -f $folderName/pom.xml
        else
          mvn -Ptemplate-validation-tests clean install -f $folderName/pom.xml
        fi
    fi
done
