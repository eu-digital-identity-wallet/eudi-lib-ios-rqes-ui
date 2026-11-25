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
import RQESLib
@testable import EudiRQESUi

@MainActor
final class TestSignedDocumentViewModel: XCTestCase {
  var interactor: MockRQESInteractor!
  var router: MockRouterGraph!
  var viewModel: SignedDocumentViewModel<MockRouterGraph>!

  override func setUp() async throws {
    self.interactor = MockRQESInteractor()
    self.router = MockRouterGraph()
    self.viewModel = SignedDocumentViewModel(
      router: router,
      interactor: interactor
    )
  }

  override func tearDown() async throws {
    self.interactor = nil
    self.router = nil
    self.viewModel = nil
  }

  func testViewDocument_WhenCalled_ThenNavigatesToViewDocumentWithSignedFlag() async {
    // Given
    stub(router) { mock in
      when(mock.navigateTo(any())).thenDoNothing()
    }

    // When
    viewModel.viewDocument()

    // Then
    verify(router).navigateTo(equal(to: .viewDocument(true)))
  }

  func testInitiate_WhenSignDocumentThrowError_ThenSetErrorState() async {
    // Given
    let expectedError = EudiRQESUiError.noDocumentProvided

    stub(interactor) { mock in
      when(mock.signDocument()).thenThrow(expectedError)
    }

    // When
    await viewModel.initiate()

    // Then
    let state = viewModel.viewState
    XCTAssertNotNil(state.error)
    XCTAssertEqual(state.error?.title, .genericErrorMessage)
    XCTAssertEqual(state.error?.description, .genericServiceErrorMessage)

    verify(interactor, never()).getSession()
  }

  func testInitiate_WhenGetSessionReturnNil_ThenSetErrorState() async {
    // Given
    let expectedDocument = Document(
      id: "id",
      fileURL: URL(string: "uri")!
    )

    stub(interactor) { mock in
      when(mock.signDocument()).thenReturn(expectedDocument)
    }

    stub(interactor) { mock in
      when(mock.getSession()).thenReturn(nil)
    }

    stub(interactor) { mock in
      when(mock.updateDocument(any())).thenDoNothing()
    }

    // When
    await viewModel.initiate()

    // Then
    let state = viewModel.viewState
    XCTAssertNotNil(state.error)
    XCTAssertEqual(state.error?.title, .genericErrorMessage)
    XCTAssertEqual(state.error?.description, .genericErrorDocumentNotFound)
  }

  func testInitiate_WhenGenSessionReturnsEmptyDocument_ThenSetErrorState() async {
    // Given
    let mockSession : SessionData = .init()
    let expectedDocument = Document(
      id: "id",
      fileURL: URL(string: "uri")!
    )

    stub(interactor) { mock in
      when(mock.signDocument()).thenReturn(expectedDocument)
    }

    stub(interactor) { mock in
      when(mock.getSession()).thenReturn(mockSession)
    }

    stub(interactor) { mock in
      when(mock.updateDocument(any())).thenDoNothing()
    }

    // When
    await viewModel.initiate()

    // Then
    let state = viewModel.viewState
    XCTAssertNotNil(state.error)
    XCTAssertEqual(state.error?.title, .genericErrorMessage)
    XCTAssertEqual(state.error?.description, .genericErrorDocumentNotFound)
  }

  func testInitiate_WhenGenSessionReturnsSessionData_ThenSetState() async {
    // Given
    let expectedDocument = Document(
      id: "id",
      fileURL: URL(string: "uri")!
    )

    let expectedDocumentData = DocumentData(
      documentName: "documentName",
      uri: URL(string: "uri")!
    )

    let qtsp = TestConstants.mockQtspData
    let mockSession: SessionData = .init(
      document: expectedDocumentData,
      qtsp: qtsp
    )

    stub(interactor) { mock in
      when(mock.signDocument()).thenReturn(expectedDocument)
    }

    stub(interactor) { mock in
      when(mock.getSession()).thenReturn(mockSession)
    }

    stub(interactor) { mock in
      when(mock.updateDocument(any())).thenDoNothing()
    }

    // When
    await viewModel.initiate()

    // Then
    let state = viewModel.viewState
    XCTAssertEqual(state.documentName, mockSession.document?.documentName)
    XCTAssertEqual(state.qtspName, mockSession.qtsp?.name)
    XCTAssertEqual(
      state.headerConfig.appIconAndTextData.appIcon,
      Image(.euWalletLogo)
    )
    XCTAssertEqual(
      state.headerConfig.appIconAndTextData.appText,
      Image(.eudiTextLogo)
    )
    XCTAssertTrue(state.isInitialized)
  }

  func testErrorAction_WhenInvoked_ThenRetriesAndRecoversState() async {
    // Given
    let expectedDocument = Document(
      id: "id",
      fileURL: URL(string: "uri")!
    )
    let expectedDocumentData = DocumentData(
      documentName: "documentName",
      uri: URL(string: "uri")!
    )
    let qtsp = TestConstants.mockQtspData
    let mockSession: SessionData = .init(
      document: expectedDocumentData,
      qtsp: qtsp
    )

    stub(interactor) { mock in
      when(mock.signDocument())
        .thenThrow(EudiRQESUiError.noDocumentProvided)
        .thenReturn(expectedDocument)
    }

    stub(interactor) { mock in
      when(mock.getSession()).thenReturn(mockSession)
    }
    stub(interactor) { mock in
      when(mock.updateDocument(any())).thenDoNothing()
    }

    let (exp, capturedStates) = beginObservation(
      { self.viewModel.viewState },
      targetCount: 2,
      includeInitial: false
    )

    // When
    await viewModel.initiate()

    await waitUntil{ self.viewModel.viewState.error == nil }

    guard let retryAction = viewModel.viewState.error?.action else {
      XCTFail("Retry action should not be nil")
      return
    }
    retryAction()

    await fulfillment(of: [exp], timeout: 1.0)
    
    // Then
    let states = capturedStates()
    guard let firstState = states.first, let lastState = states.last else {
      XCTFail("Expected error in state, but was nil")
      return
    }

    XCTAssertNotNil(firstState.error)
    XCTAssertEqual(firstState.error?.title, .genericErrorMessage)

    XCTAssertNil(lastState.error)
    XCTAssertFalse(lastState.isLoading)
    XCTAssertEqual(lastState.documentName, expectedDocumentData.documentName)
    XCTAssertEqual(lastState.qtspName, qtsp.name)
    XCTAssertTrue(lastState.isInitialized)
    XCTAssertEqual(
      lastState.headerConfig.appIconAndTextData.appIcon,
      Image(.euWalletLogo)
    )
    XCTAssertEqual(
      lastState.headerConfig.appIconAndTextData.appText,
      Image(.eudiTextLogo)
    )
  }

  /// Initializes EudiRQESUi so that onCancel's requireInstance() does not fatalError. The retry action fires
  /// self.onCancel(), and the test waits for the cancel Task to reset the EudiRQESUi state.
  func testInitiate_WhenSessionLacksQtspName_ThenActionTriggersOnCancel() async {
    // Given
    let bootConfig = MockEudiRQESUiConfig()
    stub(bootConfig) { mock in
      when(mock.theme.get).thenReturn(AppTheme())
    }
    let eudiRQESUi = EudiRQESUi(
      config: bootConfig,
      router: router,
      state: .sign,
      session: TestConstants.mockSession
    )

    let signedDoc = Document(id: "id", fileURL: URL(string: "file://signed.pdf")!)
    let sessionWithoutQtsp = SessionData(
      document: DocumentData(documentName: "doc.pdf", uri: URL(string: "file://doc.pdf")!)
    )

    stub(interactor) { mock in
      when(mock.signDocument()).thenReturn(signedDoc)
      when(mock.getSession()).thenReturn(sessionWithoutQtsp)
      when(mock.updateDocument(any())).thenDoNothing()
    }

    await viewModel.initiate()

    guard let action = viewModel.viewState.error?.action else {
      XCTFail("action should not be nil")
      return
    }

    // When
    action()

    // Then
    let end = Date().addingTimeInterval(2.0)
    while Date() < end {
      let state = await eudiRQESUi.getState()
      if state == .none { break }
      try? await Task.sleep(nanoseconds: 20_000_000)
    }

    let finalState = await eudiRQESUi.getState()
    XCTAssertEqual(finalState, .none)
  }

  func testInitiate_WhenIsInitializedIsTrue_ThenDoesNothing() async {
    // Given
    let initialState = SignedDocumenState(
      isLoading: false,
      document: DocumentData(
        documentName: "test.pdf",
        uri: URL(string: "file://uri")!
      ),
      qtsp: TestConstants.mockQtspData,
      documentName: "test.pdf",
      qtspName: "qtsp",
      headerConfig: .init(
        appIconAndTextData: .init(
          appIcon: Image(.euWalletLogo),
          appText: Image(.eudiTextLogo)
        )
      ),
      error: nil,
      isInitialized: true
    )

    viewModel.setState { _ in initialState }

    stub(interactor) { mock in
      when(mock.signDocument()).thenReturn(nil)

      when(mock.getSession()).thenReturn(nil)

      when(mock.updateDocument(any())).thenDoNothing()
    }

    // When
    await viewModel.initiate()

    // Then
    let state = viewModel.viewState
    XCTAssertTrue(state.isInitialized)
  }
}
