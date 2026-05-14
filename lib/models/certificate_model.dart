class CertificateData {
  final String serialNumber;
  final String issuer;
  final String subject;
  final String subjectUid;
  final String notBefore;
  final String notAfter;
  final String publicKey;
  final String signature;

  const CertificateData({
    required this.serialNumber,
    required this.issuer,
    required this.subject,
    required this.subjectUid,
    required this.notBefore,
    required this.notAfter,
    required this.publicKey,
    required this.signature,
  });

  factory CertificateData.fromMap(Map<String, dynamic> m) => CertificateData(
        serialNumber: m['serialNumber'] ?? '',
        issuer: m['issuer'] ?? '',
        subject: m['subject'] ?? '',
        subjectUid: m['subjectUid'] ?? '',
        notBefore: m['notBefore'] ?? '',
        notAfter: m['notAfter'] ?? '',
        publicKey: m['publicKey'] ?? '',
        signature: m['signature'] ?? '',
      );

  Map<String, dynamic> toMap() => {
        'serialNumber': serialNumber,
        'issuer': issuer,
        'subject': subject,
        'subjectUid': subjectUid,
        'notBefore': notBefore,
        'notAfter': notAfter,
        'publicKey': publicKey,
        'signature': signature,
      };

  bool get isExpired {
    final after = DateTime.tryParse(notAfter);
    if (after == null) return true;
    return DateTime.now().isAfter(after);
  }

  bool get isNotYetValid {
    final before = DateTime.tryParse(notBefore);
    if (before == null) return true;
    return DateTime.now().isBefore(before);
  }

  bool get isTemporallyValid => !isExpired && !isNotYetValid;
}