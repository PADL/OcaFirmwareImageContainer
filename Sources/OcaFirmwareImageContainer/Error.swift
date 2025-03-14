/*
 * Copyright 2025 PADL Software Pty Ltd. All rights reserved.
 *
 * The information and source code contained herein is the exclusive
 * property of PADL Software Pty Ltd and may not be disclosed, examined
 * or reproduced in whole or in part without explicit written authorization
 * from the company.
 */

public enum OcaFirmwareImageContainerError: Error {
  case invalidComponentIndex
  case invalidMagicNumber
  case invalidOffset

  case invalidHeaderSize
  case invalidImageSize
  case invalidVerifySize

  case unknownHeaderVersion
  case unknownComponent
  case unknownModelCode

  case checksumVerificationFailed
  case signatureVerificationFailed

  case invalidComponent
  case invalidParameter
  case encodingNotBegun
}
