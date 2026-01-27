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

extension OcaModelGUID: _OcaFirmwareImageContainerEncodable {
  func encode(into context: inout any _OcaFirmwareImageContainerWriter) throws {
    try context.encode(integer: reserved)
    try context.encode(integer: mfrCode.id.0)
    try context.encode(integer: mfrCode.id.1)
    try context.encode(integer: mfrCode.id.2)
    try context.encode(integer: modelCode.0)
    try context.encode(integer: modelCode.1)
    try context.encode(integer: modelCode.2)
    try context.encode(integer: modelCode.3)
  }
}

extension OcaModelGUID: _OcaFirmwareImageContainerDecodable {
  static func decode(from context: inout any _OcaFirmwareImageContainerReader) async throws
    -> OcaModelGUID
  {
    let reserved: OcaUint8 = try await context.decode()
    let mfrCode_id_0: OcaUint8 = try await context.decode()
    let mfrCode_id_1: OcaUint8 = try await context.decode()
    let mfrCode_id_2: OcaUint8 = try await context.decode()
    let modelCode_0: OcaUint8 = try await context.decode()
    let modelCode_1: OcaUint8 = try await context.decode()
    let modelCode_2: OcaUint8 = try await context.decode()
    let modelCode_3: OcaUint8 = try await context.decode()

    return Self(
      reserved: reserved,
      mfrCode: OcaOrganizationID((mfrCode_id_0, mfrCode_id_1, mfrCode_id_2)),
      modelCode: (modelCode_0, modelCode_1, modelCode_2, modelCode_3)
    )
  }
}

public struct OcaFirmwareImageContainerHeader: _OcaFirmwareImageContainerEncodable,
  _OcaFirmwareImageContainerDecodable,
  CustomStringConvertible
{
  private static let OcaFirmwareImageContainerHeaderVersion1: OcaUint32 = 0x0000_0001
  private static let OcaFirmwareImageContainerHeaderMagicNumber: OcaUint32 = 0xCFF1_A00C
  private static let Size = 16 // without model GUID trailer

  public struct Flags: OptionSet {
    public typealias RawValue = OcaBitSet16

    public var rawValue: OcaBitSet16

    public init(rawValue: OcaBitSet16) {
      self.rawValue = rawValue
    }
  }

  // offset: 0, length: 4
  public var magicNumber: OcaUint32 { Self.OcaFirmwareImageContainerHeaderMagicNumber }
  // offset: 4, length: 2
  public let headerVersion: OcaUint32
  // offset: 8, length: 2
  public var headerSize: OcaUint16 { OcaUint16(Self.Size) + modelCount * 8 }
  // offset: 10, length: 2
  public let headerFlags: Flags // OcaBitSet16
  // offset: 12, length: 2
  public var modelCount: OcaUint16 { OcaUint16(models.count) }
  // offset: 14, length: 2
  public let componentCount: OcaUint16
  // offset: 16, length: modelCount * 8
  public let models: [OcaModelGUID]

  init(
    headerVersion: OcaUint32 = Self.OcaFirmwareImageContainerHeaderVersion1,
    headerFlags: Flags = .init(),
    componentCount: OcaUint16 = 0,
    models: [OcaModelGUID] = []
  ) {
    self.headerVersion = headerVersion
    self.headerFlags = headerFlags
    self.componentCount = componentCount
    self.models = models
  }

  public var description: String {
    "OcaFirmwareImageContainerHeader(headerVersion: \(headerVersion), headerFlags: \(headerFlags), componentCount: \(componentCount), models: \(models))"
  }

  func encode(into context: inout _OcaFirmwareImageContainerWriter) throws {
    try context.encode(integer: magicNumber)
    try context.encode(integer: headerVersion)
    try context.encode(integer: headerSize)
    try context.encode(integer: headerFlags.rawValue)
    try context.encode(integer: modelCount)
    try context.encode(integer: componentCount)
    for model in models {
      try model.encode(into: &context)
    }
  }

  static func decode(from context: inout _OcaFirmwareImageContainerReader) async throws -> Self {
    let magicNumber: OcaUint32 = try await context.decode()
    guard magicNumber == Self.OcaFirmwareImageContainerHeaderMagicNumber else {
      throw OcaFirmwareImageContainerError.invalidMagicNumber
    }
    let headerVersion: OcaUint32 = try await context.decode()
    guard headerVersion == Self.OcaFirmwareImageContainerHeaderVersion1 else {
      throw OcaFirmwareImageContainerError.unknownHeaderVersion
    }
    let headerSize: OcaUint16 = try await context.decode()
    guard headerSize >= Self.Size else {
      throw OcaFirmwareImageContainerError.invalidHeaderSize
    }
    let headerFlags: Flags = try await Flags(rawValue: context.decode())
    let modelCount: OcaUint16 = try await context.decode()
    guard modelCount > 0 else {
      throw OcaFirmwareImageContainerError.invalidModelCount
    }
    let componentCount: OcaUint16 = try await context.decode()

    guard Int(headerSize) >= Self.Size + Int(modelCount) * 8 else {
      throw OcaFirmwareImageContainerError.invalidHeaderSize
    }
    var models = [OcaModelGUID]()
    for _ in 0..<modelCount {
      try await models.append(OcaModelGUID.decode(from: &context))
    }

    let unknownBytes = Int(headerSize) - Self.Size - Int(modelCount) * 8
    try await _ = context.decode(count: unknownBytes) { _ in }

    return Self(
      headerFlags: headerFlags,
      componentCount: componentCount,
      models: models
    )
  }
}

public struct OcaFirmwareImageContainerComponentDescriptor: _OcaFirmwareImageContainerEncodable,
  _OcaFirmwareImageContainerDecodable,
  CustomStringConvertible
{
  static let Size = 48

  public struct Flags: OptionSet {
    public typealias RawValue = OcaBitSet16

    public var rawValue: OcaBitSet16

    public init(rawValue: OcaBitSet16) {
      self.rawValue = rawValue
    }

    public static let local = Flags(rawValue: 1 << 0)
    public static let critical = Flags(rawValue: 1 << 1)
    public static let supportsUnsequenced = Flags(rawValue: 1 << 2)
  }

  public let component: OcaComponent
  public let flags: Flags // OcaBitSet16

  public let major: OcaUint32
  public let minor: OcaUint32
  public let build: OcaUint32

  public internal(set) var imageOffset: OcaUint64
  public internal(set) var imageSize: OcaUint64
  public internal(set) var verifyOffset: OcaUint64
  public internal(set) var verifySize: OcaUint64

  public init(
    component: OcaComponent,
    flags: Flags = .init(),
    major: OcaUint32 = 0,
    minor: OcaUint32 = 0,
    build: OcaUint32 = 0,
    imageOffset: OcaUint64 = 0,
    imageSize: OcaUint64 = 0,
    verifyOffset: OcaUint64 = 0,
    verifySize: OcaUint64 = 0
  ) {
    self.component = component
    self.flags = flags
    self.major = major
    self.minor = minor
    self.build = build
    self.imageOffset = imageOffset
    self.imageSize = imageSize
    self.verifyOffset = verifyOffset
    self.verifySize = verifySize
  }

  public var description: String {
    "OcaFirmwareImageComponentDescriptor(component: \(component), flags: \(flags), major: \(major), minor: \(minor), build: \(build))"
  }

  func encode(into context: inout _OcaFirmwareImageContainerWriter) throws {
    try context.encode(integer: component)
    try context.encode(integer: flags.rawValue)
    try context.encode(integer: major)
    try context.encode(integer: minor)
    try context.encode(integer: build)
    try context.encode(integer: imageOffset)
    try context.encode(integer: imageSize)
    try context.encode(integer: verifyOffset)
    try context.encode(integer: verifySize)
  }

  static func decode(from context: inout _OcaFirmwareImageContainerReader) async throws -> Self {
    let component: OcaComponent = try await context.decode()
    let flags: Flags = try await Flags(rawValue: context.decode())

    let major: OcaUint32 = try await context.decode()
    let minor: OcaUint32 = try await context.decode()
    let build: OcaUint32 = try await context.decode()

    let imageOffset: OcaUint64 = try await context.decode()
    let imageSize: OcaUint64 = try await context.decode()
    guard imageOffset + imageSize <= context.size else {
      throw OcaFirmwareImageContainerError.invalidImageSize
    }

    let verifyOffset: OcaUint64 = try await context.decode()
    let verifySize: OcaUint64 = try await context.decode()
    guard verifyOffset + verifySize <= context.size else {
      throw OcaFirmwareImageContainerError.invalidVerifySize
    }

    return Self(
      component: component,
      flags: flags,
      major: major,
      minor: minor,
      build: build,
      imageOffset: imageOffset,
      imageSize: imageSize,
      verifyOffset: verifyOffset,
      verifySize: verifySize
    )
  }
}
