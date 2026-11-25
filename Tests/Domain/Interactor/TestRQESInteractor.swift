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

final class TestRQESInteractor: XCTestCase {
  
  var eudiRQESUi: EudiRQESUi!
  var config: MockEudiRQESUiConfig!
  var rqesController: MockRQESController!
  var interactor: RQESInteractorImpl!
  
  override func setUp() async throws {
    
    self.rqesController = MockRQESController()
    self.config = MockEudiRQESUiConfig()
    
    stub(config) { mock in
      when(mock.theme.get).thenReturn(AppTheme())
      when(mock.transactionLogger.get).thenReturn(nil)
    }
    
    self.eudiRQESUi = await .init(
      config: config,
      router: MockRouterGraph(),
      session: TestConstants.mockSession
    )
    
    self.interactor = RQESInteractorImpl(
      rqesUi: eudiRQESUi,
      rqesController: rqesController
    )
  }
  
  override func tearDown() {
    self.eudiRQESUi = nil
    self.rqesController = nil
    self.config = nil
    self.interactor = nil
  }
  
  func testCreateRQESService_WhenQtspSelected_ThenCreateAndCacheService() async throws {
    // When
    try await interactor.createRQESService(TestConstants.mockQtspData)
    
    // Then
    let service = await eudiRQESUi.getRQESService()
    XCTAssertNotNil(service)
  }
  
  func testCreateRQESService_WhenConfigProvidesTransactionLogger_ThenReadLoggerFromConfigAndCreateService() async throws {
    // Given
    let logger = MockTransactionLogger()
    stub(config) { mock in
      when(mock.transactionLogger.get).thenReturn(logger)
    }
    
    // When
    try await interactor.createRQESService(TestConstants.mockQtspData)
    
    // Then
    let service = await eudiRQESUi.getRQESService()
    XCTAssertNotNil(service)
    verify(config).transactionLogger.get()
  }
  
  func testCreateRQESService_WhenQtspSelectedButDocumentDataIsNotCached_ThenThrowError() async throws {
    // Given
    let fileUri = try XCTUnwrap(URL(string: "rqes://no_extension"))
    
    eudiRQESUi = await .init(
      config: config,
      router: MockRouterGraph(),
      session: .init(document: .init(documentName: "test", uri: fileUri))
    )
    
    interactor = RQESInteractorImpl(
      rqesUi: eudiRQESUi,
      rqesController: rqesController
    )
    
    // When
    do {
      try await interactor.createRQESService(TestConstants.mockQtspData)
      XCTFail("Error should be thrown here")
    }
    catch {
      // Then
      XCTAssertEqual(error.localizedDescription, EudiRQESUiError.noDocumentProvided.localizedDescription)
    }
  }
  
  func testGetSession_WhenSessionIsCached_ThenReturnSession() async {
    // When
    let session = await interactor.getSession()

    // Then
    XCTAssertNotNil(session)
  }
  
  func testGetQTSps_WhenConfigHasValues_ThenReturnQtsps() async {
    // Given
    stub(config) { mock in
      when(mock.rssps.get).thenReturn(
        [TestConstants.mockQtspData]
      )
    }
    
    // When
    let qtsps = await interactor.getQTSps()

    // Then
    XCTAssertTrue(!qtsps.isEmpty)
  }
  
  func testFetchCredentials_WhenCodeIsCached_ThenReturnCredentialInfoArray() async throws {
    // Given
    let expectedAuthCode = "12345"
    let mockAuthService = await TestConstants.getMockAuthorizedService()
    let expectedCredentialInfo = try await TestConstants.getCredentialInfo()
    
    stub(rqesController) { mock in
      when(mock.authorizeService(any())).thenReturn(
        mockAuthService
      )
    }
    
    stub(rqesController) { mock in
      when(mock.getCredentialsList()).thenReturn(
        [expectedCredentialInfo]
      )
    }
    
    eudiRQESUi = await .init(
      config: config,
      router: MockRouterGraph(),
      session: .init(code: expectedAuthCode)
    )
    
    interactor = RQESInteractorImpl(
      rqesUi: eudiRQESUi,
      rqesController: rqesController
    )
    
    // When
    let credentials = try await interactor.fetchCredentials().get()
    
    // Then
    XCTAssertFalse(credentials.isEmpty)
    
    let service = await eudiRQESUi.getRQESServiceAuthorized()
    XCTAssertNotNil(service)
  }
  
  func testFetchCredentials_WhenCodeIsCachedButServiceThrowsError_ThenReturnError() async {
    // Given
    let expectedAuthCode = "12345"
    let mockAuthService = await TestConstants.getMockAuthorizedService()
    
    stub(rqesController) { mock in
      when(mock.authorizeService(any())).thenReturn(
        mockAuthService
      )
    }
    
    stub(rqesController) { mock in
      when(mock.getCredentialsList()).thenThrow(EudiRQESUiError.unableToFetchCredentials)
    }
    
    eudiRQESUi = await .init(
      config: config,
      router: MockRouterGraph(),
      session: .init(code: expectedAuthCode)
    )
    
    interactor = RQESInteractorImpl(
      rqesUi: eudiRQESUi,
      rqesController: rqesController
    )
    
    // When
    do {
      let _ = try await interactor.fetchCredentials().get()
      XCTFail("Error should be thrown here")
    }
    catch {
      // Then
      XCTAssertEqual(error.localizedDescription, EudiRQESUiError.unableToFetchCredentials.localizedDescription)
    }
  }
  
  func testFetchCredentials_WhenCodeIsNotCached_ThenReturnError() async {
    // When
    do {
      let _ = try await interactor.fetchCredentials().get()
      XCTFail("Error should be thrown here")
    }
    catch {
      // Then
      XCTAssertEqual(error.localizedDescription, EudiRQESUiError.unableToFetchCredentials.localizedDescription)
    }
  }

  func testFetchCredentials_WhenCredentialInfoAlreadyCached_ThenReturnsCachedSuccess() async throws {
    // Given
    let expectedCredentialInfo = try await TestConstants.getCredentialInfo()
    let expectedCredentials = [expectedCredentialInfo]

    eudiRQESUi = await .init(
      config: config,
      router: MockRouterGraph(),
      session: .init(credentialCertificate: expectedCredentials)
    )

    interactor = RQESInteractorImpl(
      rqesUi: eudiRQESUi,
      rqesController: rqesController
    )

    // When
    let credentials = try await interactor.fetchCredentials().get()

    // Then
    XCTAssertEqual(credentials.count, expectedCredentials.count)
    verify(rqesController, never()).authorizeService(any())
    verify(rqesController, never()).getCredentialsList()
  }
  
  func testUpdateQTSP_WhenValuePassed_ThenVerifyCachedSelectedQtsp() async {
    // Given
    let expected = TestConstants.mockQtspData
    
    // When
    await interactor.updateQTSP(expected)
    
    // Then
    let stored = await eudiRQESUi.getSessionData().qtsp
    XCTAssertEqual(expected, stored)
  }
  
  func testUpdateDocument_WhenValuePassed_ThenVerifyCachedDocument() async throws {
    // Given
    let newFileUrl = try XCTUnwrap(URL(string: "file://new_path/test.pdf"))
    let expected = DocumentData(
      documentName: "test.pdf",
      uri: newFileUrl
    )
    
    // When
    await interactor.updateDocument(newFileUrl)
    
    // Then
    let stored = await eudiRQESUi.getSessionData().document
    XCTAssertEqual(expected, stored)
  }
  
  func testSaveCertificate_WhenValuePassed_ThenVerifyCachedCertificate() async throws {
    // Given
    let expected = try await TestConstants.getCredentialInfo()
    
    // When
    await interactor.saveCertificate(expected)
    
    // Then
    let stored = await eudiRQESUi.getSessionData().certificate
    XCTAssertNotNil(stored)
  }
  
  func testOpenAuthrorizationURL_WhenAuthUrlReturnFromService_ThenVerifyUrl() async throws {
    // Given
    let expectedUrl = try XCTUnwrap(URL(string: "rqes://url"))
    
    stub(rqesController) { mock in
      when(mock.getServiceAuthorizationUrl()).thenReturn(
        expectedUrl
      )
    }
    
    // When
    let result = try await interactor.openAuthrorizationURL()
    
    // Then
    XCTAssertEqual(result, expectedUrl)
  }
  
  func testOpenCredentialAuthrorizationURL_WhenSessionIsCachedAndValid_ThenReturnValidUrl() async throws {
    // Given
    let mockCredentialInfo = try await TestConstants.getCredentialInfo()
    let expectedUrl = try XCTUnwrap(URL(string: "rqes://url"))
    
    stub(rqesController) { mock in
      when(mock.getCredentialAuthorizationUrl(credentialInfo: any(), documents: any())).thenReturn(expectedUrl)
    }
    
    eudiRQESUi = await .init(
      config: config,
      router: MockRouterGraph(),
      session: .init(
        document: TestConstants.mockDocumentData,
        certificate: mockCredentialInfo
      )
    )
    
    interactor = RQESInteractorImpl(
      rqesUi: eudiRQESUi,
      rqesController: rqesController
    )
    
    // When
    let result = try await interactor.openCredentialAuthrorizationURL()
    
    // Then
    XCTAssertEqual(result, expectedUrl)
    
  }
  
  func testOpenCredentialAuthrorizationURL_WhenSessionIsCachedButCertificateIsNil_ThenThrowError() async {
    // When
    do {
      let _ = try await interactor.openCredentialAuthrorizationURL()
      XCTFail("Error should be thrown here")
    } catch {
      // Then
      XCTAssertEqual(error.localizedDescription, EudiRQESUiError.noDocumentProvided.localizedDescription)
    }
    
  }
  
  func testOpenCredentialAuthrorizationURL_WhenSessionIsCachedAndValidButServiceReturnsError_ThenThrowError() async throws {
    // Given
    let mockCredentialInfo = try await TestConstants.getCredentialInfo()
    
    stub(rqesController) { mock in
      when(mock.getCredentialAuthorizationUrl(credentialInfo: any(), documents: any())).thenThrow(EudiRQESUiError.unableToFetchCredentials)
    }
    
    eudiRQESUi = await .init(
      config: config,
      router: MockRouterGraph(),
      session: .init(
        document: TestConstants.mockDocumentData,
        certificate: mockCredentialInfo
      )
    )
    
    interactor = RQESInteractorImpl(
      rqesUi: eudiRQESUi,
      rqesController: rqesController
    )
    
    // When
    do {
      let _ = try await interactor.openCredentialAuthrorizationURL()
      XCTFail("Error should be thrown here")
    } catch {
      // Then
      XCTAssertEqual(error.localizedDescription, EudiRQESUiError.unableToFetchCredentials.localizedDescription)
    }
    
  }
  
  func testSignDocument_WhenSessionIsValidAndAuthCodeExists_ThenReturnSignedDocument() async throws {
    // Given
    let expectedAuthCode = "12345"
    let mockAuthService = await TestConstants.getMockAuthorizedService()
    let expectedUrl = try XCTUnwrap(URL(string: "rqes://file_path/file.pdf"))
    let expectedSignedDocument: Document = .init(id: "id", fileURL: expectedUrl)
    
    
    stub(rqesController) { mock in
      when(mock.authorizeService(any())).thenReturn(
        mockAuthService
      )
    }
    
    stub(rqesController) { mock in
      when(mock.signDocuments(any())).thenReturn(
        [
          .init(id: "id", fileURL: expectedUrl),
          .init(id: "id2", fileURL: expectedUrl)
        ]
      )
    }
    
    eudiRQESUi = await .init(
      config: config,
      router: MockRouterGraph(),
      session: .init(code: expectedAuthCode)
    )
    
    interactor = RQESInteractorImpl(
      rqesUi: eudiRQESUi,
      rqesController: rqesController
    )
    
    // When
    let result = try await interactor.signDocument()
    
    // Then
    XCTAssertEqual(result?.id, expectedSignedDocument.id)
  }
  
  func testSignDocument_WhenSessionIsValidButAuthCodeDoesNotExists_ThenThrowError() async {
    // When
    do {
      let _ = try await interactor.signDocument()
      XCTFail("Error should be thrown here")
    } catch {
      // Then
      XCTAssertEqual(error.localizedDescription, EudiRQESUiError.unableToSignHashDocument.localizedDescription)
    }
  }
  
  func testSignDocument_WhenSessionIsValidAndAuthCodeExistsButServiceThrowsError_ThenThrowError() async throws {
    // Given
    let expectedAuthCode = "12345"
    let mockAuthService = await TestConstants.getMockAuthorizedService()
    
    
    stub(rqesController) { mock in
      when(mock.authorizeService(any())).thenReturn(
        mockAuthService
      )
    }
    
    stub(rqesController) { mock in
      when(mock.signDocuments(any())).thenThrow(EudiRQESUiError.unableToSignHashDocument)
    }
    
    eudiRQESUi = await .init(
      config: config,
      router: MockRouterGraph(),
      session: .init(code: expectedAuthCode)
    )
    
    interactor = RQESInteractorImpl(
      rqesUi: eudiRQESUi,
      rqesController: rqesController
    )
    
    // When
    do {
      let _ = try await interactor.signDocument()
      XCTFail("Error should be thrown here")
    } catch {
      // Then
      XCTAssertEqual(error.localizedDescription, EudiRQESUiError.unableToSignHashDocument.localizedDescription)
    }
  }
  
}
