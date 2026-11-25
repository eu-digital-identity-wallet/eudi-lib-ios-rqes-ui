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
final class TestServiceSelectionViewModel: XCTestCase {
  var interactor: MockRQESInteractor!
  var router: MockRouterGraph!
  var viewModel: ServiceSelectionViewModel<MockRouterGraph>!

  override func setUp() async throws {
    self.interactor = MockRQESInteractor()
    self.router = MockRouterGraph()
    self.viewModel = ServiceSelectionViewModel(
      router: router,
      interactor: interactor
    )
  }

  override func tearDown() async throws {
    self.interactor = nil
    self.router = nil
    self.viewModel = nil
  }

  func testInitiate_WhenGetQtspServices_ThenSetState() async {
    // Given
    let qtsp = TestConstants.mockQtspData
    let qtspData = [qtsp]

    stub(interactor) { stub in
      when(stub.getQTSps()).thenReturn(qtspData)
    }

    // When
    await viewModel.initiate()

    // Then
    let state = viewModel.viewState
    XCTAssertNil(state.error)
    XCTAssertFalse(state.isLoading)
    XCTAssertEqual(state.services, qtspData)
  }

  func testInitiate_WhenGetQtspServicesIsEmpty_ThenSetErrorState() async {
    // Given
    stub(interactor) { stub in
      when(stub.getQTSps()).thenReturn([])
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
    XCTAssertNotNil(state.error)
    XCTAssertEqual(state.error?.title, .genericErrorMessage)
    verify(router).pop()
  }

  func testOpenAuthorization_WhenCreateRQESServiceFails_ThenSetErrorState() async {
    // Given
    let expectedError = EudiRQESUiError.noDocumentProvided
    let qtsp = TestConstants.mockQtspData
    viewModel.selectedItem = qtsp

    stub(interactor) { stub in
      when(stub.createRQESService(any())).thenThrow(expectedError)
    }

    stub(router) { mock in
      when(mock.pop()).thenDoNothing()
    }

    let (exp, capturedStates) = beginObservation(
      { self.viewModel.viewState },
      targetCount: 2
    )

    // When
    viewModel.nextStep()

    await waitUntil{ self.viewModel.viewState.error != nil }

    // Then
    await fulfillment(of: [exp], timeout: 1.0)

    let states = capturedStates()
    guard let firstState = states.first, let lastState = states.last else {
      XCTFail("Expected error in state, but was nil")
      return
    }
    XCTAssertNil(firstState.error)
    XCTAssertNotNil(lastState.error)
    XCTAssertEqual(lastState.error?.title, .genericErrorMessage)

    guard let cancelAction = states.last!.error?.cancelAction else {
      XCTFail("cancelAction should not be nil")
      return
    }
    cancelAction()
    verify(router).pop()
  }

  func testOpenAuthorization_WhenAllSucceeds_ThenNoErrorAndPauseCalled() async {
    // Given
    let qtsp = TestConstants.mockQtspData

    viewModel.selectedItem = qtsp

    let expectedURL = URL(string: "https://test")!

    stub(interactor) { stub in
      when(stub.createRQESService(equal(to: qtsp))).thenDoNothing()
      when(stub.openAuthrorizationURL()).thenReturn(expectedURL)
      when(stub.updateQTSP(equal(to: qtsp))).thenDoNothing()
    }

    let (exp, capturedStates) = beginObservation(
      { self.viewModel.viewState },
      targetCount: 2
    )

    // When
    viewModel.nextStep()

    await waitUntil{ self.viewModel.viewState.error != nil }

    await fulfillment(of: [exp], timeout: 1.0)

    // Then
    let states = capturedStates()
    guard let lastState = states.last else {
      XCTFail("Expected error in state, but was nil")
      return
    }

    XCTAssertFalse(lastState.isLoading)

    verify(interactor).createRQESService(equal(to: qtsp))
    verify(interactor).openAuthrorizationURL()
    verify(interactor).updateQTSP(equal(to: qtsp))
  }

  func testOpenAuthorization_WhenSelectedItemIsNil_ThenThrowError() async {
    // Given
    viewModel.selectedItem = nil

    stub(router) { mock in
      when(mock.pop()).thenDoNothing()
    }

    let (exp, capturedStates) = beginObservation(
      { self.viewModel.viewState },
      targetCount: 1
    )

    // When
    viewModel.nextStep()

    // Then
    await waitUntil{ self.viewModel.viewState.error != nil }

    guard let cancelAction = viewModel.viewState.error?.cancelAction else {
      XCTFail("cancelAction should not be nil")
      return
    }
    cancelAction()

    await fulfillment(of: [exp], timeout: 2.0)

    let states = capturedStates()
    guard let lastState = states.last else {
      XCTFail("Expected error in state, but was nil")
      return
    }
    XCTAssertNotNil(lastState.error)
    XCTAssertEqual(lastState.error?.title, .genericErrorMessage)

    verify(router).pop()

    verify(interactor, never()).createRQESService(any())
    verify(interactor, never()).openAuthrorizationURL()
    verify(interactor, never()).updateQTSP(any())
  }

  /// Initializes EudiRQESUi for onPause's requireInstance. The error is set with unableToOpenBrowser and the
  /// cancelAction clears it.
  func testOpenAuthorization_WhenURLNotOpenable_ThenSetsUnableToOpenBrowserAndCancelActionClearsError() async {
    // Given
    let bootConfig = MockEudiRQESUiConfig()
    stub(bootConfig) { mock in
      when(mock.theme.get).thenReturn(AppTheme())
    }
    _ = EudiRQESUi(config: bootConfig, router: router)

    let qtsp = TestConstants.mockQtspData
    viewModel.selectedItem = qtsp
    let unopenableURL = URL(string: "rqes-x-test-unknown://example.com")!

    stub(interactor) { stub in
      when(stub.createRQESService(equal(to: qtsp))).thenDoNothing()
      when(stub.openAuthrorizationURL()).thenReturn(unopenableURL)
      when(stub.updateQTSP(equal(to: qtsp))).thenDoNothing()
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

  func testErrorAction_WhenInvoked_ThenRetriesAndRecoversState() async {
    // Given
    let qtsp = TestConstants.mockQtspData
    let qtspData = [qtsp]

    stub(interactor) { stub in
      when(stub.getQTSps()).thenReturn([], qtspData)
    }
    stub(router) { mock in
      when(mock.pop()).thenDoNothing()
    }

    let (exp, capturedStates) = beginObservation(
      { self.viewModel.viewState },
      targetCount: 2
    )

    // When
    await viewModel.initiate()

    // Then
    guard let retryAction = viewModel.viewState.error?.action else {
      XCTFail("Retry action should not be nil")
      return
    }
    retryAction()

    await waitUntil{ self.viewModel.viewState.error == nil }

    await fulfillment(of: [exp], timeout: 1.0)

    let states = capturedStates()
    guard let firstState = states.first, let lastState = states.last else {
      XCTFail("Expected error in state, but was nil")
      return
    }

    XCTAssertNotNil(firstState.error)

    XCTAssertNil(lastState.error)
    XCTAssertEqual(lastState.services, qtspData)
    XCTAssertFalse(lastState.isLoading)
  }
}
