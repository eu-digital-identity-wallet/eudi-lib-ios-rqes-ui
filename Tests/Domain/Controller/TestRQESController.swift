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
import Cuckoo
import RqesKit
@testable import EudiRQESUi

final class TestRQESController: XCTestCase {

  var eudiRQESUi: EudiRQESUi!
  var config: MockEudiRQESUiConfig!
  var controller: RQESControllerImpl!

  override func setUp() async throws {

    self.config = MockEudiRQESUiConfig()

    stub(config) { mock in
      when(mock.theme.get).thenReturn(AppTheme())
    }

    // EudiRQESUi with neither rqesService nor rqesServiceAuthorized set,
    // so every controller method must hit its guard and throw.
    self.eudiRQESUi = await .init(
      config: config,
      router: MockRouterGraph()
    )

    self.controller = RQESControllerImpl(rqesUi: eudiRQESUi)
  }

  override func tearDown() {
    self.eudiRQESUi = nil
    self.config = nil
    self.controller = nil
  }

  func testGetServiceAuthorizationUrl_WhenNoRQESService_ThenThrowsNoRQESServiceProvided() async {
    // Then
    await assertThrowsNoService {
      _ = try await self.controller.getServiceAuthorizationUrl()
    }
  }

  func testAuthorizeService_WhenNoRQESService_ThenThrowsNoRQESServiceProvided() async {
    // Then
    await assertThrowsNoService {
      _ = try await self.controller.authorizeService("authCode")
    }
  }

  func testAuthorizeCredential_WhenNoAuthorizedService_ThenThrowsNoRQESServiceProvided() async {
    // Then
    await assertThrowsNoService {
      _ = try await self.controller.authorizeCredential("authCode")
    }
  }

  func testSignDocuments_WhenNoAuthorizedService_ThenThrowsNoRQESServiceProvided() async {
    // Then
    await assertThrowsNoService {
      _ = try await self.controller.signDocuments("authCode")
    }
  }

  func testGetCredentialsList_WhenNoAuthorizedService_ThenThrowsNoRQESServiceProvided() async {
    // Then
    await assertThrowsNoService {
      _ = try await self.controller.getCredentialsList()
    }
  }

  func testGetCredentialAuthorizationUrl_WhenNoAuthorizedService_ThenThrowsNoRQESServiceProvided() async throws {
    // Given
    let credentialInfo = try await TestConstants.getCredentialInfo()
    let document = Document(id: "id", fileURL: try XCTUnwrap(URL(string: "file://internal/test.pdf")))

    // Then
    await assertThrowsNoService {
      _ = try await self.controller.getCredentialAuthorizationUrl(
        credentialInfo: credentialInfo,
        documents: [document]
      )
    }
  }
}

private extension TestRQESController {

  func assertThrowsNoService(
    _ block: () async throws -> Void,
    file: StaticString = #filePath,
    line: UInt = #line
  ) async {
    do {
      try await block()
      XCTFail("Expected EudiRQESUiError.noRQESServiceProvided to be thrown", file: file, line: line)
    } catch {
      XCTAssertEqual(
        error.localizedDescription,
        EudiRQESUiError.noRQESServiceProvided.localizedDescription,
        file: file,
        line: line
      )
    }
  }
}
