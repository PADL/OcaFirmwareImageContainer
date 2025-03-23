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
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import SystemPackage

private func readContents(of file: String) async throws -> [UInt8] {
  guard let data = NSData(contentsOfFile: file)
  else { throw SystemPackage.Errno.noSuchFileOrDirectory }
  return Array(data)
}

public final class OcaFirmwareImageContainerURLReader: _OcaFirmwareImageContainerReader {
  let data: Data
  var index = 0
  var size: Int {
    data.count
  }

  public static func decode(
    url: URL
  ) async throws -> OcaFirmwareImageContainerDecoder {
    var this: any _OcaFirmwareImageContainerReader = try await Self(
      url: url
    )
    return try await OcaFirmwareImageContainerDecoder.decode(from: &this)
  }

  init(url: URL) async throws {
    if url.isFileURL {
      data = try Data(contentsOf: url, options: .alwaysMapped)
    } else {
      #if canImport(FoundationNetworking)
      let (data, _) = try await URLSession.shared.data(from: url)
      self.data = data
      #else
      let (bytes, _) = try await URLSession.shared.bytes(from: url)
      self.data = try await Data(bytes)
      #endif
    }
  }

  func read<T>(
    count: Int,
    at offset: Int,
    _ body: (UnsafeBufferPointer<UInt8>) async throws -> T
  ) async throws -> T {
    guard data.count >= offset + count else {
      throw OcaFirmwareImageContainerError.invalidOffset
    }
    let slice = Array(data[offset..<(offset + count)])
    return try await body(slice.withUnsafeBufferPointer { $0 })
  }
}
