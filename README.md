# travis-stack-ghpages

`deploy-haddock.sh` is a script for Travis CI that deploys haddocks into gh-pages automatically.

## 1. Create a project

Create a stack project in root directory of your git repository.

## 2. Add .travis.yml

Add `.travis.yml` like the following settings.

```yaml
language: c

sudo: false

cache:
  directories:
    - ~/.stack
    - ~/.local

addons:
  apt:
    sources:
      - hvr-ghc
    packages:
      - ghc-8.0.2

before_install:
  - mkdir -p ~/.local/bin
  - export PATH=~/.local/bin:$PATH
  - travis_retry curl -L https://www.stackage.org/stack/linux-x86_64 | tar -xzO --wildcards '*/stack' > ~/.local/bin/stack
  - chmod a+x ~/.local/bin/stack

install:
  - stack setup --no-terminal

script:
  - stack test --no-terminal --skip-ghc-check
  - stack haddock --no-haddock-deps --no-terminal --skip-ghc-check

deploy:
  provider: script
  script: curl -sSL https://raw.githubusercontent.com/nokijp/travis-stack-ghpages/master/deploy-haddock.sh | bash
  skip_cleanup: true
  on:
    branch: master
```

## 3. Generate SSH key

Generate SSH key files by running the following command.

```bash
$ ssh-keygen -t rsa -b 4096 -f deploy_key
```

DO NOT push the generated files.

## 4. Add the key into your repository

Add the generated public key into your repository, and allow write access.

The setting is found at `https://github.com/organization_name/repository_name/settings/keys`.

## 5. Encrypt the key

Encrypt `deploy_key` using [Travis CI Command Line Client](https://github.com/travis-ci/travis.rb#readme).

```bash
$ travis encrypt-file deploy_key
encrypting deploy_key for organization_name/repository_name
storing result as deploy_key.enc
storing secure env variables for decryption

Please add the following to your build script (before_install stage in your .travis.yml, for instance):

    openssl aes-256-cbc -K $encrypted_48abfe812a09_key -iv $encrypted_48abfe812a09_iv -in deploy_key.enc -out deploy_key -d

Pro Tip: You can add it automatically by running with --add.

Make sure to add deploy_key.enc to the git repository.
Make sure not to add deploy_key to the git repository.
Commit all changes to your .travis.yml.
```

Make a note of the identifier like `"48abfe812a09"`.

Next, add `deploy_key.enc` to your repository.

```bash
$ git add deploy_key.enc
```

## 6. Add settings

Add the following lines into `.travis.yml`.

```yaml
env:
  global:
    - ENCRYPTION_LABEL: 48abfe812a09
    - DEPLOY_USER_EMAIL: travisci@example.com
```

- `ENCRYPTION_LABEL` is the identifier from the previous step.
- `DEPLOY_USER_EMAIL` is the e-mail address that will be used in commits by Travis CI.

## 7. Run build

Run Travis CI build, and then the haddocks will be uploaded into github.io.
