#!/bin/sh

set -e

./bin/mise install # Installs the version from .mise.toml

./bin/mise exec -- tuist install --path ../ # `--path` needed as this is run from within the `ci_scripts` directory
./bin/mise exec -- tuist setup insights -p ../
./bin/mise exec -- tuist setup cache -p ../
./bin/mise exec -- tuist generate -p ../ --no-open # `-p` needed as this is run from within the `ci_scripts` directory
