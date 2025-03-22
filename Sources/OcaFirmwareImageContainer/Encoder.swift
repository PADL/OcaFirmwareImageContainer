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

import Crypto
import SwiftOCA

public protocol OcaFirmwareImageComponent {
  var descriptor: OcaFirmwareImageContainerComponentDescriptor { get }
  func withImageData(_ body: (UnsafeBufferPointer<UInt8>) throws -> ()) throws
  func withVerifyData(_ body: (UnsafeBufferPointer<UInt8>) throws -> ()) throws
}

protocol _OcaFirmwareImageContainerEncodable {
  func encode(into context: inout _OcaFirmwareImageContainerWriter) throws
}

protocol _OcaFirmwareImageContainerWriter {
  var index: Int { get }

  mutating func rewind(to index: Int) throws

  mutating func write(bytes: UnsafeBufferPointer<UInt8>, at offset: Int?) throws

  func read<T>(
    count: Int,
    at offset: Int,
    _ body: (UnsafeBufferPointer<UInt8>) throws -> T
  ) throws -> T
}

extension _OcaFirmwareImageContainerWriter {
  mutating func encode(integer value: some FixedWidthInteger) throws {
    try encode(value, at: nil)
  }

  mutating func encode(bytes: [UInt8], at offset: Int?) throws {
    try bytes.withUnsafeBufferPointer { bytes in
      try write(bytes: bytes, at: offset)
    }
  }

  mutating func encode(bytes: [UInt8]) throws {
    try encode(bytes: bytes, at: nil)
  }

  mutating func encode<T: FixedWidthInteger>(
    _ value: T,
    at offset: Int?
  ) throws {
    try withUnsafePointer(to: value.littleEndian) { bytes in
      try bytes.withMemoryRebound(to: UInt8.self, capacity: MemoryLayout<T>.size) { bytes in
        try encode(
          bytes: Array(UnsafeBufferPointer(start: bytes, count: MemoryLayout<T>.size)),
          at: offset
        )
      }
    }
  }
}

final class OcaFirmwareImageContainerEncoder: _OcaFirmwareImageContainerEncodable,
  CustomStringConvertible
{
  public let headerFlags: OcaFirmwareImageContainerHeader.Flags
  public let modelGUID: OcaModelGUID // OcaUint32
  public private(set) var components: [OcaFirmwareImageComponent] = []
  var context: _OcaFirmwareImageContainerWriter? = nil
  var _componentsDescriptorsWithOffsets: [
    OcaComponent: OcaFirmwareImageContainerComponentDescriptor
  ] =
    [:]

  public var description: String {
    "OcaFirmwareImageContainerEncoder(header: \(_headerForEncoding), componentDescriptors: \(_componentsDescriptorsWithOffsets))"
  }

  init(
    headerFlags: OcaFirmwareImageContainerHeader.Flags,
    modelGUID: OcaModelGUID,
    components: [OcaFirmwareImageComponent]
  ) throws {
    self.headerFlags = headerFlags
    self.modelGUID = modelGUID
    self.components = components + [_OcaFirmwareImageContainerSHA512Checksum(encoder: self)]
  }

  var _headerForEncoding: OcaFirmwareImageContainerHeader {
    OcaFirmwareImageContainerHeader(
      headerFlags: headerFlags,
      componentCount: OcaUint16(components.count),
      modelGUID: modelGUID
    )
  }

  var _componentDescriptors: [OcaFirmwareImageContainerComponentDescriptor] {
    components.map { _componentsDescriptorsWithOffsets[$0.descriptor.component]! }
  }

  private static func _alignOffset(_ offset: inout OcaUint64) {
    offset = (offset + 7) & ~7 // round up to nearest 8-byte boundary
  }

  private static func _makeComponentDescriptorsWithOffsets(
    from components: [OcaFirmwareImageComponent]
  ) throws
    -> (OcaUint64, [OcaComponent: OcaFirmwareImageContainerComponentDescriptor])
  {
    var currentOffset = OcaUint64(
      OcaFirmwareImageContainerHeader.Size + components
        .count * OcaFirmwareImageContainerComponentDescriptor
        .Size
    )
    var componentsDescriptorsWithOffsets =
      [OcaComponent: OcaFirmwareImageContainerComponentDescriptor]()

    for component in components {
      var componentDescriptorWithOffset = component.descriptor
      try component.withImageData { data in
        if !data.isEmpty {
          componentDescriptorWithOffset.imageOffset = currentOffset
          componentDescriptorWithOffset.imageSize = OcaUint64(data.count)
          currentOffset += componentDescriptorWithOffset.imageSize
          _alignOffset(&currentOffset)
        } else {
          componentDescriptorWithOffset.imageOffset = 0
          componentDescriptorWithOffset.imageSize = 0
        }
      }
      try component.withVerifyData { data in
        if !data.isEmpty {
          componentDescriptorWithOffset.verifyOffset = currentOffset
          componentDescriptorWithOffset.verifySize = OcaUint64(data.count)
          currentOffset += componentDescriptorWithOffset.verifySize
          _alignOffset(&currentOffset)
        } else {
          componentDescriptorWithOffset.verifyOffset = 0
          componentDescriptorWithOffset.verifySize = 0
        }
      }

      componentsDescriptorsWithOffsets[component.descriptor.component] =
        componentDescriptorWithOffset
    }

    return (currentOffset, componentsDescriptorsWithOffsets)
  }

  func encode(into context: inout _OcaFirmwareImageContainerWriter) throws {
    self.context = context

    let imageSize: OcaUint64
    var componentDescriptorOffset: Int

    (imageSize, _componentsDescriptorsWithOffsets) = try Self
      ._makeComponentDescriptorsWithOffsets(from: components)

    // header
    let header = _headerForEncoding
    try header.encode(into: &context)
    componentDescriptorOffset = context.index

    // descriptors ex-aggregate checksum
    for component in components {
      let componentDescriptor = _componentsDescriptorsWithOffsets[component.descriptor.component]!

      try context.rewind(to: componentDescriptorOffset)
      try componentDescriptor.encode(into: &context)
      componentDescriptorOffset += OcaFirmwareImageContainerComponentDescriptor.Size

      if componentDescriptor.imageOffset != 0 {
        precondition(componentDescriptor.imageOffset < imageSize)
        try component.withImageData { data in
          try context.write(bytes: data, at: Int(componentDescriptor.imageOffset))
        }
      }
      if componentDescriptor.verifyOffset != 0 {
        precondition(componentDescriptor.verifyOffset < imageSize)
        try component.withVerifyData { data in
          try context.write(bytes: data, at: Int(componentDescriptor.verifyOffset))
        }
      }
    }
  }
}
