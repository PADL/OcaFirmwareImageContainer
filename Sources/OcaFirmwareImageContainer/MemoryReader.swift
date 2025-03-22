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

public final class OcaFirmwareImageContainerMemoryReader: _OcaFirmwareImageContainerReader {
  let data: [UInt8]
  var index = 0
  var size: Int {
    data.count
  }

  public static func decode(
    bytes: [UInt8]
  ) async throws -> OcaFirmwareImageContainerDecoder {
    var this: any _OcaFirmwareImageContainerReader = Self(
      data: bytes
    )
    return try await OcaFirmwareImageContainerDecoder.decode(from: &this)
  }

  init(data: [UInt8]) {
    self.data = data
  }

  func read<T>(
    count: Int,
    at offset: Int,
    _ body: (UnsafeBufferPointer<UInt8>) async throws -> T
  ) async throws -> T {
    guard data.count >= offset + count else {
      throw OcaFirmwareImageContainerError.invalidOffset
    }
    let slice = data[offset..<(offset + count)].withUnsafeBufferPointer { $0 }
    return try await body(slice)
  }
}
