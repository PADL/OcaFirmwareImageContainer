/*
 * Copyright 2025 PADL Software Pty Ltd. All rights reserved.
 *
 * The information and source code contained herein is the exclusive
 * property of PADL Software Pty Ltd and may not be disclosed, examined
 * or reproduced in whole or in part without explicit written authorization
 * from the company.
 */

import SwiftOCA

protocol _OcaFirmwareImageContainerDecodable {
  static func decode(from context: inout _OcaFirmwareImageContainerReader) async throws -> Self
}

protocol _OcaFirmwareImageContainerReader {
  var size: Int { get }
  var index: Int { get set }

  mutating func read<T>(
    count: Int,
    at offset: Int,
    _ body: (UnsafeBufferPointer<UInt8>) async throws -> T
  ) async throws -> T
}

extension _OcaFirmwareImageContainerReader {
  mutating func decode(
    count: Int,
    _ body: (UnsafeBufferPointer<UInt8>) async throws -> ()
  ) async throws {
    try await read(count: count, at: index, body)
    index += count
  }

  mutating func decode<T: FixedWidthInteger>(integerAt offset: Int? = nil) async throws -> T {
    var value = T()
    try await decode(count: MemoryLayout<T>.size) { bytes in
      withUnsafeMutableBytes(of: &value) { valuePtr in
        valuePtr.copyBytes(from: bytes)
      }
    }
    return value.littleEndian
  }
}

public final class OcaFirmwareImageContainerDecoder: _OcaFirmwareImageContainerDecodable,
  CustomStringConvertible
{
  public let header: OcaFirmwareImageContainerHeader
  public let componentDescriptors: [OcaFirmwareImageContainerComponentDescriptor]
  var context: _OcaFirmwareImageContainerReader

  public var description: String {
    "OcaFirmwareImageContainerDecoder(header: \(header), componentDescriptors: \(componentDescriptors))"
  }

  init(
    header: OcaFirmwareImageContainerHeader,
    componentDescriptors: [OcaFirmwareImageContainerComponentDescriptor],
    context: _OcaFirmwareImageContainerReader
  ) async throws {
    self.header = header
    self.componentDescriptors = componentDescriptors
    self.context = context

    try await verifyAggregateImageChecksum()
  }

  static func decode(from context: inout any _OcaFirmwareImageContainerReader) async throws
    -> Self
  {
    let header = try await OcaFirmwareImageContainerHeader.decode(from: &context)
    var componentDescriptors = [OcaFirmwareImageContainerComponentDescriptor]()
    for _ in 0..<header.componentCount {
      try await componentDescriptors
        .append(OcaFirmwareImageContainerComponentDescriptor.decode(from: &context))
    }
    return try await Self(
      header: header,
      componentDescriptors: componentDescriptors,
      context: context
    )
  }

  public typealias ComponentCallback<T> = (
    OcaFirmwareImageContainerComponentDescriptor,
    UnsafeBufferPointer<UInt8>,
    [UInt8]
  ) async throws -> T

  public var componentCount: Int {
    componentDescriptors.count
  }

  public func withComponent<T>(
    at index: Int,
    _ body: ComponentCallback<T>
  ) async throws -> T {
    guard index < componentDescriptors.count else {
      throw OcaFirmwareImageContainerError.invalidComponentIndex
    }

    let componentDescriptor = componentDescriptors[index]
    let verifyData = try await context.read(
      count: Int(componentDescriptor.verifySize),
      at: Int(componentDescriptor.verifyOffset)
    ) { Array($0) }

    return try await context.read(
      count: Int(componentDescriptor.imageSize),
      at: Int(componentDescriptor.imageOffset)
    ) { image in
      try await body(componentDescriptor, image, verifyData)
    }
  }

  public func withComponent<T>(
    _ component: OcaComponent,
    _ body: ComponentCallback<T>
  ) async throws -> T {
    for i in 0..<componentCount {
      guard componentDescriptors[i].component == component else { continue }
      return try await withComponent(at: i, body)
    }

    print("OcaFirmwareImageContainerDecoder: failed to find component '\(component)'")
    throw OcaFirmwareImageContainerError.unknownComponent
  }
}
