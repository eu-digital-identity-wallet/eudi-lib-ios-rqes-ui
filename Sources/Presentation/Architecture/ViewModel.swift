/*
 * Copyright (c) 2023 European Commission
 *
 * Licensed under the EUPL, Version 1.2 or - as soon they will be approved by the European
 * Commission - subsequent versions of the EUPL (the "Licence"); You may not use this work
 * except in compliance with the Licence.
 *
 * You may obtain a copy of the Licence at:
 * https://joinup.ec.europa.eu/software/page/eupl
 *
 * Unless required by applicable law or agreed to in writing, software distributed under
 * the Licence is distributed on an "AS IS" basis, WITHOUT WARRANTIES OR CONDITIONS OF
 * ANY KIND, either express or implied. See the Licence for the specific language
 * governing permissions and limitations under the Licence.
 */
@_exported import SwiftUI
@_exported import Combine
@_exported import Copyable

protocol ViewState {}

@MainActor
class ViewModel<Router: RouterGraph, UiState: ViewState>: ObservableObject {

  lazy var cancellables = Set<AnyCancellable>()

  @Published private(set) var viewState: UiState

  let router: Router

  init(router: Router, initialState: UiState) {
    self.router = router
    self.viewState = initialState
  }

  func setState(_ reducer: (UiState) -> UiState) {
    self.viewState = reducer(viewState)
  }
  
  func dismiss() {
    NotificationCenter.default.post(
      name: .didCloseDocumentSelection,
      object: nil
    )
  }
}
