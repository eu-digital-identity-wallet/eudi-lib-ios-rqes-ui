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
final class TestCredentialSelectionViewModel: XCTestCase {
  var interactor: MockRQESInteractor!
  var router: MockRouterGraph!
  var eudiRQESUi: EudiRQESUi!
  var viewModel: CredentialSelectionViewModel<MockRouterGraph>!

  override func setUp() async throws {
    self.interactor = MockRQESInteractor()
    self.router = MockRouterGraph()
    self.viewModel = CredentialSelectionViewModel(
      router: router,
      interactor: interactor
    )
  }

  override func tearDown() async throws {
    self.interactor = nil
    self.router = nil
    self.viewModel = nil
  }

  func testInitiate_WhenCredentialsFetchSucceeds_ThenUpdatesState() async throws {
    // Given
    let expectedCredentialInfo = try await TestConstants.getCredentialInfo()
    let expectedCredentials = [expectedCredentialInfo]

    stub(interactor) { stub in
      when(stub.fetchCredentials()).thenReturn(.success(expectedCredentials))
    }

    // When
    await viewModel.initiate()

    // Then
    let state = viewModel.viewState
    XCTAssertFalse(state.isLoading)
    XCTAssertEqual(state.credentials.count, expectedCredentials.count)
    XCTAssertEqual(state.credentialInfos.count, expectedCredentials.count)
    XCTAssertNil(state.error)
  }

  func testInitiate_WhenFetchCredentialsFailure_ThenSetErrorState() async {
    // Given
    let error = EudiRQESUiError.unableToFetchCredentials
    stub(interactor) { stub in
      when(stub.fetchCredentials()).thenThrow(error)
    }

    stub(router) { mock in
      when(mock.pop()).thenDoNothing()
    }

    // When
    await viewModel.initiate()

    // Then
    guard let cancelAction = viewModel.viewState.error?.cancelAction else {
      XCTFail("cancelAction should not be nil")
      return
    }
    cancelAction()

    let state = viewModel.viewState
    XCTAssertEqual(state.error?.title, .genericErrorMessage)
    XCTAssertEqual(state.error?.description, .genericServiceErrorMessage)

    verify(router).pop()
  }

  func testInitiate_WhenFetchCredentialsReturnsError_ThenSetErrorState() async {
    // Given
    let error = EudiRQESUiError.unableToFetchCredentials
    stub(interactor) { stub in
      when(stub.fetchCredentials()).thenReturn(.failure(error))
    }

    // When
    await viewModel.initiate()

    // Then
    let state = viewModel.viewState
    XCTAssertEqual(state.error?.title, .genericErrorMessage)
    XCTAssertEqual(state.error?.description, .genericServiceErrorMessage)
  }

  func testSetCertificate_WhenViewStateHasCredentialInfos_ThenSaveCertificateCalled() async throws{
    // Given
    let expectation = XCTestExpectation(description: "SaveCertificate called")

    let credentialDataUIModel = CredentialDataUIModel(id: "id", name: "description")
    let expectedCredentialInfo = try await TestConstants.getCredentialInfo()
    let expectedCredentialInfos = [expectedCredentialInfo]

    viewModel.setState {
      $0.copy(
        isLoading: false,
        credentials: expectedCredentialInfos.map { $0.toUi() },
        credentialInfos: expectedCredentialInfos
      )
      .copy(error: nil)
    }

    stub(interactor) { stub in
      when(stub.saveCertificate(any())).then { _ in
        expectation.fulfill()
      }
    }

    // When
    viewModel.setCertificate(credentialDataUIModel)

    // Then
    await fulfillment(of: [expectation], timeout: 1.0)
    verify(interactor).saveCertificate(any())
  }

  func testNextStep_WhenOpenCredentialAuthrorizationURLFailure_ThenSetErrorState() async {
    // Given
    let config = MockEudiRQESUiConfig()
    stub(config) { mock in
      when(mock.theme.get).thenReturn(AppTheme())
    }
    
    self.eudiRQESUi = .init(
      config: config,
      router: router
    )

    let error = EudiRQESUiError.noDocumentProvided
    stub(interactor) { stub in
      when(stub.openCredentialAuthrorizationURL())
        .thenThrow(error)
    }
    
    let (exp, capturedStates) = beginObservation(
      { self.viewModel.viewState },
      targetCount: 2,
      includeInitial: false
    )

    // When
    viewModel.nextStep()

    await waitUntil { self.viewModel.viewState.error != nil }

    // Then
    guard let cancelAction = viewModel.viewState.error?.cancelAction else {
      XCTFail("CancelAction should not be nil")
      return
    }

    cancelAction()

    await fulfillment(of: [exp], timeout: 1.0)

    let states = capturedStates()
    
    guard let firstState = states.first, let lastState = states.last else {
      XCTFail("Expected error in state, but was nil")
      return
    }

    XCTAssertNotNil(firstState, "Should have captured a state with error")
    XCTAssertEqual(firstState.error?.title, .genericErrorMessage)
    XCTAssertEqual(firstState.error?.description, .genericServiceErrorMessage)

    XCTAssertNil(lastState.error)
  }

  /// Initializes EudiRQESUi for onPause's requireInstance.
  func testNextStep_WhenURLNotOpenable_ThenSetsUnableToOpenBrowserAndCancelActionClearsError() async {
    // Given
    let bootConfig = MockEudiRQESUiConfig()
    stub(bootConfig) { mock in
      when(mock.theme.get).thenReturn(AppTheme())
    }
    _ = EudiRQESUi(config: bootConfig, router: router)

    let unopenableURL = URL(string: "rqes-x-test-unknown://example.com")!

    stub(interactor) { stub in
      when(stub.openCredentialAuthrorizationURL()).thenReturn(unopenableURL)
    }

    // When
    viewModel.nextStep()
    await waitUntil { self.viewModel.viewState.error != nil }

    // Then
    XCTAssertEqual(viewModel.viewState.error?.description, .unableToOpenBrowser)

    guard let cancelAction = viewModel.viewState.error?.cancelAction else {
      XCTFail("cancelAction should not be nil")
      return
    }
    cancelAction()

    await waitUntil { self.viewModel.viewState.error == nil }
    XCTAssertNil(viewModel.viewState.error)
  }

  func testErrorAction_WhenInvoked_ThenRetriesAndRecoversState() async throws {
    // Given
    let expectedCredentialInfo = try await TestConstants.getCredentialInfo()
    let expectedCredentials = [expectedCredentialInfo]

    stub(interactor) { stub in
      when(stub.fetchCredentials())
        .thenThrow(EudiRQESUiError.unableToFetchCredentials)
        .thenReturn(.success(expectedCredentials))
    }

    stub(router) { mock in
      when(mock.pop()).thenDoNothing()
    }

    let (exp, capturedStates) = beginObservation(
      { self.viewModel.viewState },
      targetCount: 2,
      includeInitial: false
    )

    // When
    await viewModel.initiate()

    // Then
    guard let retryAction = viewModel.viewState.error?.action else {
      XCTFail("Retry action should not be nil")
      return
    }
    retryAction()

    await fulfillment(of: [exp], timeout: 1.0)

    let states = capturedStates()
    guard let firstState = states.first, let lastState = states.last else {
      XCTFail("Expected error in state, but was nil")
      return
    }

    XCTAssertNotNil(firstState.error)

    XCTAssertNil(lastState.error)
    XCTAssertFalse(lastState.isLoading)
    XCTAssertEqual(lastState.credentials.count, expectedCredentials.count)
    XCTAssertEqual(lastState.credentialInfos.count, expectedCredentials.count)
  }
}
