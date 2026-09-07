# OpenGUI for WorkBuddy 0.2.0

Public testing prerelease for WorkBuddy 5.5.3 or newer on macOS arm64/x64.

- Install the prebuilt package, private Node, MCP, Skill and lifecycle Hooks through one installer, without a source build or Xcode.
- Control authorized Android devices from screenshots while keeping a separate read-only phone mirror available.
- Continue unfinished tasks through host lifecycle Hooks and preserve unrelated configuration and previous packages during upgrades.

Finish existing phone tasks, close their mirrors and quit WorkBuddy. Download `opengui-workbuddy-0.2.0-install.command` and its `.sha256`, verify the checksum, then run the installer with `bash`. Reopen WorkBuddy, trust the OpenGUI MCP and select `/opengui`; first request read-only device discovery.

This prerelease is for testing. Automated tests, packaged startup and an isolated installation without system Node have passed locally. Real WorkBuddy desktop, phone actions, two-device conflicts and host stop/continuation acceptance remain incomplete. It is not a stable or marketplace-approved release.
