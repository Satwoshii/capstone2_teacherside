import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

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
  String _subjectFilter = 'All Subjects';
  String _roomFilter = 'All Rooms';
  TimeFilterOption _timeFilter = TimeFilterOption.allTime;
  DateTimeRange? _customDateRange;
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

  bool get _hasActiveFilters =>
      _statusFilter != null ||
      _subjectFilter != 'All Subjects' ||
      _roomFilter != 'All Rooms' ||
      _timeFilter != TimeFilterOption.allTime ||
      _searchController.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _refresh();
    _refreshTimer = Timer.periodic(
        const Duration(seconds: 15), (_) => _refresh(silent: true));
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

  void _clearFilters() {
    _searchController.clear();
    setState(() {
      _statusFilter = null;
      _subjectFilter = 'All Subjects';
      _roomFilter = 'All Rooms';
      _timeFilter = TimeFilterOption.allTime;
      _customDateRange = null;
    });
  }

  Future<void> _pickCustomDateTimeRange() async {
    final picked = await _showCustomDateTimeRangePopup(initialRange: _customDateRange);
    if (picked != null) {
      setState(() {
        _customDateRange = picked;
        _timeFilter = TimeFilterOption.custom;
      });
    }
  }

  Future<DateTimeRange?> _showCustomDateTimeRangePopup({DateTimeRange? initialRange}) async {
    final now = DateTime.now();
    DateTime startDate = initialRange?.start ?? DateTime(now.year, now.month, now.day, 0, 0);
    TimeOfDay startTime = TimeOfDay(hour: startDate.hour, minute: startDate.minute);

    DateTime endDate = initialRange?.end ?? DateTime(now.year, now.month, now.day, 23, 59);
    TimeOfDay endTime = TimeOfDay(hour: endDate.hour, minute: endDate.minute);

    return showDialog<DateTimeRange>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDlgState) {
            String formatDate(DateTime dt) {
              final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
              return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
            }

            String formatTime(TimeOfDay tod) {
              final h = tod.hour == 0 ? 12 : (tod.hour > 12 ? tod.hour - 12 : tod.hour);
              final ampm = tod.hour >= 12 ? 'PM' : 'AM';
              final m = tod.minute.toString().padLeft(2, '0');
              return '$h:$m $ampm';
            }

            return AlertDialog(
              backgroundColor: _card,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _accentAForeground.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.event_available_rounded, color: _accentAForeground, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Custom Date & Time Range',
                          style: TextStyle(color: _text, fontWeight: FontWeight.w800, fontSize: 17),
                        ),
                        Text(
                          'Select starting and ending date & time',
                          style: TextStyle(color: _sub, fontSize: 11.5, fontWeight: FontWeight.normal),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 480,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Start Date & Time
                    Text('START DATE & TIME', style: TextStyle(color: _sub, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: InkWell(
                            onTap: () async {
                              final pickedDate = await showDatePicker(
                                context: context,
                                initialDate: startDate,
                                firstDate: DateTime(2020),
                                lastDate: DateTime(now.year + 2),
                              );
                              if (pickedDate != null) {
                                setDlgState(() => startDate = pickedDate);
                              }
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                              decoration: BoxDecoration(
                                color: _field,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: _border),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.calendar_today_rounded, size: 16, color: _accentAForeground),
                                  const SizedBox(width: 8),
                                  Text(formatDate(startDate), style: TextStyle(color: _text, fontSize: 12.5, fontWeight: FontWeight.w600)),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 2,
                          child: InkWell(
                            onTap: () async {
                              final pickedTime = await showTimePicker(
                                context: context,
                                initialTime: startTime,
                              );
                              if (pickedTime != null) {
                                setDlgState(() => startTime = pickedTime);
                              }
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                              decoration: BoxDecoration(
                                color: _field,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: _border),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.access_time_rounded, size: 16, color: _accentAForeground),
                                  const SizedBox(width: 8),
                                  Text(formatTime(startTime), style: TextStyle(color: _text, fontSize: 12.5, fontWeight: FontWeight.w600)),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // End Date & Time
                    Text('END DATE & TIME', style: TextStyle(color: _sub, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: InkWell(
                            onTap: () async {
                              final pickedDate = await showDatePicker(
                                context: context,
                                initialDate: endDate,
                                firstDate: DateTime(2020),
                                lastDate: DateTime(now.year + 2),
                              );
                              if (pickedDate != null) {
                                setDlgState(() => endDate = pickedDate);
                              }
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                              decoration: BoxDecoration(
                                color: _field,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: _border),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.calendar_today_rounded, size: 16, color: _accentAForeground),
                                  const SizedBox(width: 8),
                                  Text(formatDate(endDate), style: TextStyle(color: _text, fontSize: 12.5, fontWeight: FontWeight.w600)),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 2,
                          child: InkWell(
                            onTap: () async {
                              final pickedTime = await showTimePicker(
                                context: context,
                                initialTime: endTime,
                              );
                              if (pickedTime != null) {
                                setDlgState(() => endTime = pickedTime);
                              }
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                              decoration: BoxDecoration(
                                color: _field,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: _border),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.access_time_rounded, size: 16, color: _accentAForeground),
                                  const SizedBox(width: 8),
                                  Text(formatTime(endTime), style: TextStyle(color: _text, fontSize: 12.5, fontWeight: FontWeight.w600)),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Quick Presets
                    Text('QUICK PRESETS', style: TextStyle(color: _sub, fontSize: 10.5, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _presetChip('Today', () {
                          setDlgState(() {
                            startDate = DateTime(now.year, now.month, now.day, 0, 0);
                            startTime = const TimeOfDay(hour: 0, minute: 0);
                            endDate = DateTime(now.year, now.month, now.day, 23, 59);
                            endTime = const TimeOfDay(hour: 23, minute: 59);
                          });
                        }),
                        _presetChip('Last 24 Hours', () {
                          final prev = now.subtract(const Duration(hours: 24));
                          setDlgState(() {
                            startDate = DateTime(prev.year, prev.month, prev.day, prev.hour, prev.minute);
                            startTime = TimeOfDay(hour: prev.hour, minute: prev.minute);
                            endDate = DateTime(now.year, now.month, now.day, now.hour, now.minute);
                            endTime = TimeOfDay(hour: now.hour, minute: now.minute);
                          });
                        }),
                        _presetChip('Last 7 Days', () {
                          final prev = now.subtract(const Duration(days: 7));
                          setDlgState(() {
                            startDate = DateTime(prev.year, prev.month, prev.day, 0, 0);
                            startTime = const TimeOfDay(hour: 0, minute: 0);
                            endDate = DateTime(now.year, now.month, now.day, 23, 59);
                            endTime = const TimeOfDay(hour: 23, minute: 59);
                          });
                        }),
                        _presetChip('This Month', () {
                          setDlgState(() {
                            startDate = DateTime(now.year, now.month, 1, 0, 0);
                            startTime = const TimeOfDay(hour: 0, minute: 0);
                            endDate = DateTime(now.year, now.month, now.day, 23, 59);
                            endTime = const TimeOfDay(hour: 23, minute: 59);
                          });
                        }),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, null),
                  child: Text('Cancel', style: TextStyle(color: _sub)),
                ),
                FilledButton.icon(
                  onPressed: () {
                    final startFull = DateTime(startDate.year, startDate.month, startDate.day, startTime.hour, startTime.minute);
                    final endFull = DateTime(endDate.year, endDate.month, endDate.day, endTime.hour, endTime.minute);
                    if (endFull.isBefore(startFull)) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('End date/time must be after start date/time.'),
                          backgroundColor: Color(0xFFEF4444),
                        ),
                      );
                      return;
                    }
                    Navigator.pop(ctx, DateTimeRange(start: startFull, end: endFull));
                  },
                  icon: const Icon(Icons.check_rounded, size: 16),
                  label: const Text('Apply Range'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _presetChip(String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: _field,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _border),
        ),
        child: Text(label, style: TextStyle(color: _text, fontSize: 11, fontWeight: FontWeight.w600)),
      ),
    );
  }

  String _formatDateTimeRangeLabel(DateTimeRange range) {
    final s = range.start;
    final e = range.end;
    final sTime = _formatTimeOfDay(TimeOfDay(hour: s.hour, minute: s.minute));
    final eTime = _formatTimeOfDay(TimeOfDay(hour: e.hour, minute: e.minute));
    return '${s.month}/${s.day} $sTime - ${e.month}/${e.day} $eTime';
  }

  String _formatTimeOfDay(TimeOfDay tod) {
    final h = tod.hour == 0 ? 12 : (tod.hour > 12 ? tod.hour - 12 : tod.hour);
    final ampm = tod.hour >= 12 ? 'PM' : 'AM';
    final m = tod.minute.toString().padLeft(2, '0');
    return '$h:$m $ampm';
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
                child: FutureBuilder<
                    (List<StudentAttendanceRecord>, AttendanceSummary)>(
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

  // ───────────────────────── TOP BAR ─────────────────────────

  Widget _topBar() {
    final navBg = _dark ? _card.withValues(alpha: 0.96) : _accentB;
    final navFg = _dark ? _text : Colors.white;
    final navSub = _dark ? _sub : Colors.white70;
    final navBorder = _dark ? _border : Colors.white.withValues(alpha: 0.1);
    final width = MediaQuery.of(context).size.width;
    final compact = width < 1250;
    final showClock = width >= 1000;

    final windowsAccount = TeacherWindowsSessionService.instance.cachedAccount;
    final currentUserDisplayName =
        windowsAccount?.displayLabel ?? widget.user.displayName;

    // Full-width bar. The title block is an Expanded (no Spacer), so it takes
    // all the free space and pushes the actions to the far right edge.
    return Container(
      width: double.infinity,
      padding:
      EdgeInsets.symmetric(horizontal: compact ? 14 : 24, vertical: 12),
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
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Student Attendance',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: navFg, fontSize: 18, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 2),
                Text(
                  'Laboratory ${widget.room.roomName} · Live PC usage',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: navSub, fontSize: 11.5),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          if (showClock) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: _dark ? _field : Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: navBorder),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.circle, size: 8, color: Color(0xFF10B981)),
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
            const SizedBox(width: 10),
          ],
          Tooltip(
            message: currentUserDisplayName,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: _dark ? _field : Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: _dark
                        ? navBorder
                        : Colors.black.withValues(alpha: 0.1)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.person_rounded,
                      size: 16, color: _dark ? _accentAForeground : _accentB),
                  if (!compact) ...[
                    const SizedBox(width: 8),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 180),
                      child: Text(
                        currentUserDisplayName,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: _dark ? navFg : Colors.black87,
                          fontSize: 12.8,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          ..._topBarActions(compact),
        ],
      ),
    );
  }

  List<Widget> _topBarActions(bool compact) {
    void openLogs() => Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StudentAttendanceLogsScreen(
            user: widget.user, room: widget.room),
      ),
    );

    if (compact) {
      return [
        _gradientButton(
          label: 'Check-In',
          icon: Icons.person_add_alt_1_rounded,
          onNavbar: true,
          onPressed: () => _showManualCheckInDialog(),
        ),
        const SizedBox(width: 8),
        PopupMenuButton<String>(
          tooltip: 'More actions',
          color: _card,
          icon: Icon(Icons.more_vert_rounded,
              color: _dark ? _sub : Colors.white),
          onSelected: (v) {
            switch (v) {
              case 'logs':
                openLogs();
                break;
              case 'export':
                _showExportDialog();
                break;
              case 'refresh':
                _refresh(force: true);
                break;
            }
          },
          itemBuilder: (_) => [
            _menuItem('logs', Icons.history_rounded, 'Login/Logout Logs'),
            _menuItem('export', Icons.download_rounded, 'Export CSV'),
            _menuItem('refresh', Icons.refresh_rounded, 'Refresh'),
          ],
        ),
      ];
    }

    return [
      _ghostButton(
          label: 'Logs', icon: Icons.history_rounded, onPressed: openLogs),
      const SizedBox(width: 8),
      _ghostButton(
          label: 'Export CSV',
          icon: Icons.download_rounded,
          onPressed: _showExportDialog),
      const SizedBox(width: 8),
      _iconTile(
        icon: Icons.refresh_rounded,
        tooltip: 'Refresh attendance data',
        onPressed: () => _refresh(force: true),
      ),
      const SizedBox(width: 10),
      _gradientButton(
        label: 'Log Check-In',
        icon: Icons.person_add_alt_1_rounded,
        onNavbar: true,
        onPressed: () => _showManualCheckInDialog(),
      ),
    ];
  }

  PopupMenuItem<String> _menuItem(String value, IconData icon, String label) {
    return PopupMenuItem<String>(
      value: value,
      child: Row(
        children: [
          Icon(icon, size: 18, color: _sub),
          const SizedBox(width: 10),
          Text(label, style: TextStyle(color: _text, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _ghostButton({
    required String label,
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    final fg = _dark ? _text : Colors.white;
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16, color: fg),
      label: Text(label,
          style: TextStyle(
              color: fg, fontSize: 12.5, fontWeight: FontWeight.w700)),
      style: OutlinedButton.styleFrom(
        side: BorderSide(color: fg.withValues(alpha: 0.35)),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  // ───────────────────────── CONTENT ─────────────────────────

  Widget _content(
      List<StudentAttendanceRecord> allRecords,
      AttendanceSummary summary,
      ) {
    final query = _searchController.text.trim().toLowerCase();
    final subjects = {'All Subjects', ...allRecords.map((r) => r.subject)};

    final filtered = allRecords.where((r) {
      if (_statusFilter != null && r.status != _statusFilter) {
        return false;
      }
      if (_subjectFilter != 'All Subjects' && r.subject != _subjectFilter) {
        return false;
      }
      if (!r.matchesRoomAndRange(
        roomFilter: _roomFilter,
        timeFilter: _timeFilter,
        customDateRange: _customDateRange,
        currentRoomName: widget.room.roomName,
      )) {
        return false;
      }
      if (query.isNotEmpty) {
        final pc = r.pcId.toLowerCase();
        final name = r.studentName.toLowerCase();
        final id = r.studentId.toLowerCase();
        final rm = (r.roomName.isNotEmpty ? r.roomName : widget.room.roomName).toLowerCase();
        return pc.contains(query) ||
            name.contains(query) ||
            id.contains(query) ||
            rm.contains(query);
      }
      return true;
    }).toList();

    // Full-width content (no maxWidth) so it lines up with the full-width
    // navbar. Horizontal padding is 24 to match the navbar.
    return RefreshIndicator(
      color: _accentAForeground,
      onRefresh: () async => _refresh(force: true),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 86),
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _summaryCardsHeader(summary),
              const SizedBox(height: 20),
              _toolbarControls(subjects, allRecords),
              const SizedBox(height: 18),
              _tableListView(filtered),
            ],
          ),
        ],
      ),
    );
  }

  Widget _summaryCardsHeader(AttendanceSummary summary) {
    final cards = <Widget Function(double)>[
          (w) => SizedBox(
        width: w,
        child: _kpiCard(
          title: 'Active on PC',
          value: '${summary.totalActive}',
          subtitle: 'Online in lab now · tap to filter',
          icon: Icons.computer_rounded,
          color: const Color(0xFF10B981),
          hasPulse: summary.totalActive > 0,
          onTap: () =>
              setState(() => _statusFilter = AttendanceStatus.active),
        ),
      ),
          (w) => SizedBox(
        width: w,
        child: _kpiCard(
          title: 'Present Today',
          value: '${summary.totalAttended}',
          subtitle: 'Active + checked-in',
          icon: Icons.how_to_reg_rounded,
          color: const Color(0xFF0EA5E9),
        ),
      ),
          (w) => SizedBox(
        width: w,
        child: _kpiCard(
          title: 'Late Check-Ins',
          value: '${summary.totalLate}',
          subtitle: 'After class start · tap to filter',
          icon: Icons.schedule_rounded,
          color: const Color(0xFFF59E0B),
          onTap: () =>
              setState(() => _statusFilter = AttendanceStatus.late),
        ),
      ),
          (w) => SizedBox(
        width: w,
        child: _kpiCard(
          title: 'Vacant PCs',
          value: '${summary.totalVacantPcs}',
          subtitle: 'Unoccupied workstations',
          icon: Icons.desktop_windows_outlined,
          color: _dark ? Colors.white54 : Colors.black54,
        ),
      ),
          (w) => SizedBox(
        width: w,
        child: _kpiCard(
          title: 'Attendance Rate',
          value: '${summary.attendanceRate.toStringAsFixed(0)}%',
          subtitle:
          '${summary.totalAttended} of ${summary.totalExpected} expected',
          icon: Icons.pie_chart_rounded,
          color: _accentAForeground,
        ),
      ),
    ];

    return LayoutBuilder(builder: (context, c) {
      const gap = 14.0;
      final perRow = c.maxWidth >= 1100 ? 5 : (c.maxWidth >= 700 ? 3 : 2);
      final w = (c.maxWidth - gap * (perRow - 1)) / perRow;
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: [for (final b in cards) b(w.floorToDouble())],
      );
    });
  }

  Widget _kpiCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    bool hasPulse = false,
    VoidCallback? onTap,
  }) {
    return Container(
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
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          mouseCursor: onTap == null
              ? SystemMouseCursors.basic
              : SystemMouseCursors.click,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(icon, color: color, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(value,
                              style: TextStyle(
                                  color: _text,
                                  fontSize: 24,
                                  fontWeight: FontWeight.w900)),
                          if (hasPulse) ...[
                            const SizedBox(width: 8),
                            Icon(Icons.circle, size: 9, color: color),
                          ],
                        ],
                      ),
                      Text(title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              color: _text,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700)),
                      Text(subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: _sub, fontSize: 10.5)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ───────────────────────── FILTERS ─────────────────────────

  Widget _toolbarControls(
      Set<String> subjects,
      List<StudentAttendanceRecord> all,
      ) {
    final availableRooms = <String>{
      'All Rooms',
      widget.room.roomName,
      ...all.map((r) => r.roomName).where((r) => r.trim().isNotEmpty),
      '101', '102', '103', '104', '201', '202',
    }.toList();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    SizedBox(
                      width: 260,
                      child: TextField(
                        controller: _searchController,
                        style: TextStyle(color: _text, fontSize: 13),
                        decoration: InputDecoration(
                          hintText: 'Search student, ID, PC…',
                          hintStyle: TextStyle(color: _sub, fontSize: 13),
                          prefixIcon: Icon(Icons.search_rounded,
                              color: _sub, size: 19),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                            tooltip: 'Clear search',
                            icon: Icon(Icons.clear_rounded,
                                color: _sub, size: 18),
                            onPressed: () => _searchController.clear(),
                          )
                              : null,
                          filled: true,
                          fillColor: _field,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                    // Room Number Filter Dropdown
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: _field,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: availableRooms.contains(_roomFilter) ? _roomFilter : 'All Rooms',
                          dropdownColor: _card,
                          icon: Icon(Icons.expand_more_rounded, color: _sub),
                          style: TextStyle(color: _text, fontSize: 12.5, fontWeight: FontWeight.w600),
                          items: availableRooms
                              .map((rm) => DropdownMenuItem(
                              value: rm,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.meeting_room_rounded, size: 15, color: _sub),
                                  const SizedBox(width: 6),
                                  Text(rm == 'All Rooms' ? 'All Rooms' : 'Room $rm',
                                      style: TextStyle(color: _text)),
                                ],
                              )))
                              .toList(),
                          onChanged: (v) {
                            if (v != null) setState(() => _roomFilter = v);
                          },
                        ),
                      ),
                    ),
                    // Time Filter Dropdown
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: _field,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<TimeFilterOption>(
                          value: _timeFilter,
                          dropdownColor: _card,
                          icon: Icon(Icons.expand_more_rounded, color: _sub),
                          style: TextStyle(color: _text, fontSize: 12.5, fontWeight: FontWeight.w600),
                          items: TimeFilterOption.values
                              .map((tf) => DropdownMenuItem(
                              value: tf,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.calendar_today_rounded, size: 15, color: _sub),
                                  const SizedBox(width: 6),
                                  Text(tf.label,
                                      style: TextStyle(color: _text)),
                                ],
                              )))
                              .toList(),
                          onChanged: (v) {
                            if (v != null) {
                              setState(() {
                                _timeFilter = v;
                              });
                              if (v == TimeFilterOption.custom && _customDateRange == null) {
                                _pickCustomDateTimeRange();
                              }
                            }
                          },
                        ),
                      ),
                    ),
                    if (_timeFilter == TimeFilterOption.custom)
                      OutlinedButton.icon(
                        onPressed: _pickCustomDateTimeRange,
                        icon: const Icon(Icons.date_range_rounded, size: 16),
                        label: Text(
                          _customDateRange != null
                              ? _formatDateTimeRangeLabel(_customDateRange!)
                              : 'Select Date & Time',
                          style: const TextStyle(fontSize: 12),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _accentAForeground,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                          icon: Icon(Icons.expand_more_rounded, color: _sub),
                          style: TextStyle(color: _text, fontSize: 12.5),
                          items: subjects
                              .map((s) => DropdownMenuItem(
                              value: s,
                              child: Text(s,
                                  style: TextStyle(color: _text))))
                              .toList(),
                          onChanged: (v) {
                            if (v != null) setState(() => _subjectFilter = v);
                          },
                        ),
                      ),
                    ),
                    if (_hasActiveFilters)
                      TextButton.icon(
                        onPressed: _clearFilters,
                        icon: const Icon(Icons.filter_alt_off_rounded,
                            size: 16),
                        label: const Text('Clear filters'),
                        style: TextButton.styleFrom(
                            foregroundColor: _accentAForeground),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _statusChip(null, 'All', Icons.apps_rounded, _sub, all.length),
                for (final s in AttendanceStatus.values) ...[
                  const SizedBox(width: 8),
                  _statusChip(s, s.label, s.icon, s.color,
                      all.where((r) => r.status == s).length),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusChip(
      AttendanceStatus? value,
      String label,
      IconData icon,
      Color color,
      int count,
      ) {
    final selected = _statusFilter == value;
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => setState(() => _statusFilter = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.18) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: selected ? color : _border, width: selected ? 1.4 : 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: selected ? color : _sub),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                    color: selected ? color : _text,
                    fontSize: 12,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600)),
            const SizedBox(width: 6),
            Text('$count',
                style: TextStyle(
                    color: selected ? color : _sub,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800)),
          ],
        ),
      ),
    );
  }

  // ───────────────────────── TABLE ─────────────────────────

  Widget _tableListView(List<StudentAttendanceRecord> records) {
    if (records.isEmpty) {
      return _emptyAttendanceState();
    }

    final gridBorderColor = _dark
        ? Colors.white.withValues(alpha: 0.1)
        : Colors.black.withValues(alpha: 0.12);

    return Container(
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _border),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final minTableWidth = math.max(constraints.maxWidth, 1350.0);
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: BoxConstraints(minWidth: minTableWidth),
                child: DataTable(
                  showCheckboxColumn: false,
                  headingRowColor: WidgetStateProperty.all(_field),
                  headingRowHeight: 48,
                  dataRowMinHeight: 52,
                  dataRowMaxHeight: 64,
                  horizontalMargin: 16,
                  columnSpacing: 20,
                  border: TableBorder(
                    verticalInside: BorderSide(
                      color: gridBorderColor,
                      width: 1,
                    ),
                    horizontalInside: BorderSide(
                      color: gridBorderColor,
                      width: 1,
                    ),
                  ),
                  columns: [
                    DataColumn(
                        label: Text('PC ID', style: _tableHeaderStyle())),
                    DataColumn(
                        label: Text('Student ID', style: _tableHeaderStyle())),
                    DataColumn(
                        label:
                        Text('Student Name', style: _tableHeaderStyle())),
                    DataColumn(
                        label: Text('Course / Section',
                            style: _tableHeaderStyle())),
                    DataColumn(
                        label: Text('Subject', style: _tableHeaderStyle())),
                    DataColumn(
                        label: Text('Date', style: _tableHeaderStyle())),
                    DataColumn(
                        label: Text('Time In', style: _tableHeaderStyle())),
                    DataColumn(
                        label: Text('Time Out', style: _tableHeaderStyle())),
                    DataColumn(
                        label: Text('Duration', style: _tableHeaderStyle())),
                    DataColumn(
                        label: Text('IP Address', style: _tableHeaderStyle())),
                    DataColumn(
                        label: Text('Status', style: _tableHeaderStyle())),
                    DataColumn(
                        label: Text('Remarks / Notes',
                            style: _tableHeaderStyle())),
                    DataColumn(
                        label: Text('Actions', style: _tableHeaderStyle())),
                  ],
                  rows: [
                    for (final r in records)
                      DataRow(
                        onSelectChanged: (_) => _showStudentDetailModal(r),
                        cells: [
                          DataCell(
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: _field,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(r.pcId,
                                    style: TextStyle(
                                        color: _text,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 12)),
                              ),
                            ),
                          ),
                          DataCell(
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Text(r.studentId,
                                  style: TextStyle(
                                      color: _text, fontSize: 12.5)),
                            ),
                          ),
                          DataCell(
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  CircleAvatar(
                                    radius: 13,
                                    backgroundColor:
                                    _accentColor.withValues(alpha: 0.15),
                                    child: Text(_initials(r.studentName),
                                        style: TextStyle(
                                            color: _accentAForeground,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold)),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(r.studentName,
                                      style: TextStyle(
                                          color: _text,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 13)),
                                ],
                              ),
                            ),
                          ),
                          DataCell(
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                  r.courseSection.isNotEmpty
                                      ? r.courseSection
                                      : '-',
                                  style: TextStyle(color: _sub, fontSize: 12)),
                            ),
                          ),
                          DataCell(
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Text(r.subject,
                                  style: TextStyle(color: _sub, fontSize: 12)),
                            ),
                          ),
                          DataCell(
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Text(r.formattedDate,
                                  style: TextStyle(color: _text, fontSize: 12)),
                            ),
                          ),
                          DataCell(
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Text(r.formattedLoginTime,
                                  style: TextStyle(color: _text, fontSize: 12)),
                            ),
                          ),
                          DataCell(
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                r.formattedLogoutTime,
                                style: TextStyle(
                                  color: r.logoutTime == null
                                      ? _accentAForeground
                                      : _text,
                                  fontSize: 12,
                                  fontWeight: r.logoutTime == null
                                      ? FontWeight.w700
                                      : FontWeight.normal,
                                ),
                              ),
                            ),
                          ),
                          DataCell(
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Text(r.formattedDuration,
                                  style: TextStyle(
                                      color: _sub,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600)),
                            ),
                          ),
                          DataCell(
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                  r.ipAddress.isNotEmpty ? r.ipAddress : '-',
                                  style: TextStyle(color: _sub, fontSize: 12)),
                            ),
                          ),
                          DataCell(
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: r.status.color.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                      color: r.status.color
                                          .withValues(alpha: 0.3)),
                                ),
                                child: Text(
                                  r.status.label,
                                  style: TextStyle(
                                      color: r.status.color,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800),
                                ),
                              ),
                            ),
                          ),
                          DataCell(
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                  r.remarks != null && r.remarks!.isNotEmpty
                                      ? r.remarks!
                                      : '-',
                                  style: TextStyle(
                                      color: r.remarks != null &&
                                          r.remarks!.isNotEmpty
                                          ? _text
                                          : _sub,
                                      fontSize: 12)),
                            ),
                          ),
                          DataCell(
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.info_outline_rounded,
                                        size: 18),
                                    color: _accentAForeground,
                                    tooltip: 'View Details',
                                    onPressed: () => _showStudentDetailModal(r),
                                  ),
                                  if (r.isActive ||
                                      r.isLate ||
                                      r.status == AttendanceStatus.present)
                                    IconButton(
                                      icon: const Icon(Icons.logout_rounded,
                                          size: 18),
                                      color: const Color(0xFFEF4444),
                                      tooltip: 'Sign Out Student',
                                      onPressed: () => _signOutStudent(r),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            );
          },
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

  // ───────────────────────── STATES ─────────────────────────

  Widget _emptyAttendanceState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _border),
      ),
      child: Column(
        children: [
          Icon(Icons.search_off_rounded,
              size: 48, color: _sub.withValues(alpha: 0.6)),
          const SizedBox(height: 12),
          Text('No records match',
              style: TextStyle(
                  color: _text, fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(
            _hasActiveFilters
                ? 'Your search or filters are hiding everything.'
                : 'Nobody has logged in yet. You can check a student in manually.',
            textAlign: TextAlign.center,
            style: TextStyle(color: _sub, fontSize: 12),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            alignment: WrapAlignment.center,
            children: [
              if (_hasActiveFilters)
                OutlinedButton.icon(
                  onPressed: _clearFilters,
                  icon: const Icon(Icons.filter_alt_off_rounded, size: 16),
                  label: const Text('Clear filters'),
                ),
              FilledButton.icon(
                onPressed: () => _showManualCheckInDialog(),
                icon: const Icon(Icons.person_add_alt_1_rounded, size: 16),
                label: const Text('Log Check-In'),
              ),
            ],
          ),
        ],
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
            const Icon(Icons.error_outline_rounded,
                color: Color(0xFFEF4444), size: 48),
            const SizedBox(height: 12),
            Text(
              'Could Not Load Attendance Records',
              style: TextStyle(
                  color: _text, fontSize: 16, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(message,
                textAlign: TextAlign.center,
                style: TextStyle(color: _sub, fontSize: 12)),
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

  // ───────────────────────── ACTIONS & DIALOGS ─────────────────────────

  Future<void> _signOutStudent(StudentAttendanceRecord record) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _card,
        title: Text('Sign Out Student?',
            style: TextStyle(color: _text, fontWeight: FontWeight.w800)),
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
            style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFEF4444)),
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
            content:
            Text('${record.studentName} signed out from ${record.pcId}.'),
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
            return SingleChildScrollView(
              child: Padding(
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
                          backgroundColor:
                          currentStatus.color.withValues(alpha: 0.15),
                          child: Icon(currentStatus.icon,
                              color: currentStatus.color, size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                record.studentName,
                                style: TextStyle(
                                    color: _text,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800),
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
                      record.studentEmail.trim().isEmpty
                          ? 'Not available'
                          : record.studentEmail,
                    ),
                    const SizedBox(height: 12),
                    _detailGridRow('Login Time', record.formattedLoginTime,
                        'Active Duration', record.formattedDuration),
                    const SizedBox(height: 12),
                    _detailGridRow('Client IP Address', record.ipAddress,
                        'Status', currentStatus.label),
                    const SizedBox(height: 20),
                    Text('Change Attendance Status',
                        style: TextStyle(
                            color: _text,
                            fontSize: 13,
                            fontWeight: FontWeight.w700)),
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
                    Text('Teacher Remarks / Notes',
                        style: TextStyle(
                            color: _text,
                            fontSize: 13,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: remarksController,
                      style: TextStyle(color: _text, fontSize: 13),
                      decoration: InputDecoration(
                        hintText:
                        'Add note (e.g., excused late arrival, equipment issue)...',
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
                        if (record.isActive ||
                            record.isLate ||
                            record.status == AttendanceStatus.present)
                          OutlinedButton.icon(
                            onPressed: () {
                              Navigator.pop(ctx);
                              _signOutStudent(record);
                            },
                            icon: const Icon(Icons.logout_rounded, size: 16),
                            label: const Text('Sign Out Student'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFFEF4444),
                              side:
                              const BorderSide(color: Color(0xFFEF4444)),
                            ),
                          ),
                        const Spacer(),
                        FilledButton(
                          onPressed: () async {
                            final messenger = ScaffoldMessenger.of(context);
                            await StudentAttendanceService.instance
                                .updateStatus(
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
              ),
            );
          },
        );
      },
    );
  }

  Widget _detailGridRow(
      String label1, String val1, String label2, String val2) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label1, style: TextStyle(color: _sub, fontSize: 11)),
              const SizedBox(height: 2),
              Text(val1,
                  style: TextStyle(
                      color: _text, fontSize: 13, fontWeight: FontWeight.w700)),
            ],
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label2, style: TextStyle(color: _sub, fontSize: 11)),
              const SizedBox(height: 2),
              Text(val2,
                  style: TextStyle(
                      color: _text, fontSize: 13, fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ],
    );
  }

  InputDecoration _fieldDecoration({String? hint}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: _sub, fontSize: 12.5),
      filled: true,
      fillColor: _field,
      isDense: true,
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
    );
  }

  Widget _fieldLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(text,
          style: TextStyle(
              color: _text, fontSize: 12.5, fontWeight: FontWeight.w700)),
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
    final subjectController =
    TextEditingController(text: 'IT 312 - Systems Admin');
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
                  Icon(Icons.person_add_alt_1_rounded,
                      color: _accentAForeground),
                  const SizedBox(width: 10),
                  Text('Log Student Check-In',
                      style: TextStyle(
                          color: _text, fontWeight: FontWeight.w800)),
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
                        _fieldLabel('Assign PC Workstation'),
                        DropdownButtonFormField<String>(
                          initialValue: availablePcs.contains(pcId)
                              ? pcId
                              : availablePcs.first,
                          dropdownColor: _card,
                          style: TextStyle(color: _text, fontSize: 13),
                          decoration: _fieldDecoration(),
                          items: availablePcs.map((pc) {
                            return DropdownMenuItem(
                                value: pc,
                                child: Text(pc,
                                    style: TextStyle(color: _text)));
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) setDlgState(() => pcId = val);
                          },
                        ),
                        const SizedBox(height: 12),
                        _fieldLabel('Student ID'),
                        TextFormField(
                          controller: studentIdController,
                          autofocus: true,
                          textInputAction: TextInputAction.next,
                          style: TextStyle(color: _text, fontSize: 13),
                          decoration: _fieldDecoration(hint: 'e.g., 2023-10024'),
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Required'
                              : null,
                        ),
                        const SizedBox(height: 12),
                        _fieldLabel('Student Full Name'),
                        TextFormField(
                          controller: nameController,
                          textInputAction: TextInputAction.next,
                          style: TextStyle(color: _text, fontSize: 13),
                          decoration: _fieldDecoration(
                              hint: 'e.g., Dela Cruz, Juan P.'),
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Required'
                              : null,
                        ),
                        const SizedBox(height: 12),
                        _fieldLabel('Student Email (Optional)'),
                        TextFormField(
                          controller: emailController,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          style: TextStyle(color: _text, fontSize: 13),
                          decoration: _fieldDecoration(
                              hint: 'e.g., student@students.nu-clark.edu.ph'),
                          validator: (v) {
                            final value = (v ?? '').trim();
                            if (value.isEmpty) return null;
                            if (!value.contains('@') || !value.contains('.')) {
                              return 'Enter a valid email or leave blank';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        _fieldLabel('Subject / Class'),
                        TextFormField(
                          controller: subjectController,
                          textInputAction: TextInputAction.next,
                          style: TextStyle(color: _text, fontSize: 13),
                          decoration: _fieldDecoration(
                              hint: 'e.g., IT 312 - Systems Admin'),
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Required'
                              : null,
                        ),
                        const SizedBox(height: 12),
                        _fieldLabel('Initial Status'),
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
                                if (selected) {
                                  setDlgState(() => status = st);
                                }
                              },
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 12),
                        _fieldLabel('Remarks / Note (Optional)'),
                        TextField(
                          controller: remarksController,
                          style: TextStyle(color: _text, fontSize: 13),
                          decoration:
                          _fieldDecoration(hint: 'Optional notes...'),
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
                      final studentName = nameController.text;

                      final messenger = ScaffoldMessenger.of(context);
                      await StudentAttendanceService.instance.checkInStudent(
                        pcId: pcId,
                        studentId: studentIdController.text,
                        studentName: studentName,
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
                          content: Text('$studentName checked in to $pcId.'),
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
    String dialogRoomFilter = _roomFilter != 'All Rooms' ? _roomFilter : 'All Rooms';
    TimeFilterOption dialogTimeFilter = _timeFilter;
    DateTimeRange? dialogCustomRange = _customDateRange;

    final allRecords = StudentAttendanceService.instance.currentRecords;
    final availableRooms = <String>{
      'All Rooms',
      widget.room.roomName,
      ...allRecords.map((r) => r.roomName).where((r) => r.trim().isNotEmpty),
      '101', '102', '103', '104', '201', '202',
    }.toList();

    showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final csvData = StudentAttendanceService.instance.exportCsv(
              roomName: widget.room.roomName,
              roomFilter: dialogRoomFilter,
              timeFilter: dialogTimeFilter,
              customDateRange: dialogCustomRange,
            );

            final matchingRecords = allRecords.where((r) {
              return r.matchesRoomAndRange(
                roomFilter: dialogRoomFilter,
                timeFilter: dialogTimeFilter,
                customDateRange: dialogCustomRange,
                currentRoomName: widget.room.roomName,
              );
            }).length;

            return AlertDialog(
              backgroundColor: _card,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _accentAForeground.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.file_download_rounded, color: _accentAForeground, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Export Attendance CSV Data',
                          style: TextStyle(color: _text, fontWeight: FontWeight.w800, fontSize: 17),
                        ),
                        Text(
                          'Select room and time filters for the exported report',
                          style: TextStyle(color: _sub, fontSize: 11.5, fontWeight: FontWeight.normal),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 620,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: _field,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: _border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              // Room Number Picker
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Room Number Filter', style: TextStyle(color: _sub, fontSize: 11, fontWeight: FontWeight.w700)),
                                    const SizedBox(height: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12),
                                      decoration: BoxDecoration(
                                        color: _card,
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(color: _border),
                                      ),
                                      child: DropdownButtonHideUnderline(
                                        child: DropdownButton<String>(
                                          value: availableRooms.contains(dialogRoomFilter) ? dialogRoomFilter : 'All Rooms',
                                          isExpanded: true,
                                          dropdownColor: _card,
                                          icon: Icon(Icons.expand_more_rounded, color: _sub),
                                          style: TextStyle(color: _text, fontSize: 12.5, fontWeight: FontWeight.w600),
                                          items: availableRooms.map((rm) {
                                            return DropdownMenuItem<String>(
                                              value: rm,
                                              child: Row(
                                                children: [
                                                  Icon(Icons.meeting_room_rounded, size: 15, color: _sub),
                                                  const SizedBox(width: 8),
                                                  Text(rm == 'All Rooms' ? 'All Rooms' : 'Room $rm'),
                                                ],
                                              ),
                                            );
                                          }).toList(),
                                          onChanged: (val) {
                                            if (val != null) {
                                              setDialogState(() {
                                                dialogRoomFilter = val;
                                              });
                                            }
                                          },
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 14),
                              // Time Filter Picker
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Time Filter', style: TextStyle(color: _sub, fontSize: 11, fontWeight: FontWeight.w700)),
                                    const SizedBox(height: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12),
                                      decoration: BoxDecoration(
                                        color: _card,
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(color: _border),
                                      ),
                                      child: DropdownButtonHideUnderline(
                                        child: DropdownButton<TimeFilterOption>(
                                          value: dialogTimeFilter,
                                          isExpanded: true,
                                          dropdownColor: _card,
                                          icon: Icon(Icons.expand_more_rounded, color: _sub),
                                          style: TextStyle(color: _text, fontSize: 12.5, fontWeight: FontWeight.w600),
                                          items: TimeFilterOption.values.map((tf) {
                                            return DropdownMenuItem<TimeFilterOption>(
                                              value: tf,
                                              child: Row(
                                                children: [
                                                  Icon(Icons.calendar_today_rounded, size: 15, color: _sub),
                                                  const SizedBox(width: 8),
                                                  Text(tf.label),
                                                ],
                                              ),
                                            );
                                          }).toList(),
                                          onChanged: (val) async {
                                            if (val != null) {
                                              if (val == TimeFilterOption.custom) {
                                                final picked = await _showCustomDateTimeRangePopup(initialRange: dialogCustomRange);
                                                if (picked != null) {
                                                  setDialogState(() {
                                                    dialogTimeFilter = TimeFilterOption.custom;
                                                    dialogCustomRange = picked;
                                                  });
                                                }
                                              } else {
                                                setDialogState(() {
                                                  dialogTimeFilter = val;
                                                });
                                              }
                                            }
                                          },
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          if (dialogTimeFilter == TimeFilterOption.custom && dialogCustomRange != null) ...[
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Text(
                                  'Selected: ${_formatDateTimeRangeLabel(dialogCustomRange!)}',
                                  style: TextStyle(color: _accentAForeground, fontSize: 11.5, fontWeight: FontWeight.w700),
                                ),
                                const Spacer(),
                                TextButton(
                                  onPressed: () async {
                                    final picked = await _showCustomDateTimeRangePopup(initialRange: dialogCustomRange);
                                    if (picked != null) {
                                      setDialogState(() {
                                        dialogCustomRange = picked;
                                      });
                                    }
                                  },
                                  child: const Text('Change Date & Time', style: TextStyle(fontSize: 11)),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Icon(Icons.info_outline_rounded, size: 14, color: _sub),
                        const SizedBox(width: 6),
                        Text(
                          'Report includes $matchingRecords matching record${matchingRecords == 1 ? '' : 's'}.',
                          style: TextStyle(color: _sub, fontSize: 11.5, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Container(
                      height: 200,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _field,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _border),
                      ),
                      child: SingleChildScrollView(
                        child: SelectableText(
                          csvData,
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 11,
                            color: _text,
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
                      final savedPath = await _saveAttendanceCsv(csvData, roomName: dialogRoomFilter);
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
            );
          },
        );
      },
    );
  }

  Future<String> _saveAttendanceCsv(String csvData, {String roomName = ''}) async {
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
    final targetRoom = roomName.isNotEmpty ? roomName : widget.room.roomName;
    final safeRoom =
    targetRoom.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
    final file = File(
        '${downloadsDir.path}/Syswatch_Attendance_Room_${safeRoom}_$stamp.csv');
    await file.writeAsString(csvData, flush: true);
    return file.path;
  }

  // ───────────────────────── SHARED WIDGETS ─────────────────────────

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
              child: Icon(icon,
                  color: _dark ? _sub : Colors.white70, size: 19),
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
    bool onNavbar = false,
  }) {
    final disabled = onPressed == null;
    // On the navy navbar (light mode) use gold so the button stands out.
    final useGold = onNavbar && !_dark;
    final bg = disabled ? _field : (useGold ? _accentA : _accentColor);
    final fg = disabled
        ? _sub
        : (useGold ? _accentB : (_dark ? Colors.black : Colors.white));

    return DecoratedBox(
      decoration: BoxDecoration(
        color: bg,
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
                Icon(icon, size: 17, color: fg),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    color: fg,
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
    final parts = name
        .trim()
        .split(RegExp(r'[\s,]+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return 'ST';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }
}