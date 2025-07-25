import SwiftUI

struct ContentErrorView: View {
  
  @Environment(\.localizationController) var localization

  private let config: Config

  init(config: Config) {
    self.config = config
  }

  var body: some View {
    VStack(alignment: .leading, spacing: SPACING_LARGE_MEDIUM) {
      HStack {
        Button(
          action: {
            config.cancelAction?()
          },
          label: {
            Image(systemName: "xmark")
              .foregroundColor(.accentColor)
          }
        )
      }
      .frame(maxWidth: .infinity, alignment: .leading)

      VStack(alignment: .leading, spacing: SPACING_MEDIUM) {
        HStack {
          Text(localization.get(with: config.title))
            .font(Theme.shared.font.headlineSmall.font)
            .foregroundStyle(Theme.shared.color.onSurface)
        }
        .frame(maxWidth: .infinity, alignment: .leading)

        HStack {
          Text(localization.get(with: config.description))
            .font(Theme.shared.font.bodyMedium.font)
            .foregroundStyle(Theme.shared.color.onSurface)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
      }

      Spacer()

      if let action = config.action {
        WrapButtonView(
          style: .primary,
          title: localization.get(with: config.button),
          onAction: action()
        )
      }
    }
    .padding([.all], 16)
  }
}

extension ContentErrorView {
  struct Config: Equatable {
    
    let title: LocalizableKey
    let description: LocalizableKey
    let button: LocalizableKey
    let cancelAction: (() -> Void)?
    let action: (() -> Void)?

    public init(
      title: LocalizableKey = .genericErrorMessage,
      description: LocalizableKey = .genericErrorDescription,
      button: LocalizableKey = .genericErrorButtonRetry,
      cancelAction: (() -> Void)? = nil,
      action: (() -> Void)? = nil
    ) {
      self.title = title
      self.description = description
      self.button = button
      self.action = action
      self.cancelAction = cancelAction
    }
  }
}

extension ContentErrorView.Config {
  static func == (lhs: ContentErrorView.Config, rhs: ContentErrorView.Config) -> Bool {
    return lhs.title == rhs.title
    && lhs.description == rhs.description
    && lhs.button == rhs.button
  }
}
