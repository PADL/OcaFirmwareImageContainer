/*
 * Copyright 2025 PADL Software Pty Ltd. All rights reserved.
 *
 * The information and source code contained herein is the exclusive
 * property of PADL Software Pty Ltd and may not be disclosed, examined
 * or reproduced in whole or in part without explicit written authorization
 * from the company.
 */

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
    return try OcaFirmwareImageContainerDecoder.decode(from: &this)
  }

  init(data: [UInt8]) {
    self.data = data
  }

  func read<T>(
    count: Int,
    at offset: Int,
    _ body: (UnsafeBufferPointer<UInt8>) throws -> T
  ) throws -> T {
    guard data.count >= offset + count else {
      throw OcaFirmwareImageContainerError.invalidOffset
    }
    return try data[offset..<(offset + count)].withUnsafeBufferPointer(body)
  }
}
