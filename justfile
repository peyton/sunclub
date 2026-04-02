#!/usr/bin/env -S just --working-directory . --justfile

[private]
@default:
    just --list

bootstrap:
    bash scripts/tooling/bootstrap.sh

[group('app')]
icons:
    bash scripts/generate-app-icons.sh

[group('app')]
generate-icons: icons

[group('app')]
appstore-validate:
    uv run python -m scripts.appstore.validate_metadata --allow-draft

[group('app')]
appstore-screenshots:
    bash scripts/appstore/capture-screenshots.sh

[group('app')]
appstore-archive:
    bash scripts/appstore/archive-and-upload.sh

[group('app')]
generate:
    bash scripts/tooling/generate.sh

[group('app')]
build:
    bash scripts/tooling/build.sh

[group('app')]
run:
    bash scripts/tooling/run.sh

[group('maintenance')]
clean-build:
    rm -rf .build .DerivedData app/build app/Sunclub.xcworkspace

[group('maintenance')]
clean-generated: clean-build
    rm -rf .state .venv .ruff_cache .rumdl_cache .pytest_cache .cache .mise .config
    find . -type d -name '__pycache__' -prune -exec rm -rf {} +

[group('maintenance')]
clean: clean-generated

test-unit:
    bash scripts/tooling/test_ios.sh --suite unit

test-ui:
    bash scripts/tooling/test_ios.sh --suite ui

test-python:
    uv run pytest tests -v

test: test-unit test-ui test-python

lint:
    bash scripts/tooling/lint.sh

fmt:
    bash scripts/tooling/fmt.sh

ci-lint: lint

ci-python: test-python

ci-build:
    bash scripts/tooling/ci_build.sh

ci: ci-lint ci-python test-unit test-ui ci-build
