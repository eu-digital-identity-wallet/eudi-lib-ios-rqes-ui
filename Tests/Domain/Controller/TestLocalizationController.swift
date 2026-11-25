/*
 * Copyright (c) 2026 European Commission
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */
import XCTest
import SwiftUI
import Cuckoo
@testable import EudiRQESUi

final class TestLocalizationController: XCTestCase {

  var config: MockEudiRQESUiConfig!
  var controller: LocalizationController!

  override func setUp() {
    self.config = MockEudiRQESUiConfig()
    self.controller = LocalizationControllerImpl(
      config: config,
      locale: .init(identifier: "en_US")
    )
  }

  override func tearDown() {
    self.config = nil
    self.controller = nil
  }
  
  func testGet_WhenTranslationIsAvailableWithoutArgs_ThenReturnsStringTranslation() {
    // Given
    let customGenericErrorTranslation = "CustomGenericError"
    stub(config) { mock in
      when(mock.translations.get).thenReturn(
        ["en_US": [.genericErrorMessage: customGenericErrorTranslation]]
      )
    }

    // When
    let result = self.controller.get(with: .genericErrorMessage)

    // Then
    XCTAssertEqual(result, customGenericErrorTranslation)
  }
  
  func testGet_WhenTranslationIsAvailableWithoutArgs_ThenReturnsLocalizedStringKeyTranslation() {
    // Given
    let customGenericErrorTranslation = "CustomGenericError"
    stub(config) { mock in
      when(mock.translations.get).thenReturn(
        ["en_US": [.genericErrorMessage: customGenericErrorTranslation]]
      )
    }

    // When
    let result: LocalizedStringKey = self.controller.get(with: .genericErrorMessage, args: [])

    // Then
    XCTAssertEqual(result, customGenericErrorTranslation.toLocalizedStringKey)
  }
  
  func testGet_WhenTranslationIsNotAvailableWithoutArgs_ThenReturnsDefaultStringTranslation() {
    // Given
    stub(config) { mock in
      when(mock.translations.get).thenReturn([:])
    }

    // When
    let result = self.controller.get(with: .genericErrorMessage)

    // Then
    XCTAssertEqual(result, LocalizableKey.genericErrorMessage.defaultTranslation(args: []))
  }
  
  func testGet_WhenTranslationIsNotAvailableWithArgs_ThenReturnsDefaultStringTranslation() {
    // Given
    stub(config) { mock in
      when(mock.translations.get).thenReturn([:])
    }

    // When
    let result: String = self.controller.get(with: .signedBy, args: ["NISCY"])

    // Then
    XCTAssertEqual(result, LocalizableKey.signedBy.defaultTranslation(args: ["NISCY"]))
  }

  @MainActor
  func testEnvironmentValuesLocalizationController_WhenSettingAValue_ThenStoresTheValue() {
    // Given
    var env = EnvironmentValues()
    let preview = PreviewLocalizationController()

    // When
    env.localizationController = preview

    // Then
    XCTAssertTrue(env.localizationController is PreviewLocalizationController)
  }

  /// Initializes the SDK so that DIGraph is loaded and _config is set.
  @MainActor
  func testEnvironmentValuesLocalizationController_WhenReadingTheDefaultValue_ThenResolvesFromTheDIGraph() async {
    // Given
    let bootConfig = MockEudiRQESUiConfig()
    stub(bootConfig) { mock in
      when(mock.theme.get).thenReturn(AppTheme())
    }
    _ = EudiRQESUi(config: bootConfig)

    // When
    let resolved = EnvironmentValues().localizationController

    // Then
    XCTAssertTrue(resolved is LocalizationControllerImpl)
  }

  @MainActor
  func testEnvironmentValuesLocalizationController_WhenPreviewEnvIsSet_ThenReturnsPreview() throws {
    // Given
    setenv("XCODE_RUNNING_FOR_PREVIEWS", "1", 1)
    defer { unsetenv("XCODE_RUNNING_FOR_PREVIEWS") }

    try XCTSkipUnless(
      ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1",
      "ProcessInfo.environment does not reflect runtime env changes on this platform"
    )

    // When
    let resolved = EnvironmentValues().localizationController

    // Then
    XCTAssertTrue(resolved is PreviewLocalizationController)
  }

  func testPreviewLocalizationController_WhenGettingAKey_ThenReturnsTheDefaultString() {
    // Given
    let preview = PreviewLocalizationController()

    // When
    let result = preview.get(with: .signDocument)

    // Then
    XCTAssertEqual(result, LocalizableKey.signDocument.defaultTranslation(args: []))
  }

  func testPreviewLocalizationController_WhenGettingAKeyWithArgs_ThenReturnsTheFormattedDefaultString() {
    // Given
    let preview = PreviewLocalizationController()

    // When
    let result: String = preview.get(with: .signedBy, args: ["NISCY"])

    // Then
    XCTAssertEqual(result, LocalizableKey.signedBy.defaultTranslation(args: ["NISCY"]))
  }

  func testPreviewLocalizationController_WhenGettingALocalizedStringKeyWithArgs_ThenReturnsThePlaceholder() {
    // Given
    let preview = PreviewLocalizationController()

    // When
    let result: LocalizedStringKey = preview.get(with: .signDocument, args: [])

    // Then
    XCTAssertEqual(result, LocalizedStringKey("Mocked Translation"))
  }
}
