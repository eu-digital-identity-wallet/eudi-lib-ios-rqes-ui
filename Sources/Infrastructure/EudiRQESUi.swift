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
import UIKit
import RqesKit

@Copyable
struct CurrentSelection {
  let document: DocumentData?
  let qtsp: QTSPData?
  let certificate: CredentialInfo?
  let code: String?

  init(
    document: DocumentData? = nil,
    qtsp: QTSPData? = nil,
    certificate: CredentialInfo? = nil,
    code: String? = nil
  ) {
    self.document = document
    self.qtsp = qtsp
    self.certificate = certificate
    self.code = code
  }
}

public final actor EudiRQESUi {

  private static var _shared: EudiRQESUi?
  private static var _config: (any EudiRQESUiConfig)?
  private static var _state: State = .none
  private static var _viewController: UIViewController?

  private let router: any RouterGraph
  var selection = CurrentSelection()

  private static var _rqesService: RQESService?
  private static var _rQESServiceAuthorized: RQESServiceAuthorized?

  @discardableResult
  public init(config: any EudiRQESUiConfig) {
    DIGraph.shared.load()
    self.router = RouterGraphImpl()
    Self._config = config
    Self._shared = self
  }

  @MainActor
  public func initiate(
    on container: UIViewController,
    fileUrl: URL,
    animated: Bool = true
  ) async throws {
    
    self.router.clear()
    
    await resetCache()
    await updateSelectionDocument(
      with: .init(
        documentName: fileUrl.lastPathComponent,
        uri: fileUrl
      )
    )
    await setState(.initial(Self.forceConfig()))
    
    try await launcSDK(on: container, animated: animated)
  }

  @MainActor
  public func resume(
    on container: UIViewController,
    authorizationCode: String,
    animated: Bool = true
  ) async throws {
    
    self.router.clear()
    
    await setState(calculateNextState())
    await updateAuthorizationCode(with: authorizationCode)
    
    try await launcSDK(on: container, animated: animated)
  }

  func updateSelectionDocument(with document: DocumentData? = nil) async {
    selection = selection.copy(document: document)
  }

  func updateQTSP(with qtsp: QTSPData? = nil) async {
    selection = selection.copy(qtsp: qtsp)
  }

  func updateCertificate(with certificate: CredentialInfo) async {
    selection = selection.copy(certificate: certificate)
  }

  public func updateAuthorizationCode(with code: String) async {
    selection = selection.copy(code: code)
  }
}

public extension EudiRQESUi {
  
  static func instance() throws -> EudiRQESUi {
    guard let _shared else {
      throw EudiRQESUiError.notInitialized
    }
    return _shared
  }
}

private extension EudiRQESUi {

  func getState() -> State {
    return Self._state
  }

  func getViewController() -> UIViewController? {
    return Self._viewController
  }

  func setViewController(_ viewController: UIViewController) {
    Self._viewController = viewController
  }

  func launcSDK(
    on container: UIViewController,
    animated: Bool
  ) async throws {
    await setViewController(try self.router.nextView(for: getState()))
    if let viewController = getViewController() {
      await container.present(viewController, animated: animated)
    }
  }
  
  func calculateNextState() -> State {
    switch getState() {
    case .none:
      return .initial(Self.forceConfig())
    case .initial, .rssps:
      return .credentials
    case .credentials:
      return .sign
    case .sign:
      return .view
    case .view:
      return .view
    }
  }
  
  func setState(_ state: State) {
    Self._state = state
  }
  
  func resetCache() async {
    selection = CurrentSelection()
    setRQESService(nil)
    setRQESServiceAuthorized(nil)
  }

}

extension EudiRQESUi {

  static func forceConfig() -> any EudiRQESUiConfig {
    return Self._config!
  }
  
  static func forceInstance() -> EudiRQESUi {
    return Self._shared!
  }
  
  func getRQESService() -> RQESService? {
    Self._rqesService
  }

  func setRQESService(_ service: RQESService?) {
    Self._rqesService = service
  }

  func getRQESServiceAuthorized() -> RQESServiceAuthorized? {
    Self._rQESServiceAuthorized
  }

  func setRQESServiceAuthorized(_ service: RQESServiceAuthorized?) {
    Self._rQESServiceAuthorized = service
  }
  
  func getRQESConfig() -> RqesServiceConfig {
    return Self.forceConfig().rQESConfig
  }
  
  func getRssps() -> [QTSPData] {
    return Self.forceConfig().rssps
  }

  @MainActor
  func cancel(animated: Bool = true) async {
    await setState(.none)
    await pause(animated: animated)
  }

  @MainActor
  func pause(animated: Bool = true) async {
    await getViewController()?.dismiss(animated: animated)
  }
}

extension EudiRQESUi {
  enum State: Equatable, Sendable {

    case none
    case initial(any EudiRQESUiConfig)
    case rssps
    case credentials
    case sign
    case view

    var id: String {
      return switch self {
      case .none:
        "none"
      case .initial:
        "initial"
      case .rssps:
        "rssps"
      case .credentials:
        "credentials"
      case .sign:
        "sign"
      case .view:
        "view"
      }
    }

    public static func == (lhs: State, rhs: State) -> Bool {
      return lhs.id == rhs.id
    }
  }
}
