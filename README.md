# Sunclub

## Source Availability and License

Sunclub is source-available, not open source. Copyright (c) 2026 Peyton
Randolph. All rights reserved.

This repository is available under the unmodified [PolyForm Strict License
1.0.0](LICENSE). The license does not permit source redistribution, binary
redistribution, sublicensing, public fork distribution, App Store or other
marketplace publication, or modified or derivative works. Commercial use is not
licensed. No trademark rights are granted. See [NOTICE](NOTICE) for the
ownership notice.

The iOS app lives in [app/](app); the static site lives in [web/](web).

```sh
just bootstrap
just run
```

Local builds use SunclubDev and generate the workspace as needed. Bootstrap
installs locked tools and Python dependencies; local Tuist caching is optional
with `just cache-setup`.

- [Agent entrypoint](AGENTS.md)
- [Architecture and feature recipe](docs/architecture.md)
- [Command reference](docs/commands.md)
- [App overview](app/README.md)
- [App automation](docs/app-automation.md)
- [Release gates](docs/release-gates.md)
- [TestFlight](docs/testflight-release.md) and [App Review](docs/app-store-submission.md)
- [Website deployment](docs/web-release.md) and [CloudKit setup](docs/cloudkit-setup.md)

Sunclub stores history locally, supports private iCloud revision sync and local
backup export/import. Imported history stays local until explicitly published
from Recovery & Changes. Automation permissions are visible in Settings.
