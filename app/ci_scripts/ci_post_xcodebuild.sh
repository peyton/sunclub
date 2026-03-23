#!/bin/sh

set -e

./bin/mise exec -- tuist inspect build --derived-data-path "$CI_DERIVED_DATA_PATH" -p ../
