/*
 * Copyright 2025 PADL Software Pty Ltd. All rights reserved.
 *
 * The information and source code contained herein is the exclusive
 * property of PADL Software Pty Ltd and may not be disclosed, examined
 * or reproduced in whole or in part without explicit written authorization
 * from the company.
 */

import Crypto
import SwiftOCA

// digest is SHA512(Header | [Component0.Descriptor | Component0.ImageData | Component0.VerifyData]
// x N )

public let OcaFirmwareImageContainerSHA512ChecksumComponent: OcaComponent = 0x8001

extension _OcaFirmwareImageContainerEncodable {
  func update(digest: inout SHA512) throws {
    var writer: any _OcaFirmwareImageContainerWriter = OcaFirmwareImageContainerMemoryWriter()
    try encode(into: &writer)
    digest.update(data: (writer as! OcaFirmwareImageContainerMemoryWriter).buffer)
  }
}

extension OcaFirmwareImageContainerDecoder {
  func verifyAggregateImageChecksum() throws {
    var digest = SHA512()

    try header.update(digest: &digest)

    for componentDescriptor in componentDescriptors {
      try componentDescriptor.update(digest: &digest)
      guard componentDescriptor.component != OcaFirmwareImageContainerSHA512ChecksumComponent
      else { continue }
      try context.read(
        count: Int(componentDescriptor.imageSize),
        at: Int(componentDescriptor.imageOffset)
      ) { bytes in
        digest.update(data: bytes)
      }
      try context.read(
        count: Int(componentDescriptor.verifySize),
        at: Int(componentDescriptor.verifyOffset)
      ) { bytes in
        digest.update(data: bytes)
      }
    }

    let checksum = digest.finalize()

    try withComponent(OcaFirmwareImageContainerSHA512ChecksumComponent) { _, _, verifyData in
      guard verifyData == Array(checksum) else {
        throw OcaFirmwareImageContainerError.checksumVerificationFailed
      }
    }
  }
}

final class _OcaFirmwareImageContainerSHA512Checksum: OcaFirmwareImageComponent {
  weak var encoder: OcaFirmwareImageContainerEncoder?

  init(encoder: OcaFirmwareImageContainerEncoder) {
    self.encoder = encoder
  }

  var descriptor: OcaFirmwareImageContainerComponentDescriptor {
    OcaFirmwareImageContainerComponentDescriptor(
      component: OcaFirmwareImageContainerSHA512ChecksumComponent
    )
  }

  func withImageData(_ body: (UnsafeBufferPointer<UInt8>) throws -> ()) throws {}

  var hasEncodedPayloads: Bool {
    guard let encoder else { return false }
    return encoder
      ._componentsDescriptorsWithOffsets[OcaFirmwareImageContainerSHA512ChecksumComponent] != nil
  }

  func withVerifyData(_ body: (UnsafeBufferPointer<UInt8>) throws -> ()) throws {
    guard let encoder else { throw OcaFirmwareImageContainerError.encodingNotBegun }

    if !hasEncodedPayloads {
      let empty = [UInt8](repeating: 0, count: SHA512.byteCount)
      try empty.withUnsafeBufferPointer(body)
      return
    }

    var digest = SHA512()
    try encoder._headerForEncoding.update(digest: &digest)

    for component in encoder.components {
      let componentDescriptor = encoder
        ._componentsDescriptorsWithOffsets[component.descriptor.component]!
      try componentDescriptor.update(digest: &digest)
      guard componentDescriptor.component != OcaFirmwareImageContainerSHA512ChecksumComponent
      else { continue }
      if componentDescriptor.imageOffset != 0 {
        try component.withImageData { data in
          digest.update(data: data)
        }
      }
      if componentDescriptor.verifyOffset != 0 {
        try component.withVerifyData { data in
          digest.update(data: data)
        }
      }
    }

    let bytes = Array(digest.finalize())
    try bytes.withUnsafeBufferPointer(body)
  }
}
