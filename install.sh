#!/bin/sh

# A script to install payload-utils as a global command.
# It defaults to a user-level installation (~/.local) to avoid requiring sudo.
# POSIX-compliant and should run with /bin/sh.

# Stop on any error
set -e

# --- Config ---
# Default to a user-local installation. FHS-like structure under $HOME.
# User can override by providing a path, like ./install.sh /usr/local
PREFIX="${1:-$HOME/.local}"

# Define installation paths based on the prefix.
# DATA_DIR is where the git repo is cloned.
# BIN_DIR is where the executable command is placed.
DATA_DIR="$PREFIX/share/payload-utils"
BIN_DIR="$PREFIX/bin"
REPO_URL="https://github.com/AF111/payload-utils.git"
WRAPPER_SCRIPT_PATH="$BIN_DIR/payload-utils"

# --- Pre-flight Checks ---
# If the target directory is not in the user's home directory, we may need sudo.
case "$PREFIX" in
  "$HOME"*)
    # Installing inside home directory, no sudo needed.
    ;;
  *)
    # Installing outside home, check for root privileges.
    if [ "$(id -u)" -ne 0 ]; then
        printf "Installation to '%s' requires root privileges.\n" "$PREFIX" >&2
        printf "Please run this script with sudo: sudo ./install.sh %s\n" "$PREFIX" >&2
        exit 1
    fi
    ;;
esac

# Check if git is installed
if ! command -v git >/dev/null 2>&1; then
    echo "Error: git is not installed. Please install git to continue." >&2
    exit 1
fi

printf "Starting installation of payload-utils...\n"
printf "Installation Prefix: %s\n" "$PREFIX"
printf "Repo Install Path:   %s\n" "$DATA_DIR"
printf "Command Path:        %s\n" "$WRAPPER_SCRIPT_PATH"
printf "\n"

# --- Cleanup ---
# Clean up any previous installations to ensure a fresh start.
if [ -d "$DATA_DIR" ]; then
    printf "Removing previous installation at %s...\n" "$DATA_DIR"
    rm -rf "$DATA_DIR"
fi
if [ -f "$WRAPPER_SCRIPT_PATH" ]; then
    printf "Removing previous command at %s...\n" "$WRAPPER_SCRIPT_PATH"
    rm -f "$WRAPPER_SCRIPT_PATH"
fi

# --- Installation ---
# Ensure target directories exist
printf "Creating directories...\n"
mkdir -p "$DATA_DIR"
mkdir -p "$BIN_DIR"

# 1. Clone the repository from GitHub into the data directory.
printf "Cloning payload-utils repository into %s...\n" "$DATA_DIR"
git clone --depth 1 "$REPO_URL" "$DATA_DIR"

# 2. Make all scripts in the 'scripts' directory executable.
printf "Setting permissions for utility scripts...\n"
chmod +x "$DATA_DIR"/scripts/*.sh

# 3. Create the main 'payload-utils' command (wrapper script).
printf "Creating command at %s...\n" "$WRAPPER_SCRIPT_PATH"

# Using a here document (cat << 'EOF') to write the script content.
cat > "$WRAPPER_SCRIPT_PATH" << EOF
#!/bin/sh
# Main wrapper script for payload-utils.

# Base directory where scripts are stored
BASE_DIR="$DATA_DIR/scripts"

# Show usage information if no script name is provided.
if [ -z "\$1" ]; then
    printf "Usage: payload-utils <script_name> [args...]\n"
    printf "\n"
    printf "Available scripts:\n"
    ls -1 "\$BASE_DIR" | sed 's/\.sh$//' >&2
    exit 1
fi

SCRIPT_NAME="\$1"
SCRIPT_PATH="\$BASE_DIR/\$SCRIPT_NAME.sh"

# Check if the requested script exists and is executable.
if [ ! -x "\$SCRIPT_PATH" ]; then
    printf "Error: Script '%s' not found or not executable.\n\n" "\$SCRIPT_NAME" >&2
    printf "Available scripts:\n" >&2
    ls -1 "\$BASE_DIR" | sed 's/\.sh$//' >&2
    exit 1
fi

# Remove the script name from the list of arguments.
shift

# Execute the target script, forwarding all remaining arguments.
exec "\$SCRIPT_PATH" "\$@"
EOF

# 4. Make the main 'payload-utils' command executable.
chmod +x "$WRAPPER_SCRIPT_PATH"

# --- PATH Configuration ---
# Ensure the user's bin directory is in their PATH.
printf "Checking shell configuration...\n"
SHELL_PROFILE=""
# Determine the user's shell profile file in a more portable way.
if [ -n "$SHELL" ]; then
    case "$(basename "$SHELL")" in
        bash)
            SHELL_PROFILE="$HOME/.bashrc"
            ;;
        zsh)
            SHELL_PROFILE="$HOME/.zshrc"
            ;;
        *)
            # Fallback for other shells like dash, ksh, etc.
            SHELL_PROFILE="$HOME/.profile"
            ;;
    esac
else
    # If $SHELL is not set, fallback to .profile
    SHELL_PROFILE="$HOME/.profile"
fi

# Check if the bin directory is already in the PATH.
case ":$PATH:" in
    *":$BIN_DIR:"*)
        printf "✅ %s is already in your PATH.\n" "$BIN_DIR"
        ;;
    *)
        printf "Adding %s to PATH in %s\n" "$BIN_DIR" "$SHELL_PROFILE"
        # Add the export command to the shell profile file.
        printf "\n# Add payload-utils to PATH\n" >> "$SHELL_PROFILE"
        printf "export PATH=\"\$PATH:%s\"\n" "$BIN_DIR" >> "$SHELL_PROFILE"
        printf "✅ PATH configured. Please restart your terminal or run 'source %s'.\n" "$SHELL_PROFILE"
        ;;
esac

# --- Uninstaller Setup ---
printf "Creating uninstaller...\n"
# The uninstaller is placed in the data directory
cat > "$DATA_DIR/scripts/uninstall.sh" << EOF
#!/bin/sh
set -e
printf "Uninstalling payload-utils...\n"

case "$PREFIX" in
  "\$HOME"*)
    # Uninstalling from home directory, no sudo needed.
    ;;
  *)
    # Uninstalling from a system directory, check for root.
    if [ "\$(id -u)" -ne 0 ]; then
        printf "Uninstallation from '%s' requires root privileges. Please run with sudo.\n" "$PREFIX" >&2
        exit 1
    fi
    ;;
esac

printf "Removing command: %s\n" "$WRAPPER_SCRIPT_PATH"
rm -f "$WRAPPER_SCRIPT_PATH"
printf "Removing data directory: %s\n" "$DATA_DIR"
rm -rf "$DATA_DIR"
printf "NOTE: You may want to manually remove the PATH entry from your shell profile (%s).\n" "$SHELL_PROFILE"
printf "✅ Uninstallation complete.\n"
EOF

chmod +x "$DATA_DIR/scripts/uninstall.sh"

printf "\n🎉 Installation successful!\n"
printf "\nTo get started, open a new terminal or run 'source %s'.\n" "$SHELL_PROFILE"
printf "Then you can use the 'payload-utils' command.\n"
printf "Example: payload-utils update\n"
