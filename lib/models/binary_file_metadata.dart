enum BinaryFileMetadataJsonKey {
  version,
  productName,
  fileDescription,
  legalCopyright,
  originalFilename,
  companyName,
  ;

  String get key {
    return toString().split('.').last;
  }
}

/// Represents file metadata information
class BinaryFileMetadata {
  final String version;
  final String productName;
  final String fileDescription;
  final String legalCopyright;
  final String originalFilename;
  final String companyName;

  factory BinaryFileMetadata.fromJson(Map<String, dynamic> json) {
    return BinaryFileMetadata(
      version: json[BinaryFileMetadataJsonKey.version.key] ?? '',
      productName: json[BinaryFileMetadataJsonKey.productName.key] ?? '',
      fileDescription:
          json[BinaryFileMetadataJsonKey.fileDescription.key] ?? '',
      legalCopyright: json[BinaryFileMetadataJsonKey.legalCopyright.key] ?? '',
      originalFilename:
          json[BinaryFileMetadataJsonKey.originalFilename.key] ?? '',
      companyName: json[BinaryFileMetadataJsonKey.companyName.key] ?? '',
    );
  }

  BinaryFileMetadata({
    this.version = '',
    this.productName = '',
    this.fileDescription = '',
    this.legalCopyright = '',
    this.originalFilename = '',
    this.companyName = '',
  });
}
