/*
 * Copyright 2025 PADL Software Pty Ltd. All rights reserved.
 *
 * The information and source code contained herein is the exclusive
 * property of PADL Software Pty Ltd and may not be disclosed, examined
 * or reproduced in whole or in part without explicit written authorization
 * from the company.
 */

import Foundation
import SystemPackage

private func readContents(of file: String) async throws -> [UInt8] {
  guard let data = NSData(contentsOfFile: file)
  else { throw SystemPackage.Errno.noSuchFileOrDirectory }
  return Array(data)
}

public final class OcaFirmwareImageContainerFileReader: _OcaFirmwareImageContainerReader {
  let data: [UInt8]
  var index = 0
  var size: Int {
    data.count
  }

  public static func decode(
    file: String
  ) async throws -> OcaFirmwareImageContainerDecoder {
    var this: any _OcaFirmwareImageContainerReader = try await Self(
      file: file
    )
    return try await OcaFirmwareImageContainerDecoder.decode(from: &this)
  }

  init(file: String) async throws {
    data = try await readContents(of: file)
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
