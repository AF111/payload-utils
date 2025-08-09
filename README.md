# payload-utils

Some CLI tools to help with Payload package installation and updates.

---

## 📦 How to Install

### 1. Open your terminal  
On **Ubuntu** or **macOS**, run the following commands.

---

### 2. Download the installer script  
```bash
curl -o install.sh https://raw.githubusercontent.com/AF111/payload-utils/refs/heads/master/install.sh
> Note: This URL points to the new sh-compatible version of the script.
```

### 3. Make the installer executable
```bash
chmod +x install.sh

```
### 4. Run the installer
Default Install (Recommended)
Installs into your home directory (~/.local) and does not require sudo:
```bash
./install.sh
```

System-wide Install (Advanced)
Installs for all users (e.g., in /usr/local). Requires sudo:

```bash
sudo ./install.sh /usr/local
```

5. Reload your shell
For the payload-utils command to be available, either open a new terminal or reload your shell configuration:

Bash / sh users

```bash
. ~/.bashrc    # or . ~/.profile
```

Zsh users
```bash
. ~/.zshrc
```

### 🚀 How to Use
After installation and reloading your shell, you can start using payload-utils.

List all available scripts

```bash
payload-utils
```

Run the update script

```bash
payload-utils
```

Run the install/update script

```bash
payload-utils update
```

