#!/usr/bin/env bash

set -e

OFFER_PATH_PATTERN="eap7*"
CURR_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
BASE_DIR="$(readlink -f ${CURR_DIR})"

setup_colors() {
  NOFORMAT='\033[0m' RED='\033[0;31m' GREEN='\033[0;32m' ORANGE='\033[0;33m' BLUE='\033[0;34m' PURPLE='\033[0;35m' CYAN='\033[0;36m' YELLOW='\033[1;33m'
}

msg() {
  echo >&2 -e "${1-}"
}

setup_colors

rc=0
failureIndicator='\[-\]'
for d in */ ; do
    folderName=$(basename $d)
    if [[ $folderName == $OFFER_PATH_PATTERN ]]; then
        msg "${YELLOW}matched folder name: $folderName. Full path is: ${BASE_DIR}/${folderName}/src/main/arm ${NOFORMAT}"
        ./../arm-ttk/arm-ttk/Test-AzTemplate.sh -TemplatePath ${BASE_DIR}/${folderName}/src/main/arm | tee testOutput
        set +e ; grep -q ${failureIndicator} testOutput;
        if [ $? -eq 0 ]; then
            msg "${RED}FAILURE in ${BASE_DIR}/${folderName}"
            rc=1
        fi
        rm testOutput
        set -e
    fi
done

if [ ${rc} -eq 1 ]; then
    exit 1
else
    exit 0
fi
