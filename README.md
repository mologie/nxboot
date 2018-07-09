# nxboot

This application enables provisioning a Tegra X1 powered device with early boot code using an iOS device. For example, you may use this application to start the Hekate Bootloader or the Lakka Linux Distrobution (RetroArch) on a supported Nintendo Switch.

The file nxboot.m wraps nxboot's functionality as standalone command-line tool and works on macOS and iOS.

## Features

* Fusée and ShofEL2 (Coreboot/Linux) payloads are supported
* Store multiple payloads and easily switch between them

## Prerequisites

* A jailbroken iOS device with firmware 10.0-11.3
* A USB 3 Type A to Type C cable
* An OTG (Lightning to USB 2.0 or 3.0) adapter. Apple's costs $35 and cheaper third-party adapters may work.

## Disclaimer

Early boot code has full access to the device it runs on and can damage it. No boot code is shipped with this application. Responsibility for consequences of using this application and executing boot code remains with the user.

## Installation

This iOS app is available on Cydia (com.mologie.nxboot). The `nxboot` command line utility is available at:

TODO: Link to nxboot utility

## License

All included source code is licensed under the GPLv2.

TODO: Bundled payload licenses?

## Attribution and Prior Work

CVE-2018-6242 was discovered by Kate Temkin (@ktemkin) and failoverfl0w (@failoverfl0w). Fusée Gelée was implemented by @ktemkin; ShofEL2 was implemented by @failoverfl0w.

JustBrandonT has implemented a proof-of-concept Fusée app for iOS 11.1 and earlier at [GBAtemp](https://gbatemp.net/threads/payload-loader-for-ios.504799/). This application was developed independently of JustBrandonT's work and is compatible with iOS 10.0-11.3.
