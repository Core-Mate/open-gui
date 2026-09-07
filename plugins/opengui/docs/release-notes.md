# OpenGUI for Codex 0.1.0

Public testing prerelease for local Codex on macOS arm64/x64.

- Install the prebuilt plugin with a host-specific installer that downloads and verifies private Node, with no source build or Xcode.
- Control authorized Android devices from screenshots, or view a read-only device wall.
- Keep existing plugin settings and previous packages, with explicit conflict checks and source recovery during upgrades.

Download `opengui-codex-0.1.0-install.command` and its `.sha256`, verify the checksum, then run the installer with `bash`. Codex CLI with plugin support is required. Start a new Codex chat after installation and first request read-only device discovery.

This prerelease is for testing. Automated tests and isolated installer checks have passed locally; desktop, real-phone and two-device acceptance remain incomplete. It is not a stable or directory-approved release.
