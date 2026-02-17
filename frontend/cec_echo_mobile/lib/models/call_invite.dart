class CallInvite {
  final String callId;
  final String otherId;
  final String otherName;
  final String callType;
  final String? meetingId;
  final bool isIncoming;
  final DateTime createdAt;
  final String status;

  CallInvite({
    required this.callId,
    required this.otherId,
    required this.otherName,
    required this.callType,
    required this.isIncoming,
    required this.createdAt,
    required this.status,
    this.meetingId,
  });

  CallInvite copyWith({
    String? status,
    String? otherName,
    String? callType,
    String? meetingId,
  }) {
    return CallInvite(
      callId: callId,
      otherId: otherId,
      otherName: otherName ?? this.otherName,
      callType: callType ?? this.callType,
      meetingId: meetingId ?? this.meetingId,
      isIncoming: isIncoming,
      createdAt: createdAt,
      status: status ?? this.status,
    );
  }

  String get displayType => callType == 'video' ? 'Video' : 'Audio';

  String get statusLabel {
    switch (status) {
      case 'incoming':
        return 'Incoming';
      case 'ringing':
        return 'Ringing';
      case 'accepted':
        return 'Joined';
      case 'rejected':
        return 'Declined';
      case 'ended':
        return 'Ended';
      default:
        return status;
    }
  }
}
