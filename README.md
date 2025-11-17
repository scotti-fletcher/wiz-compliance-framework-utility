# wiz-compliance-framework-utility

Wiz utility script to import / export / transfer compliance frameworks. This is example code only. Read and test everything before using it in your environment.

## Prerequisites (macOS)
- Install Homebrew if you do not have it yet: https://brew.sh
- Install rbenv: `brew install rbenv ruby-build`

## Setup
Run these from the repository root:
```bash
rbenv current
rbenv -l
rbenv local 3.4.7
gem install bundler
bundle install
ruby framework.rb
```

## Limitations
- Will not re-create custom Host Config or Cloud Config rules. Script updates to add this are planned for the future.

## Disclaimer
- This repository contains example code only. Review and test thoroughly before using it in your own environment.
