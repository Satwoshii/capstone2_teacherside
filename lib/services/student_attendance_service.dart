import '../models/lab_overview.dart';
import '../models/student_attendance.dart';
import 'api_client.dart';
import 'api_endpoints.dart';

class StudentAttendanceService {
  StudentAttendanceService._();

  static final StudentAttendanceService instance = StudentAttendanceService._();

  final List<StudentAttendanceRecord> _records = [];

  List<StudentAttendanceRecord> get currentRecords => List.unmodifiable(_records);

  /// Loads Student attendance from the Syswatch MariaDB API.
  ///
  /// The Teacher app no longer invents/sample-generates attendance rows when
  /// the server is empty or unavailable. If the API cannot be reached, the
  /// caller receives the real error so the UI can show that attendance is not
  /// connected instead of displaying fake students.
  Future<(List<StudentAttendanceRecord>, AttendanceSummary)> getAttendance({
    required LabOverview room,
    bool forceRefresh = false,
    bool includeHistory = false,
  }) async {
    final response = await ApiClient.instance.getJson(
      ApiEndpoints.teacherAttendance,
      query: {
        'scope': includeHistory ? 'history' : 'today',
      },
    );

    final rawList = response['records'] ?? response['attendance'];
    _records.clear();

    if (rawList is List) {
      for (final item in rawList) {
        if (item is Map) {
          _records.add(
            StudentAttendanceRecord.fromJson(
              item.map((k, v) => MapEntry(k.toString(), v)),
            ),
          );
        }
      }
    }

    _records.sort((a, b) => b.loginTime.compareTo(a.loginTime));

    final summary = _computeSummary(room);
    return (List<StudentAttendanceRecord>.unmodifiable(_records), summary);
  }

  /// Manually records a Student attendance/check-in in MariaDB.
  Future<StudentAttendanceRecord> checkInStudent({
    required String pcId,
    required String studentId,
    required String studentName,
    required String studentEmail,
    required String courseSection,
    required String subject,
    required AttendanceStatus status,
    String? remarks,
  }) async {
    final response = await ApiClient.instance.postJson(
      ApiEndpoints.teacherAttendance,
      body: {
        'action': 'check_in',
        'pc_id': pcId.trim(),
        'student_id': studentId.trim(),
        'student_name': studentName.trim(),
        'student_email': studentEmail.trim(),
        'course_section': courseSection.trim(),
        'subject': subject.trim(),
        'status': status.name,
        'remarks': remarks?.trim(),
      },
    );

    final rawRecord = response['record'];
    if (rawRecord is! Map) {
      throw const ApiRequestException(
        statusCode: 500,
        code: 'attendance_record_missing',
        message: 'The server saved the attendance record but did not return it.',
      );
    }

    final record = StudentAttendanceRecord.fromJson(
      rawRecord.map((key, value) => MapEntry(key.toString(), value)),
    );

    // Keep one current locally cached record for this PC. Historical rows will
    // be fetched again from the database on the next refresh.
    _records.removeWhere(
      (r) => r.pcId.toLowerCase() == record.pcId.toLowerCase() && r.isActive,
    );
    _records.insert(0, record);
    return record;
  }

  /// Updates attendance status/Teacher remarks in MariaDB.
  Future<StudentAttendanceRecord> updateStatus({
    required String recordId,
    required AttendanceStatus newStatus,
    String? remarks,
  }) async {
    final response = await ApiClient.instance.postJson(
      ApiEndpoints.teacherAttendance,
      body: {
        'action': 'update_status',
        'id': recordId,
        'status': newStatus.name,
        'remarks': remarks,
      },
    );

    final rawRecord = response['record'];
    if (rawRecord is! Map) {
      throw const ApiRequestException(
        statusCode: 500,
        code: 'attendance_record_missing',
        message: 'The attendance record was updated but could not be reloaded.',
      );
    }

    final updated = StudentAttendanceRecord.fromJson(
      rawRecord.map((key, value) => MapEntry(key.toString(), value)),
    );

    final index = _records.indexWhere((r) => r.id == recordId);
    if (index >= 0) {
      _records[index] = updated;
    } else {
      _records.insert(0, updated);
    }
    return updated;
  }

  Future<void> signOutStudent(String recordId) async {
    await updateStatus(
      recordId: recordId,
      newStatus: AttendanceStatus.signedOut,
      remarks: 'Signed out by Teacher',
    );
  }

  AttendanceSummary _computeSummary(LabOverview room) {
    final active = _records.where((r) => r.status == AttendanceStatus.active).length;
    final present = _records.where((r) => r.status == AttendanceStatus.present).length;
    final lateCount = _records.where((r) => r.status == AttendanceStatus.late).length;
    final signedOut = _records.where((r) => r.status == AttendanceStatus.signedOut).length;
    final absent = _records.where((r) => r.status == AttendanceStatus.absent).length;

    final occupiedPcs = _records
        .where((r) => r.isActive || r.status == AttendanceStatus.late || r.status == AttendanceStatus.present)
        .map((r) => r.pcId.toLowerCase())
        .toSet();
    final totalExpected = room.expectedPcCount > 0 ? room.expectedPcCount : room.registeredPcCount;
    final totalVacantPcs = (totalExpected - occupiedPcs.length).clamp(0, 999);

    return AttendanceSummary(
      totalExpected: totalExpected,
      totalActive: active,
      totalPresent: present,
      totalLate: lateCount,
      totalSignedOut: signedOut,
      totalAbsent: absent,
      totalVacantPcs: totalVacantPcs,
    );
  }

  String exportCsv({required String roomName}) {
    final buffer = StringBuffer();
    final now = DateTime.now();
    buffer.writeln('# SysWatch Laboratory Student Attendance Report');
    buffer.writeln('# Room: ${_csvCell(roomName)}');
    buffer.writeln('# Date Generated: ${_csvCell(now.toLocal().toString())}');
    buffer.writeln('PC ID,Student ID,Student Name,Email,Subject,Time In,Time Out,Duration,Status,IP Address,Remarks');

    for (final r in _records) {
      final line = [
        r.pcId,
        r.studentId,
        r.studentName,
        r.studentEmail,
        r.subject,
        r.formattedLoginTime,
        r.formattedLogoutTime,
        r.formattedDuration,
        r.status.label,
        r.ipAddress,
        r.remarks ?? '',
      ].map(_csvCell).join(',');
      buffer.writeln(line);
    }

    return buffer.toString();
  }

  String _csvCell(String value) {
    final escaped = value.replaceAll('"', '""');
    return '"$escaped"';
  }
}
