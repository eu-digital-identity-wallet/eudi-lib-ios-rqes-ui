# EUDI Remote Qualified Electronic Signature (RQES) UI library for iOS

[![License: Apache 2.0](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](https://opensource.org/licenses/Apache-2.0)
[![Swift](https://img.shields.io/badge/Swift-6.2-F05138.svg?logo=swift)](https://swift.org)
[![SwiftUI](https://img.shields.io/badge/SwiftUI-enabled-007AFF.svg?logo=swift)](https://developer.apple.com/xcode/swiftui/)
[![iOS](https://img.shields.io/badge/iOS-17%2B-000000.svg?logo=apple)](https://developer.apple.com/ios/)
[![SonarCloud](https://img.shields.io/badge/SonarCloud-enabled-F3702A.svg?logo=sonarcloud)](https://sonarcloud.io)
[![Dependency Check](https://img.shields.io/badge/Dependency--Check-enabled-005A9C.svg)](https://owasp.org/www-project-dependency-check/)
[![Gitleaks](https://img.shields.io/badge/Gitleaks-enabled-orange.svg)](https://github.com/gitleaks/gitleaks)

:heavy_exclamation_mark: **Important!** Before you proceed, please read
the [EUDI Wallet Reference Implementation project description](https://github.com/eu-digital-identity-wallet/.github/blob/main/profile/reference-implementation.md)

----

## Table of contents

* [Overview](#overview)
* [Requirements](#requirements)
* [Installation](#installation)
* [How to use](#how-to-use)
  * [Configuration](#configuration)
  * [Setup](#setup)
  * [Initialization](#initialization)
* [Theming and rebranding](#theming-and-rebranding)
  * [Colors and typography](#colors-and-typography)
  * [Logos and images](#logos-and-images)
  * [Text and labels](#text-and-labels)
* [How to contribute](#how-to-contribute)
* [License](#license)

## Overview

This package provides the core and UI functionality for the EUDI Wallet, focusing on the Remote Qualified Electronic Signature (RQES) service. 
The `EudiRQESUi` actor defines methods for setting up and using the SDK. The SDK offers compile-time configuration capabilities through the `EudiRQESUiConfig` protocol.

## Requirements

- iOS 17 or higher

## Installation

### Swift Package Manager

Open `Xcode`, go to `File -> Swift Packages -> Add Package Dependency`, and enter `https://github.com/eu-digital-identity-wallet/eudi-lib-ios-rqes-ui.git`

You can also add `EudiRQESUi` as a dependency to your `Package.swift`:
```swift
dependencies: [
  .package(url: "https://github.com/eu-digital-identity-wallet/eudi-lib-ios-rqes-ui.git", from: "LATEST_RELEASE")
]
```

```swift
 targets: [
    .target(
      dependencies: [
        .product(
          name: "EudiRQESUi",
          package: "eudi-lib-ios-rqes-ui"
        )
      ]
    )
```

## How to use

### Configuration

Implement the `EudiRQESUiConfig` protocol and supply all the necessary options for the SDK.

```swift
final class RQESConfigImpl: EudiRQESUiConfig {

  var rssps: [QTSPData]

  // Optional. Default is false.
  var printLogs: Bool

  // Optional. Default English translations will be used if not set.
  var translations: [String : [LocalizableKey : String]]

  // Optional. Default theme will be used if not set.
  var theme: ThemeProtocol

  // Optional. Default is nil (signing transactions are not logged).
  var transactionLogger: (any TransactionLogger)?
}
```

`TransactionLogger` comes from `MdocDataModel18013`. When set, the SDK records one
`TransactionEntry.signingSealing` entry per signed document through the underlying
`RqesKit` service, for both completed and failed signing attempts. The entry's
`interactingPartyName` is the `name` of the selected `QTSPData`. Store or update entries
by `transactionIdentifier`; logger errors never affect signing.

Example:

```swift
final class RQESConfigImpl: EudiRQESUiConfig {

  var rssps: [QTSPData] {
    return .init(
            name: "your_dev_name",
            rsspId: "your_dev_rssp",
            tsaUrl: "your_dev_tsa",
            clientId: "your_dev_clientid",
            clientSecret: "your_dev_secret",
            authFlowRedirectionURI: "your_registered_deeplink",
            hashAlgorithm: .SHA256,
            includeRevocationInfo: false
        )
  }

  var printLogs: Bool {
    true
  }
}
```

### Setup

Register the `authFlowRedirectionURI` in your application's plist to ensure the RQES Service can trigger your application.
It is the application's responsibility to retrieve the `code` query parameter from the deep link and pass it to the SDK to continue the flow.

```Xml
<array>
	<dict>
		<key>CFBundleTypeRole</key>
		<string>Editor</string>
		<key>CFBundleURLName</key>
		<string>$(PRODUCT_BUNDLE_IDENTIFIER)</string>
		<key>CFBundleURLSchemes</key>
		<array>
			<string>rqes</string>
		</array>
	</dict>
</array>
```

Alternatively, you can use universal app links with associated domains [Apple Documentation](https://developer.apple.com/documentation/xcode/supporting-associated-domains)

Initialize the SDK by providing your configuration. You must first ensure instance availability before performing any actions

```swift
let eudiRQESUi: EudiRQESUi
do {
  eudiRQESUi = try EudiRQESUi.instance()
} catch {
  eudiRQESUi = await EudiRQESUi.init(config: rqes_config)
}
```

### Initialization

Start the signing process by providing your TopViewController and the URL of the selected file.

```swift
try await EudiRQESUi.instance().initiate(
  on: view_controller,
  fileUrl: file_url
)
```

Resume the signing process once the `authFlowRedirectionURI` triggers your application following the PID presentation process. 
Provide your TopViewController and the extracted code from the `authFlowRedirectionURI` deep link.

```swift
try await EudiRQESUi.instance().resume(
  on: view_controller,
  authorizationCode: code
)
```

If you are using SwiftUI, you can retrieve the TopViewController using the bundled SDK's UIApplication extension function.
Please note that if the application is transitioning from the background to the foreground, this function may return nil for the first ~500 milliseconds.

```swift
let controller = await UIApplication.shared.topViewController()
```

## Theming and rebranding

The SDK renders its own screens with **its own theme** — your app's global styling (tint color, fonts, etc.) is not applied to them. It follows the system light/dark setting automatically (the colors and the wordmark that ship with the SDK provide matching light/dark variants). The theme is resolved once, from the `theme` you set on your `EudiRQESUiConfig`, when you create the `EudiRQESUi` instance — so it is effectively start-up configuration.

You can rebrand the SDK along three independent axes, all wired through your `EudiRQESUiConfig`:

| What you change     | How                                                | Types / resources                                                                       |
|---------------------|----------------------------------------------------|-----------------------------------------------------------------------------------------|
| Colors & typography | Override `theme`                                   | `ThemeProtocol`, `ColorManagerProtocol`, `TypographyManagerProtocol`, `TypographyStyle` |
| Logos & images      | Replace the image assets shipped in the SDK bundle | `Images.xcassets` (`euWalletLogo`, `eudiTextLogo`, …)                                    |
| Text & labels       | Override `translations`                            | `LocalizableKey` (see [Configuration](#configuration))                                   |

> The public theming types live under `Sources/Infrastructure/Theme` (`ThemeProtocol`, `ColorManagerProtocol`, `TypographyManagerProtocol`, `TypographyStyle`). The SDK's built-in implementations (`AppTheme`, `ColorManager`, `TypographyManager`) are `internal`, so you supply your own conforming types rather than tweaking the defaults. Because the defaults are not visible outside the SDK, a custom `ThemeProtocol` must provide **both** `color` and `font` (there is no partial override) — mirror the defaults for the axis you don't intend to change.

### Colors and typography

Override the `theme` property of your config and return a custom `ThemeProtocol`. A theme is simply a colors provider plus a typography provider.

**Colors.** Implement `ColorManagerProtocol`; every role is a SwiftUI `Color` and all nine are required. The built-in defaults fall into three groups: the **brand** colors `success`, `successBackground` and `groupedBackground` ship as asset-catalog entries with light/dark variants; the **semantic** colors `primaryLabel`, `secondaryLabel`, `background` and `accent` resolve to the matching UIKit adaptive colors (`.label`, `.secondaryLabel`, `.systemBackground`, `.systemBlue`); and the **system** colors `black` and `white` resolve to plain black/white.

```swift
import SwiftUI
import EudiRQESUi

struct BrandColors: ColorManagerProtocol {
  var black: Color { .black }
  var white: Color { .white }

  var success: Color { Color(red: 0.17, green: 0.49, blue: 0.04) }
  var successBackground: Color { Color(red: 0.89, green: 0.93, blue: 0.91) }
  var groupedBackground: Color { Color(red: 0.92, green: 0.95, blue: 0.99) }

  var primaryLabel: Color { .primary }
  var secondaryLabel: Color { .secondary }
  var background: Color { Color(.systemBackground) }
  var accent: Color { Color("BrandAccent") } // e.g. from your app's asset catalog
}
```

**Typography.** Implement `TypographyManagerProtocol`; each of the 15 roles returns a `TypographyStyle(font:spacing:)`. Bundle your font files in your app target and reference them with `Font.custom(_:size:relativeTo:)` — passing `relativeTo:` keeps Dynamic Type scaling. Return `.system(...)` for any role you want to leave as the system font.

```swift
import SwiftUI
import EudiRQESUi

struct BrandTypography: TypographyManagerProtocol {

  private func custom(_ name: String, _ size: CGFloat, _ relativeTo: Font.TextStyle) -> TypographyStyle {
    TypographyStyle(font: .custom(name, size: size, relativeTo: relativeTo), spacing: 0)
  }

  var displayLarge: TypographyStyle  { custom("Brand-Bold", 34, .largeTitle) }
  var displayMedium: TypographyStyle { custom("Brand-Bold", 28, .title) }
  var displaySmall: TypographyStyle  { custom("Brand-Bold", 22, .title2) }

  var headlineLarge: TypographyStyle  { custom("Brand-Medium", 20, .title3) }
  var headlineMedium: TypographyStyle { custom("Brand-Medium", 17, .headline) }
  var headlineSmall: TypographyStyle  { custom("Brand-Medium", 15, .subheadline) }

  var titleLarge: TypographyStyle  { custom("Brand-Medium", 28, .title) }
  var titleMedium: TypographyStyle { custom("Brand-Medium", 22, .title2) }
  var titleSmall: TypographyStyle  { custom("Brand-Medium", 20, .title3) }

  var bodyLarge: TypographyStyle  { custom("Brand-Regular", 17, .body) }
  var bodyMedium: TypographyStyle { custom("Brand-Regular", 16, .callout) }
  var bodySmall: TypographyStyle  { custom("Brand-Regular", 13, .footnote) }

  var labelLarge: TypographyStyle  { custom("Brand-Medium", 17, .headline) }
  var labelMedium: TypographyStyle { custom("Brand-Regular", 12, .caption) }
  var labelSmall: TypographyStyle  { custom("Brand-Regular", 11, .caption2) }
}
```

Wire both providers into a theme and set it on your config:

```swift
struct BrandTheme: ThemeProtocol {
  var color: ColorManagerProtocol { BrandColors() }
  var font: TypographyManagerProtocol { BrandTypography() }
}

final class RQESConfigImpl: EudiRQESUiConfig {

  var rssps: [QTSPData] { ... }

  // Custom theme
  var theme: ThemeProtocol { BrandTheme() }
}
```

> **Building the SDK from source?** As an alternative to a custom `ColorManagerProtocol`, add a colorset named after the role (e.g. `accent`, `primaryLabel`, `success`) to `Sources/Resources/Colors.xcassets`; a matching-name entry takes precedence over the built-in default, so you can restyle individual roles without supplying a whole theme. Give it light and dark variants to keep adapting to the system appearance.

> **Building the SDK from source?** As an alternative to a custom `TypographyManagerProtocol`, drop your `.ttf`/`.otf` files into `Sources/Resources/` and add an `RQESFontConfig.plist` mapping the weight keys `bold`, `medium` and `regular` to the fonts' PostScript names. The bundled `TypographyManager` auto-registers the fonts at start-up and reads the plist; missing or empty entries fall back to system fonts.
> ```xml
> <dict>
>   <key>bold</key>    <string>YourFont-Bold</string>
>   <key>medium</key>  <string>YourFont-Medium</string>
>   <key>regular</key> <string>YourFont-Regular</string>
> </dict>
> ```

### Logos and images

The header and success screens show the EU Wallet mark and the EUDI wordmark, and several screens use status/step icons. These ship in the SDK's own asset catalog (`Sources/Resources/Images.xcassets`) and are referenced through generated symbols such as `Image(.euWalletLogo)` and `Image(.eudiTextLogo)`; they are **not** exposed through config. Unlike Android resource merging, iOS asset catalogs are bundled per-module, so you cannot shadow them from your app — rebrand them by **replacing the assets in the SDK bundle when you build the SDK from source / vendor it**, keeping the same asset names so the `Image(.…)` references keep resolving.

| Asset                               | Used for                          | Dark variant             |
|-------------------------------------|-----------------------------------|--------------------------|
| `euWalletLogo`                      | EU Wallet mark (header & success) | no                       |
| `eudiTextLogo`                      | EUDI wordmark (header & success)  | yes (`eudiTextLogoDark`) |
| `verified`                          | Relying-party "verified" badge    | no                       |
| `verifiedUser`                      | Document "verified user" icon     | no                       |
| `gpdGood`                           | Validation indicator              | no                       |
| `stepOne` / `stepTwo` / `stepThree` | Step indicators                   | no                       |

For an asset that has a dark variant (the wordmark), provide both the light and the `…Dark` image so the SDK keeps adapting to the system appearance.

### Text and labels

All user-facing copy is overridden through `translations` (see [Configuration](#configuration)): map any `LocalizableKey` to your own wording, keyed by locale identifier. Anything you don't override falls back to the built-in English defaults. For keys that take a runtime value, keep the `%@` placeholder where the value should be inserted (for example `LocalizableKey.signedBy`).

```swift
var translations: [String: [LocalizableKey: String]] {
  [
    "en": [
      .selectDocument: "Choose a document",
      .signedBy: "Signed by %@"
    ],
    "de": [
      .selectDocument: "Dokument auswählen",
      .signedBy: "Signiert von %@"
    ]
  ]
}
```

## How to contribute

We welcome contributions to this project. To ensure that the process is smooth for everyone
involved, follow the guidelines found in [CONTRIBUTING.md](CONTRIBUTING.md).

## License

Copyright (c) 2025 European Commission

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
