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
import UIKit
import Cuckoo
@testable import EudiRQESUi

final class TestEudiRQESUi: XCTestCase {
  
  var router: MockRouterGraph!
  var config: MockEudiRQESUiConfig!
  var eudiRQESUi: EudiRQESUi!
  
  override func setUp() async throws {
    
    self.router = MockRouterGraph()
    self.config = MockEudiRQESUiConfig()
    
    stub(config) { mock in
      when(mock.theme.get).thenReturn(AppTheme())
    }
    
    self.eudiRQESUi = await .init(
      config: config,
      router: router
    )
  }
  
  override func tearDown() {
    self.router = nil
    self.config = nil
    self.eudiRQESUi = nil
  }
  
  func testInitiate_WhenRouterGraphClearAndNextViewCalled_ThenVerifyStateAndCacheAndRouter() async throws {

    // Given
    let controller = await UIViewController()
    let expectedDocumentData = TestConstants.mockDocumentData
    let expectedState = EudiRQESUi.State.initial(self.config)
    
    stub(router) { mock in
      when(mock.clear()).thenDoNothing()
    }
    stub(router) { mock in
      when(mock.nextView(for: expectedState)).thenReturn(controller)
    }
    
    // When
    try await self.eudiRQESUi.initiate(on: UIViewController(), fileUrl: expectedDocumentData.uri)
    
    // Then
    verify(router).clear()
    verify(router).nextView(for: expectedState)
    
    let authService = await eudiRQESUi.getRQESServiceAuthorized()
    let service = await eudiRQESUi.getRQESService()
    XCTAssertNil(service)
    XCTAssertNil(authService)
    
    let session = await eudiRQESUi.getSessionData()
    XCTAssertEqual(session.document, expectedDocumentData)
    
    let state = await eudiRQESUi.getState()
    XCTAssertEqual(state, expectedState)
    
  }
  
  func testResume_WhenRouterGraphClearAndNextViewCalled_ThenVerifyStateAndCacheAndRouter() async throws {

    // Given
    let controller = await UIViewController()
    let expectedAuthCode = "123145"
    let expectedState = EudiRQESUi.State.credentials

    self.eudiRQESUi = await .init(
      config: self.config,
      router: self.router,
      state: .rssps
    )

    stub(router) { mock in
      when(mock.clear()).thenDoNothing()
    }
    stub(router) { mock in
      when(mock.nextView(for: expectedState)).thenReturn(controller)
    }

    // When
    try await self.eudiRQESUi.resume(on: UIViewController(), authorizationCode: expectedAuthCode)

    // Then
    verify(router).clear()
    verify(router).nextView(for: expectedState)

    let session = await eudiRQESUi.getSessionData()
    XCTAssertEqual(session.code, expectedAuthCode)

    let state = await eudiRQESUi.getState()
    XCTAssertEqual(state, expectedState)

  }

  func testCalculateNextState_WhenStartingFromNone_ThenReturnsInitial() async throws {
    // Then
    try await runResumeTransition(
      startingFrom: .none,
      expectedNext: .initial(self.config)
    )
  }

  func testCalculateNextState_WhenStartingFromInitial_ThenReturnsCredentials() async throws {
    // Then
    try await runResumeTransition(
      startingFrom: .initial(self.config),
      expectedNext: .credentials
    )
  }

  func testCalculateNextState_WhenStartingFromCredentials_ThenReturnsSign() async throws {
    // Then
    try await runResumeTransition(
      startingFrom: .credentials,
      expectedNext: .sign
    )
  }

  func testCalculateNextState_WhenStartingFromSign_ThenReturnsView() async throws {
    // Then
    try await runResumeTransition(
      startingFrom: .sign,
      expectedNext: .view
    )
  }

  func testCalculateNextState_WhenStartingFromView_ThenReturnsView() async throws {
    // Then
    try await runResumeTransition(
      startingFrom: .view,
      expectedNext: .view
    )
  }

  func testStateEquality_WhenComparingAllCases_ThenUsesIdComparison() {
    // Then
    XCTAssertEqual(EudiRQESUi.State.none, .none)
    XCTAssertEqual(EudiRQESUi.State.initial(config), .initial(config))
    XCTAssertEqual(EudiRQESUi.State.rssps, .rssps)
    XCTAssertEqual(EudiRQESUi.State.credentials, .credentials)
    XCTAssertEqual(EudiRQESUi.State.sign, .sign)
    XCTAssertEqual(EudiRQESUi.State.view, .view)
    XCTAssertNotEqual(EudiRQESUi.State.none, .initial(config))
  }

  func testCancel_WhenInvoked_ThenResetsStateAndSessionAndServices() async {

    // Given
    self.eudiRQESUi = await .init(
      config: config,
      router: router,
      state: .initial(config),
      session: TestConstants.mockSession
    )

    let initialSession = await eudiRQESUi.getSessionData()
    XCTAssertNotNil(initialSession.document)

    // When
    await eudiRQESUi.cancel()

    // Then
    let state = await eudiRQESUi.getState()
    XCTAssertEqual(state, .none)

    let session = await eudiRQESUi.getSessionData()
    XCTAssertNil(session.document)
    XCTAssertNil(session.qtsp)
    XCTAssertNil(session.code)

    let service = await eudiRQESUi.getRQESService()
    XCTAssertNil(service)

    let authService = await eudiRQESUi.getRQESServiceAuthorized()
    XCTAssertNil(authService)
  }

  func testRequireConfig_WhenInitialized_ThenReturnsConfig() {
    // When
    let returnedConfig = EudiRQESUi.requireConfig()

    // Then
    XCTAssertTrue((returnedConfig as AnyObject) === (self.config as AnyObject))
  }

  func testRequireTheme_WhenInitialized_ThenReturnsTheme() {
    // When
    let theme = EudiRQESUi.requireTheme()

    // Then
    XCTAssertTrue(theme is AppTheme)
  }

  func testInstance_WhenInitialized_ThenReturnsSameInstance() throws {
    // When
    let returned = try EudiRQESUi.instance()

    // Then
    XCTAssertTrue(returned === self.eudiRQESUi)
  }

  /// Uses the public init that wires DIGraph and RouterGraphImpl.
  @MainActor
  func testInit_WhenUsingThePublicInit_ThenSetsTheSharedInstance() async throws {

    // When
    let newInstance = EudiRQESUi(config: config)

    // Then
    let returned = try EudiRQESUi.instance()
    XCTAssertTrue(returned === newInstance)
  }

  /// Waits for the unstructured Task of the cancel to complete.
  func testOnCancel_WhenCalledOnViewModel_ThenTriggersEudiRQESUiCancel() async {

    // Given
    self.eudiRQESUi = await .init(
      config: config,
      router: router,
      state: .initial(config),
      session: TestConstants.mockSession
    )

    let viewModel = await DocumentSelectionViewModel(
      router: router,
      interactor: MockRQESInteractor()
    )

    // When
    await viewModel.onCancel()

    // Then
    let end = Date().addingTimeInterval(2.0)
    while Date() < end {
      let document = await eudiRQESUi.getSessionData().document
      if document == nil { break }
      try? await Task.sleep(nanoseconds: 20_000_000)
    }

    let finalState = await eudiRQESUi.getState()
    XCTAssertEqual(finalState, .none)

    let finalSession = await eudiRQESUi.getSessionData()
    XCTAssertNil(finalSession.document)
  }
}

private extension TestEudiRQESUi {

  func runResumeTransition(
    startingFrom initialState: EudiRQESUi.State,
    expectedNext: EudiRQESUi.State
  ) async throws {

    let controller = await UIViewController()

    self.eudiRQESUi = await .init(
      config: config,
      router: router,
      state: initialState
    )

    stub(router) { mock in
      when(mock.clear()).thenDoNothing()
    }
    stub(router) { mock in
      when(mock.nextView(for: expectedNext)).thenReturn(controller)
    }

    try await self.eudiRQESUi.resume(on: UIViewController(), authorizationCode: "test")

    let state = await eudiRQESUi.getState()
    XCTAssertEqual(state, expectedNext)
  }
}
