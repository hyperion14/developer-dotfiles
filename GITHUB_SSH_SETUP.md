# GitHub SSH Key Setup

**Issue**: Your SSH key for GitHub has a passphrase and needs to be properly configured.

---

## Current Status

✅ **SSH Key Exists**: `~/.ssh/github_id_ed25519.pub`
```
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICoImbJY+S5JWT/ApjT0a0lkUT+1UjPmi2nZYkxp4Fmn justus.kampp@gmail.com
```

❌ **Not added to GitHub** or SSH agent not configured properly
❌ **Connection test failed**: `Permission denied (publickey)`

---

## Solution: Two Options

### Option 1: Add Existing Key to GitHub (Recommended)

**Step 1: Copy your public key**
```bash
cat ~/.ssh/github_id_ed25519.pub
```

Copy this entire line (starts with `ssh-ed25519`).

**Step 2: Add to GitHub**
1. Go to: https://github.com/settings/keys
2. Click **"New SSH key"**
3. Title: `Developer Server - BHK RAG`
4. Key type: `Authentication Key`
5. Paste the key from Step 1
6. Click **"Add SSH key"**

**Step 3: Test connection**
```bash
# Add key to SSH agent
ssh-add ~/.ssh/github_id_ed25519
# (Enter passphrase when prompted)

# Test GitHub connection
ssh -T git@github.com
```

You should see: `Hi YOUR_USERNAME! You've successfully authenticated...`

---

### Option 2: Create New Key Without Passphrase

If you don't remember the passphrase or want a simpler setup:

**Step 1: Create new key (no passphrase)**
```bash
# Backup old key
mv ~/.ssh/github_id_ed25519 ~/.ssh/github_id_ed25519.old
mv ~/.ssh/github_id_ed25519.pub ~/.ssh/github_id_ed25519.pub.old

# Create new key without passphrase
ssh-keygen -t ed25519 -C "justus.kampp@gmail.com" -f ~/.ssh/github_id_ed25519 -N ""
```

**Step 2: Add new key to GitHub**
```bash
cat ~/.ssh/github_id_ed25519.pub
```
Then follow Option 1, Step 2 above.

**Step 3: Test**
```bash
ssh -T git@github.com
```

---

## Automated Setup

I've updated your SSH config (` ~/.ssh/config`) to automatically use the GitHub key.

**To use the key permanently** (survives reboots), add to `~/.bashrc`:

```bash
echo '
# Auto-start SSH agent and add GitHub key
if [ -z "$SSH_AUTH_SOCK" ]; then
    eval "$(ssh-agent -s)" > /dev/null
    ssh-add ~/.ssh/github_id_ed25519 2>/dev/null
fi
' >> ~/.bashrc
```

Then reload:
```bash
source ~/.bashrc
```

---

## Verify Setup

After completing either option, verify:

```bash
# 1. Test SSH connection
ssh -T git@github.com

# Should output:
# Hi YOUR_USERNAME! You've successfully authenticated, but GitHub does not provide shell access.

# 2. Test git operation
cd ~/projects/bhk-rag-system
git remote -v
git fetch origin  # Should work without password prompt
```

---

## Current SSH Config

Your `~/.ssh/config` now includes:

```
Host github.com
    HostName github.com
    User git
    IdentityFile ~/.ssh/github_id_ed25519
    AddKeysToAgent yes
```

This ensures Git always uses the correct key for GitHub.

---

## Troubleshooting

### "Permission denied (publickey)"
- **Cause**: Key not added to GitHub account
- **Fix**: Follow Option 1, Step 2

### "Enter passphrase for key"
- **Cause**: Key has passphrase, not in SSH agent
- **Fix**: Run `ssh-add ~/.ssh/github_id_ed25519` (enter passphrase)
- **Better**: Add SSH agent startup to `.bashrc` (see Automated Setup)

### "Could not open a connection to your authentication agent"
- **Cause**: SSH agent not running
- **Fix**: Run `eval "$(ssh-agent -s)"` then `ssh-add ~/.ssh/github_id_ed25519`

### "Key is already in use"
- **Cause**: Key already added to different GitHub account
- **Fix**: Create new key (Option 2) or use different account

---

## Quick Fix Script

Run this to complete the setup:

```bash
#!/bin/bash

# Add key to SSH agent (enter passphrase when prompted)
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/github_id_ed25519

# Show public key to add to GitHub
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Add this key to GitHub:"
echo "https://github.com/settings/keys"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
cat ~/.ssh/github_id_ed25519.pub
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
read -p "Press Enter after adding the key to GitHub..."

# Test connection
echo "Testing GitHub connection..."
ssh -T git@github.com
```

Save as `setup_github_ssh.sh`, make executable, and run:
```bash
chmod +x setup_github_ssh.sh
./setup_github_ssh.sh
```

---

## After Setup Complete

Once your SSH key is working, you can run:
```bash
./setup_github_repos.sh
```

This will set up both repositories and push them to GitHub.

---

**Next Step**: Choose Option 1 or Option 2 above and complete the setup!
