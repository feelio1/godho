/// Public licensing status of a hospital record.
///
/// This is a fact from the public registry, not a judgement of quality.
enum HospitalStatus {
  open,
  closed,
  unknown;

  static HospitalStatus fromJson(String? value) {
    switch (value) {
      case 'open':
        return HospitalStatus.open;
      case 'closed':
        return HospitalStatus.closed;
      default:
        return HospitalStatus.unknown;
    }
  }

  String get label {
    switch (this) {
      case HospitalStatus.open:
        return '영업';
      case HospitalStatus.closed:
        return '폐업';
      case HospitalStatus.unknown:
        return '상태 확인 필요';
    }
  }
}
