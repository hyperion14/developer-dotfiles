# Server Reorganization - Quick Start Guide

**Issue Found**: Some directories in your home are owned by root, which blocks the migration.

---

## 🚦 Two-Step Process

### Step 1: Fix Permissions ⚠️ **DO THIS FIRST**

```bash
./fix_permissions_first.sh
```

This will:
- Check which directories are root-owned
- Ask for your sudo password
- Change ownership to `developer:developer`
- Verify the fix

**Time**: 30 seconds

---

### Step 2: Run Migration ✅

```bash
./migrate_server_structure.sh
```

This will:
- Create backup
- Move projects from /opt to ~/projects
- Organize into production/development structure
- Fix remaining permissions
- Restart services
- Create management scripts

**Time**: 5-10 minutes

---

## 📋 Complete Commands

```bash
# 1. Fix permissions (requires sudo password)
./fix_permissions_first.sh

# 2. Run migration (automated, interactive)
./migrate_server_structure.sh

# 3. Verify everything works
~/scripts/deployment/service-status.sh
```

---

## 🔍 What's Wrong Now?

Current issue:
```
/home/developer/data/  - owned by root ❌
/home/developer/logs/  - owned by root ❌
```

These need to be owned by `developer` for the migration to work.

---

## ⚡ Quick Fix (Manual Alternative)

If you prefer to fix manually:

```bash
# Fix ownership (enter your sudo password when prompted)
sudo chown -R developer:developer ~/data ~/logs

# Verify it worked
ls -la ~/ | grep -E "data|logs"
# Should show: drwxr-xr-x developer developer

# Then run migration
./migrate_server_structure.sh
```

---

## 📚 Full Documentation

- **Strategy**: [SERVER_REORGANIZATION_STRATEGY.md](SERVER_REORGANIZATION_STRATEGY.md)
- **Summary**: [SERVER_STRUCTURE_SUMMARY.md](SERVER_STRUCTURE_SUMMARY.md)
- **This Guide**: [QUICK_START_REORGANIZATION.md](QUICK_START_REORGANIZATION.md)

---

## 🆘 Troubleshooting

### "Permission denied" when running fix script
**Solution**: The script needs sudo access. Enter your password when prompted.

### "sudo: a password is required"
**Solution**: You need to enter your system password. This is normal and safe.

### Migration script says "permission issues"
**Solution**: Run `./fix_permissions_first.sh` first.

---

## ✅ Success Indicators

After Step 1 (fix_permissions_first.sh):
```bash
ls -la ~/ | grep -E "data|logs"
# Should show developer:developer ownership
```

After Step 2 (migrate_server_structure.sh):
```bash
docker ps
# Should show all containers running

ls -la ~/projects/
# Should show production/ and development/ directories
```

---

**Start here**: `./fix_permissions_first.sh`
