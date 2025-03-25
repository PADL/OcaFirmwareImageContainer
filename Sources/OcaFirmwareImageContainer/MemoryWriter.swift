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

import SwiftOCA

public struct OcaFirmwareImageContainerMemoryComponent: OcaFirmwareImageComponent,
  CustomStringConvertible
{
  public let descriptor: OcaFirmwareImageContainerComponentDescriptor
  public let imageData: [UInt8]
  public let verifyData: [UInt8]

  public init(
    descriptor: OcaFirmwareImageContainerComponentDescriptor,
    imageData: [UInt8],
    verifyData: [UInt8]
  ) {
    self.descriptor = descriptor
    self.imageData = imageData
    self.verifyData = verifyData
  }

  public func withImageData(_ body: (UnsafeBufferPointer<UInt8>) throws -> ()) throws {
    try imageData.withUnsafeBufferPointer(body)
  }

  public func withVerifyData(_ body: (UnsafeBufferPointer<UInt8>) throws -> ()) throws {
    try verifyData.withUnsafeBufferPointer(body)
  }

  public var description: String {
    descriptor.description
  }
}

extension OcaFirmwareImageContainerEncoder {}

public final class OcaFirmwareImageContainerMemoryWriter: _OcaFirmwareImageContainerWriter {
  var buffer = [UInt8]()

  public static func encode(
    flags: OcaFirmwareImageContainerHeader.Flags = .init(),
    models: [OcaModelGUID] = [.init(
      reserved: 0,
      mfrCode: .init(),
      modelCode: 0
    )],
    components: [OcaFirmwareImageContainerMemoryComponent] = []
  ) throws
    -> [UInt8]
  {
    var this: any _OcaFirmwareImageContainerWriter = Self()

    let encoder = try OcaFirmwareImageContainerEncoder(
      headerFlags: flags,
      models: models,
      components: components
    )
    try encoder.encode(into: &this)
    return (this as! Self).buffer
  }

  var index: Int = 0

  func rewind(to index: Int) throws {
    guard index <= buffer.count else {
      throw OcaFirmwareImageContainerError.invalidOffset
    }
    self.index = index
  }

  func write(bytes: UnsafeBufferPointer<UInt8>, at offset: Int?) throws {
    let index = offset ?? index
    let end = index + bytes.count
    if buffer.capacity <= end {
      buffer.reserveCapacity(end)
    }
    if buffer.count <= end {
      buffer.pad(toLength: end, with: 0xCC)
    }

    buffer.replaceSubrange(index..<end, with: bytes)

    self.index += bytes.count
  }

  func read<T>(
    count: Int,
    at offset: Int,
    _ body: (UnsafeBufferPointer<UInt8>) throws -> T
  ) throws -> T {
    guard buffer.count >= offset + count else {
      throw OcaFirmwareImageContainerError.invalidOffset
    }
    return try buffer[offset..<(offset + count)].withUnsafeBufferPointer(body)
  }
}

private extension RangeReplaceableCollection {
  mutating func pad(toLength count: Int, with element: Element) {
    append(contentsOf: repeatElement(element, count: Swift.max(0, count - self.count)))
  }
}
