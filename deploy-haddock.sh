#!/bin/bash

set -eu

readonly git_user='Travis CI'
readonly git_email="$DEPLOY_USER_EMAIL"
readonly git_commit_message='deploy haddock to gh-pages'

function read_cabal_file() {
  cat *.cabal | grep -m 1 "^$1" | awk '{ print $2 }'
}
readonly package_name="$(read_cabal_file name)"
readonly package_version="$(read_cabal_file version)"
readonly stack_docs_dir="$(stack path --local-doc-root)/$package_name-$package_version"
readonly deploy_key_enc="$(pwd)/deploy_key.enc"

readonly target_branch='gh-pages'

readonly git_repo="$(git config remote.origin.url)"
readonly git_ssh_repo="${git_repo/https:\/\/github.com\//git@github.com:}"

function setup_git() {
  git config user.name "$git_user"
  git config user.email "$git_email"
}

function setup_ssh() {
  local -r encryption_label="$1"
  local -r encrypted_key_var="encrypted_${encryption_label}_key"
  local -r encrypted_iv_var="encrypted_${encryption_label}_iv"

  openssl aes-256-cbc -K "${!encrypted_key_var}" -iv "${!encrypted_iv_var}" -in "$deploy_key_enc" -out deploy_key -d
  chmod 600 deploy_key
  eval "$(ssh-agent -s)"
  ssh-add deploy_key
}

function setup_dir() {
  local -r dist_dir=dist

  rm -rf "$dist_dir"
  git clone "$git_repo" "$dist_dir"
  cd "$dist_dir"
  git checkout "$target_branch" || git checkout --orphan "$target_branch"
  git reset --hard
}

function copy_docs() {
  cp -r "$stack_docs_dir/"* .
}

setup_dir
copy_docs
git add .

if git diff --cached --quiet --exit-code; then
  echo 'nothing to commit'
  exit 0
fi

setup_git
git commit -m "$git_commit_message"

setup_ssh "$ENCRYPTION_LABEL"
git push "$git_ssh_repo" "$target_branch"
