//
// Copyright (c) 2025 PADL Software Pty Ltd
//
// Licensed under the Apache License, Version 2.0 (the License);
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an 'AS IS' BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//

import ArgumentParser
import Foundation
import OcaFirmwareImageContainer

@main
struct OcaFWExtractImage: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "ocafw-extract-image",
    abstract: "Extract a component from an OCA firmware image"
  )

  @Argument(help: "URL of the firmware image")
  var url: String

  @Argument(help: "Component index to extract")
  var component: Int

  @Option(name: .shortAndLong, help: "Output file path for the component image")
  var output: String

  mutating func run() async throws {
    guard let imageURL = URL(string: url) else {
      throw ValidationError("Invalid URL: \(url)")
    }

    let decoder = try await OcaFirmwareImageContainerURLReader.decode(url: imageURL)

    guard component >= 0, component < decoder.componentCount else {
      throw ValidationError(
        "Component index \(component) out of range (0..<\(decoder.componentCount))"
      )
    }

    try await decoder.withComponent(at: component) { descriptor, imageData, verifyData in
      let imageOutputURL = URL(fileURLWithPath: output)
      let verifyOutputURL = URL(
        fileURLWithPath: output + ".sig"
      )

      let imageBytes = Data(buffer: imageData)
      try imageBytes.write(to: imageOutputURL)
      print("Wrote component image (\(imageBytes.count) bytes) to \(imageOutputURL.path)")

      if !verifyData.isEmpty {
        let verifyBytes = Data(verifyData)
        try verifyBytes.write(to: verifyOutputURL)
        print(
          "Wrote component signature (\(verifyBytes.count) bytes) to \(verifyOutputURL.path)"
        )
      }
    }
  }
}
