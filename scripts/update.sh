#!/bin/sh

# Function to print usage
print_usage() {
    echo "Usage: $0 [<version-tag> | --latest | --prerelease] [--pm <package-manager>]"
    echo
    echo "Options:"
    echo "  <version-tag>        Specify exact version to upgrade to"
    echo "  --latest            Upgrade to the latest stable release"
    echo "  --prerelease        Upgrade to the latest prerelease version"
    echo "  --pm <name>         Force specific package manager (npm, yarn, pnpm)"
    exit 1
}

# Function to fetch latest version from GitHub API
fetch_latest_version() {
    include_prerelease=$1
    api_url="https://api.github.com/repos/payloadcms/payload/releases"
    
    # Check if curl is installed
    if ! command -v curl > /dev/null 2>&1; then
        echo "Error: curl is required but not installed."
        echo "Please install curl first."
        exit 1
    fi
    
    if [ "$include_prerelease" = "true" ]; then
        # Include prereleases
        VERSION=$(curl -s "$api_url" | jq -r '.[0].tag_name')
    else
        # Get latest stable release
        VERSION=$(curl -s "$api_url" | jq -r '.[] | select(.prerelease == false) | .tag_name' | head -n 1)
    fi
    
    if [ -z "$VERSION" ] || [ "$VERSION" = "null" ]; then
        echo "Error: Failed to fetch version from GitHub API"
        exit 1
    fi
    
    # Remove 'v' prefix if present
    VERSION=$(echo "$VERSION" | sed 's/^v//')
    echo "Found version: $VERSION"
}

# Function to detect package manager
detect_package_manager() {
    # Check if package manager was specified via --pm flag
    if [ ! -z "$FORCED_PM" ]; then
        case "$FORCED_PM" in
            npm|yarn|pnpm)
                PM="$FORCED_PM"
                PM_INSTALL="$FORCED_PM install"
                PM_UPDATE="$FORCED_PM up"
                echo "Using forced package manager: $PM"
                return
                ;;
            *)
                echo "Error: Invalid package manager specified. Use npm, yarn, or pnpm."
                exit 1
                ;;
        esac
    fi

    # Check for lock files
    if [ -f "pnpm-lock.yaml" ]; then
        PM="pnpm"
        PM_INSTALL="pnpm install"
        PM_UPDATE="pnpm up"
    elif [ -f "yarn.lock" ]; then
        PM="yarn"
        PM_INSTALL="yarn"
        PM_UPDATE="yarn up"
    elif [ -f "package-lock.json" ]; then
        PM="npm"
        PM_INSTALL="npm install"
        PM_UPDATE="npm install"
    else
        # Check user agent for package manager
        case "$npm_config_user_agent" in
            *pnpm*)
                PM="pnpm"
                PM_INSTALL="pnpm install"
                PM_UPDATE="pnpm up"
                ;;
            *yarn*)
                PM="yarn"
                PM_INSTALL="yarn"
                PM_UPDATE="yarn up"
                ;;
            *)
                # Default to npm if no other evidence is found
                PM="npm"
                PM_INSTALL="npm install"
                PM_UPDATE="npm install"
                ;;
        esac
    fi
    
    echo "Detected package manager: $PM"
}

# Parse arguments
FORCED_PM=""
VERSION=""
while [ $# -gt 0 ]; do
    case "$1" in
        --latest)
            fetch_latest_version "false"
            shift
            ;;
        --prerelease)
            fetch_latest_version "true"
            shift
            ;;
        --pm)
            if [ -z "$2" ]; then
                echo "Error: --pm requires a package manager name"
                exit 1
            fi
            FORCED_PM="$2"
            shift 2
            ;;
        --help|-h)
            print_usage
            ;;
        *)
            if [ -z "$VERSION" ]; then
                VERSION=$1
                shift
            else
                echo "Error: Unexpected argument: $1"
                print_usage
            fi
            ;;
    esac
done

# Check if version is set
if [ -z "$VERSION" ]; then
    print_usage
fi

# Check if package.json exists
if [ ! -f "package.json" ]; then
    echo "Error: package.json not found in current directory"
    exit 1
fi

# Check for jq installation
if ! command -v jq > /dev/null 2>&1; then
    echo "Error: jq is required but not installed."
    echo "Please install jq first:"
    echo "  - For Ubuntu/Debian: sudo apt-get install jq"
    echo "  - For macOS: brew install jq"
    echo "  - For Windows: chocolatey install jq"
    exit 1
fi

# Detect package manager
detect_package_manager

# Extract packages into an array -match @payloadcms/* and exact payload module
PACKAGES=($(jq -r '.dependencies + .devDependencies | to_entries | .[] | select(.key | test("^@payloadcms/|^payload$")) | .key' package.json))

if [ -z "$PACKAGES" ]; then
    echo "No Payload CMS packages found in package.json"
    exit 1
fi

# Print packages that will be updated
echo "The following packages will be updated to version $VERSION:\n$(printf '%s\n' "${PACKAGES[@]}")"

# Ask for confirmation
printf "Do you want to continue? (y/N) "
read -r answer
case "$answer" in
    [Yy]*)
        ;;
    *)
        echo "Operation cancelled"
        exit 1
        ;;
esac

# Build the install command
COMMAND="$PM install"

for package in "${PACKAGES[@]}"; do
    COMMAND+=" $package@$VERSION"
done

# Execute the command
echo "Installing Payload CMS packages version $VERSION..."
echo "Running: $COMMAND"

eval "$COMMAND"

echo "Done. Please check your package.json and lock files."
