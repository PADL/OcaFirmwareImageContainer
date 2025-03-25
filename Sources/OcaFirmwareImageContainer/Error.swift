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
  case invalidModelCount

  case checksumVerificationFailed
  case signatureVerificationFailed

  case invalidComponent
  case invalidParameter
  case encodingNotBegun
}
