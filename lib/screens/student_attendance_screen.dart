import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/app_user.dart';
import '../models/lab_overview.dart';
import '../models/student_attendance.dart';
import '../services/student_attendance_service.dart';
import '../services/teacher_windows_session_service.dart';
import '../utils/value_helpers.dart';
import '../widgets/theme_toggle_button.dart';
import 'student_attendance_logs_screen.dart';

enum _AttendanceViewMode { grid, table }

class StudentAttendanceScreen extends StatefulWidget {
  final AppUser user;
  final LabOverview room;

  const StudentAttendanceScreen({
    super.key,
    required this.user,
    required this.room,
  });

  @override
  State<StudentAttendanceScreen> createState() =>
      _StudentAttendanceScreenState();
}

class _StudentAttendanceScreenState extends State<StudentAttendanceScreen> {
  Future<(List<StudentAttendanceRecord>, AttendanceSummary)>? _future;
  Timer? _refreshTimer;
  Timer? _clockTimer;

  final TextEditingController _searchController = TextEditingController();
  AttendanceStatus? _statusFilter;
  _AttendanceViewMode _viewMode = _AttendanceViewMode.grid;
  String _subjectFilter = 'All Subjects';
  DateTime _now = DateTime.now();

  bool get _dark => Theme.of(context).brightness == Brightness.dark;
  Color get _background =>
      _dark ? const Color(0xFF090A0E) : const Color(0xFFF0F2F5);
  Color get _card => _dark ? const Color(0xFF13141A) : Colors.white;
  Color get _field =>
      _dark ? const Color(0xFF1C1E26) : const Color(0xFFEDF0F5);
  Color get _text => _dark ? Colors.white : const Color(0xFF1A1C1E);
  Color get _sub => _dark ? Colors.white54 : Colors.black54;
  Color get _border =>
      _dark ? Colors.white.withValues(alpha: 0.08) : Colors.black12;
  Color get _accentA => const Color(0xFFFFD700);
  Color get _accentB => const Color(0xFF003366);
  Color get _accentAForeground => _dark ? _accentA : _accentB;
  Color get _accentBForeground => _dark ? Colors.white : _accentB;
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
        if (mounted) {
          setState(() {});
        }
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
                      return _errorState('No attendance data available.');
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
    final currentUserDisplayName = windowsAccount?.displayLabel ??
        widget.user.displayName;

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
            tooltip: 'Back to Dashboard',
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
              Icons.co_present_rounded,
              color: _dark ? _accentAForeground : Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 13),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Student Attendance Monitoring',
                style: TextStyle(
                  color: navFg,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.1,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Laboratory ${widget.room.roomName} · Student PC Usage',
                style: TextStyle(color: navSub, fontSize: 11.5),
              ),
            ],
          ),
          const Spacer(),
          // Live Clock Widget
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
            label: 'Login/Logout Logs',
            icon: Icons.history_rounded,
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => StudentAttendanceLogsScreen(
                    user: widget.user,
                    room: widget.room,
                  ),
                ),
              );
            },
          ),
          const SizedBox(width: 8),
          _gradientButton(
            label: 'Log Check-In',
            icon: Icons.person_add_alt_1_rounded,
            onPressed: () => _showManualCheckInDialog(),
          ),
          const SizedBox(width: 8),
          _gradientButton(
            label: 'Export CSV',
            icon: Icons.download_rounded,
            onPressed: () => _showExportDialog(),
          ),
          const SizedBox(width: 8),
          _iconTile(
            icon: Icons.refresh_rounded,
            tooltip: 'Refresh attendance data',
            onPressed: () => _refresh(force: true),
          ),
        ],
      ),
    );
  }

  Widget _content(
    List<StudentAttendanceRecord> allRecords,
    AttendanceSummary summary,
  ) {
    // Filter records
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
        return pc.contains(query) ||
            name.contains(query) ||
            id.contains(query);
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
                  _summaryCardsHeader(summary),
                  const SizedBox(height: 20),
                  _toolbarControls(subjects),
                  const SizedBox(height: 18),
                  if (_viewMode == _AttendanceViewMode.grid)
                    _gridMapView(filtered, allRecords)
                  else
                    _tableListView(filtered),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryCardsHeader(AttendanceSummary summary) {
    return Row(
      children: [
        Expanded(
          child: _kpiCard(
            title: 'Students Active on PC',
            value: '${summary.totalActive}',
            subtitle: 'Currently online in Lab',
            icon: Icons.computer_rounded,
            color: const Color(0xFF10B981),
            hasPulse: summary.totalActive > 0,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: _kpiCard(
            title: 'Total Present Today',
            value: '${summary.totalAttended}',
            subtitle: 'Includes active & checked-in',
            icon: Icons.how_to_reg_rounded,
            color: const Color(0xFF0EA5E9),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: _kpiCard(
            title: 'Late Check-Ins',
            value: '${summary.totalLate}',
            subtitle: 'Arrived after class start',
            icon: Icons.schedule_rounded,
            color: const Color(0xFFF59E0B),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: _kpiCard(
            title: 'Vacant PC Slots',
            value: '${summary.totalVacantPcs}',
            subtitle: 'Unoccupied workstations',
            icon: Icons.desktop_windows_outlined,
            color: _dark ? Colors.white54 : Colors.black54,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: _kpiCard(
            title: 'Attendance Rate',
            value: '${summary.attendanceRate.toStringAsFixed(0)}%',
            subtitle: '${summary.totalAttended} of ${summary.totalExpected} expected',
            icon: Icons.pie_chart_rounded,
            color: _accentAForeground,
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
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: _dark ? 0.12 : 0.03),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(11),
                  border: Border.all(color: color.withValues(alpha: 0.3)),
                ),
                child: Icon(icon, color: color, size: 19),
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
                        blurRadius: 8,
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
          const SizedBox(height: 2),
          Text(
            title,
            style: TextStyle(
              color: _text,
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(color: _sub, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _toolbarControls(Set<String> subjects) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _border),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          // Search Field
          SizedBox(
            width: 280,
            child: TextField(
              controller: _searchController,
              style: TextStyle(color: _text, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Search student, ID, or PC...',
                hintStyle: TextStyle(color: _sub, fontSize: 13),
                prefixIcon: Icon(Icons.search_rounded, color: _sub, size: 19),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear_rounded, color: _sub, size: 18),
                        onPressed: () => _searchController.clear(),
                      )
                    : null,
                filled: true,
                fillColor: _field,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          // Status Filter Chips/Dropdown
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: _field,
              borderRadius: BorderRadius.circular(12),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<AttendanceStatus?>(
                value: _statusFilter,
                hint: Text('Filter Status', style: TextStyle(color: _sub, fontSize: 12.5)),
                dropdownColor: _card,
                style: TextStyle(color: _text, fontSize: 12.5),
                items: [
                  DropdownMenuItem<AttendanceStatus?>(
                    value: null,
                    child: Text('All Statuses', style: TextStyle(color: _text)),
                  ),
                  for (final status in AttendanceStatus.values)
                    DropdownMenuItem<AttendanceStatus?>(
                      value: status,
                      child: Row(
                        children: [
                          Icon(status.icon, color: status.color, size: 16),
                          const SizedBox(width: 8),
                          Text(status.label, style: TextStyle(color: _text)),
                        ],
                      ),
                    ),
                ],
                onChanged: (val) => setState(() => _statusFilter = val),
              ),
            ),
          ),
          // Subject Dropdown
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: _field,
              borderRadius: BorderRadius.circular(12),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _subjectFilter,
                dropdownColor: _card,
                style: TextStyle(color: _text, fontSize: 12.5),
                items: subjects.map((sub) {
                  return DropdownMenuItem<String>(
                    value: sub,
                    child: Text(sub, style: TextStyle(color: _text)),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _subjectFilter = val);
                },
              ),
            ),
          ),
          const Spacer(),
          // View Mode Selector (Grid vs Table)
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: _field,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _viewModeOption(
                  mode: _AttendanceViewMode.grid,
                  icon: Icons.grid_view_rounded,
                  label: 'PC Layout',
                ),
                _viewModeOption(
                  mode: _AttendanceViewMode.table,
                  icon: Icons.table_rows_rounded,
                  label: 'List View',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _viewModeOption({
    required _AttendanceViewMode mode,
    required IconData icon,
    required String label,
  }) {
    final selected = _viewMode == mode;
    return InkWell(
      onTap: () => setState(() => _viewMode = mode),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? _card : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 6,
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: selected ? _accentAForeground : _sub,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: selected ? _text : _sub,
                fontSize: 12,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _gridMapView(
    List<StudentAttendanceRecord> filtered,
    List<StudentAttendanceRecord> allRecords,
  ) {
    // Map each PC to the record that should currently occupy the workstation.
    //
    // Do NOT trust list order here. Older Syswatch builds stored some timestamps
    // using Manila wall-clock time without an offset, so a historical signed-out
    // row can sort ahead of the real active row. The grid must always prefer an
    // occupied attendance state (Active / Present / Late) for the same PC.
    // If both records have the same occupancy state, keep the newest login.
    final Map<String, StudentAttendanceRecord> activeRecordMap = {};
    for (final record in allRecords) {
      final key = record.pcId.trim().toLowerCase();
      if (key.isEmpty) continue;

      final current = activeRecordMap[key];
      if (current == null) {
        activeRecordMap[key] = record;
        continue;
      }

      final recordOccupied = record.isPresent;
      final currentOccupied = current.isPresent;

      if (recordOccupied && !currentOccupied) {
        activeRecordMap[key] = record;
        continue;
      }

      if (recordOccupied == currentOccupied &&
          record.loginTime.isAfter(current.loginTime)) {
        activeRecordMap[key] = record;
      }
    }

    final pcSlots = <Map<String, dynamic>>[];

    // Add all workstations from LabOverview
    for (final pc in widget.room.workstations) {
      if (!pc.isRegistered) continue;
      final key = pc.pcId.toLowerCase();
      final rec = activeRecordMap[key];
      pcSlots.add({'pcId': pc.pcId, 'record': rec, 'workstation': pc});
    }

    // Include any manual attendance logs not in workstations list
    for (final rec in filtered) {
      if (!pcSlots.any((slot) => (slot['pcId'] as String).toLowerCase() == rec.pcId.toLowerCase())) {
        pcSlots.add({'pcId': rec.pcId, 'record': rec, 'workstation': null});
      }
    }

    if (pcSlots.isEmpty) {
      return _emptyAttendanceState();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final double availableWidth = constraints.maxWidth;
        const double spacing = 14.0;
        const int minColumns = 5;
        const double minCardWidth = 200.0;

        // Calculate card width targeting 5 columns per row to align with top KPI cards
        final double widthFor5 =
            (availableWidth - (minColumns - 1) * spacing) / minColumns;

        int columns = minColumns;
        double cardWidth = widthFor5;

        // On smaller screens where 5 cards would be under 200px wide, wrap into optimal columns
        if (widthFor5 < minCardWidth) {
          columns = ((availableWidth + spacing) / (minCardWidth + spacing))
              .floor()
              .clamp(1, minColumns);
          cardWidth = (availableWidth - (columns - 1) * spacing) / columns;
        }

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final slot in pcSlots)
              SizedBox(
                width: cardWidth,
                child: _pcAttendanceCard(
                  pcId: slot['pcId'] as String,
                  record: slot['record'] as StudentAttendanceRecord?,
                  workstation: slot['workstation'] as LabWorkstation?,
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _pcAttendanceCard({
    required String pcId,
    required StudentAttendanceRecord? record,
    required LabWorkstation? workstation,
  }) {
    final isOccupied = record != null && record.isPresent;
    final status = record?.status ?? AttendanceStatus.signedOut;
    final statusColor = isOccupied ? status.color : (_dark ? Colors.white24 : Colors.black26);

    return Container(
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isOccupied ? statusColor.withValues(alpha: 0.4) : _border,
          width: isOccupied ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: _dark ? 0.12 : 0.03),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: isOccupied
              ? () => _showStudentDetailModal(record)
              : () => _showManualCheckInDialog(preselectedPcId: pcId),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top PC Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: _field,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.computer_rounded, size: 14, color: _text),
                          const SizedBox(width: 6),
                          Text(
                            pcId,
                            style: TextStyle(
                              color: _text,
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    // Status Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(status.icon, size: 12, color: statusColor),
                          const SizedBox(width: 4),
                          Text(
                            isOccupied ? status.label : 'Vacant',
                            style: TextStyle(
                              color: statusColor,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                if (isOccupied) ...[
                  // Student Details
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 19,
                        backgroundColor: _accentColor.withValues(alpha: 0.15),
                        child: Text(
                          _initials(record.studentName),
                          style: TextStyle(
                            color: _accentAForeground,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              record.studentName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: _text,
                                fontSize: 13.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 1),
                            Text(
                              'ID: ${record.studentId}',
                              style: TextStyle(color: _sub, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _field.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.login_rounded, size: 13, color: _sub),
                            const SizedBox(width: 6),
                            Text(
                              'In: ${record.formattedLoginTime}',
                              style: TextStyle(color: _text, fontSize: 11.5, fontWeight: FontWeight.w600),
                            ),
                            const Spacer(),
                            Icon(Icons.timer_outlined, size: 13, color: _sub),
                            const SizedBox(width: 4),
                            Text(
                              record.formattedDuration,
                              style: TextStyle(color: _sub, fontSize: 11.5, fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                        if (record.remarks != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Note: ${record.remarks}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: _accentAForeground, fontSize: 10.5, fontStyle: FontStyle.italic),
                          ),
                        ],
                      ],
                    ),
                  ),
                ] else ...[
                  // Vacant PC Display
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Column(
                        children: [
                          Icon(
                            Icons.desktop_windows_outlined,
                            size: 32,
                            color: _sub.withValues(alpha: 0.5),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Workstation Unoccupied',
                            style: TextStyle(color: _sub, fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            height: 30,
                            child: OutlinedButton.icon(
                              onPressed: () => _showManualCheckInDialog(preselectedPcId: pcId),
                              icon: const Icon(Icons.add_rounded, size: 14),
                              label: const Text('Assign Student', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: _accentAForeground,
                                side: BorderSide(color: _accentAForeground.withValues(alpha: 0.4)),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                padding: const EdgeInsets.symmetric(horizontal: 10),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _tableListView(List<StudentAttendanceRecord> records) {
    if (records.isEmpty) {
      return _emptyAttendanceState();
    }

    return Container(
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _border),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 980),
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(_field),
              dividerThickness: 1,
              horizontalMargin: 20,
              columnSpacing: 24,
              columns: [
                DataColumn(label: Text('PC ID', style: _tableHeaderStyle())),
                DataColumn(label: Text('Student ID', style: _tableHeaderStyle())),
                DataColumn(label: Text('Student Name', style: _tableHeaderStyle())),
                DataColumn(label: Text('Subject', style: _tableHeaderStyle())),
                DataColumn(label: Text('Time In', style: _tableHeaderStyle())),
                DataColumn(label: Text('Duration', style: _tableHeaderStyle())),
                DataColumn(label: Text('Status', style: _tableHeaderStyle())),
                DataColumn(label: Text('Actions', style: _tableHeaderStyle())),
              ],
              rows: [
                for (final r in records)
                  DataRow(
                    cells: [
                      DataCell(
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: _field,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(r.pcId, style: TextStyle(color: _text, fontWeight: FontWeight.w800, fontSize: 12)),
                        ),
                      ),
                      DataCell(Text(r.studentId, style: TextStyle(color: _text, fontSize: 12.5))),
                      DataCell(
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 13,
                              backgroundColor: _accentColor.withValues(alpha: 0.15),
                              child: Text(_initials(r.studentName), style: TextStyle(color: _accentAForeground, fontSize: 10, fontWeight: FontWeight.bold)),
                            ),
                            const SizedBox(width: 8),
                            Text(r.studentName, style: TextStyle(color: _text, fontWeight: FontWeight.w700, fontSize: 13)),
                          ],
                        ),
                      ),
                      DataCell(Text(r.subject, style: TextStyle(color: _sub, fontSize: 12))),
                      DataCell(Text(r.formattedLoginTime, style: TextStyle(color: _text, fontSize: 12))),
                      DataCell(Text(r.formattedDuration, style: TextStyle(color: _sub, fontSize: 12, fontWeight: FontWeight.w600))),
                      DataCell(
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: r.status.color.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: r.status.color.withValues(alpha: 0.3)),
                          ),
                          child: Text(
                            r.status.label,
                            style: TextStyle(color: r.status.color, fontSize: 11, fontWeight: FontWeight.w800),
                          ),
                        ),
                      ),
                      DataCell(
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.info_outline_rounded, size: 18),
                              color: _accentAForeground,
                              tooltip: 'View Details',
                              onPressed: () => _showStudentDetailModal(r),
                            ),
                            if (r.isActive || r.isLate || r.status == AttendanceStatus.present)
                              IconButton(
                                icon: const Icon(Icons.logout_rounded, size: 18),
                                color: const Color(0xFFEF4444),
                                tooltip: 'Sign Out Student',
                                onPressed: () => _signOutStudent(r),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  TextStyle _tableHeaderStyle() {
    return TextStyle(
      color: _text,
      fontWeight: FontWeight.w800,
      fontSize: 12.5,
    );
  }

  Widget _emptyAttendanceState() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _border),
      ),
      child: Center(
        child: Column(
          children: [
            Icon(
              Icons.search_off_rounded,
              size: 48,
              color: _sub.withValues(alpha: 0.6),
            ),
            const SizedBox(height: 12),
            Text(
              'No Student Attendance Records Found',
              style: TextStyle(color: _text, fontSize: 16, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              'Try adjusting your search query or filter, or manually log a student check-in.',
              style: TextStyle(color: _sub, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _errorState(String message) {
    return Center(
      child: Container(
        width: 480,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, color: Color(0xFFEF4444), size: 48),
            const SizedBox(height: 12),
            Text(
              'Could Not Load Attendance Records',
              style: TextStyle(color: _text, fontSize: 16, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(message, textAlign: TextAlign.center, style: TextStyle(color: _sub, fontSize: 12)),
            const SizedBox(height: 18),
            _gradientButton(
              label: 'Retry',
              icon: Icons.refresh_rounded,
              onPressed: () => _refresh(force: true),
            ),
          ],
        ),
      ),
    );
  }

  // Action Modals & Dialogs

  Future<void> _signOutStudent(StudentAttendanceRecord record) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _card,
        title: Text('Sign Out Student?', style: TextStyle(color: _text, fontWeight: FontWeight.w800)),
        content: Text(
          'Are you sure you want to sign out ${record.studentName} from ${record.pcId}?',
          style: TextStyle(color: _sub),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: TextStyle(color: _sub)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await StudentAttendanceService.instance.signOutStudent(record.id);
      _refresh(silent: true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${record.studentName} signed out from ${record.pcId}.'),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
      }
    }
  }

  void _showStudentDetailModal(StudentAttendanceRecord record) {
    final remarksController = TextEditingController(text: record.remarks ?? '');
    AttendanceStatus currentStatus = record.status;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: _card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 24,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 22,
                        backgroundColor: currentStatus.color.withValues(alpha: 0.15),
                        child: Icon(currentStatus.icon, color: currentStatus.color, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              record.studentName,
                              style: TextStyle(color: _text, fontSize: 18, fontWeight: FontWeight.w800),
                            ),
                            Text(
                              'ID: ${record.studentId} · PC: ${record.pcId}',
                              style: TextStyle(color: _sub, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.close_rounded, color: _sub),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const Divider(height: 28),
                  _detailGridRow(
                    'Subject',
                    record.subject,
                    'Student Email',
                    record.studentEmail.trim().isEmpty ? 'Not available' : record.studentEmail,
                  ),
                  const SizedBox(height: 12),
                  _detailGridRow('Login Time', record.formattedLoginTime, 'Active Duration', record.formattedDuration),
                  const SizedBox(height: 12),
                  _detailGridRow('Client IP Address', record.ipAddress, 'Status', currentStatus.label),
                  const SizedBox(height: 20),
                  Text('Change Attendance Status', style: TextStyle(color: _text, fontSize: 13, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final st in AttendanceStatus.values)
                        ChoiceChip(
                          label: Text(st.label),
                          selected: currentStatus == st,
                          selectedColor: st.color.withValues(alpha: 0.25),
                          labelStyle: TextStyle(
                            color: currentStatus == st ? st.color : _text,
                            fontWeight: FontWeight.bold,
                            fontSize: 11.5,
                          ),
                          onSelected: (selected) {
                            if (selected) {
                              setModalState(() => currentStatus = st);
                            }
                          },
                        ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Text('Teacher Remarks / Notes', style: TextStyle(color: _text, fontSize: 13, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: remarksController,
                    style: TextStyle(color: _text, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Add note (e.g., excused late arrival, equipment issue)...',
                      hintStyle: TextStyle(color: _sub, fontSize: 12.5),
                      filled: true,
                      fillColor: _field,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),
                  Row(
                    children: [
                      if (record.isActive || record.isLate || record.status == AttendanceStatus.present)
                        OutlinedButton.icon(
                          onPressed: () {
                            Navigator.pop(ctx);
                            _signOutStudent(record);
                          },
                          icon: const Icon(Icons.logout_rounded, size: 16),
                          label: const Text('Sign Out Student'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFFEF4444),
                            side: const BorderSide(color: Color(0xFFEF4444)),
                          ),
                        ),
                      const Spacer(),
                      FilledButton(
                        onPressed: () async {
                          final messenger = ScaffoldMessenger.of(context);
                          await StudentAttendanceService.instance.updateStatus(
                            recordId: record.id,
                            newStatus: currentStatus,
                            remarks: remarksController.text,
                          );
                          _refresh(silent: true);
                          if (ctx.mounted) {
                            Navigator.pop(ctx);
                          }
                          messenger.showSnackBar(
                            const SnackBar(
                              content: Text('Attendance record updated.'),
                              backgroundColor: Color(0xFF10B981),
                            ),
                          );
                        },
                        child: const Text('Save Changes'),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _detailGridRow(String label1, String val1, String label2, String val2) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label1, style: TextStyle(color: _sub, fontSize: 11)),
              const SizedBox(height: 2),
              Text(val1, style: TextStyle(color: _text, fontSize: 13, fontWeight: FontWeight.w700)),
            ],
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label2, style: TextStyle(color: _sub, fontSize: 11)),
              const SizedBox(height: 2),
              Text(val2, style: TextStyle(color: _text, fontSize: 13, fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ],
    );
  }

  void _showManualCheckInDialog({String? preselectedPcId}) {
    final formKey = GlobalKey<FormState>();

    // Registered PCs list
    final availablePcs = widget.room.workstations
        .where((pc) => pc.isRegistered)
        .map((pc) => pc.pcId)
        .toList();
    if (availablePcs.isEmpty) {
      availablePcs.add('PC-01');
    }

    String pcId = preselectedPcId ?? availablePcs.first;
    final studentIdController = TextEditingController();
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final subjectController = TextEditingController(text: 'IT 312 - Systems Admin');
    final remarksController = TextEditingController();
    AttendanceStatus status = AttendanceStatus.active;

    showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDlgState) {
            return AlertDialog(
              backgroundColor: _card,
              title: Row(
                children: [
                  Icon(Icons.person_add_alt_1_rounded, color: _accentAForeground),
                  const SizedBox(width: 10),
                  Text('Log Student Check-In', style: TextStyle(color: _text, fontWeight: FontWeight.w800)),
                ],
              ),
              content: SizedBox(
                width: 480,
                child: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Assign PC Workstation', style: TextStyle(color: _text, fontSize: 12.5, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 6),
                        DropdownButtonFormField<String>(
                          initialValue: availablePcs.contains(pcId) ? pcId : availablePcs.first,
                          dropdownColor: _card,
                          style: TextStyle(color: _text, fontSize: 13),
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: _field,
                            isDense: true,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                          ),
                          items: availablePcs.map((pc) {
                            return DropdownMenuItem(value: pc, child: Text(pc, style: TextStyle(color: _text)));
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) setDlgState(() => pcId = val);
                          },
                        ),
                        const SizedBox(height: 12),
                        Text('Student ID', style: TextStyle(color: _text, fontSize: 12.5, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: studentIdController,
                          style: TextStyle(color: _text, fontSize: 13),
                          decoration: InputDecoration(
                            hintText: 'e.g., 2023-10024',
                            filled: true,
                            fillColor: _field,
                            isDense: true,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                        ),
                        const SizedBox(height: 12),
                        Text('Student Full Name', style: TextStyle(color: _text, fontSize: 12.5, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: nameController,
                          style: TextStyle(color: _text, fontSize: 13),
                          decoration: InputDecoration(
                            hintText: 'e.g., Dela Cruz, Juan P.',
                            filled: true,
                            fillColor: _field,
                            isDense: true,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                        ),
                        const SizedBox(height: 12),
                        Text('Student Email (Optional)', style: TextStyle(color: _text, fontSize: 12.5, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: emailController,
                          keyboardType: TextInputType.emailAddress,
                          style: TextStyle(color: _text, fontSize: 13),
                          decoration: InputDecoration(
                            hintText: 'e.g., student@students.nu-clark.edu.ph',
                            filled: true,
                            fillColor: _field,
                            isDense: true,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                          ),
                          validator: (v) {
                            final value = (v ?? '').trim();
                            if (value.isEmpty) return null;
                            if (!value.contains('@') || !value.contains('.')) return 'Enter a valid email or leave blank';
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        Text('Subject / Class', style: TextStyle(color: _text, fontSize: 12.5, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: subjectController,
                          style: TextStyle(color: _text, fontSize: 13),
                          decoration: InputDecoration(
                            hintText: 'e.g., IT 312 - Systems Admin',
                            filled: true,
                            fillColor: _field,
                            isDense: true,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                        ),
                        const SizedBox(height: 12),
                        Text('Initial Status', style: TextStyle(color: _text, fontSize: 12.5, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 8,
                          children: [
                            AttendanceStatus.active,
                            AttendanceStatus.present,
                            AttendanceStatus.late,
                          ].map((st) {
                            return ChoiceChip(
                              label: Text(st.label),
                              selected: status == st,
                              selectedColor: st.color.withValues(alpha: 0.25),
                              labelStyle: TextStyle(
                                color: status == st ? st.color : _text,
                                fontWeight: FontWeight.bold,
                                fontSize: 11.5,
                              ),
                              onSelected: (selected) {
                                if (selected) setDlgState(() => status = st);
                              },
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 12),
                        Text('Remarks / Note (Optional)', style: TextStyle(color: _text, fontSize: 12.5, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 6),
                        TextField(
                          controller: remarksController,
                          style: TextStyle(color: _text, fontSize: 13),
                          decoration: InputDecoration(
                            hintText: 'Optional notes...',
                            filled: true,
                            fillColor: _field,
                            isDense: true,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text('Cancel', style: TextStyle(color: _sub)),
                ),
                FilledButton(
                  onPressed: () async {
                    if (formKey.currentState?.validate() == true) {
                      final email = emailController.text.trim();

                      final messenger = ScaffoldMessenger.of(context);
                      await StudentAttendanceService.instance.checkInStudent(
                        pcId: pcId,
                        studentId: studentIdController.text,
                        studentName: nameController.text,
                        studentEmail: email,
                        courseSection: 'Not set',
                        subject: subjectController.text,
                        status: status,
                        remarks: remarksController.text,
                      );
                      _refresh(silent: true);
                      if (ctx.mounted) {
                        Navigator.pop(ctx);
                      }
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text('${nameController.text} checked in to $pcId.'),
                          backgroundColor: const Color(0xFF10B981),
                        ),
                      );
                    }
                  },
                  child: const Text('Check In Student'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showExportDialog() {
    final csvData = StudentAttendanceService.instance.exportCsv(
      roomName: widget.room.roomName,
    );

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _card,
        title: Row(
          children: [
            Icon(Icons.download_rounded, color: _accentAForeground),
            const SizedBox(width: 10),
            Text('Export Attendance CSV Report', style: TextStyle(color: _text, fontWeight: FontWeight.w800)),
          ],
        ),
        content: SizedBox(
          width: 580,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Copy or download the raw CSV data for Laboratory ${widget.room.roomName}:',
                style: TextStyle(color: _sub, fontSize: 12),
              ),
              const SizedBox(height: 12),
              Container(
                height: 240,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _field,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _border),
                ),
                child: SingleChildScrollView(
                  child: SelectableText(
                    csvData,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 11,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Close', style: TextStyle(color: _sub)),
          ),
          OutlinedButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: csvData));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Attendance CSV copied to clipboard.'),
                  backgroundColor: Color(0xFF10B981),
                ),
              );
            },
            icon: const Icon(Icons.copy_rounded, size: 16),
            label: const Text('Copy'),
          ),
          FilledButton.icon(
            onPressed: () async {
              try {
                final savedPath = await _saveAttendanceCsv(csvData);
                if (ctx.mounted) Navigator.pop(ctx);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('CSV exported to: $savedPath'),
                      backgroundColor: const Color(0xFF10B981),
                      duration: const Duration(seconds: 5),
                    ),
                  );
                }
              } catch (error) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('CSV export failed: ${cleanError(error)}'),
                      backgroundColor: const Color(0xFFEF4444),
                    ),
                  );
                }
              }
            },
            icon: const Icon(Icons.download_rounded, size: 16),
            label: const Text('Save CSV'),
          ),
        ],
      ),
    );
  }


  Future<String> _saveAttendanceCsv(String csvData) async {
    final profile = Platform.environment['USERPROFILE'];
    final downloadsDir = profile != null && profile.trim().isNotEmpty
        ? Directory('$profile/Downloads')
        : Directory.current;

    if (!await downloadsDir.exists()) {
      await downloadsDir.create(recursive: true);
    }

    final now = DateTime.now();
    final stamp = '${now.year.toString().padLeft(4, '0')}'
        '${now.month.toString().padLeft(2, '0')}'
        '${now.day.toString().padLeft(2, '0')}_'
        '${now.hour.toString().padLeft(2, '0')}'
        '${now.minute.toString().padLeft(2, '0')}'
        '${now.second.toString().padLeft(2, '0')}';
    final safeRoom = widget.room.roomName.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
    final file = File('${downloadsDir.path}/Syswatch_Attendance_Room_${safeRoom}_$stamp.csv');
    await file.writeAsString(csvData, flush: true);
    return file.path;
  }

  Widget _iconTile({
    required IconData icon,
    required String tooltip,
    required VoidCallback? onPressed,
  }) {
    final navBorder = _dark ? _border : Colors.white.withValues(alpha: 0.1);
    return Tooltip(
      message: tooltip,
      child: SizedBox(
        width: 40,
        height: 40,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: _dark ? _field : Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: navBorder),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: onPressed,
              child: Icon(icon, color: _dark ? _sub : Colors.white70, size: 19),
            ),
          ),
        ),
      ),
    );
  }

  Widget _gradientButton({
    required String label,
    required IconData icon,
    required VoidCallback? onPressed,
  }) {
    final disabled = onPressed == null;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: disabled ? _field : _accentColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 11),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 17,
                  color: disabled ? _sub : (_dark ? Colors.black : Colors.white),
                ),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    color: disabled ? _sub : (_dark ? Colors.black : Colors.white),
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
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
