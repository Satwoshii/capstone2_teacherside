import 'package:flutter/material.dart';

enum AttendanceStatus {
  active,
  present,
  late,
  signedOut,
  absent;

  String get label {
    switch (this) {
      case AttendanceStatus.active:
        return 'Active (PC Online)';
      case AttendanceStatus.present:
        return 'Present';
      case AttendanceStatus.late:
        return 'Late Check-in';
      case AttendanceStatus.signedOut:
        return 'Signed Out';
      case AttendanceStatus.absent:
        return 'Absent';
    }
  }

  Color get color {
    switch (this) {
      case AttendanceStatus.active:
        return const Color(0xFF10B981); // Emerald Green
      case AttendanceStatus.present:
        return const Color(0xFF0EA5E9); // Ocean Blue
      case AttendanceStatus.late:
        return const Color(0xFFF59E0B); // Amber / Orange
      case AttendanceStatus.signedOut:
        return const Color(0xFF6B7280); // Neutral Slate
      case AttendanceStatus.absent:
        return const Color(0xFFEF4444); // Crimson Red
    }
  }

  IconData get icon {
    switch (this) {
      case AttendanceStatus.active:
        return Icons.computer_rounded;
      case AttendanceStatus.present:
        return Icons.check_circle_rounded;
      case AttendanceStatus.late:
        return Icons.schedule_rounded;
      case AttendanceStatus.signedOut:
        return Icons.logout_rounded;
      case AttendanceStatus.absent:
        return Icons.cancel_rounded;
    }
  }

  static AttendanceStatus fromString(String? raw) {
    if (raw == null) return AttendanceStatus.present;
    final text = raw.trim().toLowerCase().replaceAll(RegExp(r'[\s_-]'), '');
    if (text.contains('active') || text == 'online') return AttendanceStatus.active;
    if (text.contains('late')) return AttendanceStatus.late;
    if (text.contains('sign') || text.contains('out') || text == 'offline') {
      return AttendanceStatus.signedOut;
    }
    if (text.contains('absent')) return AttendanceStatus.absent;
    return AttendanceStatus.present;
  }
}

class StudentAttendanceRecord {
  final String id;
  final String studentId;
  final String studentName;
  final String studentEmail;
  final String courseSection;
  final String subject;
  final String pcId;
  final String workstationId;
  final DateTime loginTime;
  final DateTime? logoutTime;
  final AttendanceStatus status;
  final String ipAddress;
  final String? remarks;
  final DateTime? lastSeenAt;

  const StudentAttendanceRecord({
    required this.id,
    required this.studentId,
    required this.studentName,
    required this.studentEmail,
    required this.courseSection,
    required this.subject,
    required this.pcId,
    required this.workstationId,
    required this.loginTime,
    this.logoutTime,
    required this.status,
    required this.ipAddress,
    this.remarks,
    this.lastSeenAt,
  });

  bool get isActive => status == AttendanceStatus.active;
  bool get isLate => status == AttendanceStatus.late;
  bool get isSignedOut => status == AttendanceStatus.signedOut;
  bool get isAbsent => status == AttendanceStatus.absent;
  bool get isPresent =>
      status == AttendanceStatus.present ||
      status == AttendanceStatus.active ||
      status == AttendanceStatus.late;

  Duration get sessionDuration {
    final end = logoutTime ?? DateTime.now();
    final diff = end.difference(loginTime);
    return diff.isNegative ? Duration.zero : diff;
  }

  String get formattedDuration {
    final dur = sessionDuration;
    final hours = dur.inHours;
    final minutes = dur.inMinutes.remainder(60);
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${minutes}m';
  }

  String get formattedLoginTime {
    final dt = loginTime.toLocal();
    final h = dt.hour == 0 ? 12 : (dt.hour > 12 ? dt.hour - 12 : dt.hour);
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m $ampm';
  }

  String get formattedLogoutTime {
    if (logoutTime == null) return 'Active Now';
    final dt = logoutTime!.toLocal();
    final h = dt.hour == 0 ? 12 : (dt.hour > 12 ? dt.hour - 12 : dt.hour);
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m $ampm';
  }

  StudentAttendanceRecord copyWith({
    String? id,
    String? studentId,
    String? studentName,
    String? studentEmail,
    String? courseSection,
    String? subject,
    String? pcId,
    String? workstationId,
    DateTime? loginTime,
    DateTime? logoutTime,
    AttendanceStatus? status,
    String? ipAddress,
    String? remarks,
    DateTime? lastSeenAt,
  }) {
    return StudentAttendanceRecord(
      id: id ?? this.id,
      studentId: studentId ?? this.studentId,
      studentName: studentName ?? this.studentName,
      studentEmail: studentEmail ?? this.studentEmail,
      courseSection: courseSection ?? this.courseSection,
      subject: subject ?? this.subject,
      pcId: pcId ?? this.pcId,
      workstationId: workstationId ?? this.workstationId,
      loginTime: loginTime ?? this.loginTime,
      logoutTime: logoutTime ?? this.logoutTime,
      status: status ?? this.status,
      ipAddress: ipAddress ?? this.ipAddress,
      remarks: remarks ?? this.remarks,
      lastSeenAt: lastSeenAt ?? this.lastSeenAt,
    );
  }

  factory StudentAttendanceRecord.fromJson(Map<String, dynamic> json) {
    final loginRaw = json['login_time'] ?? json['time_in'] ?? json['created_at'];
    final logoutRaw = json['logout_time'] ?? json['time_out'];
    final lastSeenRaw = json['last_seen_at'];

    return StudentAttendanceRecord(
      id: (json['id'] ?? json['attendance_id'] ?? '').toString(),
      studentId: (json['student_id'] ?? json['student_number'] ?? 'N/A').toString(),
      studentName: (json['student_name'] ?? json['full_name'] ?? 'Student User').toString(),
      studentEmail: (json['student_email'] ?? json['email'] ?? '').toString(),
      courseSection: (json['course_section'] ?? json['section'] ?? 'Not set').toString(),
      subject: (json['subject'] ?? json['class_subject'] ?? 'Computer Lab Session').toString(),
      pcId: (json['pc_id'] ?? json['workstation_pc_id'] ?? 'PC').toString(),
      workstationId: (json['workstation_id'] ?? '').toString(),
      loginTime: DateTime.tryParse(loginRaw?.toString() ?? '') ?? DateTime.now(),
      logoutTime: DateTime.tryParse(logoutRaw?.toString() ?? ''),
      status: AttendanceStatus.fromString((json['status'] ?? '').toString()),
      ipAddress: (json['ip_address'] ?? json['client_ip'] ?? 'Not available').toString(),
      remarks: _nullable(json['remarks'] ?? json['notes']),
      lastSeenAt: DateTime.tryParse(lastSeenRaw?.toString() ?? ''),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'student_id': studentId,
      'student_name': studentName,
      'student_email': studentEmail,
      'course_section': courseSection,
      'subject': subject,
      'pc_id': pcId,
      'workstation_id': workstationId,
      'login_time': loginTime.toIso8601String(),
      'logout_time': logoutTime?.toIso8601String(),
      'status': status.name,
      'ip_address': ipAddress,
      'remarks': remarks,
      'last_seen_at': lastSeenAt?.toIso8601String(),
    };
  }
}

class AttendanceSummary {
  final int totalExpected;
  final int totalActive;
  final int totalPresent;
  final int totalLate;
  final int totalSignedOut;
  final int totalAbsent;
  final int totalVacantPcs;

  const AttendanceSummary({
    required this.totalExpected,
    required this.totalActive,
    required this.totalPresent,
    required this.totalLate,
    required this.totalSignedOut,
    required this.totalAbsent,
    required this.totalVacantPcs,
  });

  int get totalAttended => totalActive + totalPresent + totalLate;

  double get attendanceRate {
    if (totalExpected <= 0) return 100.0;
    final rate = (totalAttended / totalExpected) * 100.0;
    return rate > 100.0 ? 100.0 : rate;
  }
}

String? _nullable(dynamic val) {
  if (val == null) return null;
  final s = val.toString().trim();
  return s.isEmpty ? null : s;
}
