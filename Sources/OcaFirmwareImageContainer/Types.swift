/*
 * Copyright 2025 PADL Software Pty Ltd. All rights reserved.
 *
 * The information and source code contained herein is the exclusive
 * property of PADL Software Pty Ltd and may not be disclosed, examined
 * or reproduced in whole or in part without explicit written authorization
 * from the company.
 */

import SwiftOCA

extension OcaModelGUID: _OcaFirmwareImageContainerEncodable {
  func encode(into context: inout any _OcaFirmwareImageContainerWriter) throws {
    try context.encode(integer: reserved)
    try context.encode(integer: mfrCode.id.0)
    try context.encode(integer: mfrCode.id.1)
    try context.encode(integer: mfrCode.id.2)
    try context.encode(integer: modelCode)
  }
}

extension OcaModelGUID: _OcaFirmwareImageContainerDecodable {
  static func decode(from context: inout any _OcaFirmwareImageContainerReader) throws
    -> OcaModelGUID
  {
    let reserved: OcaUint8 = try context.decode()
    let mfrCode_id_0: OcaUint8 = try context.decode()
    let mfrCode_id_1: OcaUint8 = try context.decode()
    let mfrCode_id_2: OcaUint8 = try context.decode()
    let modelCode: OcaUint32 = try context.decode()

    return Self(
      reserved: reserved,
      mfrCode: OcaOrganizationID((mfrCode_id_0, mfrCode_id_1, mfrCode_id_2)),
      modelCode: modelCode
    )
  }
}

public struct OcaFirmwareImageContainerHeader: _OcaFirmwareImageContainerEncodable,
  _OcaFirmwareImageContainerDecodable,
  CustomStringConvertible
{
  public static let OcaFirmwareImageContainerHeaderVersion1: OcaUint16 = 0x0101
  public static let OcaFirmwareImageContainerHeaderMagicNumber: OcaUint32 = 0xCFF1_A00C
  public static let Size = 24

  public struct Flags: OptionSet {
    public typealias RawValue = OcaBitSet16

    public var rawValue: OcaBitSet16

    public init(rawValue: OcaBitSet16) {
      self.rawValue = rawValue
    }
  }

  // offset: 0
  public let magicNumber: OcaUint32
  // offset: 4
  public let headerVersion: OcaUint16
  // offset: 6
  public let headerSize: OcaUint16
  // offset: 8
  public let headerFlags: Flags // OcaBitSet16
  // offset: 10
  public let componentCount: OcaUint16
  // offset: 12
  public let modelGUID: OcaModelGUID
  // offset: 20
  public let modelCodeMask: OcaUint32

  init(
    magicNumber: OcaUint32 = Self.OcaFirmwareImageContainerHeaderMagicNumber,
    headerVersion: OcaUint16 = Self.OcaFirmwareImageContainerHeaderVersion1,
    headerSize: OcaUint16 = OcaUint16(Self.Size),
    headerFlags: Flags = .init(),
    componentCount: OcaUint16 = 0,
    modelGUID: OcaModelGUID = OcaModelGUID(
      reserved: 0,
      mfrCode: .init(),
      modelCode: 0
    ),
    modelCodeMask: OcaUint32 = 0xFFFF_FFFF
  ) {
    self.magicNumber = magicNumber
    self.headerVersion = headerVersion
    self.headerSize = headerSize
    self.headerFlags = headerFlags
    self.componentCount = componentCount
    self.modelGUID = modelGUID
    self.modelCodeMask = modelCodeMask
  }

  public var description: String {
    "OcaFirmwareImageContainerHeader(headerVersion: \(headerVersion), headerFlags: \(headerFlags), componentCount: \(componentCount), modelGUID: \(modelGUID), modelCodeMask: \(modelCodeMask)"
  }

  func encode(into context: inout _OcaFirmwareImageContainerWriter) throws {
    try context.encode(integer: magicNumber)
    try context.encode(integer: headerVersion)
    try context.encode(integer: headerSize)
    try context.encode(integer: headerFlags.rawValue)
    try context.encode(integer: componentCount)
    try modelGUID.encode(into: &context)
    try context.encode(integer: modelCodeMask)
  }

  static func decode(from context: inout _OcaFirmwareImageContainerReader) throws -> Self {
    let magicNumber: OcaUint32 = try context.decode()
    guard magicNumber == Self.OcaFirmwareImageContainerHeaderMagicNumber else {
      throw OcaFirmwareImageContainerError.invalidMagicNumber
    }
    let headerVersion: OcaUint16 = try context.decode()
    guard headerVersion == Self.OcaFirmwareImageContainerHeaderVersion1 else {
      throw OcaFirmwareImageContainerError.unknownHeaderVersion
    }
    let headerSize: OcaUint16 = try context.decode()
    guard headerSize >= Self.Size else {
      throw OcaFirmwareImageContainerError.invalidHeaderSize
    }
    let headerFlags: Flags = try Flags(rawValue: context.decode())
    let componentCount: OcaUint16 = try context.decode()
    let modelGUID: OcaModelGUID = try OcaModelGUID.decode(from: &context)
    let modelCodeMask: OcaUint32 = try context.decode()
    let unknownBytes = Int(headerSize) - Self.Size
    try _ = context.decode(count: unknownBytes) { _ in }
    return Self(
      headerFlags: headerFlags,
      componentCount: componentCount,
      modelGUID: modelGUID,
      modelCodeMask: modelCodeMask
    )
  }
}

public struct OcaFirmwareImageContainerComponentDescriptor: _OcaFirmwareImageContainerEncodable,
  _OcaFirmwareImageContainerDecodable,
  CustomStringConvertible
{
  public static let Size = 48

  public struct Flags: OptionSet {
    public typealias RawValue = OcaBitSet16

    public var rawValue: OcaBitSet16

    public init(rawValue: OcaBitSet16) {
      self.rawValue = rawValue
    }
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

  static func decode(from context: inout _OcaFirmwareImageContainerReader) throws -> Self {
    let component: OcaComponent = try context.decode()
    let flags: Flags = try Flags(rawValue: context.decode())

    let major: OcaUint32 = try context.decode()
    let minor: OcaUint32 = try context.decode()
    let build: OcaUint32 = try context.decode()

    let imageOffset: OcaUint64 = try context.decode()
    let imageSize: OcaUint64 = try context.decode()
    guard imageOffset + imageSize <= context.size else {
      throw OcaFirmwareImageContainerError.invalidImageSize
    }

    let verifyOffset: OcaUint64 = try context.decode()
    let verifySize: OcaUint64 = try context.decode()
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
