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
final class TestDocumentSelectionViewModel: XCTestCase {
  var interactor: MockRQESInteractor!
  var router: MockRouterGraph!
  var viewModel: DocumentSelectionViewModel<MockRouterGraph>!

  override func setUp() async throws {
    self.interactor = MockRQESInteractor()
    self.router = MockRouterGraph()
    self.viewModel = DocumentSelectionViewModel(
      router: router,
      interactor: interactor
    )
  }

  override func tearDown() async throws {
    self.interactor = nil
    self.router = nil
    self.viewModel = nil
  }

  func testInitiate_WhenGetSessionReturnSessionData_ThenReturnSuccess() async {
    // Given
    let expectedQTSPName = "Wallet-Centric"
    let expectedSession: SessionData = .init(
      document: TestConstants.mockDocumentData,
      qtsp: TestConstants.mockQtspData
    )

    stub(interactor) { stub in
      when(stub.getSession()).thenReturn(expectedSession)
    }

    // When
    await viewModel.initiate()

    // Then
    let state = viewModel.viewState
    XCTAssertFalse(state.isLoading)
    XCTAssertNil(state.error)
    XCTAssertEqual(
      state.documentSelection?.mainText,
      .custom(TestConstants.mockDocumentData.documentName)
    )
    XCTAssertEqual(
      state.qtspServiceSelection?.mainText,
      .custom(expectedQTSPName)
    )
    XCTAssertEqual(
      state.certificateSelection?.mainText,
      .selectCertificate
    )
  }

  func testInitiate_WhenGetSessionReturnSessionDataWithNilQtsp_ThenReturnSuccess() async {
    // Given
    let expectedSession: SessionData = .init(
      document: TestConstants.mockDocumentData
    )

    stub(interactor) { stub in
      when(stub.getSession()).thenReturn(expectedSession)
    }

    // When
    await viewModel.initiate()

    // Then
    let state = viewModel.viewState
    XCTAssertFalse(state.isLoading)
    XCTAssertNil(state.error)
    XCTAssertEqual(
      state.documentSelection?.mainText,
      .custom(TestConstants.mockDocumentData.documentName)
    )
    XCTAssertEqual(
      state.qtspServiceSelection?.mainText,
      .selectService
    )
    XCTAssertNil(state.certificateSelection?.mainText)
  }

  func testInitiate_WhenGetSessionReturnSessionData_ThenVerifyViewDocumentCalled() async {
    // Given
    let expectedSession: SessionData = .init(
      document: TestConstants.mockDocumentData
    )

    stub(router) { mock in
      when(mock.navigateTo(any())).thenDoNothing()
    }

    stub(interactor) { stub in
      when(stub.getSession()).thenReturn(expectedSession)
    }

    // When
    await viewModel.initiate()

    guard let action = viewModel.viewState.documentSelection?.action else {
      XCTFail("Action closure not set in documentSelection")
      return
    }

    action()

    // Then
    verify(router).navigateTo(equal(to: .viewDocument(false)))
  }

  func testInitiate_WhenGetSessionReturnSessionData_ThenVerifySelectService() async {
    // Given
    let expectedSession: SessionData = .init(
      document: TestConstants.mockDocumentData
    )

    stub(router) { mock in
      when(mock.navigateTo(any())).thenDoNothing()
    }

    stub(interactor) { stub in
      when(stub.getSession()).thenReturn(expectedSession)
    }

    // When
    await viewModel.initiate()

    guard let action = viewModel.viewState.qtspServiceSelection?.action else {
      XCTFail("Action closure not set in documentSelection")
      return
    }

    action()

    // Then
    verify(router).navigateTo(equal(to: .serviceSelection))
  }

  func testInitiate_WhenGetSessionReturnSessionData_ThenVerifySelectCertificate() async {
    // Given
    let expectedSession: SessionData = .init(
      document: TestConstants.mockDocumentData,
      qtsp: TestConstants.mockQtspData
    )

    stub(router) { mock in
      when(mock.navigateTo(any())).thenDoNothing()
    }

    stub(interactor) { stub in
      when(stub.getSession()).thenReturn(expectedSession)
    }

    // When
    await viewModel.initiate()

    guard let action = viewModel.viewState.certificateSelection?.action else {
      XCTFail("Action closure not set in documentSelection")
      return
    }

    action()

    // Then
    verify(router).navigateTo(equal(to: .credentialSelection))
  }

  func testErrorAction_WhenInvoked_ThenRetriesAndRecoversState() async {
    // Given
    let expectedQTSPName = "Wallet-Centric"
    let sessionWithNilDoc: SessionData = .init()
    let sessionWithDoc = SessionData(
      document: TestConstants.mockDocumentData,
      qtsp: TestConstants.mockQtspData
    )

    stub(interactor) { stub in
      when(stub.getSession()).thenReturn(sessionWithNilDoc)
    }

    stub(interactor) { stub in
      when(stub.getSession()).thenReturn(sessionWithNilDoc, sessionWithDoc)
    }

    let (exp, capturedStates) = beginObservation(
      { self.viewModel.viewState },
      targetCount: 2
    )

    // When
    await viewModel.initiate()

    guard let retryAction = viewModel.viewState.error?.action else {
      XCTFail("Retry action is nil")
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

    XCTAssertNil(lastState.error)
    XCTAssertFalse(lastState.isLoading)
    XCTAssertEqual(
      lastState.documentSelection?.mainText,
      .custom(TestConstants.mockDocumentData.documentName)
    )
    XCTAssertEqual(
      lastState.qtspServiceSelection?.mainText,
      .custom(expectedQTSPName)
    )
    XCTAssertEqual(
      lastState.certificateSelection?.mainText,
      .selectCertificate
    )
  }

  func testInitiate_WhenGetSessionReturnSessionDataWithNilDocumentName_ThenReturnSuccess() async {
    // Given
    let expectedSession: SessionData = .init()
    let expectedError = ContentErrorView.Config(
      title: .genericErrorMessage,
      description: .genericErrorDocumentNotFound,
    )

    stub(interactor) { stub in
      when(stub.getSession()).thenReturn(expectedSession)
    }

    // When
    await viewModel.initiate()

    // Then
    let state = viewModel.viewState
    XCTAssertFalse(state.isLoading)
    XCTAssertEqual(state.error, expectedError)
  }

  func testViewDocument_WhenCalled_ThenNavigatesToViewDocument() async {
    // Given
    stub(router) { mock in
      when(mock.navigateTo(any())).thenDoNothing()
    }

    // When
    viewModel.viewDocument()

    // Then
    verify(router).navigateTo(equal(to: .viewDocument(false)))
  }

  func testSelectService_WhenCalled_ThenNavigatesToServiceSelection() async {
    // Given
    stub(router) { mock in
      when(mock.navigateTo(any())).thenDoNothing()
    }

    // When
    viewModel.selectService()

    // Then
    verify(router).navigateTo(equal(to: .serviceSelection))
  }

  func testSelectCertificate_WhenCalled_ThenNavigatesToCredentialSelection() async {
    // Given
    stub(router) { mock in
      when(mock.navigateTo(any())).thenDoNothing()
    }

    // When
    viewModel.selectCertificate()

    // Then
    verify(router).navigateTo(equal(to: .credentialSelection))
  }
}
