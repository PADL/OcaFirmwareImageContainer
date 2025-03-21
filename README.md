## OCA Firmware Image Container Format

The container format is designed to bundle one or more components for updating via OCA.

The format is opaque to the format of the component image and verify data, with the exception that it defines a well known component ID allowing the controller to perform limited client-side integrity verification. However, the format and (optionally cryptographic) integrity of the images themselves should be validated by the device being updated.

Integers are encoded in little-endian byte order. This is a change from OCP.1, but is a convenience reflecting the few big-endian platforms that exist today.

```c
struct {
    OcaUint32       MagicNumber;        // OcaFirmwareImageContainerHeaderMagicNumber = 0xCFF1_A00C
    OcaUint32       HeaderVersion;      // OcaFirmwareImageContainerHeaderVersion1 = 1
    OcaUint16       HeaderSize;         // size of this structure in octets, 24
    OcaBitSet16     HeaderFlags;        // flags, unknown flags MUST be ignored
    OcaUint16       ComponentCount;     // number of component descriptors
    OcaModelGUID    ModelGUID;          // device this container applies to
    OcaBlobFixedLen<4> ModelCodeMask;   // relevant bits of device modelGUID.modelCode to check
} OcaFirmwareImageContainerHeader;

struct {
    OcaComponent    Component;          // component ID this image applies to
    OcaBitSet16     Flags;              // flags, unknown flags MUST be ignored
    OcaUint32       Major;              // major version of firmware image
    OcaUint32       Minor;              // minor version of firmware image
    OcaUint32       Build;              // build version of firmware image
    OcaUint64       ImageOffset;        // offset from start of container to image data
    OcaUint64       ImageSize;          // length of image data
    OcaUint64       VerifyOffset;       // offset from start of container to verify data
    OcaUint64       VerifySize;         // length of verify data
} OcaFirmwareImageContainerComponentDescriptor;

struct {
    // offset: 0
    OcaFirmwareImageContainerHeader                 Header;
    // offset: header.headerSize
    OcaFirmwareImageContainerComponentDescriptor    ComponentDescriptors[header.componentCount];
    // offset: header.headerSize + (header.componentCount * 48)
    OcaUint8                                        ComponentPayloads[];
} OcaFirmwareImageContainer;
```

A firmware image container file consists of a single `OcaFirmwareImageContainerHeader` follows by zero or more `OcaFirmwareImageContainerComponentDescriptor`s. Offsets MUST be aligned at 8 byte boundaries, to allow in-place decoding on 64-bit platforms. `headerSize` must be at least 24; any additional octets MUST be skipped and ignored. This allows for flags to gate future expansion without incrementing the header version.

There MUST be no more than one component descriptor for a given component ID (i.e. duplicate component IDs are not permitted).

A single flag, 0x1, is defined indicating that the component descriptor is to be processed locally and not sent to the device.

The following component is defined for controller-side integrity verification. Controllers MUST validate that the container matches the model GUID of the device (after masking with modelCodeMask) as well as the container checksum. However, these validation checks are advisory only: the checksum is not a cryptographic checksum, and an untrusted controller could always extract the images directly and update them over OCA. Devices MUST validate the image data using the corresponding verify data. The local flag MUST be set on the checksum component descriptor.

Pseudo-code for calculating the checksum is provided below:

```
calculateSHA512ContainerChecksum(
    OcaFirmwareImageContainerHeader header,
    OcaUint16 count,
    OcaFirmwareImageContainerComponentDescriptor descriptors[count])
{
    checksum = SHA512()

    checksum.update(header.encode())

    for (index = 0, index < count, index++) {
        checksum.update(descriptors[index].encode())

        if (descriptors[index].component == OcaFirmwareImageContainerSHA512ChecksumComponent)
            continue

        checksum.update(header.start + descriptors[index].imageOffset ... imageSize)
        checksum.update(header.start + descriptors[index].verifyOffset ... verifySize)
    }

    return checksum.finalize()
}
```

Notes:

* padding is not included in the checksum
* the container checksum is controller-side only; it MUST NOT be sent over OCA
* `imageOffset` and `imageSize` are zero; the checksum is placed at `verifyOffset`, and `verifySize` is 64
* the component descriptor for the checksum is included as input into the checksum data
