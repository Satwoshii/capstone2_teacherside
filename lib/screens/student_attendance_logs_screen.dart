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
  String _roomFilter = 'All Rooms';
  TimeFilterOption _timeFilter = TimeFilterOption.allTime;
  DateTimeRange? _customDateRange;
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
      includeHistory: true,
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
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
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
                  _toolbarControls(subjects, allRecords),
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

  Widget _toolbarControls(Set<String> subjects, List<StudentAttendanceRecord> allRecords) {
    final availableRooms = <String>{
      'All Rooms',
      widget.room.roomName,
      ...allRecords.map((r) => r.roomName).where((r) => r.trim().isNotEmpty),
      '101', '102', '103', '104', '201', '202',
    }.toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          // Search Bar
          SizedBox(
            width: 280,
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
                  hintText: 'Search student, ID, PC, or section...',
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
          // Room Filter Dropdown
          Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: _field,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _border),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: availableRooms.contains(_roomFilter) ? _roomFilter : 'All Rooms',
                dropdownColor: _card,
                style: TextStyle(color: _text, fontSize: 13, fontWeight: FontWeight.w600),
                items: availableRooms.map((rm) {
                  return DropdownMenuItem<String>(
                    value: rm,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.meeting_room_rounded, size: 16, color: _sub),
                        const SizedBox(width: 8),
                        Text(rm == 'All Rooms' ? 'All Rooms' : 'Room $rm'),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _roomFilter = val);
                },
              ),
            ),
          ),
          // Time Filter Dropdown
          Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: _field,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _border),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<TimeFilterOption>(
                value: _timeFilter,
                dropdownColor: _card,
                style: TextStyle(color: _text, fontSize: 13, fontWeight: FontWeight.w600),
                items: TimeFilterOption.values.map((tf) {
                  return DropdownMenuItem<TimeFilterOption>(
                    value: tf,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.calendar_today_rounded, size: 15, color: _sub),
                        const SizedBox(width: 8),
                        Text(tf.label),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() => _timeFilter = val);
                    if (val == TimeFilterOption.custom && _customDateRange == null) {
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
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
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
              DataColumn(label: Text('Subject', style: TextStyle(color: _text, fontWeight: FontWeight.w800))),
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
                  // Subject
                  DataCell(
                    Text(
                      r.subject,
                      style: TextStyle(
                        color: _text,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
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
                          'Export Attendance Logs CSV',
                          style: TextStyle(color: _text, fontWeight: FontWeight.w800, fontSize: 17),
                        ),
                        Text(
                          'Filter logs by room number and time period before downloading',
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
                          'Report includes $matchingRecords matching log record${matchingRecords == 1 ? '' : 's'}.',
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
                        content: Text('Attendance logs CSV copied to clipboard.'),
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
                      final savedPath = await _saveAttendanceCsv(csvData, prefix: 'Syswatch_Attendance_Logs', roomName: dialogRoomFilter);
                      if (ctx.mounted) Navigator.pop(ctx);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Logs exported to: $savedPath'),
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


  Future<String> _saveAttendanceCsv(String csvData, {required String prefix, String roomName = ''}) async {
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
    final safeRoom = targetRoom.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
    final file = File('${downloadsDir.path}/${prefix}_Room_${safeRoom}_$stamp.csv');
    await file.writeAsString(csvData, flush: true);
    return file.path;
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
