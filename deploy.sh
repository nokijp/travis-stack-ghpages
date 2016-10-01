#!/bin/bash

set -e

GIT_USER='Travis CI'
GIT_EMAIL="$DEPLOY_USER_EMAIL"
GIT_COMMIT_MESSAGE='deploy to gh-pages'

STACK_DIST_DIR="$(pwd)/$(stack path --dist-dir)"
DEPLOY_KEY_ENC="$(pwd)/deploy_key.enc"

TARGET_BRANCH=gh-pages

GIT_REPO="$(git config remote.origin.url)"
GIT_SSH_REPO="${GIT_REPO/https:\/\/github.com\//git@github.com:}"

function setup_git() {
  git config user.name "$GIT_USER"
  git config user.email "$GIT_EMAIL"
}

function setup_ssh() {
  local encryption_label="$1"
  local encrypted_key_var="encrypted_${encryption_label}_key"
  local encrypted_iv_var="encrypted_${encryption_label}_iv"

  openssl aes-256-cbc -K "${!encrypted_key_var}" -iv "${!encrypted_iv_var}" -in "$DEPLOY_KEY_ENC" -out deploy_key -d
  chmod 600 deploy_key
  eval "$(ssh-agent -s)"
  ssh-add deploy_key
}

function setup_dir() {
  local tmp_dir=dist

  rm -rf "$tmp_dir"
  git clone "$GIT_REPO" "$tmp_dir"
  cd "$tmp_dir"
  git checkout "$TARGET_BRANCH" || git checkout --orphan "$TARGET_BRANCH"
  git reset --hard
}

function repo_package_path() {
  if [[ "$1" =~ ([^/]+)-([0-9.]+)(\.tar\.gz)$ ]]; then
    echo "${BASH_REMATCH[1]}/${BASH_REMATCH[2]}/${BASH_REMATCH[1]}${BASH_REMATCH[3]}"
  fi
}

function copy_packages() {
  for src_path in "$STACK_DIST_DIR/"*-*.tar.gz; do
    local target_path="$(repo_package_path "$src_path")"

    mkdir -p "$(dirname "$target_path")"
    cp "$src_path" "$target_path"
  done
}

setup_dir

copy_packages
git add .

if git diff --cached --quiet --exit-code; then
  echo 'nothing to commit'
  exit 0
fi

setup_git
git commit -m "$GIT_COMMIT_MESSAGE"

setup_ssh "$ENCRYPTION_LABEL"
git push "$GIT_SSH_REPO" "$TARGET_BRANCH"
