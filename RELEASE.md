# Release Process

This document describes the automated release process for emacs-openclaw.

## Overview

The project uses automated CI/CD for creating releases with:
- **Semantic Versioning** (MAJOR.MINOR.PATCH)
- **Automated Changelog Generation**
- **GitHub Releases with Release Notes**
- **Version Synchronization** across files

## Quick Release Methods

### Method 1: Manual Version Bump (Recommended)

1. **Update VERSION file:**
   ```bash
   echo "0.2.0" > VERSION
   ```

2. **Commit and push to main:**
   ```bash
   git add VERSION
   git commit -m "chore: bump version to 0.2.0"
   git push origin main
   ```

3. **Automated actions:** The release workflow automatically:
   - Updates `emacs-openclaw.el` version
   - Generates changelog
   - Creates git tag (v0.2.0)
   - Creates GitHub release

### Method 2: Using GitHub Actions UI

1. Go to **Actions** → **Release** workflow
2. Click **Run workflow**
3. Choose either:
   - Enter specific version (e.g., `1.0.0`)
   - Or select release type (major/minor/patch)
4. Click **Run workflow**

The workflow will automatically handle everything.

### Method 3: Using GitHub CLI

```bash
# Specific version
gh workflow run release.yml -f version=1.0.0

# Or auto-increment
gh workflow run release.yml -f release_type=minor
```

### Method 4: Using Helper Script

```bash
# See current version
./release.sh current

# Get version suggestion based on commits
./release.sh suggest

# Bump version locally
./release.sh bump patch    # 0.1.0 -> 0.1.1
./release.sh bump minor    # 0.1.0 -> 0.2.0
./release.sh bump major    # 0.1.0 -> 1.0.0

# Then commit and push
git add VERSION emacs-openclaw.el
git commit -m "chore: bump version to X.Y.Z"
git push origin main
```

## Conventional Commits

The semantic release workflow analyzes commits to suggest version bumps:

### Patch Release (0.1.0 → 0.1.1)
```bash
fix: correct buffer initialization
fix(chat): handle empty responses properly
```

### Minor Release (0.1.0 → 0.2.0)
```bash
feat: add new Gmail attachment support
feat(calendar): implement recurring events
```

### Major Release (0.1.0 → 1.0.0)
```bash
feat!: redesign API interface
fix!: change configuration format

# Or in commit body:
feat: new feature

BREAKING CHANGE: This changes the public API
```

## Workflow Details

### 1. Release Workflow (`.github/workflows/release.yml`)

**Triggers:**
- Push to main with VERSION file changes
- Manual workflow dispatch

**Actions:**
1. Reads version from VERSION file (or input)
2. Checks if tag already exists
3. Updates `emacs-openclaw.el` version
4. Generates changelog from git commits
5. Creates and pushes git tag
6. Creates GitHub release with notes

### 2. Semantic Release Workflow (`.github/workflows/semantic-release.yml`)

**Triggers:**
- Push to main (excluding VERSION/CHANGELOG changes)

**Actions:**
1. Analyzes commits since last tag
2. Suggests version bump type (major/minor/patch)
3. Logs recommendation in workflow output

## Version Synchronization

Versions are maintained in two places:

1. **`VERSION` file:** Source of truth for automation
2. **`emacs-openclaw.el`:** Package version (line 4)

The release workflow automatically syncs these.

## Changelog

The `CHANGELOG.md` follows [Keep a Changelog](https://keepachangelog.com/) format and is automatically updated on release with:
- List of commits since last release
- Date of release
- Link to full changelog on GitHub

## Release Notes

GitHub releases include:
- Changes section with commit list
- Links to full changelog
- Tag comparison link

## Manual Release (Emergency)

If workflows fail, create a release manually:

```bash
# 1. Update version
echo "0.2.0" > VERSION
sed -i 's/^;; Version: .*/;; Version: 0.2.0/' emacs-openclaw.el

# 2. Update CHANGELOG.md manually

# 3. Commit
git add VERSION emacs-openclaw.el CHANGELOG.md
git commit -m "chore: release v0.2.0"

# 4. Tag
git tag -a v0.2.0 -m "Release v0.2.0"

# 5. Push
git push origin main
git push origin v0.2.0

# 6. Create GitHub release via UI
```

## Best Practices

1. **Use conventional commits** for automatic version suggestions
2. **Test before releasing** - ensure CI passes
3. **Update VERSION on main** for automatic releases
4. **Review CHANGELOG** after automated generation
5. **Keep version in sync** between VERSION and emacs-openclaw.el

## Troubleshooting

### Tag already exists
If a tag already exists, the workflow skips creation. Delete the tag if needed:
```bash
git tag -d v0.2.0
git push origin :refs/tags/v0.2.0
```

### VERSION out of sync
If VERSION and emacs-openclaw.el are out of sync:
```bash
# Reset to VERSION file
VERSION=$(cat VERSION)
sed -i "s/^;; Version: .*/;; Version: $VERSION/" emacs-openclaw.el
git commit -am "chore: sync version"
```

### Workflow fails
Check workflow logs in GitHub Actions for specific errors. Common issues:
- Git conflicts
- Permission issues
- Invalid version format

## Version History

See [CHANGELOG.md](CHANGELOG.md) for complete version history.
