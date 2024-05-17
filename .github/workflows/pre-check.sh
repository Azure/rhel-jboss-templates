# Check env

## Check if the required tools are installed
echo "Checking if the required tools are installed..."
echo "Checking progress started..."

if ! command -v jq &> /dev/null; then
    echo "Env Check Failed."
    echo "jq is not installed. Please install it to proceed."
    exit 1
fi
echo "1/3...jq is installed."

# Check gh installed
if ! command -v gh &> /dev/null; then
    echo "Env Check Failed."
    echo "GitHub CLI (gh) is not installed. Please install it to proceed."
    exit 1
fi
echo "2/3...GitHub CLI (gh) is installed."


# Check if the GitHub CLI (gh) is logged in
if ! gh auth status &> /dev/null; then
    echo "Env Check Failed."
    echo "You are not logged in to GitHub CLI (gh). Please log in to proceed."
    exit 1
fi
echo "3/3...You are logged in to GitHub CLI (gh)."

echo "Checking progress completed..."

## Set environment variables
export param_file="credentials-params.json"