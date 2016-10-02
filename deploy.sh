#!/bin/bash

set -e

git_user='Travis CI'
git_email="$DEPLOY_USER_EMAIL"
git_commit_message='deploy to gh-pages'

stack_dist_dir="$(pwd)/$(stack path --dist-dir)"
deploy_key_enc="$(pwd)/deploy_key.enc"

target_branch=gh-pages

git_repo="$(git config remote.origin.url)"
git_ssh_repo="${git_repo/https:\/\/github.com\//git@github.com:}"

function setup_git() {
  git config user.name "$git_user"
  git config user.email "$git_email"
}

function setup_ssh() {
  local encryption_label="$1"
  local encrypted_key_var="encrypted_${encryption_label}_key"
  local encrypted_iv_var="encrypted_${encryption_label}_iv"

  openssl aes-256-cbc -K "${!encrypted_key_var}" -iv "${!encrypted_iv_var}" -in "$deploy_key_enc" -out deploy_key -d
  chmod 600 deploy_key
  eval "$(ssh-agent -s)"
  ssh-add deploy_key
}

function setup_dir() {
  local tmp_dir=dist

  rm -rf "$tmp_dir"
  git clone "$git_repo" "$tmp_dir"
  cd "$tmp_dir"
  git checkout "$target_branch" || git checkout --orphan "$target_branch"
  git reset --hard
}

function copy_packages() {
  function repo_package_path() {
    if [[ "$1" =~ ([^/]+)-([0-9.]+)(\.tar\.gz)$ ]]; then
      echo "${BASH_REMATCH[1]}/${BASH_REMATCH[2]}/${BASH_REMATCH[1]}${BASH_REMATCH[3]}"
    fi
  }

  local src_path
  for src_path in "$stack_dist_dir"/*-*.tar.gz; do
    local dest_path="$(repo_package_path "$src_path")"
    if [[ -z "$dest_path" ]]; then
      continue
    fi

    mkdir -p "$(dirname "$dest_path")"
    cp "$src_path" "$dest_path"
  done
}

function generate_index() {
  local index_tarball="$1"

  local temp_dir="$(mktemp -d)"
  local src_tarball
  for src_tarball in */*/*.tar.gz; do
    if ! [[ "$src_tarball" =~ ([^/]+/[0-9.]+)/([^/]+)\.tar\.gz ]]; then
      continue
    fi
    local dest_dir="$temp_dir/${BASH_REMATCH[1]}"
    local cabal_name="${BASH_REMATCH[2]}.cabal"

    if ! tar ztf "$cabal_name"; then
      continue
    fi
    mkdir -p "$dest_dir"
    tar zxOf "$src_tarball" "$cabal_name" > "$dest_dir/$cabal_name"
  done

  tar zcf "$index_tarball" -C "$temp_dir" "$temp_dir"/*
}

setup_dir

copy_packages
generate_index '00-index.tar.gz'

git add .

if git diff --cached --quiet --exit-code; then
  echo 'nothing to commit'
  exit 0
fi

setup_git
git commit -m "$git_commit_message"

setup_ssh "$ENCRYPTION_LABEL"
git push "$git_ssh_repo" "$target_branch"
