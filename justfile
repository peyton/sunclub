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

[group('web')]
web-serve PORT='8000':
    port="{{PORT}}"; port="${port#PORT=}"; cd web && uv run python -m http.server "$port"

[group('web')]
web-check:
    mise exec -- prettier --check "web/**/*.{html,css}"
    uv run python -m scripts.web.validate_static_site web

[group('web')]
web-fmt:
    mise exec -- prettier --write "web/**/*.{html,css}"

[group('web')]
web-build: web-check
    rm -rf .build/web
    mkdir -p .build/web
    cp -R web/. .build/web/

[group('web')]
web-package VERSION='local': web-build
    version="{{VERSION}}"; version="${version#VERSION=}"; uv run python -m scripts.web.package_static_site --version "$version"

[group('web')]
web-release-tag VERSION:
    VERSION={{VERSION}} bash scripts/web/release-tag.sh

[group('cloudflare')]
cloudflare-status:
    uv run python -m scripts.cloudflare.pages status
    uv run python -m scripts.cloudflare.email status

[group('cloudflare')]
cloudflare-pages-setup:
    uv run python -m scripts.cloudflare.pages setup

[group('cloudflare')]
cloudflare-pages-dns:
    uv run python -m scripts.cloudflare.pages setup-dns

[group('cloudflare')]
cloudflare-pages-deploy BRANCH='master': web-build
    uv run python -m scripts.cloudflare.pages_deploy --branch "{{BRANCH}}"

[group('cloudflare')]
cloudflare-pages-status:
    uv run python -m scripts.cloudflare.pages status

[group('cloudflare')]
cloudflare-email-setup:
    uv run python -m scripts.cloudflare.email setup

[group('cloudflare')]
cloudflare-email-status:
    uv run python -m scripts.cloudflare.email status

[group('cloudflare')]
cloudflare-check: web-check
    uv run python -m scripts.cloudflare.common check
    uv run python -m scripts.cloudflare.pages status
    uv run python -m scripts.cloudflare.email status

[group('app')]
appstore-archive:
    bash scripts/appstore/archive-and-upload.sh

[group('app')]
appstore-submit-dry-run:
    bash scripts/appstore/submit-review.sh --dry-run

[group('app')]
appstore-submit-review:
    bash scripts/appstore/submit-review.sh --submit

[group('app')]
release-tag VERSION:
    VERSION={{VERSION}} bash scripts/appstore/release-tag.sh

[group('app')]
release-testflight VERSION:
    VERSION={{VERSION}} bash scripts/appstore/release-tag.sh

[group('app')]
generate:
    bash scripts/tooling/generate.sh

[group('app')]
visual-assets:
    xcrun swift scripts/generate-visual-assets.swift

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

[group('cloudkit')]
cloudkit-save-token:
    bash scripts/cloudkit/save-token.sh

[group('cloudkit')]
cloudkit-doctor:
    bash scripts/cloudkit/doctor.sh

[group('cloudkit')]
cloudkit-ensure-container:
    bash scripts/cloudkit/ensure-container.sh

[group('cloudkit')]
cloudkit-export-schema:
    bash scripts/cloudkit/export-schema.sh

[group('cloudkit')]
cloudkit-validate-schema:
    bash scripts/cloudkit/validate-schema.sh

[group('cloudkit')]
cloudkit-import-schema:
    bash scripts/cloudkit/import-schema.sh

[group('cloudkit')]
cloudkit-reset-dev:
    bash scripts/cloudkit/reset-development.sh

test-unit:
    bash scripts/tooling/test_ios.sh --suite unit

test-ui:
    bash scripts/tooling/test_ios.sh --suite ui

test-python:
    uv run pytest tests -v

test: test-unit test-ui test-python

lint: web-check
    bash scripts/tooling/lint.sh

fmt: web-fmt
    bash scripts/tooling/fmt.sh

ci-lint: lint

ci-python: test-python

ci-build:
    bash scripts/tooling/ci_build.sh

ci: ci-lint ci-python test-unit test-ui ci-build
