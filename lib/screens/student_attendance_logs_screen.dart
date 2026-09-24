import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/app_user.dart';
import '../models/lab_overview.dart';
import '../models/student_attendance.dart';
import '../services/student_attendance_service.dart';
import '../services/teacher_windows_session_service.dart';
import '../utils/value_helpers.dart';
import '../widgets/theme_toggle_button.dart';

class StudentAttendanceLogsScreen extends StatefulWidget {
  final AppUser user;
  final LabOverview room;

  const StudentAttendanceLogsScreen({
    super.key,
    required this.user,
    required this.room,
  });

  @override
  State<StudentAttendanceLogsScreen> createState() =>
      _StudentAttendanceLogsScreenState();
}

class _StudentAttendanceLogsScreenState extends State<StudentAttendanceLogsScreen> {
  Future<(List<StudentAttendanceRecord>, AttendanceSummary)>? _future;
  Timer? _refreshTimer;
  Timer? _clockTimer;

  final TextEditingController _searchController = TextEditingController();
  AttendanceStatus? _statusFilter;
  String _subjectFilter = 'All Subjects';
  DateTime _now = DateTime.now();

  bool get _dark => Theme.of(context).brightness == Brightness.dark;
  Color get _background => _dark ? const Color(0xFF090A0E) : const Color(0xFFF0F2F5);
  Color get _card => _dark ? const Color(0xFF13141A) : Colors.white;
  Color get _field => _dark ? const Color(0xFF1C1E26) : const Color(0xFFEDF0F5);
  Color get _text => _dark ? Colors.white : const Color(0xFF1A1C1E);
  Color get _sub => _dark ? Colors.white54 : Colors.black54;
  Color get _border => _dark ? Colors.white.withValues(alpha: 0.08) : Colors.black12;
  Color get _accentA => const Color(0xFFFFD700);
  Color get _accentB => const Color(0xFF003366);
  Color get _accentAForeground => _dark ? _accentA : _accentB;
  Color get _accentColor => _dark ? _accentA : _accentB;

  @override
  void initState() {
    super.initState();
    _refresh();
    _refreshTimer = Timer.periodic(const Duration(seconds: 15), (_) => _refresh(silent: true));
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {
          _now = DateTime.now();
        });
      }
    });
    _searchController.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    setState(() {});
  }

  void _refresh({bool silent = false, bool force = false}) {
    final future = StudentAttendanceService.instance.getAttendance(
      room: widget.room,
      forceRefresh: force,
    );
    if (!silent) {
      setState(() {
        _future = future;
      });
    } else {
      future.then((_) {
        if (mounted) setState(() {});
      }).catchError((_) {});
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _clockTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      body: Stack(
        children: [
          _ambientBackground(),
          Column(
            children: [
              _topBar(),
              Expanded(
                child: FutureBuilder<(List<StudentAttendanceRecord>, AttendanceSummary)>(
                  future: _future,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Center(
                        child: Container(
                          width: 58,
                          height: 58,
                          decoration: BoxDecoration(
                            color: _card,
                            shape: BoxShape.circle,
                            border: Border.all(color: _border),
                          ),
                          padding: const EdgeInsets.all(16),
                          child: CircularProgressIndicator(
                            color: _accentAForeground,
                            strokeWidth: 2.4,
                          ),
                        ),
                      );
                    }
                    if (snapshot.hasError) {
                      return _errorState(cleanError(snapshot.error!));
                    }
                    final data = snapshot.data;
                    if (data == null) {
                      return _errorState('No login/logout summary logs available.');
                    }
                    return _content(data.$1, data.$2);
                  },
                ),
              ),
            ],
          ),
          const Positioned(
            left: 20,
            bottom: 20,
            child: ThemeToggleButton(),
          ),
        ],
      ),
    );
  }

  Widget _ambientBackground() {
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned(
            top: -180,
            left: -120,
            child: Container(
              width: 520,
              height: 520,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    _accentB.withValues(alpha: _dark ? 0.15 : 0.12),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            right: -180,
            bottom: -220,
            child: Container(
              width: 620,
              height: 620,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    _accentAForeground.withValues(alpha: _dark ? 0.12 : 0.10),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _topBar() {
    final navBg = _dark ? _card.withValues(alpha: 0.96) : _accentB;
    final navFg = _dark ? _text : Colors.white;
    final navSub = _dark ? _sub : Colors.white70;
    final navBorder = _dark ? _border : Colors.white.withValues(alpha: 0.1);

    final windowsAccount = TeacherWindowsSessionService.instance.cachedAccount;
    final currentUserDisplayName = windowsAccount?.displayLabel ?? widget.user.displayName;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 13),
      decoration: BoxDecoration(
        color: navBg,
        border: Border(bottom: BorderSide(color: navBorder)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: _dark ? 0.16 : 0.08),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          _iconTile(
            icon: Icons.arrow_back_rounded,
            tooltip: 'Back to Attendance',
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 14),
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: _dark ? _accentColor.withValues(alpha: 0.14) : Colors.white.withValues(alpha: 0.2),
              border: Border.all(
                color: _dark ? _accentColor.withValues(alpha: 0.38) : Colors.white.withValues(alpha: 0.3),
                width: 1.2,
              ),
            ),
            child: Icon(
              Icons.history_edu_rounded,
              color: _dark ? _accentAForeground : Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 13),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Student Login & Logout Summary Logs',
                style: TextStyle(
                  color: navFg,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.1,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Laboratory ${widget.room.roomName} · Detailed Time-In & Time-Out Audit',
                style: TextStyle(color: navSub, fontSize: 11.5),
              ),
            ],
          ),
          const Spacer(),
          // Clock
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: _dark ? _field : Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: navBorder),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Color(0xFF10B981),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _formatClock(_now),
                  style: TextStyle(
                    color: navFg,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // User Pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: _dark ? _field : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _dark ? navBorder : Colors.black.withValues(alpha: 0.1),
                width: 1.2,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: _dark
                        ? _accentAForeground.withValues(alpha: 0.12)
                        : _accentB.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.person_rounded,
                    color: _dark ? _accentAForeground : _accentB,
                    size: 15,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  currentUserDisplayName,
                  style: TextStyle(
                    color: _dark ? navFg : Colors.black87,
                    fontSize: 12.8,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          _gradientButton(
            label: 'Export Logs CSV',
            icon: Icons.download_rounded,
            onPressed: () => _showExportDialog(),
          ),
          const SizedBox(width: 8),
          _iconTile(
            icon: Icons.refresh_rounded,
            tooltip: 'Refresh logs',
            onPressed: () => _refresh(force: true),
          ),
        ],
      ),
    );
  }

  Widget _content(List<StudentAttendanceRecord> allRecords, AttendanceSummary summary) {
    final query = _searchController.text.trim().toLowerCase();
    final subjects = {'All Subjects', ...allRecords.map((r) => r.subject)};

    final filtered = allRecords.where((r) {
      if (_statusFilter != null && r.status != _statusFilter) {
        return false;
      }
      if (_subjectFilter != 'All Subjects' && r.subject != _subjectFilter) {
        return false;
      }
      if (query.isNotEmpty) {
        final pc = r.pcId.toLowerCase();
        final name = r.studentName.toLowerCase();
        final id = r.studentId.toLowerCase();
        final sec = r.courseSection.toLowerCase();
        return pc.contains(query) ||
            name.contains(query) ||
            id.contains(query) ||
            sec.contains(query);
      }
      return true;
    }).toList();

    return RefreshIndicator(
      color: _accentAForeground,
      onRefresh: () async => _refresh(force: true),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 86),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1540),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _summaryCardsHeader(allRecords, summary),
                  const SizedBox(height: 20),
                  _toolbarControls(subjects),
                  const SizedBox(height: 18),
                  _logsTableCard(filtered),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryCardsHeader(List<StudentAttendanceRecord> allRecords, AttendanceSummary summary) {
    final signedOutCount = allRecords.where((r) => r.isSignedOut).length;
    final activeCount = allRecords.where((r) => r.isActive).length;

    return Row(
      children: [
        Expanded(
          child: _kpiCard(
            title: 'Total Logged-In Sessions',
            value: '${allRecords.length}',
            subtitle: 'Recorded student check-ins',
            icon: Icons.login_rounded,
            color: const Color(0xFF0EA5E9),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: _kpiCard(
            title: 'Currently Active (Online)',
            value: '$activeCount',
            subtitle: 'Students currently logged in',
            icon: Icons.computer_rounded,
            color: const Color(0xFF10B981),
            hasPulse: activeCount > 0,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: _kpiCard(
            title: 'Signed Out Sessions',
            value: '$signedOutCount',
            subtitle: 'Successfully logged out',
            icon: Icons.logout_rounded,
            color: const Color(0xFF6B7280),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: _kpiCard(
            title: 'Room Occupancy Rate',
            value: '${summary.attendanceRate.toStringAsFixed(1)}%',
            subtitle: '${summary.totalAttended} of ${summary.totalExpected} PCs occupied',
            icon: Icons.analytics_rounded,
            color: const Color(0xFF8B5CF6),
          ),
        ),
      ],
    );
  }

  Widget _kpiCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    bool hasPulse = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: _dark ? 0.2 : 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const Spacer(),
              if (hasPulse)
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: 0.6),
                        blurRadius: 6,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            value,
            style: TextStyle(
              color: _text,
              fontSize: 26,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              color: _text,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(
              color: _sub,
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _toolbarControls(Set<String> subjects) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
      ),
      child: Row(
        children: [
          // Search Bar
          Expanded(
            flex: 3,
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                color: _field,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _border),
              ),
              child: TextField(
                controller: _searchController,
                style: TextStyle(color: _text, fontSize: 13.5),
                decoration: InputDecoration(
                  hintText: 'Search by student name, ID, PC workstation, or section...',
                  hintStyle: TextStyle(color: _sub, fontSize: 13),
                  prefixIcon: Icon(Icons.search_rounded, color: _sub, size: 18),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: Icon(Icons.clear_rounded, color: _sub, size: 16),
                          onPressed: () => _searchController.clear(),
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          // Subject Dropdown
          Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: _field,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _border),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: subjects.contains(_subjectFilter) ? _subjectFilter : 'All Subjects',
                dropdownColor: _card,
                style: TextStyle(color: _text, fontSize: 13, fontWeight: FontWeight.w600),
                items: subjects.map((sub) {
                  return DropdownMenuItem<String>(
                    value: sub,
                    child: Text(sub),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() => _subjectFilter = val);
                  }
                },
              ),
            ),
          ),
          const SizedBox(width: 14),
          // Status Filter Dropdown
          Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: _field,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _border),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<AttendanceStatus?>(
                value: _statusFilter,
                dropdownColor: _card,
                style: TextStyle(color: _text, fontSize: 13, fontWeight: FontWeight.w600),
                hint: Text('All Statuses', style: TextStyle(color: _sub, fontSize: 13)),
                items: [
                  const DropdownMenuItem<AttendanceStatus?>(
                    value: null,
                    child: Text('All Statuses'),
                  ),
                  ...AttendanceStatus.values.map((st) {
                    return DropdownMenuItem<AttendanceStatus?>(
                      value: st,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: st.color,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(st.label),
                        ],
                      ),
                    );
                  }),
                ],
                onChanged: (val) {
                  setState(() => _statusFilter = val);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _logsTableCard(List<StudentAttendanceRecord> records) {
    if (records.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(60),
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _border),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history_toggle_off_rounded, size: 52, color: _sub.withValues(alpha: 0.5)),
            const SizedBox(height: 16),
            Text(
              'No Student Login/Logout Logs Found',
              style: TextStyle(color: _text, fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              'Try adjusting your search query or status filter criteria.',
              style: TextStyle(color: _sub, fontSize: 13),
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: _dark ? 0.2 : 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(_field),
            dataRowMinHeight: 56,
            dataRowMaxHeight: 68,
            horizontalMargin: 20,
            columnSpacing: 24,
            columns: [
              DataColumn(label: Text('PC / WS', style: TextStyle(color: _text, fontWeight: FontWeight.w800))),
              DataColumn(label: Text('Student Name & ID', style: TextStyle(color: _text, fontWeight: FontWeight.w800))),
              DataColumn(label: Text('Section & Subject', style: TextStyle(color: _text, fontWeight: FontWeight.w800))),
              DataColumn(label: Text('Time In (Login)', style: TextStyle(color: _text, fontWeight: FontWeight.w800))),
              DataColumn(label: Text('Time Out (Logout)', style: TextStyle(color: _text, fontWeight: FontWeight.w800))),
              DataColumn(label: Text('Duration', style: TextStyle(color: _text, fontWeight: FontWeight.w800))),
              DataColumn(label: Text('Status', style: TextStyle(color: _text, fontWeight: FontWeight.w800))),
              DataColumn(label: Text('Remarks / Notes', style: TextStyle(color: _text, fontWeight: FontWeight.w800))),
            ],
            rows: records.map((r) {
              return DataRow(
                cells: [
                  // PC / WS
                  DataCell(
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: _accentColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: _accentColor.withValues(alpha: 0.3)),
                          ),
                          child: Text(
                            r.pcId,
                            style: TextStyle(
                              color: _accentAForeground,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Student Name & ID
                  DataCell(
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 16,
                          backgroundColor: _accentColor.withValues(alpha: 0.15),
                          child: Text(
                            _initials(r.studentName),
                            style: TextStyle(
                              color: _accentAForeground,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              r.studentName,
                              style: TextStyle(
                                color: _text,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              r.studentId,
                              style: TextStyle(
                                color: _sub,
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Section & Subject
                  DataCell(
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          r.courseSection,
                          style: TextStyle(
                            color: _text,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          r.subject,
                          style: TextStyle(
                            color: _sub,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Time In (Login)
                  DataCell(
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.login_rounded, size: 14, color: Color(0xFF10B981)),
                        const SizedBox(width: 6),
                        Text(
                          r.formattedLoginTime,
                          style: TextStyle(
                            color: _text,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Time Out (Logout)
                  DataCell(
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.logout_rounded,
                          size: 14,
                          color: r.logoutTime != null ? const Color(0xFFEF4444) : _sub,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          r.formattedLogoutTime,
                          style: TextStyle(
                            color: r.logoutTime != null ? _text : _sub,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Duration
                  DataCell(
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _field,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        r.formattedDuration,
                        style: TextStyle(
                          color: _text,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                  ),
                  // Status
                  DataCell(
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: r.status.color.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: r.status.color.withValues(alpha: 0.35)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(r.status.icon, size: 13, color: r.status.color),
                          const SizedBox(width: 6),
                          Text(
                            r.status.label,
                            style: TextStyle(
                              color: r.status.color,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Remarks / Notes
                  DataCell(
                    Text(
                      r.remarks ?? '—',
                      style: TextStyle(
                        color: r.remarks != null ? _text : _sub,
                        fontSize: 12,
                        fontStyle: r.remarks != null ? FontStyle.normal : FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  void _showExportDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: [
            Icon(Icons.download_rounded, color: _accentAForeground),
            const SizedBox(width: 12),
            Text('Export Attendance Logs', style: TextStyle(color: _text, fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          'Export all student login and logout history logs for laboratory ${widget.room.roomName} as a CSV report?',
          style: TextStyle(color: _sub, fontSize: 13.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: _sub)),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: _accentColor,
              foregroundColor: _dark ? Colors.black : Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            icon: const Icon(Icons.download_rounded, size: 18),
            label: const Text('Download CSV'),
            onPressed: () {
              Navigator.pop(ctx);
              final csv = StudentAttendanceService.instance.exportCsv(roomName: widget.room.roomName);
              Clipboard.setData(ClipboardData(text: csv));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Attendance logs CSV copied to clipboard!'),
                  backgroundColor: const Color(0xFF10B981),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _errorState(String message) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(32),
        margin: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, color: Color(0xFFEF4444), size: 44),
            const SizedBox(height: 14),
            Text(
              'Failed to Load Logs',
              style: TextStyle(color: _text, fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: _sub, fontSize: 13),
            ),
            const SizedBox(height: 18),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: _accentColor,
                foregroundColor: _dark ? Colors.black : Colors.white,
              ),
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Retry'),
              onPressed: () => _refresh(force: true),
            ),
          ],
        ),
      ),
    );
  }

  Widget _iconTile({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onPressed,
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _dark ? _border : Colors.white.withValues(alpha: 0.2)),
              color: _dark ? _field : Colors.white.withValues(alpha: 0.15),
            ),
            child: Icon(
              icon,
              color: _dark ? _text : Colors.white,
              size: 20,
            ),
          ),
        ),
      ),
    );
  }

  Widget _gradientButton({
    required String label,
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onPressed,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: LinearGradient(
              colors: _dark
                  ? [_accentA, _accentA.withValues(alpha: 0.8)]
                  : [Colors.white, Colors.white.withValues(alpha: 0.9)],
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: _dark ? Colors.black : _accentB,
                size: 16,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: _dark ? Colors.black : _accentB,
                  fontSize: 12.8,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatClock(DateTime dt) {
    final h = dt.hour == 0 ? 12 : (dt.hour > 12 ? dt.hour - 12 : dt.hour);
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    final m = dt.minute.toString().padLeft(2, '0');
    final s = dt.second.toString().padLeft(2, '0');
    return '$h:$m:$s $ampm';
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'[\s,]+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return 'ST';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }
}
