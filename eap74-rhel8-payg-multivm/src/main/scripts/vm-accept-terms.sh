set -Eeuo pipefail

az vm image terms accept --urn $URN:latest
