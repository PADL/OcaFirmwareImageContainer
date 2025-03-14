## OCA Firmware Image Container Format

The container format is designed to bundle one or more components for updating via OCA.

The format is opaque to the format of the component image and verify data, with the exception that it defines a well known component ID allowing the controller to perform limited client-side integrity verification. However, the format and (optionally cryptographic) integrity of the images themselves should be validated by the device being updated.

Integers are encoded in little-endian byte order. This is a change from OCP.1, but is a convenience reflecting the few big-endian platforms that exist today.

```c
struct {
    OcaUint32       magicNumber;        // OcaFirmwareImageContainerHeaderMagicNumber = 0xCFF1_A00C
    OcaUint32       headerVersion;      // OcaFirmwareImageContainerHeaderVersion1 = 1
    OcaUint16       headerSize;         // size of this structure in octets, 24
    OcaBitSet16     headerFlags;        // flags, unknown flags MUST be ignored
    OcaUint16       componentCount;     // number of component descriptors
    OcaModelGUID    modelGUID;          // device this container applies to
    OcaBlobFixedLen<4> modelCodeMask;   // relevant bits of device modelGUID.modelCode to check
} OcaFirmwareImageContainerHeader;

struct {
    OcaComponent    component;          // component ID this image applies to
    OcaBitSet16     flags;              // flags, unknown flags MUST be ignored
    OcaUint32       major;              // major version of firmware image
    OcaUint32       minor;              // minor version of firmware image
    OcaUint32       build;              // build version of firmware image
    OcaUint64       imageOffset;        // offset from start of container to image data
    OcaUint64       imageSize;          // length of image data
    OcaUint64       verifyOffset;       // offset from start of container to verify data
    OcaUint64       verifySize;         // length of verify data
} OcaFirmwareImageContainerComponentDescriptor;

struct {
    // offset: 0
    OcaFirmwareImageContainerHeader                 header;
    // offset: header.headerSize
    OcaFirmwareImageContainerComponentDescriptor    componentDescriptors[header.componentCount];
    // offset: header.headerSize + (header.componentCount * 48)
    OcaUint8                                        componentPayloads[];
} OcaFirmwareImageContainer;
```

A firmware image container file consists of a single `OcaFirmwareImageContainerHeader` follows by zero or more `OcaFirmwareImageContainerComponentDescriptor`s. Offsets MUST be aligned at 8 byte boundaries, to allow in-place decoding on 64-bit platforms. `headerSize` must be at least 24; any additional octets MUST be skipped and ignored. This allows for flags to gate future expansion without incrementing the header version.

There MUST be no more than one component descriptor for a given component ID (i.e. duplicate component IDs are not permitted).

No flags are defined at present.

The following component is defined for controller-side integrity verification. Controllers MUST validate that the container matches the model GUID of the device (after masking with modelCodeMask) as well as the container checksum. However, these validation checks are advisory only: the checksum is not a cryptographic checksum, and an untrusted controller could always extract the images directly and update them over OCA. Devices MUST validate the image data using the corresponding verify data.

`OcaFirmwareImageContainerSHA512ChecksumComponent` has the value `0x8001`.

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
