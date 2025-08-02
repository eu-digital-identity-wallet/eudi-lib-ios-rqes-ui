/*
 * Copyright (c) 2025 European Commission
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
struct WrapTextView: View {
  private let text: String
  private let textConfig: TextConfig

  init(
    text: String,
    textConfig: TextConfig
  ) {
    self.text = text
    self.textConfig = textConfig
  }

  var body: some View {
    Text(text)
      .font(textConfig.font)
      .foregroundColor(textConfig.color)
      .multilineTextAlignment(textConfig.textAlign)
      .lineLimit(textConfig.maxLines)
      .fontWeight(textConfig.fontWeight)
  }
}
