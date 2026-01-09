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

### ios build_test

```sh
[bundle exec] fastlane ios build_test
```

Build Sample App for simulator (no code signing)

### ios build_sample

```sh
[bundle exec] fastlane ios build_sample
```

Build signed IPA for App Store / TestFlight

### ios release_testflight

```sh
[bundle exec] fastlane ios release_testflight
```

Build and upload to TestFlight

### ios test

```sh
[bundle exec] fastlane ios test
```

Run tests

### ios bump_version

```sh
[bundle exec] fastlane ios bump_version
```

Increment version number

----

This README.md is auto-generated and will be re-generated every time [_fastlane_](https://fastlane.tools) is run.

More information about _fastlane_ can be found on [fastlane.tools](https://fastlane.tools).

The documentation of _fastlane_ can be found on [docs.fastlane.tools](https://docs.fastlane.tools).
