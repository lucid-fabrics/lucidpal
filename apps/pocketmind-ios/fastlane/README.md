fastlane documentation
----

# Installation

Make sure you have the latest version of the Xcode command line tools installed:

```sh
xcode-select --install
```

For _fastlane_ installation instructions, see [Installing _fastlane_](https://docs.fastlane.tools/#installing-fastlane)

# Available Actions

## iOS

### ios generate

```sh
[bundle exec] fastlane ios generate
```

Regenerate .xcodeproj from project.yml using xcodegen

### ios prepare

```sh
[bundle exec] fastlane ios prepare
```

Enable Developer Mode on device and verify connectivity (USB or Wi-Fi)

### ios device

```sh
[bundle exec] fastlane ios device
```

Prepare device, build debug build, and install on connected iPhone

### ios beta

```sh
[bundle exec] fastlane ios beta
```

Build release and upload to TestFlight

### ios release

```sh
[bundle exec] fastlane ios release
```

Build release and submit to App Store

----

This README.md is auto-generated and will be re-generated every time [_fastlane_](https://fastlane.tools) is run.

More information about _fastlane_ can be found on [fastlane.tools](https://fastlane.tools).

The documentation of _fastlane_ can be found on [docs.fastlane.tools](https://docs.fastlane.tools).
