# Check env

# ANSI color codes
GREEN='\033[0;32m'
NC='\033[0m' # No Color

## Check if the required tools are installed and logged in
echo -e "${GREEN}To run this script, you need to have the following tools installed:${NC}"
echo -e "${GREEN}1. yq${NC}"
echo -e "${GREEN}2. Github cli (gh)${NC}"
echo -e "${GREEN}3. Azure CLI (az)${NC}"
echo -e "${GREEN}And you need to be logged in to GitHub CLI (gh), and Azure CLI (az).${NC}"

echo "Checking if the required tools are installed..."
echo "Checking progress started..."

if ! command -v yq &> /dev/null; then
    echo "Env Check Failed."
    echo "yq is not installed. Please install it to proceed."
    exit 1
fi
echo "1/5...jq is installed."

# Check gh installed
if ! command -v gh &> /dev/null; then
    echo "Env Check Failed."
    echo "GitHub CLI (gh) is not installed. Please install it to proceed."
    exit 1
fi
echo "2/5...GitHub CLI (gh) is installed."


# Check if the GitHub CLI (gh) is logged in
if ! gh auth status &> /dev/null; then
    echo "Env Check Failed."
    echo "You are not logged in to GitHub CLI (gh). Please log in to proceed."
    exit 1
fi
echo "3/5...You are logged in to GitHub CLI (gh)."

# check if az is installed
if ! command -v az &> /dev/null; then
    echo "Env Check Failed."
    echo "Azure CLI (az) is not installed. Please install it to proceed."
    exit 1
fi
echo "4/5...Azure CLI (az) is installed."


# check if az is logged in
if ! az account show &> /dev/null; then
    echo "Env Check Failed."
    echo "You are not logged in to Azure CLI (az). Please log in to proceed."
    exit 1
fi
echo "5/5...You are logged in to Azure CLI (az)."

echo "Checking progress completed..."

## Set environment variables
export param_file="../resource/credentials-params.yaml"