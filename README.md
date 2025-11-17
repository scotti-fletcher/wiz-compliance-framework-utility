# wiz-compliance-framework-utility

This is a utility script to import / export / copy compliance frameworks. This is example code only. Read and test everything before using it in your environment.

## Prerequisites (macOS)
- Install Homebrew if you do not have it yet: https://brew.sh
- Install rbenv: `brew install rbenv`

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

## Usage
- Run `ruby framework.rb --framework <framework_id> --action <export|import|copy> [options]`.
- `--framework`: ID of the security framework to export / import / copy.
- `--action`: `export` pulls the framework and rules from the source Wiz tenant into `frameworks/<framework_id>/`; `import` pushes a previously exported framework to the target Wiz tenant; `transfer` does both in one run.
- `--source-client-id`, `--source-secret`, `--source-auth-url`, `--source-api-url`: source tenant credentials and endpoints (required for `export`/`transfer`).
- `--target-client-id`, `--target-secret`, `--target-auth-url`, `--target-api-url`: target tenant credentials and endpoints (required for `import`/`transfer`).
- `-v/--verbose`: print progress to stdout in addition to the audit log.

## Credentials
- The script reads defaults from environment variables: `SOURCE_CLIENT_ID`, `SOURCE_SECRET`, `SOURCE_AUTH_URL`, `SOURCE_API_URL`, `TARGET_CLIENT_ID`, `TARGET_SECRET`, `TARGET_AUTH_URL`, `TARGET_API_URL`.
- Recommended: Set credentials as environment variables instead of passing secrets on the command line to avoid shell history exposure.

## API permissions
- Source API key (minimum): `read:controls`, `read:cloud_configuration`, `read:host_configuration`, `read:security_frameworks`.
- Target API key (minimum): `read:controls`, `update:controls`, `create:controls`, `read:cloud_configuration`, `update:cloud_configuration`, `create:cloud_configuration`, `read:host_configuration`, `update:host_configuration`, `create:host_configuration`, `read:security_frameworks`, `update:security_frameworks`, `create:security_frameworks`.

## Limitations
- Will not re-create custom Host Config or Cloud Config rules. Script updates to add this are planned for the future.

## Disclaimer
- This repository contains example code only. Review and test thoroughly before using it in your own environment.
