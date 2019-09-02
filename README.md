# NXBoot

This application enables provisioning a Tegra X1 powered device with early boot code using an iOS or macOS device. For example, you may use this application to start the Hekate Bootloader or the Lakka Linux Distrobution (RetroArch) on a supported Nintendo Switch.

**Disclaimer:** Early boot code has full access to the device it runs on and can damage it. No boot code is shipped with this application. Responsibility for consequences of using this application and executing boot code remains with the user.

## Released Features

* Command line tool for iOS and macOS
* Native app for iOS
* Fusée and ShofEL2 (Coreboot/Linux) payloads are supported
* Store multiple payloads and easily switch between them
* Install payloads via iTunes File Transfer or any iCloud/Files-Compatible file transfer app
* Auto-boot, just connect your device while the app is opened

## Planned Features

There is no ETA on those, it's just a bunch of ideas that I think are nice to have for this app:

* Managed payload profiles with auto-updates (always have the latest Hekate etc. available without any effort)
* Optional Substrate tweak that disables the unsupported device message when a Switch is connected
* macOS GUI (currently limited to command-line tool)
* iOS 7+ support (currently requires iOS 10+)

## Prerequisites

* A jailbroken iOS device with firmware 10.0-12.4 (later iOS versions are most likely fine too)
* Proper sandbox patches installed by the jailbreak (unc0ver works as-is)
* A USB 3 Type A to Type C cable
* An OTG (Lightning to USB 2.0 or 3.0) adapter. Apple's costs $35 and cheaper third-party adapters may work.

## Installation

For installation instructions please visit the [project homepage at mologie.github.io](https://mologie.github.io/nxboot/).

## Components

* NXBoot: The feature-complete iOS GUI for iOS 10+
* NXBootLegacy: Experiments to make NXBoot work under iOS 7+, incomplete
* NXBootMac: Experiments for a macOS GUI for NXBoot
* NXBootCmd(Mac): iOS and macOS command line tool for injecting payloads
* NXBootKit(Mac): The framework that powers the above tools

## License

All included source code is licensed under the GPLv3. Pull requests must be made available under the same license.

## Attribution and Prior Work

CVE-2018-6242 was discovered by Kate Temkin (@ktemkin) and fail0verflow (@fail0verflow). Fusée Gelée was implemented by @ktemkin; ShofEL2 was implemented by @fail0verflow.

JustBrandonT has implemented a proof-of-concept Fusée app for iOS 11.1 and earlier at [GBAtemp](https://gbatemp.net/threads/payload-loader-for-ios.504799/). This application was developed independently of JustBrandonT's work.
