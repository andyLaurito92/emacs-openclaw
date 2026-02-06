#!/bin/bash
# Release Helper Script for emacs-openclaw
# This script helps create releases manually or provides information about the release process

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

show_help() {
    cat << EOF
Usage: $0 [COMMAND] [OPTIONS]

Commands:
    bump [major|minor|patch]   Bump version and prepare release
    current                    Show current version
    suggest                    Suggest next version based on commits
    help                       Show this help message

Examples:
    $0 current                 # Show current version
    $0 suggest                 # Suggest next version based on commits
    $0 bump patch              # Bump patch version (0.1.0 -> 0.1.1)
    $0 bump minor              # Bump minor version (0.1.0 -> 0.2.0)
    $0 bump major              # Bump major version (0.1.0 -> 1.0.0)

Release Process:
    1. Make your changes and commit with conventional commit messages:
       - feat: for new features (minor bump)
       - fix: for bug fixes (patch bump)
       - BREAKING CHANGE: for breaking changes (major bump)
    
    2. Use this script to bump the version:
       ./release.sh bump [major|minor|patch]
    
    3. Push changes to main:
       git push origin main
    
    4. The GitHub Actions workflow will automatically:
       - Create a git tag
       - Generate changelog
       - Create GitHub release

Alternatively, use GitHub Actions workflow dispatch:
    gh workflow run release.yml -f version=1.0.0
    or
    gh workflow run release.yml -f release_type=minor

EOF
}

get_current_version() {
    if [ -f VERSION ]; then
        cat VERSION
    else
        echo "0.1.0"
    fi
}

bump_version() {
    local bump_type=$1
    local current=$(get_current_version)
    
    IFS='.' read -r -a parts <<< "$current"
    local major=${parts[0]}
    local minor=${parts[1]}
    local patch=${parts[2]}
    
    case "$bump_type" in
        major)
            major=$((major + 1))
            minor=0
            patch=0
            ;;
        minor)
            minor=$((minor + 1))
            patch=0
            ;;
        patch)
            patch=$((patch + 1))
            ;;
        *)
            echo "Error: Invalid bump type. Use major, minor, or patch."
            exit 1
            ;;
    esac
    
    local new_version="${major}.${minor}.${patch}"
    echo "$new_version"
}

suggest_version() {
    echo "Analyzing commits since last tag..."
    
    LAST_TAG=$(git describe --tags --abbrev=0 2>/dev/null || echo "")
    
    if [ -z "$LAST_TAG" ]; then
        echo "No previous tags found. Suggesting initial release based on current VERSION file."
        COMMITS=$(git log --pretty=format:"%s" --no-merges)
    else
        echo "Last tag: $LAST_TAG"
        COMMITS=$(git log ${LAST_TAG}..HEAD --pretty=format:"%s" --no-merges)
    fi
    
    BUMP_TYPE="none"
    
    # Check for breaking changes (major bump)
    if echo "$COMMITS" | grep -qE "^[a-zA-Z]+(\(.+\))?!:|BREAKING CHANGE:"; then
        BUMP_TYPE="major"
        echo "Breaking changes detected (major bump recommended)"
    # Check for features (minor bump)
    elif echo "$COMMITS" | grep -qE "^feat(\(.+\))?:"; then
        BUMP_TYPE="minor"
        echo "New features detected (minor bump recommended)"
    # Check for fixes (patch bump)
    elif echo "$COMMITS" | grep -qE "^fix(\(.+\))?:"; then
        BUMP_TYPE="patch"
        echo "Bug fixes detected (patch bump recommended)"
    else
        echo "No conventional commits found. Manual version bump recommended."
    fi
    
    if [ "$BUMP_TYPE" != "none" ]; then
        CURRENT=$(get_current_version)
        SUGGESTED=$(bump_version "$BUMP_TYPE")
        echo ""
        echo "Current version: $CURRENT"
        echo "Suggested version: $SUGGESTED"
        echo ""
        echo "To bump: ./release.sh bump $BUMP_TYPE"
    fi
}

do_bump() {
    local bump_type=$1
    local current=$(get_current_version)
    local new_version=$(bump_version "$bump_type")
    
    echo "Bumping version from $current to $new_version"
    
    # Update VERSION file
    echo "$new_version" > VERSION
    
    # Update emacs-openclaw.el
    if [ -f emacs-openclaw.el ]; then
        sed -i "s/^;; Version: .*/;; Version: $new_version/" emacs-openclaw.el
        echo "Updated emacs-openclaw.el"
    fi
    
    echo ""
    echo "Version bumped to $new_version"
    echo ""
    echo "Next steps:"
    echo "1. Review changes: git diff"
    echo "2. Commit changes: git add VERSION emacs-openclaw.el && git commit -m 'chore: bump version to $new_version'"
    echo "3. Push to main: git push origin main"
    echo "4. GitHub Actions will create the release automatically"
}

# Main command handling
case "${1:-help}" in
    current)
        get_current_version
        ;;
    suggest)
        suggest_version
        ;;
    bump)
        if [ -z "$2" ]; then
            echo "Error: Please specify bump type (major, minor, or patch)"
            exit 1
        fi
        do_bump "$2"
        ;;
    help|*)
        show_help
        ;;
esac
