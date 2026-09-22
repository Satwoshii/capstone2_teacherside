import 'package:flutter/material.dart';

import '../services/teacher_service.dart';
import '../services/teacher_windows_session_service.dart';
import '../utils/value_helpers.dart';
import '../widgets/theme_toggle_button.dart';

/// Protected Teacher room configuration opened with Ctrl + Shift + A.
///
/// This screen deliberately mirrors the visual language of the Student-side
/// protected PC configuration: centered card, large protected-access badge,
/// rounded field shells, section labels, full-width primary action, and the
/// same light/dark background treatment.
class TeacherRoomConfigDialog extends StatefulWidget {
  const TeacherRoomConfigDialog({super.key});

  @override
  State<TeacherRoomConfigDialog> createState() =>
      _TeacherRoomConfigDialogState();
}

class _TeacherRoomConfigDialogState extends State<TeacherRoomConfigDialog>
    with SingleTickerProviderStateMixin {
  final _adminEmailController = TextEditingController();
  final _adminPasswordController = TextEditingController();
  final _roomController = TextEditingController();
  final _pcCountController = TextEditingController(text: '40');
  final _verifyKey = GlobalKey<FormState>();
  final _saveKey = GlobalKey<FormState>();

  bool _passwordVisible = false;
  bool _verifying = false;
  bool _saving = false;
  bool _verified = false;
  String? _error;
  String? _selectedTeacherUid;
  List<Map<String, dynamic>> _teachers = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _rooms = <Map<String, dynamic>>[];

  late final AnimationController _entryCtrl;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;

  bool get _dark => Theme.of(context).brightness == Brightness.dark;

  Color get _bgColor =>
      _dark ? const Color(0xFF090A0E) : const Color(0xFFF0F2F5);

  Color get _cardColor =>
      _dark ? const Color(0xFF13141A) : Colors.white;

  Color get _fieldColor =>
      _dark ? const Color(0xFF1C1E26) : const Color(0xFFEDF0F5);

  Color get _textColor =>
      _dark ? Colors.white : const Color(0xFF1A1C1E);

  Color get _hintColor =>
      _dark ? Colors.white38 : Colors.black38;

  Color get _borderColor => _dark
      ? const Color(0x12FFFFFF)
      : Colors.black.withValues(alpha: 0.09);

  Color get _accentA => Theme.of(context).colorScheme.primary;
  Color get _accentB => Theme.of(context).colorScheme.secondary;
  Color get _successColor => const Color(0xFF31C48D);
  Color get _errorColor => const Color(0xFFFF6B6B);

  @override
  void initState() {
    super.initState();

    _entryCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _fadeAnim = CurvedAnimation(
      parent: _entryCtrl,
      curve: Curves.easeOut,
    );

    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _entryCtrl,
        curve: Curves.easeOutCubic,
      ),
    );

    _entryCtrl.forward();
  }

  @override
  void dispose() {
    _entryCtrl.dispose();
    _adminEmailController.dispose();
    _adminPasswordController.dispose();
    _roomController.dispose();
    _pcCountController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _mapList(dynamic raw) {
    if (raw is! List) return <Map<String, dynamic>>[];
    return raw.whereType<Map>().map((item) {
      return item.map((key, value) => MapEntry(key.toString(), value));
    }).toList();
  }

  Future<void> _verifyAdmin() async {
    if (_verifying || !(_verifyKey.currentState?.validate() ?? false)) return;

    setState(() {
      _verifying = true;
      _error = null;
    });

    try {
      final response = await TeacherService.instance.loadRoomConfiguration(
        adminEmail: _adminEmailController.text,
        adminPassword: _adminPasswordController.text,
      );
      final teachers = _mapList(response['teachers']);
      final rooms = _mapList(response['rooms']);
      if (teachers.isEmpty) {
        throw Exception(
          'No active Teacher account exists. Create the Teacher account in '
          'the Admin application first.',
        );
      }

      final first = teachers.first;
      final assigned = (first['assigned_room_name'] ?? '').toString().trim();
      Map<String, dynamic>? assignedRoom;
      if (assigned.isNotEmpty) {
        for (final room in rooms) {
          if ((room['room_name'] ?? '').toString().toLowerCase() ==
              assigned.toLowerCase()) {
            assignedRoom = room;
            break;
          }
        }
      }

      if (!mounted) return;
      setState(() {
        _teachers = teachers;
        _rooms = rooms;
        _selectedTeacherUid = (first['uid'] ?? '').toString();
        _verified = true;
        _verifying = false;
        _roomController.text = assigned;
        if (assignedRoom != null) {
          _pcCountController.text =
              (assignedRoom['pc_count'] ?? 40).toString();
        }
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _verifying = false;
        _verified = false;
        _error = cleanError(error);
      });
    }
  }

  void _selectTeacher(String? uid) {
    if (uid == null || uid.isEmpty) return;
    final teacher = _teachers.firstWhere(
      (item) => (item['uid'] ?? '').toString() == uid,
      orElse: () => const <String, dynamic>{},
    );
    final assigned = (teacher['assigned_room_name'] ?? '').toString().trim();
    Map<String, dynamic>? assignedRoom;
    if (assigned.isNotEmpty) {
      for (final room in _rooms) {
        if ((room['room_name'] ?? '').toString().toLowerCase() ==
            assigned.toLowerCase()) {
          assignedRoom = room;
          break;
        }
      }
    }

    setState(() {
      _selectedTeacherUid = uid;
      _roomController.text = assigned;
      if (assignedRoom != null) {
        _pcCountController.text = (assignedRoom['pc_count'] ?? 40).toString();
      }
    });
  }

  void _selectRoom(Map<String, dynamic> room) {
    setState(() {
      _roomController.text = (room['room_name'] ?? '').toString();
      _pcCountController.text = (room['pc_count'] ?? 40).toString();
    });
  }

  Future<void> _save() async {
    if (_saving || !(_saveKey.currentState?.validate() ?? false)) return;
    final uid = (_selectedTeacherUid ?? '').trim();
    if (uid.isEmpty) {
      setState(() => _error = 'Select the Teacher account.');
      return;
    }

    final pcCount = int.tryParse(_pcCountController.text.trim());
    if (pcCount == null || pcCount < 1 || pcCount > 200) {
      setState(() => _error = 'PC count must be from 1 to 200.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      var windowsIdentity =
          TeacherWindowsSessionService.instance.windowsIdentityPayload();
      if (windowsIdentity == null) {
        await TeacherWindowsSessionService.instance.currentAccount();
        windowsIdentity =
            TeacherWindowsSessionService.instance.windowsIdentityPayload();
      }

      await TeacherService.instance.configureRoom(
        adminEmail: _adminEmailController.text,
        adminPassword: _adminPasswordController.text,
        teacherUid: uid,
        roomName: _roomController.text,
        pcCount: pcCount,
        windowsIdentity: windowsIdentity,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = cleanError(error);
      });
    }
  }

  void _resetVerification() {
    if (_saving || _verifying) return;
    setState(() {
      _verified = false;
      _teachers = <Map<String, dynamic>>[];
      _rooms = <Map<String, dynamic>>[];
      _selectedTeacherUid = null;
      _roomController.clear();
      _pcCountController.text = '40';
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      body: Stack(
        children: [
          _ambientBackground(),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: FadeTransition(
                opacity: _fadeAnim,
                child: SlideTransition(
                  position: _slideAnim,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeOut,
                    width: _verified ? 620 : 520,
                    child: _buildCard(),
                  ),
                ),
              ),
            ),
          ),
          const Positioned(
            bottom: 24,
            right: 24,
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
                    _accentA.withValues(alpha: _dark ? 0.12 : 0.08),
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
                    _accentB.withValues(alpha: _dark ? 0.10 : 0.07),
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

  Widget _buildCard() {
    return Container(
      padding: const EdgeInsets.fromLTRB(40, 42, 40, 36),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: _borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: _dark ? 0.55 : 0.10),
            blurRadius: 64,
            offset: const Offset(0, 28),
          ),
        ],
      ),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        child: _verified
            ? _buildConfigurationStep(key: const ValueKey('configuration'))
            : _buildVerificationStep(key: const ValueKey('verification')),
      ),
    );
  }

  Widget _buildVerificationStep({required Key key}) {
    return Column(
      key: key,
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildHeader(
          icon: Icons.admin_panel_settings_rounded,
          title: 'ADMIN VERIFICATION',
          subtitle: 'Sign in with an Admin or Super Admin account\n'
              'to change the Teacher laboratory assignment.',
        ),
        const SizedBox(height: 30),
        if (_error != null) ...[
          _errorPanel(_error!),
          const SizedBox(height: 16),
        ],
        Form(
          key: _verifyKey,
          child: Column(
            children: [
              _buildTextFormField(
                controller: _adminEmailController,
                icon: Icons.shield_outlined,
                label: 'Admin / Super Admin Email',
                hint: 'admin@school.edu',
                keyboardType: TextInputType.emailAddress,
                enabled: !_verifying && !_saving,
                validator: (value) => (value ?? '').trim().isEmpty
                    ? 'Enter the administrator email.'
                    : null,
                onFieldSubmitted: (_) => _verifyAdmin(),
              ),
              const SizedBox(height: 14),
              _buildPasswordField(),
            ],
          ),
        ),
        const SizedBox(height: 28),
        _buildPrimaryButton(
          label: _verifying ? 'Verifying...' : 'Open Teacher Configuration',
          icon: Icons.settings_applications_rounded,
          loading: _verifying,
          onPressed: (_verifying || _saving) ? null : _verifyAdmin,
        ),
        const SizedBox(height: 16),
        _buildBackButton('Cancel', () => Navigator.of(context).pop(false)),
      ],
    );
  }

  Widget _buildConfigurationStep({required Key key}) {
    return Form(
      key: _saveKey,
      child: Column(
        key: key,
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHeader(
            icon: Icons.meeting_room_rounded,
            title: 'TEACHER ROOM CONFIGURATION',
            subtitle: 'Assign the shared Teacher account to its laboratory\n'
                'and configure how many PC slots the room contains.',
          ),
          const SizedBox(height: 26),
          _verifiedBanner(),
          if (_error != null) ...[
            const SizedBox(height: 14),
            _errorPanel(_error!),
          ],
          const SizedBox(height: 24),
          _sectionLabel('Teacher Account'),
          const SizedBox(height: 10),
          _buildTeacherDropdown(),
          const SizedBox(height: 26),
          Divider(
            color: _textColor.withValues(alpha: 0.07),
            thickness: 1,
          ),
          const SizedBox(height: 22),
          _sectionLabel('Laboratory Assignment'),
          const SizedBox(height: 10),
          _buildTextFormField(
            controller: _roomController,
            icon: Icons.meeting_room_rounded,
            label: 'Room Name',
            hint: '706',
            enabled: !_saving,
            validator: (value) => (value ?? '').trim().isEmpty
                ? 'Enter the laboratory room.'
                : null,
          ),
          if (_rooms.isNotEmpty) ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'EXISTING ROOMS',
                style: TextStyle(
                  color: _textColor.withValues(alpha: 0.28),
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.0,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _rooms.map(_buildRoomChip).toList(),
              ),
            ),
          ],
          const SizedBox(height: 14),
          _buildTextFormField(
            controller: _pcCountController,
            icon: Icons.computer_rounded,
            label: 'PC Count',
            hint: '40',
            enabled: !_saving,
            keyboardType: TextInputType.number,
            validator: (value) {
              final count = int.tryParse((value ?? '').trim());
              if (count == null || count < 1 || count > 200) {
                return 'Enter a PC count from 1 to 200.';
              }
              return null;
            },
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'PC Count is used by the Teacher Lab Map. Allowed range: 1–200.',
              style: TextStyle(
                color: _textColor.withValues(alpha: 0.35),
                fontSize: 11.5,
                height: 1.4,
              ),
            ),
          ),
          const SizedBox(height: 28),
          _buildPrimaryButton(
            label: _saving ? 'Saving...' : 'Save Teacher Room',
            icon: Icons.save_rounded,
            loading: _saving,
            onPressed: _saving ? null : _save,
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton.icon(
                onPressed: _saving ? null : _resetVerification,
                icon: Icon(
                  Icons.verified_user_outlined,
                  size: 16,
                  color: _textColor.withValues(alpha: 0.35),
                ),
                label: Text(
                  'Verify another admin',
                  style: TextStyle(
                    color: _textColor.withValues(alpha: 0.35),
                    fontSize: 12.5,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              TextButton.icon(
                onPressed: _saving
                    ? null
                    : () => Navigator.of(context).pop(false),
                icon: Icon(
                  Icons.close_rounded,
                  size: 16,
                  color: _textColor.withValues(alpha: 0.35),
                ),
                label: Text(
                  'Cancel',
                  style: TextStyle(
                    color: _textColor.withValues(alpha: 0.35),
                    fontSize: 12.5,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeader({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Column(
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _accentA.withValues(alpha: 0.15),
            border: Border.all(
              color: _accentA.withValues(alpha: 0.40),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: _accentA.withValues(alpha: 0.12),
                blurRadius: 20,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Icon(icon, color: _accentA, size: 34),
        ),
        const SizedBox(height: 18),
        Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: _accentA,
            fontSize: 20,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: _textColor.withValues(alpha: 0.42),
            fontSize: 13,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
          decoration: BoxDecoration(
            color: _accentA.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _accentA.withValues(alpha: 0.18)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.keyboard_rounded, size: 14, color: _accentA),
              const SizedBox(width: 6),
              Text(
                'Ctrl + Shift + A',
                style: TextStyle(
                  color: _accentA,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _verifiedBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: _successColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: _successColor.withValues(alpha: 0.26)),
      ),
      child: Row(
        children: [
          Icon(Icons.verified_user_rounded, color: _successColor, size: 19),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Administrator verified. Teacher room settings are unlocked.',
              style: TextStyle(
                color: _textColor,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _errorPanel(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: _errorColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: _errorColor.withValues(alpha: 0.28)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline_rounded, color: _errorColor, size: 19),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: _textColor,
                fontSize: 12.5,
                height: 1.4,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          color: _textColor.withValues(alpha: 0.35),
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildTextFormField({
    required TextEditingController controller,
    required IconData icon,
    required String label,
    String? hint,
    bool enabled = true,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    ValueChanged<String>? onFieldSubmitted,
  }) {
    return _TeacherConfigFieldShell(
      fieldColor: _fieldColor,
      borderColor: _borderColor,
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Icon(
              icon,
              color: enabled
                  ? _accentA.withValues(alpha: 0.75)
                  : _textColor.withValues(alpha: 0.25),
              size: 18,
            ),
          ),
          Expanded(
            child: TextFormField(
              controller: controller,
              enabled: enabled,
              keyboardType: keyboardType,
              validator: validator,
              onFieldSubmitted: onFieldSubmitted,
              style: TextStyle(color: _textColor, fontSize: 14.5),
              decoration: InputDecoration(
                hintText: hint ?? label,
                hintStyle: TextStyle(color: _hintColor, fontSize: 14),
                labelText: label,
                labelStyle: TextStyle(
                  color: _textColor.withValues(alpha: 0.40),
                  fontSize: 13,
                ),
                floatingLabelStyle: TextStyle(
                  color: _accentA.withValues(alpha: 0.80),
                  fontSize: 12,
                ),
                border: InputBorder.none,
                errorBorder: InputBorder.none,
                focusedErrorBorder: InputBorder.none,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 4, vertical: 14),
                errorStyle: TextStyle(color: _errorColor, fontSize: 11),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPasswordField() {
    return _TeacherConfigFieldShell(
      fieldColor: _fieldColor,
      borderColor: _borderColor,
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Icon(
              Icons.lock_outline_rounded,
              color: _accentA.withValues(alpha: 0.75),
              size: 18,
            ),
          ),
          Expanded(
            child: TextFormField(
              controller: _adminPasswordController,
              enabled: !_verifying && !_saving,
              obscureText: !_passwordVisible,
              validator: (value) => (value ?? '').isEmpty
                  ? 'Enter the administrator password.'
                  : null,
              onFieldSubmitted: (_) => _verifyAdmin(),
              style: TextStyle(color: _textColor, fontSize: 14.5),
              decoration: InputDecoration(
                hintText: 'Password',
                hintStyle: TextStyle(color: _hintColor, fontSize: 14),
                labelText: 'Password',
                labelStyle: TextStyle(
                  color: _textColor.withValues(alpha: 0.40),
                  fontSize: 13,
                ),
                floatingLabelStyle: TextStyle(
                  color: _accentA.withValues(alpha: 0.80),
                  fontSize: 12,
                ),
                border: InputBorder.none,
                errorBorder: InputBorder.none,
                focusedErrorBorder: InputBorder.none,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 4, vertical: 14),
                errorStyle: TextStyle(color: _errorColor, fontSize: 11),
              ),
            ),
          ),
          IconButton(
            tooltip: _passwordVisible ? 'Hide password' : 'Show password',
            onPressed: (_verifying || _saving)
                ? null
                : () => setState(() => _passwordVisible = !_passwordVisible),
            icon: Icon(
              _passwordVisible
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined,
              color: _textColor.withValues(alpha: 0.30),
              size: 18,
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
    );
  }

  Widget _buildTeacherDropdown() {
    return _TeacherConfigFieldShell(
      fieldColor: _fieldColor,
      borderColor: _borderColor,
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Icon(
              Icons.school_rounded,
              color: _accentA.withValues(alpha: 0.75),
              size: 18,
            ),
          ),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedTeacherUid,
                isExpanded: true,
                dropdownColor: _cardColor,
                borderRadius: BorderRadius.circular(14),
                icon: Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: _textColor.withValues(alpha: 0.40),
                ),
                style: TextStyle(color: _textColor, fontSize: 14),
                items: _teachers.map((teacher) {
                  final uid = (teacher['uid'] ?? '').toString();
                  final name =
                      (teacher['display_name'] ?? 'Teacher').toString();
                  final email = (teacher['email'] ?? '').toString();
                  final room =
                      (teacher['assigned_room_name'] ?? '').toString().trim();
                  return DropdownMenuItem<String>(
                    value: uid,
                    child: Text(
                      room.isEmpty
                          ? '$name · $email'
                          : '$name · $email · Room $room',
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
                onChanged: _saving ? null : _selectTeacher,
              ),
            ),
          ),
          const SizedBox(width: 12),
        ],
      ),
    );
  }

  Widget _buildRoomChip(Map<String, dynamic> room) {
    final roomName = (room['room_name'] ?? '').toString();
    final pcCount = (room['pc_count'] ?? 0).toString();
    final active = room['active'] == true ||
        room['active'] == 1 ||
        room['active'].toString() == '1';
    final selected =
        _roomController.text.trim().toLowerCase() == roomName.toLowerCase();
    final color = selected ? _accentA : (active ? _accentA : _hintColor);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _saving ? null : () => _selectRoom(room),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
          decoration: BoxDecoration(
            color: selected
                ? _accentA.withValues(alpha: 0.12)
                : _fieldColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected
                  ? _accentA.withValues(alpha: 0.45)
                  : _borderColor,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.meeting_room_rounded, size: 16, color: color),
              const SizedBox(width: 7),
              Text(
                '$roomName · $pcCount PCs${active ? '' : ' · inactive'}',
                style: TextStyle(
                  color: selected ? _accentA : _textColor,
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPrimaryButton({
    required String label,
    required IconData icon,
    required bool loading,
    required VoidCallback? onPressed,
  }) {
    return SizedBox(
      height: 50,
      width: double.infinity,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: onPressed == null ? null : _accentA,
          borderRadius: BorderRadius.circular(14),
          boxShadow: onPressed == null
              ? null
              : [
                  BoxShadow(
                    color: _accentA.withValues(alpha: 0.28),
                    blurRadius: 16,
                    offset: const Offset(0, 5),
                  ),
                ],
        ),
        child: ElevatedButton.icon(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor:
                onPressed == null ? _fieldColor : Colors.transparent,
            shadowColor: Colors.transparent,
            foregroundColor: onPressed == null
                ? _textColor.withValues(alpha: 0.40)
                : (_dark ? const Color(0xFF080A0E) : Colors.white),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          icon: loading
              ? SizedBox(
                  width: 17,
                  height: 17,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: _textColor.withValues(alpha: 0.40),
                  ),
                )
              : Icon(icon, size: 19),
          label: Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 14.5,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBackButton(String label, VoidCallback onPressed) {
    return TextButton.icon(
      onPressed: (_saving || _verifying) ? null : onPressed,
      icon: Icon(
        Icons.arrow_back_rounded,
        size: 16,
        color: _textColor.withValues(alpha: 0.35),
      ),
      label: Text(
        label,
        style: TextStyle(
          color: _textColor.withValues(alpha: 0.35),
          fontSize: 13,
        ),
      ),
      style: TextButton.styleFrom(splashFactory: NoSplash.splashFactory),
    );
  }
}

class _TeacherConfigFieldShell extends StatelessWidget {
  final Color fieldColor;
  final Color borderColor;
  final Widget child;

  const _TeacherConfigFieldShell({
    required this.fieldColor,
    required this.borderColor,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: fieldColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      child: child,
    );
  }
}
