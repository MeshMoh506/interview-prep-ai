# 📋 Daily Git Workflow - Follow This!

## 🌅 START OF DAY:
```bash
# 1. Always work on main branch
git checkout main

# 2. Pull latest changes (if working with team)
git pull origin main

# 3. Check status before starting
git status

# 4. Verify .env is NOT tracked
git ls-files | grep "\.env$"
# Should return: nothing (except .env.example)
```

---

## 💻 DURING WORK:
```bash
# Save work frequently (every 1-2 hours)
git add .
git commit -m "Work in progress: [what you did]"

# Check what's staged before committing
git status

# NEVER add .env file:
git rm --cached backend/.env  # if accidentally added
```

---

## 🌙 END OF DAY:
```bash
# 1. Final check - what changed today?
git status

# 2. Add all changes
git add .

# 3. Commit with descriptive message
git commit -m "Day X Complete: [feature name] - [what works]"

# 4. Push to GitHub
git push origin main

# 5. Verify on GitHub.com
# Go to: https://github.com/MeshMoh506/interview-prep-ai
# Check: Latest commit shows your work
```

---

## 🚨 IF PUSH FAILS:

### Error: "Push declined due to secrets"
```bash
# Find what file has secrets:
git status

# Remove the file from git:
git rm --cached path/to/file

# Or remove from commit:
git reset HEAD~1
```

### Error: "Remote rejected"
```bash
# Force push (use carefully!)
git push origin main --force

# Or create new branch:
git checkout -b day-X-work
git push origin day-X-work
```

---

## ✅ BEFORE EVERY COMMIT - CHECKLIST:

- [ ] .env file is NOT in git status
- [ ] No API keys in code (check with: grep -r "gsk_" .)
- [ ] .env.example has FAKE keys only
- [ ] Commit message is descriptive
- [ ] Code runs without errors

---

## 🔑 API KEY SAFETY:

### NEVER COMMIT:
- ❌ .env
- ❌ Real API keys in code
- ❌ Database passwords
- ❌ Secret tokens

### SAFE TO COMMIT:
- ✅ .env.example (with placeholders)
- ✅ Code using os.getenv()
- ✅ README with setup instructions
- ✅ All application code

---

## 🆘 EMERGENCY - KEY EXPOSED:
```bash
# 1. Immediately rotate ALL keys:
# - Groq: https://console.groq.com/keys
# - Supabase: Project settings → Database → Reset password

# 2. Remove from git history:
git filter-branch --force --index-filter \
  "git rm --cached --ignore-unmatch backend/.env" \
  --prune-empty --tag-name-filter cat -- --all

# 3. Force push:
git push origin main --force

# 4. Update local .env with NEW keys
```

---

