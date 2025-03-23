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

import Foundation
import OcaFirmwareImageContainer

private func usage() -> Never {
  print("usage: \(CommandLine.arguments[0]) [url ...]")
  exit(2)
}

extension BinaryInteger {
  var asHex: String {
    let formatString = "0x%0\(MemoryLayout<Self>.size * 2)X"
    return String(format: formatString, UInt(self))
  }
}

@main
public final class InfernoFirmwareTool {
  public static func main() async throws {
    guard CommandLine.arguments.count > 1 else { usage() }
    for urlString in CommandLine.arguments[1...] {
      guard let url = URL(string: urlString) else { usage() }

      let decoder = try await OcaFirmwareImageContainerURLReader.decode(url: url)
      print("Version:\t\(decoder.header.headerVersion.asHex)")
      print("Flags:\t\t\(decoder.header.headerFlags.rawValue.asHex)")
      print("Model GUID:\t0x\(decoder.header.modelGUID)")
      print("Model mask:\t\(decoder.header.modelCodeMask.asHex)")
      print("--------------------------------------------------------")

      for descriptor in decoder.componentDescriptors {
        print("Component:\t\(descriptor.component.asHex)")
        print("Flags:\t\t\(descriptor.flags.rawValue.asHex)")
        print("Version:\t\(descriptor.major).\(descriptor.minor).\(descriptor.build)")
        print("Image offset:\t\(descriptor.imageOffset.asHex)")
        print("Image size:\t\(descriptor.imageSize.asHex)")
        print("Verify offset:\t\(descriptor.verifyOffset.asHex)")
        print("Verify size:\t\(descriptor.verifySize.asHex)")
        print("--------------------------------------------------------")
      }
    }
  }
}
