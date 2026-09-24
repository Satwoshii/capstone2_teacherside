import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../models/app_user.dart';
import '../models/fault_report.dart';
import '../models/lab_overview.dart';
import '../services/teacher_service.dart';
import '../services/teacher_windows_session_service.dart';
import '../services/native_image_picker_service.dart';
import '../utils/value_helpers.dart';
import '../widgets/theme_toggle_button.dart';
import 'student_attendance_screen.dart';
import 'teacher_chat_screen.dart';

const _teacherProblemOptions = <_TeacherProblemOption>[
  _TeacherProblemOption(
    label: 'Keyboard problem',
    severity: 'minor',
    icon: Icons.keyboard_rounded,
  ),
  _TeacherProblemOption(
    label: 'Mouse problem',
    severity: 'minor',
    icon: Icons.mouse_rounded,
  ),
  _TeacherProblemOption(
    label: 'Monitor or display problem',
    severity: 'minor',
    icon: Icons.monitor_rounded,
  ),
  _TeacherProblemOption(
    label: 'Software or application problem',
    severity: 'medium',
    icon: Icons.apps_rounded,
  ),
  _TeacherProblemOption(
    label: 'Ethernet or LAN disconnected',
    severity: 'high',
    icon: Icons.lan_rounded,
  ),
  _TeacherProblemOption(
    label: 'Network port or LAN cable damage',
    severity: 'high',
    icon: Icons.cable_rounded,
  ),
  _TeacherProblemOption(
    label: 'Visible physical damage',
    severity: 'high',
    icon: Icons.build_circle_outlined,
  ),
  _TeacherProblemOption(
    label: 'PC power or startup problem',
    severity: 'critical',
    icon: Icons.power_settings_new_rounded,
  ),
  _TeacherProblemOption(
    label: 'CPU problem',
    severity: 'critical',
    icon: Icons.memory_rounded,
  ),
  _TeacherProblemOption(
    label: 'RAM or memory problem',
    severity: 'critical',
    icon: Icons.developer_board_rounded,
  ),
  _TeacherProblemOption(
    label: 'Disk not detected or disk failure',
    severity: 'critical',
    icon: Icons.storage_rounded,
  ),
  _TeacherProblemOption(
    label: 'Storage health problem',
    severity: 'critical',
    icon: Icons.health_and_safety_outlined,
  ),
  _TeacherProblemOption(
    label: 'Low storage capacity',
    severity: 'critical',
    icon: Icons.disc_full_rounded,
  ),
  _TeacherProblemOption(
    label: 'Smoke, sparks, burning smell, or electrical hazard',
    severity: 'emergency',
    icon: Icons.local_fire_department_rounded,
  ),
  _TeacherProblemOption(
    label: 'Other workstation problem',
    severity: 'medium',
    icon: Icons.report_problem_outlined,
  ),
];

class _TeacherProblemOption {
  final String label;
  final String severity;
  final IconData icon;

  const _TeacherProblemOption({
    required this.label,
    required this.severity,
    required this.icon,
  });
}

class TeacherDashboardScreen extends StatefulWidget {
  final AppUser user;

  const TeacherDashboardScreen({super.key, required this.user});

  @override
  State<TeacherDashboardScreen> createState() =>
      _TeacherDashboardScreenState();
}

class _TeacherDashboardScreenState extends State<TeacherDashboardScreen> {
  Future<(LabOverview, List<FaultReport>)>? _future;
  LabOverview? _latestRoom;
  Timer? _timer;
  bool _loggingOut = false;
  final _busyReports = <String>{};
  String _historyLogFilter = 'all';

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
  Color get _errorColor => const Color(0xFFFF6B6B);
  Color get _accentColor => _dark ? _accentA : _accentB;

  // ── Responsive breakpoints ─────────────────────────────────────────────
  double _screenWidth(BuildContext context) => MediaQuery.sizeOf(context).width;
  bool _isCompact(BuildContext context) => _screenWidth(context) < 620;
  bool _isMedium(BuildContext context) =>
      _screenWidth(context) >= 620 && _screenWidth(context) < 980;

  double _horizontalPagePadding(BuildContext context) {
    if (_isCompact(context)) return 14;
    if (_isMedium(context)) return 20;
    return 28;
  }

  double _dialogWidth(BuildContext context, double desired) {
    final available = _screenWidth(context) - 48;
    return desired > available ? available.clamp(240, desired) : desired;
  }

  @override
  void initState() {
    super.initState();
    _refresh();
    _timer = Timer.periodic(const Duration(seconds: 20), (_) => _refresh());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _refresh() {
    if (!mounted || _loggingOut) return;
    unawaited(TeacherService.instance.heartbeatSession().catchError((_) {}));

    setState(() {
      _future = Future.wait<dynamic>([
        TeacherService.instance.overview(),
        TeacherService.instance.listReports(),
      ]).then((values) {
        return (values[0] as LabOverview, values[1] as List<FaultReport>);
      });
    });
  }

  Future<void> _logout() async {
    if (_loggingOut) return;

    setState(() => _loggingOut = true);
    _timer?.cancel();
    _timer = null;

    try {
      await TeacherService.instance.logout();
    } catch (_) {}

    exit(0);
  }

  Color _conditionColor(String value) {
    switch (value) {
      case 'red':
        return const Color(0xFFE53935);
      case 'yellow':
        return const Color(0xFFF9A825);
      default:
        return const Color(0xFF22A06B);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      body: SafeArea(
        child: Stack(
          children: [
            _ambientBackground(),
            Column(
              children: [
                _topBar(),
                Expanded(
                  child: FutureBuilder<(LabOverview, List<FaultReport>)>(
                    future: _future,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return Center(
                          child: Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              color: _card,
                              shape: BoxShape.circle,
                              border: Border.all(color: _border),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.1),
                                  blurRadius: 20,
                                ),
                              ],
                            ),
                            padding: const EdgeInsets.all(16),
                            child: CircularProgressIndicator(
                              color: _accentAForeground,
                              strokeWidth: 2.5,
                            ),
                          ),
                        );
                      }
                      if (snapshot.hasError) {
                        return _errorState(cleanError(snapshot.error!));
                      }
                      final data = snapshot.data;
                      if (data == null) return _errorState('No room data found.');
                      return _content(data.$1, data.$2);
                    },
                  ),
                ),
              ],
            ),
            Positioned(
              left: _isCompact(context) ? 14 : 24,
              bottom: _isCompact(context) ? 14 : 24,
              child: const ThemeToggleButton(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _ambientBackground() {
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned(
            top: -200,
            left: -150,
            child: Container(
              width: 580,
              height: 580,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    _accentB.withValues(alpha: _dark ? 0.18 : 0.10),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            right: -200,
            bottom: -250,
            child: Container(
              width: 680,
              height: 680,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    _accentAForeground.withValues(alpha: _dark ? 0.14 : 0.08),
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
    final room = widget.user.assignedRoomName ?? 'Unassigned';
    final windowsAccount = TeacherWindowsSessionService.instance.cachedAccount;
    final currentUserDisplayName =
        windowsAccount?.displayLabel ?? widget.user.displayName;

    final navBg = _dark ? _card.withValues(alpha: 0.94) : _accentB;
    final navFg = _dark ? _text : Colors.white;
    final navSub = _dark ? _sub : Colors.white70;
    final navBorder = _dark ? _border : Colors.white.withOpacity(0.12);

    final compact = _isCompact(context);

    final logo = Container(
      width: compact ? 40 : 46,
      height: compact ? 40 : 46,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: LinearGradient(
          colors: [
            _accentAForeground.withValues(alpha: 0.25),
            _accentAForeground.withValues(alpha: 0.08),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(
          color: _dark
              ? _accentColor.withValues(alpha: 0.45)
              : Colors.white.withOpacity(0.35),
          width: 1.2,
        ),
      ),
      child: Icon(
        Icons.school_rounded,
        color: _dark ? _accentAForeground : Colors.white,
        size: compact ? 22 : 25,
      ),
    );

    final titleBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'SysWatch',
              style: TextStyle(
                color: navFg,
                fontSize: compact ? 16 : 18,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: _accentAForeground.withValues(alpha: 0.20),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'TEACHER',
                style: TextStyle(
                  color: _dark ? _accentAForeground : Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          'Laboratory $room · Monitoring Dashboard',
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: navSub,
            fontSize: compact ? 11 : 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );

    final userChip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: _dark ? _field : Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _dark ? navBorder : Colors.white.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: _accentAForeground.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.person_rounded,
              color: _dark ? _accentAForeground : Colors.white,
              size: 14,
            ),
          ),
          const SizedBox(width: 8),
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: compact ? 120 : 180),
            child: Text(
              currentUserDisplayName,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: navFg,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );

    final actions = <Widget>[
      if (!compact && _latestRoom != null) ...[
        _gradientButton(
          label: 'Attendance',
          icon: Icons.co_present_rounded,
          onPressed: () => _openAttendance(_latestRoom!),
        ),
        const SizedBox(width: 8),
      ],
      if (!compact) ...[
        _gradientButton(
          label: 'Chat ITSO',
          icon: Icons.forum_rounded,
          onPressed: _openChat,
        ),
        const SizedBox(width: 8),
      ],
      _iconTile(
        icon: Icons.refresh_rounded,
        tooltip: 'Refresh dashboard',
        onPressed: _refresh,
      ),
      const SizedBox(width: 8),
      _iconTile(
        icon: _loggingOut
            ? Icons.hourglass_top_rounded
            : Icons.logout_rounded,
        tooltip: 'Close Teacher App',
        onPressed: _loggingOut ? null : _logout,
      ),
      if (compact) ...[
        const SizedBox(width: 8),
        _overflowMenu(navBorder),
      ],
    ];

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 14 : 24,
        vertical: compact ? 10 : 14,
      ),
      decoration: BoxDecoration(
        color: navBg,
        border: Border(bottom: BorderSide(color: navBorder)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: _dark ? 0.25 : 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: compact
          ? Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              logo,
              const SizedBox(width: 10),
              Expanded(child: titleBlock),
              ...actions,
            ],
          ),
          const SizedBox(height: 10),
          userChip,
        ],
      )
          : Row(
        children: [
          logo,
          const SizedBox(width: 14),
          Expanded(child: titleBlock),
          const SizedBox(width: 12),
          userChip,
          const SizedBox(width: 14),
          ...actions,
        ],
      ),
    );
  }

  Widget _overflowMenu(Color navBorder) {
    return SizedBox(
      width: 40,
      height: 40,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: _dark ? _field : Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: navBorder),
        ),
        child: PopupMenuButton<String>(
          tooltip: 'More actions',
          icon: Icon(
            Icons.more_vert_rounded,
            color: _dark ? _sub : Colors.white70,
            size: 20,
          ),
          color: _card,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          onSelected: (value) {
            if (value == 'attendance' && _latestRoom != null) {
              _openAttendance(_latestRoom!);
            } else if (value == 'chat') {
              _openChat();
            }
          },
          itemBuilder: (context) => [
            if (_latestRoom != null)
              PopupMenuItem(
                value: 'attendance',
                child: Row(
                  children: [
                    Icon(
                      Icons.co_present_rounded,
                      size: 18,
                      color: _accentAForeground,
                    ),
                    const SizedBox(width: 10),
                    Text('Student Attendance', style: TextStyle(color: _text)),
                  ],
                ),
              ),
            PopupMenuItem(
              value: 'chat',
              child: Row(
                children: [
                  Icon(
                    Icons.forum_rounded,
                    size: 18,
                    color: _accentAForeground,
                  ),
                  const SizedBox(width: 10),
                  Text('Chat with ITSO', style: TextStyle(color: _text)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _iconTile({
    required IconData icon,
    required String tooltip,
    required VoidCallback? onPressed,
  }) {
    final navBorder = _dark ? _border : Colors.white.withOpacity(0.15);
    return Tooltip(
      message: tooltip,
      child: SizedBox(
        width: 40,
        height: 40,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: _dark ? _field : Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: navBorder),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: onPressed,
              child: Icon(
                icon,
                color: _dark ? _text : Colors.white,
                size: 19,
              ),
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
        boxShadow: disabled
            ? null
            : [
          BoxShadow(
            color: _accentColor.withValues(alpha: 0.28),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 17,
                  color: disabled ? _sub : (_dark ? Colors.black : Colors.white),
                ),
                const SizedBox(width: 7),
                Text(
                  label,
                  style: TextStyle(
                    color: disabled ? _sub : (_dark ? Colors.black : Colors.white),
                    fontWeight: FontWeight.w800,
                    fontSize: 12.8,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openChat() async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => TeacherChatScreen(user: widget.user),
      ),
    );
  }

  Future<void> _openAttendance(LabOverview room) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => StudentAttendanceScreen(
          user: widget.user,
          room: room,
        ),
      ),
    );
  }

  List<FaultReport> _reportsForPc(
      LabWorkstation pc,
      List<FaultReport> reports,
      ) {
    final workstationId = pc.workstationId.trim().toLowerCase();
    final pcId = pc.pcId.trim().toLowerCase();
    return reports.where((report) {
      final reportWorkstationId = report.workstationId.trim().toLowerCase();
      final reportPcId = report.pcId.trim().toLowerCase();
      return (workstationId.isNotEmpty && reportWorkstationId == workstationId) ||
          (pcId.isNotEmpty && reportPcId == pcId);
    }).toList();
  }

  Widget _content(LabOverview room, List<FaultReport> reports) {
    _latestRoom = room;
    final openReports = reports
        .where((report) => !report.repaired && report.workflowStatus != 'resolved')
        .toList();
    final resolvedReports = reports
        .where((report) => report.repaired || report.workflowStatus == 'resolved')
        .toList();
    final reportableWorkstations =
    room.workstations.where((pc) => pc.canReport).toList();
    final color = _conditionColor(room.maintenanceColor);
    final hPad = _horizontalPagePadding(context);
    final compact = _isCompact(context);

    return RefreshIndicator(
      color: _accentAForeground,
      onRefresh: () async => _refresh(),
      child: ListView(
        padding: EdgeInsets.fromLTRB(hPad, hPad, hPad, 86),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1540),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _roomHeader(room, color),
                  const SizedBox(height: 20),
                  _sectionCard(
                    icon: Icons.grid_view_rounded,
                    title: 'Lab Workstation Map',
                    subtitle: room.workstations.isEmpty
                        ? 'No PC slots configured for Laboratory ${room.roomName}.'
                        : 'Select any workstation slot to inspect active status or view detailed reports.',
                    trailing: compact
                        ? null
                        : _gradientButton(
                      label: 'Student Attendance',
                      icon: Icons.co_present_rounded,
                      onPressed: () => _openAttendance(room),
                    ),
                    trailingBelow: compact
                        ? SizedBox(
                      width: double.infinity,
                      child: _gradientButton(
                        label: 'Student Attendance',
                        icon: Icons.co_present_rounded,
                        onPressed: () => _openAttendance(room),
                      ),
                    )
                        : null,
                    child: room.workstations.isEmpty
                        ? _emptyLabMap(room)
                        : LayoutBuilder(
                      builder: (context, constraints) {
                        final (tileWidth, tileHeight) =
                        _pcTileDimensions(constraints.maxWidth);
                        return Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            for (final pc in room.workstations)
                              SizedBox(
                                width: tileWidth,
                                height: tileHeight,
                                child: _pcTile(
                                  pc,
                                  _reportsForPc(pc, reports),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 20),
                  _sectionCard(
                    icon: Icons.assignment_rounded,
                    title: 'Active Room Reports',
                    subtitle: openReports.isEmpty
                        ? 'No unresolved issues currently reported in Laboratory ${room.roomName}.'
                        : '${openReports.length} report${openReports.length == 1 ? '' : 's'} requiring attention.',
                    trailing: compact
                        ? null
                        : _gradientButton(
                      label: 'Report Damaged PC',
                      icon: Icons.add_alert_rounded,
                      onPressed: () {
                        if (reportableWorkstations.isEmpty) {
                          _showNoRegisteredPcDialog(room);
                        } else {
                          _showCreateReport(room);
                        }
                      },
                    ),
                    trailingBelow: compact
                        ? SizedBox(
                      width: double.infinity,
                      child: _gradientButton(
                        label: 'Report Damaged PC',
                        icon: Icons.add_alert_rounded,
                        onPressed: () {
                          if (reportableWorkstations.isEmpty) {
                            _showNoRegisteredPcDialog(room);
                          } else {
                            _showCreateReport(room);
                          }
                        },
                      ),
                    )
                        : null,
                    child: openReports.isEmpty
                        ? _emptyReports()
                        : Column(
                      children: [
                        for (final report in openReports)
                          _reportCard(report),
                      ],
                    ),
                  ),
                  if (resolvedReports.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    _sectionCard(
                      icon: Icons.history_rounded,
                      title: 'Report History Log',
                      subtitle: _historyLogFilter == 'all'
                          ? '${resolvedReports.length} resolved fault report${resolvedReports.length == 1 ? '' : 's'} archived.'
                          : 'Showing filtered reports (${_filteredResolvedReportsCount(resolvedReports)} of ${resolvedReports.length}) · Tap "Total Archived" or Reset to clear.',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _historyLogsSummary(resolvedReports),
                          if (_filteredResolvedReports(resolvedReports).isEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 24),
                              child: Center(
                                child: Text(
                                  'No resolved reports match the selected filter category.',
                                  style: TextStyle(color: _sub, fontSize: 13),
                                ),
                              ),
                            )
                          else
                            for (final report in _filteredResolvedReports(resolvedReports).take(100))
                              _reportCard(report),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  (double, double) _pcTileDimensions(double availableWidth) {
    const spacing = 12.0;
    const targetColumns = 10;
    const minTileWidth = 90.0;

    if (availableWidth <= 0) return (130.0, 134.0);

    final widthFor10 =
        (availableWidth - (targetColumns - 1) * spacing) / targetColumns;

    if (widthFor10 >= minTileWidth) {
      return (widthFor10, 134.0);
    }

    final columns = ((availableWidth + spacing) / (minTileWidth + spacing))
        .floor()
        .clamp(2, targetColumns);
    final width = (availableWidth - (columns - 1) * spacing) / columns;
    return (width, 134.0);
  }

  Widget _emptyLabMap(LabOverview room) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
      decoration: BoxDecoration(
        color: _field.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
      ),
      child: Column(
        children: [
          Icon(Icons.desktop_access_disabled_rounded, color: _sub, size: 38),
          const SizedBox(height: 12),
          Text(
            'No PC Slots Configured',
            style: TextStyle(
              color: _text,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Configure workstation slots for Laboratory ${room.roomName} in the Admin dashboard.',
            textAlign: TextAlign.center,
            style: TextStyle(color: _sub, fontSize: 12.5, height: 1.4),
          ),
        ],
      ),
    );
  }

  Future<void> _showNoRegisteredPcDialog(LabOverview room) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: _card,
        shape: _dialogShape,
        title: _dialogTitle('No PC Slot Available', Icons.desktop_access_disabled_rounded),
        content: SizedBox(
          width: _dialogWidth(context, 430),
          child: Text(
            'Laboratory ${room.roomName} has no registered PC slots available for reporting. Configure PC counts in the Admin app or connect a student computer.',
            style: TextStyle(color: _sub, fontSize: 13, height: 1.5),
          ),
        ),
        actions: [
          _dialogCancelButton(() => Navigator.pop(dialogContext)),
        ],
      ),
    );
  }

  Widget _sectionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget child,
    Widget? trailing,
    Widget? trailingBelow,
  }) {
    final compact = _isCompact(context);
    return Container(
      padding: EdgeInsets.all(compact ? 16 : 22),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: _dark ? 0.18 : 0.04),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: _accentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _accentColor.withValues(alpha: 0.25)),
                ),
                child: Icon(icon, color: _accentAForeground, size: 21),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: _text,
                        fontSize: 16.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(color: _sub, fontSize: 12),
                    ),
                  ],
                ),
              ),
              if (trailing != null) trailing,
            ],
          ),
          if (trailingBelow != null) ...[
            const SizedBox(height: 14),
            trailingBelow,
          ],
          const SizedBox(height: 20),
          child,
        ],
      ),
    );
  }

  Widget _roomHeader(LabOverview room, Color color) {
    final healthy = room.maintenanceColor == 'green';
    final warning = room.maintenanceColor == 'yellow';
    final statusText = room.unregisteredPcCount > 0 && healthy
        ? '${room.unregisteredPcCount} slot${room.unregisteredPcCount == 1 ? '' : 's'} pending registration.'
        : healthy
        ? 'All workstation diagnostics clear.'
        : warning
        ? 'Active minor workstation issues detected.'
        : 'Attention required: critical workstation faults detected.';

    final compact = _isCompact(context);

    final icon = Container(
      width: compact ? 56 : 68,
      height: compact ? 56 : 68,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: color.withValues(alpha: 0.12),
        border: Border.all(color: color.withValues(alpha: 0.32), width: 1.5),
      ),
      child: Icon(
        Icons.meeting_room_rounded,
        color: color,
        size: compact ? 28 : 34,
      ),
    );

    final titleAndStatus = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          runSpacing: 6,
          children: [
            Text(
              'Laboratory ${room.roomName}',
              style: TextStyle(
                color: _text,
                fontSize: compact ? 20 : 24,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.2,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: color.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    healthy ? 'HEALTHY' : warning ? 'WARNING' : 'ATTENTION',
                    style: TextStyle(
                      color: color,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.6,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          statusText,
          style: TextStyle(color: _sub, fontSize: 13, height: 1.35),
        ),
      ],
    );

    final metrics = Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: compact ? WrapAlignment.start : WrapAlignment.end,
      children: [
        _metric('Online', room.onlinePcCount, const Color(0xFF22A06B)),
        _metric('Offline', room.offlinePcCount, Colors.blueGrey),
        if (room.unregisteredPcCount > 0)
          _metric('Unregistered', room.unregisteredPcCount, const Color(0xFF8A8F98)),
        _metric('Problems', room.activeProblemCount, color),
        _metric(
          'Approve',
          room.awaitingTeacherApprovalCount,
          _accentBForeground,
        ),
      ],
    );

    return Container(
      padding: EdgeInsets.all(compact ? 18 : 24),
      decoration: BoxDecoration(
        color: color.withValues(alpha: _dark ? 0.08 : 0.035),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: _dark ? 0.12 : 0.06),
            blurRadius: 28,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: compact
          ? Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              icon,
              const SizedBox(width: 14),
              Expanded(child: titleAndStatus),
            ],
          ),
          const SizedBox(height: 18),
          metrics,
        ],
      )
          : Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          icon,
          const SizedBox(width: 18),
          Expanded(child: titleAndStatus),
          const SizedBox(width: 12),
          metrics,
        ],
      ),
    );
  }

  Widget _metric(String label, int value, Color color) {
    return Container(
      width: 92,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.25)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            '$value',
            style: TextStyle(
              color: color,
              fontSize: 22,
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: _sub,
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _pcTile(LabWorkstation pc, List<FaultReport> pcReports) {
    final maintenanceColor = _conditionColor(pc.maintenanceColor);
    final statusColor = pc.isRegistered
        ? (pc.isOnline ? maintenanceColor : Colors.blueGrey)
        : Colors.blueGrey;
    final connectionColor = pc.isRegistered
        ? (pc.isOnline ? const Color(0xFF22A06B) : Colors.blueGrey)
        : const Color(0xFF8A8F98);
    final connectionLabel = !pc.isRegistered
        ? 'UNREG'
        : (pc.isOnline ? 'ONLINE' : 'OFFLINE');

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _showPcDetails(pc, pcReports),
        child: Ink(
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: _dark ? 0.08 : 0.04),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: statusColor.withValues(alpha: 0.45),
              width: 1.2,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    pc.isRegistered
                        ? Icons.computer_rounded
                        : Icons.desktop_access_disabled_rounded,
                    color: statusColor,
                    size: 20,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  pc.pcId,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _text,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 2.5,
                  ),
                  decoration: BoxDecoration(
                    color: connectionColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: connectionColor.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 5,
                        height: 5,
                        decoration: BoxDecoration(
                          color: connectionColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          connectionLabel,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: connectionColor,
                            fontSize: 8.5,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (pcReports.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    '${pcReports.length} issue${pcReports.length == 1 ? '' : 's'}',
                    style: TextStyle(
                      color: maintenanceColor,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
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

  Widget _reportCard(FaultReport report) {
    final busy = _busyReports.contains(report.id);
    final severityColor = _severityColor(report.severity);
    final workflow = _workflowLabel(report.workflowStatus);
    final compact = _isCompact(context);

    final actionArea = busy
        ? SizedBox(
      width: 32,
      height: 32,
      child: CircularProgressIndicator(
        strokeWidth: 2.4,
        color: _accentAForeground,
      ),
    )
        : (report.workflowStatus == 'reported' ||
        report.workflowStatus == 'reopened')
        ? _outlineAction(
      label: 'Send to ITSO',
      icon: Icons.send_rounded,
      onPressed: () => _showForwardDialog(report),
    )
        : report.workflowStatus == 'awaiting_teacher_approval'
        ? Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _outlineAction(
          label: 'Still Damaged',
          icon: Icons.close_rounded,
          onPressed: () => _showVerifyDialog(report, false),
        ),
        _gradientButton(
          label: 'PC is OK',
          icon: Icons.check_rounded,
          onPressed: () => _showVerifyDialog(report, true),
        ),
      ],
    )
        : null;

    final infoColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '${report.pcId} · ${report.issue}',
                style: TextStyle(
                  color: _text,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: _sub,
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          report.details,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: _sub,
            fontSize: 12.5,
            height: 1.35,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Reported: ${formatDateTime(report.createdAt)}'
              '${report.acceptedByName != null ? '\nAccepted by ITSO: ${report.acceptedByName} · ${formatDateTime(report.acceptedAt)}' : ''}'
              '${report.handledByName != null ? '\nHandled by ITSO: ${report.handledByName} · ${formatDateTime(report.handledAt)}' : ''}'
              '${report.completedByName != null ? '\nCompleted by ITSO: ${report.completedByName} · ${formatDateTime(report.completedAt)}' : ''}'
              '${report.repairedAt != null ? '\nITSO Fixed: ${formatDateTime(report.repairedAt)}' : ''}'
              '${report.teacherApprovedAt != null ? '\nTeacher Verified: ${formatDateTime(report.teacherApprovedAt)}' : ''}',
          style: TextStyle(
            color: _sub,
            fontSize: 11,
            height: 1.35,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            _statusChip(
              report.severity.toUpperCase(),
              severityColor,
            ),
            _statusChip(workflow, _accentBForeground),
            if (report.queuePosition != null)
              _statusChip(
                'QUEUE #${report.queuePosition}',
                const Color(0xFF8E6CEF),
              ),
          ],
        ),
      ],
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _showReportDetails(report),
          child: Ink(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _field.withValues(alpha: _dark ? 0.6 : 0.7),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _border),
            ),
            child: compact
                ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: severityColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(13),
                        border: Border.all(
                          color: severityColor.withValues(alpha: 0.25),
                        ),
                      ),
                      child: Icon(
                        Icons.report_rounded,
                        color: severityColor,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(child: infoColumn),
                  ],
                ),
                if (actionArea != null) ...[
                  const SizedBox(height: 14),
                  actionArea,
                ],
              ],
            )
                : Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: severityColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(13),
                    border: Border.all(
                      color: severityColor.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Icon(
                    Icons.report_rounded,
                    color: severityColor,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(child: infoColumn),
                if (actionArea != null) ...[
                  const SizedBox(width: 16),
                  actionArea,
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showReportDetails(FaultReport report) async {
    final severityColor = _severityColor(report.severity);

    Widget detailRow(String label, String value, {Color? valueColor}) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Wrap(
          crossAxisAlignment: WrapCrossAlignment.start,
          children: [
            SizedBox(
              width: 140,
              child: Text(
                label,
                style: TextStyle(
                  color: _sub,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            SizedBox(
              width: _dialogWidth(context, 620) - 140 - 44,
              child: SelectableText(
                value.isEmpty ? '—' : value,
                style: TextStyle(
                  color: valueColor ?? _text,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  height: 1.35,
                ),
              ),
            ),
          ],
        ),
      );
    }

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: _card,
        shape: _dialogShape,
        titlePadding: const EdgeInsets.fromLTRB(22, 22, 22, 6),
        contentPadding: const EdgeInsets.fromLTRB(22, 6, 22, 8),
        actionsPadding: const EdgeInsets.fromLTRB(16, 6, 16, 14),
        title: _dialogTitle(
          '${report.pcId} Report Details',
          Icons.description_rounded,
        ),
        content: SizedBox(
          width: _dialogWidth(context, 620),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    _statusChip(report.severity.toUpperCase(), severityColor),
                    _statusChip(
                      _workflowLabel(report.workflowStatus),
                      _accentBForeground,
                    ),
                    if (report.queuePosition != null)
                      _statusChip(
                        'QUEUE #${report.queuePosition}${report.queueTotal != null ? ' / ${report.queueTotal}' : ''}',
                        const Color(0xFF8E6CEF),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Divider(color: _border),
                detailRow('PC ID', report.pcId),
                detailRow('Laboratory', report.roomName),
                detailRow('Workstation ID', report.workstationId),
                detailRow('Issue', report.issue),
                detailRow('Severity', report.severity.toUpperCase(), valueColor: severityColor),
                detailRow('Source', report.source),
                detailRow('Reported At', formatDateTime(report.createdAt)),
                if (report.studentEmail != null)
                  detailRow('Student Account', report.studentEmail!),
                const SizedBox(height: 10),
                Text(
                  'Description',
                  style: TextStyle(
                    color: _sub,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: _field,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _border),
                  ),
                  child: SelectableText(
                    report.details.isEmpty ? 'No description provided.' : report.details,
                    style: TextStyle(color: _text, fontSize: 13, height: 1.45),
                  ),
                ),
                const SizedBox(height: 12),
                Divider(color: _border),
                if (report.acceptedByName != null)
                  detailRow(
                    'Accepted by ITSO',
                    '${report.acceptedByName} · ${formatDateTime(report.acceptedAt)}',
                  ),
                if (report.handledByName != null)
                  detailRow(
                    'Handled by ITSO',
                    '${report.handledByName} · ${formatDateTime(report.handledAt)}',
                  ),
                if (report.completedByName != null)
                  detailRow(
                    'Completed by ITSO',
                    '${report.completedByName} · ${formatDateTime(report.completedAt)}',
                  ),
                if (report.repairedAt != null)
                  detailRow('Repair Date', formatDateTime(report.repairedAt)),
                if (report.teacherApprovedAt != null)
                  detailRow(
                    'Teacher Verified',
                    formatDateTime(report.teacherApprovedAt),
                  ),
                if (report.technicianNotes != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    'ITSO Repair Notes',
                    style: TextStyle(
                      color: _sub,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: _field,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: _border),
                    ),
                    child: SelectableText(
                      report.technicianNotes!,
                      style: TextStyle(color: _text, fontSize: 13, height: 1.45),
                    ),
                  ),
                ],
                if (report.teacherNotes != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    'Teacher Notes',
                    style: TextStyle(
                      color: _sub,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: _field,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: _border),
                    ),
                    child: SelectableText(
                      report.teacherNotes!,
                      style: TextStyle(color: _text, fontSize: 13, height: 1.45),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
          if (report.workflowStatus == 'reported' ||
              report.workflowStatus == 'reopened')
            _dialogPrimaryButton(
              label: 'Send to ITSO',
              onPressed: () {
                Navigator.pop(dialogContext);
                unawaited(_showForwardDialog(report));
              },
            ),
          if (report.workflowStatus == 'awaiting_teacher_approval') ...[
            _outlineAction(
              label: 'Still Damaged',
              icon: Icons.close_rounded,
              onPressed: () {
                Navigator.pop(dialogContext);
                unawaited(_showVerifyDialog(report, false));
              },
            ),
            _dialogPrimaryButton(
              label: 'PC is OK',
              onPressed: () {
                Navigator.pop(dialogContext);
                unawaited(_showVerifyDialog(report, true));
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _statusChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.4,
        ),
      ),
    );
  }

  Widget _outlineAction({
    required String label,
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: _accentBForeground,
        side: BorderSide(color: _accentBForeground.withValues(alpha: 0.45)),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
      ),
    );
  }

  Color _severityColor(String severity) {
    switch (severity.toLowerCase()) {
      case 'critical':
      case 'emergency':
      case 'high':
        return const Color(0xFFE53935);
      case 'medium':
        return const Color(0xFFF9A825);
      default:
        return const Color(0xFF4F8EF7);
    }
  }

  String? _severityForProblem(String? problemLabel) {
    if (problemLabel == null) return null;
    for (final problem in _teacherProblemOptions) {
      if (problem.label == problemLabel) return problem.severity;
    }
    return null;
  }

  String _severityLabel(String severity) {
    final value = severity.toLowerCase();
    return '${value.substring(0, 1).toUpperCase()}${value.substring(1)}';
  }

  String _workflowLabel(String status) {
    return status.replaceAll('_', ' ').toUpperCase();
  }

  ShapeBorder get _dialogShape => RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(24),
    side: BorderSide(color: _border),
  );

  Widget _dialogTitle(String text, IconData icon) {
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: _accentColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _accentAForeground.withValues(alpha: 0.25)),
          ),
          child: Icon(icon, color: _accentAForeground, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: _text,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }

  InputDecoration _dialogFieldDecoration({
    required String label,
    String? helperText,
  }) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: _sub, fontSize: 13.5),
      helperText: helperText,
      helperStyle: TextStyle(color: _sub, fontSize: 11.5),
      helperMaxLines: 3,
      filled: true,
      fillColor: _field,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: _border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: _border),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: _border.withValues(alpha: 0.5)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: _accentAForeground.withValues(alpha: 0.8), width: 1.8),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: _errorColor),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: _errorColor, width: 1.8),
      ),
      errorStyle: TextStyle(color: _errorColor, fontSize: 11.5),
    );
  }

  Widget _dialogCancelButton(VoidCallback? onPressed) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: _sub,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      ),
      child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w600)),
    );
  }

  Widget _dialogPrimaryButton({
    required String label,
    required VoidCallback? onPressed,
    bool loading = false,
  }) {
    final disabled = onPressed == null;
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          child: Ink(
            decoration: BoxDecoration(
              color: disabled ? _field : _accentColor,
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (loading) ...[
                  SizedBox(
                    width: 15,
                    height: 15,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        disabled ? _sub : (_dark ? Colors.black : Colors.white),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                Text(
                  label,
                  style: TextStyle(
                    color: disabled ? _sub : (_dark ? Colors.black : Colors.white),
                    fontWeight: FontWeight.w800,
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

  Future<void> _showCreateReport(LabOverview room) async {
    final reportableWorkstations =
    room.workstations.where((pc) => pc.canReport).toList();
    if (reportableWorkstations.isEmpty) {
      await _showNoRegisteredPcDialog(room);
      return;
    }
    String workstationId = reportableWorkstations.first.workstationId;
    String? selectedProblem;
    String? severity;
    String details = '';
    File? proofImage;
    final key = GlobalKey<FormState>();
    bool saving = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          Future<void> save() async {
            if (saving || !(key.currentState?.validate() ?? false)) return;
            final selectedSeverity = _severityForProblem(selectedProblem);
            if (selectedProblem == null || selectedSeverity == null) return;
            setDialogState(() => saving = true);
            try {
              final selectedPc = reportableWorkstations.firstWhere(
                    (pc) => pc.workstationId == workstationId,
              );
              final reportId = await TeacherService.instance.createReport(
                workstationId: workstationId,
                pcId: selectedPc.pcId,
                issue: selectedProblem!.trim(),
                details: details.trim(),
                severity: selectedSeverity,
              );
              if (proofImage != null) {
                await TeacherService.instance.uploadReportAttachment(
                  reportId: reportId,
                  attachmentType: 'report_evidence',
                  image: proofImage!,
                );
              }
              if (!dialogContext.mounted || !mounted) return;
              Navigator.pop(dialogContext);
              _message('Damaged PC reported to ITSO.');
              _refresh();
            } catch (error) {
              if (dialogContext.mounted) setDialogState(() => saving = false);
              if (mounted) _message(cleanError(error));
            }
          }

          return AlertDialog(
            backgroundColor: _card,
            shape: _dialogShape,
            titlePadding: const EdgeInsets.fromLTRB(22, 22, 22, 6),
            contentPadding: const EdgeInsets.fromLTRB(22, 6, 22, 8),
            actionsPadding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
            title: _dialogTitle('Report Damaged PC', Icons.report_problem_rounded),
            content: SizedBox(
              width: _dialogWidth(context, 520),
              child: Form(
                key: key,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DropdownButtonFormField<String>(
                        value: workstationId,
                        dropdownColor: _card,
                        iconEnabledColor: _accentAForeground,
                        style: TextStyle(color: _text, fontSize: 14),
                        decoration: _dialogFieldDecoration(label: 'Select PC'),
                        items: reportableWorkstations
                            .map((pc) => DropdownMenuItem(
                          value: pc.workstationId,
                          child: Text(pc.pcId),
                        ))
                            .toList(),
                        onChanged: saving
                            ? null
                            : (value) => setDialogState(
                              () => workstationId = value ?? workstationId,
                        ),
                      ),
                      const SizedBox(height: 14),
                      DropdownButtonFormField<String>(
                        value: selectedProblem,
                        isExpanded: true,
                        dropdownColor: _card,
                        iconEnabledColor: _accentAForeground,
                        style: TextStyle(color: _text, fontSize: 14),
                        decoration: _dialogFieldDecoration(
                          label: 'Problem Category',
                          helperText: 'Select the closest matching problem.',
                        ),
                        items: _teacherProblemOptions
                            .map(
                              (problem) => DropdownMenuItem<String>(
                            value: problem.label,
                            child: Row(
                              children: [
                                Icon(problem.icon, size: 18, color: _accentAForeground),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    problem.label,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                            .toList(),
                        onChanged: saving
                            ? null
                            : (value) {
                          setDialogState(() {
                            selectedProblem = value;
                            severity = _severityForProblem(value);
                          });
                        },
                        validator: (value) => value == null
                            ? 'Select the workstation problem.'
                            : null,
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        enabled: !saving,
                        maxLines: 4,
                        style: TextStyle(color: _text, fontSize: 14),
                        cursorColor: _accentAForeground,
                        decoration: _dialogFieldDecoration(label: 'Issue Details'),
                        onChanged: (value) => details = value,
                        validator: (value) => (value ?? '').trim().isEmpty
                            ? 'Enter report details.'
                            : null,
                      ),
                      const SizedBox(height: 14),
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        runSpacing: 8,
                        children: [
                          ConstrainedBox(
                            constraints: BoxConstraints(
                              maxWidth: _dialogWidth(context, 520) - 32,
                            ),
                            child: Text(
                              proofImage == null
                                  ? 'Proof image: optional JPG/PNG (max 8 MB)'
                                  : 'Proof: ${proofImage!.uri.pathSegments.last}',
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: _sub, fontSize: 12.5),
                            ),
                          ),
                          OutlinedButton.icon(
                            onPressed: saving
                                ? null
                                : () async {
                              try {
                                final picked = await NativeImagePickerService.instance.pickJpgOrPng();
                                if (picked != null && dialogContext.mounted) {
                                  setDialogState(() => proofImage = picked);
                                }
                              } catch (error) {
                                if (mounted) _message(cleanError(error));
                              }
                            },
                            icon: const Icon(Icons.image_outlined, size: 18),
                            label: Text(proofImage == null ? 'Attach Image' : 'Change'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      InputDecorator(
                        decoration: _dialogFieldDecoration(
                          label: 'Assigned Severity',
                          helperText:
                          'Severity is assigned automatically based on issue type.',
                        ),
                        child: Row(
                          children: [
                            Icon(
                              severity == null
                                  ? Icons.auto_awesome_outlined
                                  : Icons.shield_rounded,
                              size: 18,
                              color: severity == null
                                  ? _sub
                                  : _severityColor(severity!),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              severity == null
                                  ? 'Select a problem category'
                                  : _severityLabel(severity!),
                              style: TextStyle(
                                color: severity == null
                                    ? _sub
                                    : _severityColor(severity!),
                                fontWeight: FontWeight.w800,
                                fontSize: 13.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              _dialogCancelButton(saving ? null : () => Navigator.pop(dialogContext)),
              _dialogPrimaryButton(
                label: saving ? 'Sending...' : 'Send to ITSO',
                onPressed: saving ? null : save,
                loading: saving,
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _showForwardDialog(FaultReport report) async {
    await _notesActionDialog(
      title: 'Send ${report.pcId} Report to ITSO',
      icon: Icons.send_rounded,
      label: 'Teacher observations',
      actionLabel: 'Send to ITSO',
      onSave: (notes) => TeacherService.instance.forwardReport(
        reportId: report.id,
        notes: notes,
      ),
      reportId: report.id,
      attachmentType: 'report_evidence',
    );
  }

  Future<void> _showVerifyDialog(FaultReport report, bool approved) async {
    await _notesActionDialog(
      title: approved ? 'Confirm ${report.pcId} is Fixed' : 'Reopen ${report.pcId}',
      icon: approved ? Icons.check_circle_rounded : Icons.replay_rounded,
      label: approved ? 'Teacher verification notes' : 'Describe the remaining problem',
      actionLabel: approved ? 'Approve PC' : 'Return to ITSO',
      onSave: (notes) => TeacherService.instance.verifyRepair(
        reportId: report.id,
        approved: approved,
        notes: notes,
      ),
      reportId: report.id,
      attachmentType: approved ? 'repair_verification' : 'still_damaged',
    );
  }

  Future<void> _notesActionDialog({
    required String title,
    required IconData icon,
    required String label,
    required String actionLabel,
    required Future<void> Function(String notes) onSave,
    required String reportId,
    required String attachmentType,
  }) async {
    final key = GlobalKey<FormState>();
    bool saving = false;
    String notes = '';
    File? proofImage;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          Future<void> save() async {
            if (saving || !(key.currentState?.validate() ?? false)) return;
            setDialogState(() => saving = true);
            setState(() => _busyReports.add(reportId));
            try {
              await onSave(notes.trim());
              if (proofImage != null) {
                await TeacherService.instance.uploadReportAttachment(
                  reportId: reportId,
                  attachmentType: attachmentType,
                  image: proofImage!,
                );
              }
              if (!dialogContext.mounted || !mounted) return;
              Navigator.pop(dialogContext);
              _message('Report updated successfully.');
              _refresh();
            } catch (error) {
              if (dialogContext.mounted) setDialogState(() => saving = false);
              if (mounted) _message(cleanError(error));
            } finally {
              if (mounted) setState(() => _busyReports.remove(reportId));
            }
          }

          return AlertDialog(
            backgroundColor: _card,
            shape: _dialogShape,
            titlePadding: const EdgeInsets.fromLTRB(22, 22, 22, 6),
            contentPadding: const EdgeInsets.fromLTRB(22, 6, 22, 8),
            actionsPadding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
            title: _dialogTitle(title, icon),
            content: SizedBox(
              width: _dialogWidth(context, 460),
              child: Form(
                key: key,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      enabled: !saving,
                      maxLines: 4,
                      style: TextStyle(color: _text, fontSize: 14),
                      cursorColor: _accentAForeground,
                      decoration: _dialogFieldDecoration(label: label),
                      onChanged: (value) => notes = value,
                      validator: (value) => (value ?? '').trim().isEmpty
                          ? 'Enter notes before continuing.'
                          : null,
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      runSpacing: 8,
                      children: [
                        ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: _dialogWidth(context, 460) - 32,
                          ),
                          child: Text(
                            proofImage == null
                                ? 'Optional proof image (JPG/PNG)'
                                : proofImage!.uri.pathSegments.last,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: _sub, fontSize: 12.5),
                          ),
                        ),
                        OutlinedButton.icon(
                          onPressed: saving
                              ? null
                              : () async {
                            try {
                              final picked = await NativeImagePickerService.instance.pickJpgOrPng();
                              if (picked != null && dialogContext.mounted) {
                                setDialogState(() => proofImage = picked);
                              }
                            } catch (error) {
                              if (mounted) _message(cleanError(error));
                            }
                          },
                          icon: const Icon(Icons.image_outlined, size: 18),
                          label: Text(proofImage == null ? 'Attach' : 'Change'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              _dialogCancelButton(saving ? null : () => Navigator.pop(dialogContext)),
              _dialogPrimaryButton(
                label: saving ? 'Saving...' : actionLabel,
                onPressed: saving ? null : save,
                loading: saving,
              ),
            ],
          );
        },
      ),
    );
  }

  void _showPcDetails(LabWorkstation pc, List<FaultReport> pcReports) {
    final color = _conditionColor(pc.maintenanceColor);
    final connectionColor = !pc.isRegistered
        ? const Color(0xFF8A8F98)
        : (pc.isOnline ? const Color(0xFF22A06B) : Colors.blueGrey);
    final connectionLabel = !pc.isRegistered
        ? 'UNREGISTERED'
        : pc.connectionStatus.toUpperCase();

    Widget row(IconData icon, String label, String value, {Color? valueColor}) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: (valueColor ?? _accentAForeground).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 17, color: valueColor ?? _accentAForeground),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(color: _sub, fontSize: 13),
              ),
            ),
            Text(
              value,
              style: TextStyle(
                color: valueColor ?? _text,
                fontSize: 13.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      );
    }

    Widget expandableProblems(
        String label,
        IconData icon,
        List<FaultReport> reports,
        Color groupColor,
        ) {
      return Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: EdgeInsets.zero,
          visualDensity: VisualDensity.compact,
          leading: Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: groupColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 17, color: groupColor),
          ),
          title: Text(
            label,
            style: TextStyle(color: _sub, fontSize: 13),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${reports.length}',
                style: TextStyle(
                  color: reports.isEmpty ? _sub : groupColor,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 4),
              Icon(Icons.expand_more_rounded, size: 18, color: _sub),
            ],
          ),
          children: reports.isEmpty
              ? [
            Padding(
              padding: const EdgeInsets.fromLTRB(46, 4, 12, 12),
              child: Text(
                'No problems logged',
                style: TextStyle(
                  color: _sub,
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                ),
              ),
            )
          ]
              : reports
              .map((r) => Padding(
            padding: const EdgeInsets.fromLTRB(46, 4, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: _severityColor(r.severity),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        r.issue,
                        style: TextStyle(
                          color: _text,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                if (r.details.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Padding(
                    padding: const EdgeInsets.only(left: 14),
                    child: Text(
                      r.details,
                      style: TextStyle(
                        color: _sub,
                        fontSize: 11.5,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ))
              .toList(),
        ),
      );
    }

    final majorReports = pcReports.where((r) {
      final s = r.severity.toLowerCase();
      return s == 'high' || s == 'critical' || s == 'emergency';
    }).toList();

    final activeReports = pcReports.where((r) {
      final s = r.severity.toLowerCase();
      return s != 'high' && s != 'critical' && s != 'emergency';
    }).toList();

    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _card,
        shape: _dialogShape,
        titlePadding: const EdgeInsets.fromLTRB(22, 22, 22, 4),
        contentPadding: const EdgeInsets.fromLTRB(22, 6, 22, 6),
        actionsPadding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
        title: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(13),
                border: Border.all(color: color.withValues(alpha: 0.28)),
              ),
              child: Icon(Icons.computer_rounded, color: color, size: 21),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                pc.pcId,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: _text,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: _dialogWidth(context, 380),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                row(
                  Icons.wifi_rounded,
                  'Connection Status',
                  connectionLabel,
                  valueColor: connectionColor,
                ),
                Divider(color: _border, height: 4),
                row(
                  pc.isRegistered ? Icons.verified_rounded : Icons.info_outline_rounded,
                  'Registration State',
                  pc.isRegistered ? 'REGISTERED' : 'NOT REGISTERED',
                  valueColor: pc.isRegistered
                      ? const Color(0xFF22A06B)
                      : const Color(0xFF8A8F98),
                ),
                Divider(color: _border, height: 4),
                row(Icons.info_outline_rounded, 'Device Health', pc.deviceStatus),
                Divider(color: _border, height: 4),
                expandableProblems(
                  'Active Issues',
                  Icons.report_outlined,
                  activeReports,
                  pc.activeProblemCount > 0 ? color : _accentAForeground,
                ),
                Divider(color: _border, height: 4),
                expandableProblems(
                  'Major Faults',
                  Icons.priority_high_rounded,
                  majorReports,
                  const Color(0xFFE53935),
                ),
              ],
            ),
          ),
        ),
        actions: [
          _dialogCancelButton(() => Navigator.pop(context)),
        ],
      ),
    );
  }

  Widget _emptyReports() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 34),
      decoration: BoxDecoration(
        color: _field.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
      ),
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: const Color(0xFF22A06B).withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_circle_outline_rounded,
              color: Color(0xFF22A06B),
              size: 28,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'All Clear',
            style: TextStyle(
              color: _text,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'No unresolved fault reports in this laboratory.',
            textAlign: TextAlign.center,
            style: TextStyle(color: _sub, fontSize: 12.5),
          ),
        ],
      ),
    );
  }

  List<FaultReport> _filteredResolvedReports(List<FaultReport> reports) {
    return reports.where((r) {
      if (_historyLogFilter == 'system') return r.detectedBySystem;
      if (_historyLogFilter == 'student') return !r.detectedBySystem;
      if (_historyLogFilter == 'high_severity') {
        final s = r.severity.toLowerCase();
        return s == 'high' || s == 'critical';
      }
      return true;
    }).toList();
  }

  int _filteredResolvedReportsCount(List<FaultReport> reports) {
    return _filteredResolvedReports(reports).length;
  }

  Widget _historyLogsSummary(List<FaultReport> reports) {
    final total = reports.length;
    final systemDetected = reports.where((r) => r.detectedBySystem).length;
    final studentReported = total - systemDetected;
    final highSeverity = reports.where((r) => r.severity.toLowerCase() == 'high' || r.severity.toLowerCase() == 'critical').length;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _field.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.analytics_rounded, size: 18, color: _accentAForeground),
              const SizedBox(width: 8),
              Text(
                'History Logs Summary & Filter Analytics',
                style: TextStyle(
                  color: _text,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              if (_historyLogFilter != 'all')
                TextButton.icon(
                  style: TextButton.styleFrom(
                    foregroundColor: _accentAForeground,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  ),
                  icon: const Icon(Icons.clear_rounded, size: 14),
                  label: const Text('Reset Filter', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
                  onPressed: () => setState(() => _historyLogFilter = 'all'),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _summaryMetricItem(
                  label: 'Total Archived',
                  value: '$total',
                  color: const Color(0xFF0EA5E9),
                  icon: Icons.assignment_turned_in_rounded,
                  isSelected: _historyLogFilter == 'all',
                  onTap: () => setState(() => _historyLogFilter = 'all'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _summaryMetricItem(
                  label: 'System Detected',
                  value: '$systemDetected',
                  color: const Color(0xFF10B981),
                  icon: Icons.computer_rounded,
                  isSelected: _historyLogFilter == 'system',
                  onTap: () => setState(() => _historyLogFilter = 'system'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _summaryMetricItem(
                  label: 'Student Reported',
                  value: '$studentReported',
                  color: const Color(0xFF8B5CF6),
                  icon: Icons.person_rounded,
                  isSelected: _historyLogFilter == 'student',
                  onTap: () => setState(() => _historyLogFilter = 'student'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _summaryMetricItem(
                  label: 'High Severity',
                  value: '$highSeverity',
                  color: const Color(0xFFEF4444),
                  icon: Icons.warning_rounded,
                  isSelected: _historyLogFilter == 'high_severity',
                  onTap: () => setState(() => _historyLogFilter = 'high_severity'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _summaryMetricItem({
    required String label,
    required String value,
    required Color color,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? color.withValues(alpha: 0.12) : _card,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? color : _border,
              width: isSelected ? 1.8 : 1.0,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 16),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      value,
                      style: TextStyle(
                        color: _text,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      label,
                      style: TextStyle(
                        color: isSelected ? color : _sub,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _errorState(String message) {
    return Center(
      child: Container(
        width: _dialogWidth(context, 430),
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: _errorColor.withValues(alpha: 0.3)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: _dark ? 0.2 : 0.05),
              blurRadius: 28,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: _errorColor.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.error_outline_rounded, size: 32, color: _errorColor),
            ),
            const SizedBox(height: 16),
            Text(
              'Failed to Load Dashboard',
              style: TextStyle(
                color: _text,
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: _sub, fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 20),
            _gradientButton(
              label: 'Try Again',
              icon: Icons.refresh_rounded,
              onPressed: _refresh,
            ),
          ],
        ),
      ),
    );
  }

  void _message(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _accentColor,
                ),
                child: Icon(
                  Icons.info_outline_rounded,
                  size: 18,
                  color: _dark ? Colors.black : Colors.white,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(
                    color: _text,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: _card,
          behavior: SnackBarBehavior.floating,
          elevation: 4,
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: _accentAForeground.withValues(alpha: 0.35)),
          ),
        ),
      );
  }
}