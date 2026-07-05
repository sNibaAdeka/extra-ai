import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../app/app_state.dart';
import '../../models/product_health_report.dart';
import '../../models/subscription_state.dart';
import '../../models/user_profile.dart';
import '../../theme/app_theme.dart';
import '../../widgets/controls.dart';
import '../../widgets/hotkey_capture.dart';
import '../../widgets/shimmer_text.dart';

/// Screens 8–13 — Settings modal: left nav (SETTINGS / ACCOUNT sections) +
/// right content area. Escape closes from any tab (wired by the shell).
class SettingsModal extends StatefulWidget {
  const SettingsModal({super.key, required this.state});

  final AppState state;

  @override
  State<SettingsModal> createState() => _SettingsModalState();
}

class _SettingsModalState extends State<SettingsModal> {
  static const _appVersion = '0.1.0';

  AppState get state => widget.state;

  /// Previous tab position — content slides toward the newly selected tab
  /// (down the nav = slides up from below, and vice versa).
  int _lastTabIndex = 0;

  @override
  Widget build(BuildContext context) {
    final tab = state.settingsTab;
    final tabIndex = SettingsTab.values.indexOf(tab);
    final direction = tabIndex >= _lastTabIndex ? 1.0 : -1.0;
    _lastTabIndex = tabIndex;
    return Container(
      width: 780,
      height: 560,
      decoration: BoxDecoration(
        color: AppTheme.bgVoid,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderSubtle),
        boxShadow: const [
          BoxShadow(
            color: Color(0x88000000),
            blurRadius: 60,
            offset: Offset(0, 24),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _nav(),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        switchInCurve: AppTheme.easeOut,
                        switchOutCurve: AppTheme.easeOut,
                        layoutBuilder: (current, previous) => Stack(
                          alignment: Alignment.centerLeft,
                          children: [...previous, ?current],
                        ),
                        child: Text(
                          _tabTitle(tab),
                          key: ValueKey(tab),
                          style: AppTheme.display(
                            size: 22,
                            weight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Tooltip(
                        message: 'Close (Esc)',
                        child: PressableScale(
                          onTap: state.closeSettings,
                          child: Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: AppTheme.borderSubtle),
                            ),
                            child: const Icon(
                              Icons.close,
                              size: 14,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 240),
                      switchInCurve: AppTheme.easeOut,
                      switchOutCurve: AppTheme.easeOut,
                      layoutBuilder: (current, previous) => Stack(
                        alignment: Alignment.topLeft,
                        children: [...previous, ?current],
                      ),
                      transitionBuilder: (child, animation) => FadeTransition(
                        opacity: animation,
                        child: SlideTransition(
                          position: Tween<Offset>(
                            begin: Offset(0, 0.02 * direction),
                            end: Offset.zero,
                          ).animate(animation),
                          child: child,
                        ),
                      ),
                      child: SingleChildScrollView(
                        key: ValueKey(tab),
                        child: _tabBody(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _tabTitle(SettingsTab tab) {
    switch (tab) {
      case SettingsTab.general:
        return 'General';
      case SettingsTab.shortcuts:
        return 'Shortcuts';
      case SettingsTab.profile:
        return 'Profile';
      case SettingsTab.plans:
        return 'Plans & Billing';
      case SettingsTab.privacy:
        return 'Data & Privacy';
      case SettingsTab.updates:
        return 'Updates';
    }
  }

  Widget _nav() {
    return Container(
      width: 200,
      padding: const EdgeInsets.all(14),
      decoration: const BoxDecoration(
        border: Border(right: BorderSide(color: AppTheme.borderSubtle)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('SETTINGS', style: AppTheme.sectionLabel()),
          const SizedBox(height: 8),
          _navItem(SettingsTab.general, Icons.tune, 'General'),
          _navItem(SettingsTab.shortcuts, Icons.keyboard_outlined, 'Shortcuts'),
          const SizedBox(height: 16),
          Text('ACCOUNT', style: AppTheme.sectionLabel()),
          const SizedBox(height: 8),
          _navItem(SettingsTab.profile, Icons.person_outline, 'Profile'),
          _navItem(
            SettingsTab.plans,
            Icons.workspace_premium_outlined,
            'Plans & Billing',
          ),
          _navItem(
            SettingsTab.privacy,
            Icons.shield_outlined,
            'Data & Privacy',
          ),
          _navItem(SettingsTab.updates, Icons.sync, 'Updates'),
          const Spacer(),
          Text(
            'Extra AI v$_appVersion',
            style: AppTheme.ui(size: 11, color: AppTheme.textDim),
          ),
        ],
      ),
    );
  }

  Widget _navItem(SettingsTab tab, IconData icon, String label) {
    final active = state.settingsTab == tab;
    return PressableScale(
      onTap: () => state.setSettingsTab(tab),
      child: Container(
        margin: const EdgeInsets.only(bottom: 2),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: active ? AppTheme.surfaceHigh : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 15,
              color: active ? AppTheme.accent : AppTheme.textDim,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: AppTheme.ui(
                size: 13,
                weight: active ? FontWeight.w600 : FontWeight.w400,
                color: active ? AppTheme.textPrimary : AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tabBody() {
    switch (state.settingsTab) {
      case SettingsTab.general:
        return _GeneralTab(state: state);
      case SettingsTab.shortcuts:
        return _ShortcutsTab(state: state);
      case SettingsTab.profile:
        return _ProfileTab(state: state);
      case SettingsTab.plans:
        return _PlansTab(state: state);
      case SettingsTab.privacy:
        return _PrivacyTab(state: state);
      case SettingsTab.updates:
        return const _UpdatesTab();
    }
  }
}

// -----------------------------------------------------------------------------
// Shared card row used across tabs.
// -----------------------------------------------------------------------------

class _SettingCard extends StatelessWidget {
  const _SettingCard({
    required this.title,
    this.subtitle,
    required this.trailing,
    this.tag,
  });

  final String title;
  final String? subtitle;
  final Widget trailing;
  final Widget? tag;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.card(radius: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      title,
                      style: AppTheme.ui(size: 14, weight: FontWeight.w600),
                    ),
                    if (tag != null) ...[const SizedBox(width: 8), tag!],
                  ],
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    subtitle!,
                    style: AppTheme.ui(
                      size: 12.5,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 16),
          trailing,
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Screen 8 — General.
// -----------------------------------------------------------------------------

class _GeneralTab extends StatefulWidget {
  const _GeneralTab({required this.state});
  final AppState state;

  @override
  State<_GeneralTab> createState() => _GeneralTabState();
}

class _GeneralTabState extends State<_GeneralTab> {
  @override
  Widget build(BuildContext context) {
    final s = widget.state.settings!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SettingCard(
          title: 'Theme',
          trailing: SegmentedControl<String>(
            options: const ['system', 'light', 'dark'],
            labels: const ['System', 'Light', 'Dark'],
            value: s.themeMode,
            onChanged: (v) async {
              await s.setThemeMode(v);
              setState(() {});
            },
          ),
        ),
        _SettingCard(
          title: 'Launch at login',
          trailing: EmberToggle(
            value: s.launchAtLogin,
            onChanged: (v) async {
              await s.setLaunchAtLogin(v);
              setState(() {});
            },
          ),
        ),
        _SettingCard(
          title: 'History retention',
          trailing: _RetentionDropdown(
            value: s.historyRetention,
            onChanged: (v) async {
              await s.setHistoryRetention(v);
              setState(() {});
            },
          ),
        ),
        const SizedBox(height: 4),
        Text('EXPERIMENTAL', style: AppTheme.sectionLabel()),
        const SizedBox(height: 10),
        _SettingCard(
          title: 'Visual grounding',
          tag: const PillTag('EXPERIMENTAL'),
          subtitle: 'Annotates screenshots when it finds an issue',
          trailing: EmberToggle(
            value: s.visualGrounding,
            onChanged: (v) async {
              await s.setVisualGrounding(v);
              setState(() {});
            },
          ),
        ),
        _SettingCard(
          title: 'Auto-detect stack',
          trailing: EmberToggle(
            value: s.autoDetectStack,
            onChanged: (v) async {
              await s.setAutoDetectStack(v);
              setState(() {});
            },
          ),
        ),
        _SettingCard(
          title: 'Stealth mode',
          subtitle: 'Hidden from screen sharing and recordings',
          trailing: EmberToggle(
            value: s.stealthMode,
            onChanged: (v) async {
              await s.setStealthMode(v);
              setState(() {});
            },
          ),
        ),
      ],
    );
  }
}

class _RetentionDropdown extends StatelessWidget {
  const _RetentionDropdown({required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String> onChanged;

  static const _labels = {
    '30d': '30 days',
    '90d': '90 days',
    'forever': 'Forever',
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.borderSubtle),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          dropdownColor: AppTheme.surfaceHigh,
          style: AppTheme.ui(size: 13, color: AppTheme.textPrimary),
          iconEnabledColor: AppTheme.textDim,
          items: [
            for (final e in _labels.entries)
              DropdownMenuItem(value: e.key, child: Text(e.value)),
          ],
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Screen 9 — Shortcuts.
// -----------------------------------------------------------------------------

class _ShortcutsTab extends StatefulWidget {
  const _ShortcutsTab({required this.state});
  final AppState state;

  @override
  State<_ShortcutsTab> createState() => _ShortcutsTabState();
}

class _ShortcutsTabState extends State<_ShortcutsTab> {
  bool _capturing = false;

  @override
  Widget build(BuildContext context) {
    final s = widget.state.settings!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: AppTheme.card(radius: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Analysis hotkey',
                style: AppTheme.ui(size: 14, weight: FontWeight.w600),
              ),
              const SizedBox(height: 10),
              KeycapBadge.combo(s.hotkeyCombo),
              const SizedBox(height: 12),
              if (_capturing)
                HotkeyCapture(
                  onCaptured: (combo) async {
                    await s.setHotkeyCombo(combo);
                    setState(() => _capturing = false);
                  },
                )
              else
                SizedBox(
                  width: 110,
                  child: GhostButtonSmall(
                    label: 'Change',
                    onTap: () => setState(() => _capturing = true),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: AppTheme.card(radius: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Quick template hotkeys',
                style: AppTheme.ui(size: 14, weight: FontWeight.w600),
              ),
              const SizedBox(height: 3),
              PressableScale(
                onTap: () {
                  widget.state.closeSettings();
                  widget.state.showHome(ShellSection.templates);
                },
                child: Text(
                  'Manage individual template shortcuts in Quick Templates',
                  style: AppTheme.ui(size: 12.5, color: AppTheme.accent),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Compact outlined button used inside settings cards.
class GhostButtonSmall extends StatelessWidget {
  const GhostButtonSmall({super.key, required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.borderSubtle),
        ),
        child: Text(
          label,
          style: AppTheme.ui(size: 13, color: AppTheme.textSecondary),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Screen 10 — Profile.
// -----------------------------------------------------------------------------

class _ProfileTab extends StatefulWidget {
  const _ProfileTab({required this.state});
  final AppState state;

  @override
  State<_ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<_ProfileTab> {
  late final TextEditingController _first;
  late final TextEditingController _last;
  bool _nameDirty = false;
  bool _showSaved = false;
  bool _pickingColor = false;

  static const _toolChoices = [
    'Cursor',
    'Windsurf',
    'Claude Code',
    'Codex',
    'v0',
    'GitHub Copilot',
    'Other', //
  ];
  static const _avatarColors = [
    0xFFFF6B35, 0xFFD94F1E, 0xFF6B3620, 0xFFE8B98A, 0xFF7A5CFA, 0xFF3D7EFF, //
  ];

  @override
  void initState() {
    super.initState();
    final s = widget.state.settings!;
    _first = TextEditingController(text: s.firstName)
      ..addListener(() => setState(() => _nameDirty = true));
    _last = TextEditingController(text: s.lastName)
      ..addListener(() => setState(() => _nameDirty = true));
  }

  @override
  void dispose() {
    _first.dispose();
    _last.dispose();
    super.dispose();
  }

  Future<void> _saveProfile(UserProfile updated) async {
    await widget.state.saveProfile(updated);
    setState(() => _showSaved = true);
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (mounted) setState(() => _showSaved = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.state.settings!;
    final profile = widget.state.profile;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Profile header + name fields.
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: AppTheme.card(radius: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Tooltip(
                    message: 'Change avatar color',
                    child: PressableScale(
                      onTap: () =>
                          setState(() => _pickingColor = !_pickingColor),
                      child: CircleAvatar(
                        radius: 18,
                        backgroundColor: Color(s.avatarColor),
                        child: Text(
                          s.initials,
                          style: AppTheme.ui(
                            size: 13,
                            weight: FontWeight.w700,
                            color: AppTheme.onAccent,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Profile',
                    style: AppTheme.ui(size: 14, weight: FontWeight.w600),
                  ),
                  if (_showSaved) ...[
                    const SizedBox(width: 10),
                    Text(
                      'Saved',
                      style: AppTheme.ui(size: 12, color: AppTheme.accent),
                    ),
                  ],
                ],
              ),
              if (_pickingColor) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    for (final c in _avatarColors)
                      PressableScale(
                        onTap: () async {
                          await s.setAvatarColor(c);
                          setState(() => _pickingColor = false);
                        },
                        child: Container(
                          width: 22,
                          height: 22,
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                            color: Color(c),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: s.avatarColor == c
                                  ? AppTheme.textPrimary
                                  : Colors.transparent,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(child: _nameField('First name', _first)),
                  const SizedBox(width: 12),
                  Expanded(child: _nameField('Last name', _last)),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: 120,
                child: Opacity(
                  opacity: _nameDirty ? 1 : 0.5,
                  child: GhostButtonSmall(
                    label: 'Save name',
                    onTap: () async {
                      if (!_nameDirty) return;
                      await s.setName(_first.text.trim(), _last.text.trim());
                      setState(() {
                        _nameDirty = false;
                        _showSaved = true;
                      });
                      Future.delayed(const Duration(milliseconds: 1200), () {
                        if (mounted) setState(() => _showSaved = false);
                      });
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),

        // Preference chips — auto-save on change.
        if (profile != null) ...[
          _prefGroup(
            'Experience level',
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final e in ExperienceLevel.values)
                  SelectChip(
                    label: e.label,
                    selected: profile.experienceLevel == e,
                    onTap: () =>
                        _saveProfile(profile.copyWith(experienceLevel: e)),
                  ),
              ],
            ),
          ),
          _prefGroup(
            'Primary tools',
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final t in _toolChoices)
                  SelectChip(
                    label: t,
                    selected: profile.primaryTools.contains(t),
                    onTap: () {
                      final tools = profile.primaryTools.toSet();
                      tools.contains(t) ? tools.remove(t) : tools.add(t);
                      if (tools.isEmpty) return; // at least one required
                      _saveProfile(
                        profile.copyWith(primaryTools: tools.toList()),
                      );
                    },
                  ),
              ],
            ),
          ),
          _prefGroup(
            'What you build',
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final f in ProjectFocus.values)
                  SelectChip(
                    label: f.label,
                    selected: profile.projectFocus == f,
                    onTap: () =>
                        _saveProfile(profile.copyWith(projectFocus: f)),
                  ),
              ],
            ),
          ),
          _prefGroup(
            'Tone preference',
            SegmentedControl<ToneLevel>(
              options: ToneLevel.values,
              labels: const ['Just the facts', 'Explain a bit'],
              value: profile.tonePreference,
              onChanged: (v) =>
                  _saveProfile(profile.copyWith(tonePreference: v)),
            ),
          ),
          const SizedBox(height: 6),
        ],

        _SettingCard(
          title: 'Email',
          subtitle: 'adyoka.sars@gmail.com',
          trailing: const SizedBox.shrink(),
        ),
        _SettingCard(
          title: 'Password',
          subtitle: 'Change the password used to sign in.',
          trailing: GhostButtonSmall(label: 'Change password', onTap: () {}),
        ),
        _SettingCard(
          title: 'Sign out',
          subtitle: 'Your local history stays on this device',
          trailing: GhostButtonSmall(
            label: 'Sign out',
            onTap: () => widget.state.onSignOut?.call(),
          ),
        ),
      ],
    );
  }

  Widget _nameField(String label, TextEditingController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTheme.ui(size: 12, color: AppTheme.textDim)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          style: AppTheme.ui(size: 13),
          cursorColor: AppTheme.accent,
          decoration: InputDecoration(
            isDense: true,
            filled: true,
            fillColor: AppTheme.bgVoid.withValues(alpha: 0.5),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 10,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppTheme.borderSubtle),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppTheme.borderFocus),
            ),
          ),
        ),
      ],
    );
  }

  Widget _prefGroup(String label, Widget child) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTheme.ui(size: 13, weight: FontWeight.w600)),
        const SizedBox(height: 8),
        child,
      ],
    ),
  );
}

// -----------------------------------------------------------------------------
// Screen 11 — Plans & Billing.
// -----------------------------------------------------------------------------

class _PlansTab extends StatefulWidget {
  const _PlansTab({required this.state});

  final AppState state;

  @override
  State<_PlansTab> createState() => _PlansTabState();
}

class _PlansTabState extends State<_PlansTab> {
  bool _annual = false;
  final TextEditingController _promo = TextEditingController();
  bool _redeeming = false;
  String? _promoError;

  @override
  void dispose() {
    _promo.dispose();
    super.dispose();
  }

  void _selectPlan(PlanTier tier) {
    widget.state.selectPlan(tier).then((_) {
      if (mounted) setState(() {});
    });
  }

  Future<void> _redeemPromo() async {
    final code = _promo.text;
    if (code.trim().isEmpty) return;
    setState(() {
      _redeeming = true;
      _promoError = null;
    });
    final result = await widget.state.redeemPromoCode(code);
    if (!mounted) return;
    setState(() {
      _redeeming = false;
      if (result.accepted) {
        _promo.clear();
        _promoError = null;
      } else {
        _promoError = result.message ?? "That code isn't valid.";
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final subscription = widget.state.subscriptionState;
    return Column(
      children: [
        _BillingStatusCard(subscription: subscription),
        if (subscription.isUnlimited) ...[
          const SizedBox(height: 12),
          const _AdminModeBanner(),
        ],
        const SizedBox(height: 16),
        Center(
          child: SegmentedControl<bool>(
            options: const [false, true],
            labels: const ['Monthly', 'Annual'],
            value: _annual,
            onChanged: (v) => setState(() => _annual = v),
          ),
        ),
        const SizedBox(height: 18),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _PlanCard(
                subtitle: 'For trying it out',
                title: 'Free',
                price: '\$0',
                current: subscription.tier == PlanTier.free,
                features: const [
                  '5 analyses per month',
                  'Works with any Code AI tool',
                  'Basic prompt grounding',
                ],
                footer: _PlanAction(
                  label: subscription.tier == PlanTier.free
                      ? 'Current plan'
                      : 'Switch to Free',
                  filled: false,
                  disabled: subscription.tier == PlanTier.free,
                  onTap: () => _selectPlan(PlanTier.free),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _PlanCard(
                subtitle: 'For freelancers',
                title: 'Pro',
                price: _annual ? '\$90 per year' : '\$9 per month',
                popular: true,
                current: subscription.tier == PlanTier.pro,
                features: const [
                  '200 analyses/month fair use',
                  '1 active project with memory',
                  'Tool-specific formatting',
                  'Full history & favorites',
                ],
                footer: _PlanAction(
                  label: subscription.tier == PlanTier.pro
                      ? 'Current plan'
                      : 'Select Pro',
                  filled: subscription.tier != PlanTier.pro,
                  disabled: subscription.tier == PlanTier.pro,
                  onTap: () => _selectPlan(PlanTier.pro),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _PlanCard(
                subtitle: 'For teams',
                title: 'Studio',
                price: _annual ? '\$290 per year' : '\$29 per month',
                current: subscription.tier == PlanTier.studio,
                features: const [
                  '500 analyses/month fair use',
                  'Up to 5 projects',
                  'Security & issue detection included',
                  'Team sharing ready',
                ],
                footer: _PlanAction(
                  label: subscription.tier == PlanTier.studio
                      ? 'Current plan'
                      : 'Select Studio',
                  filled: false,
                  disabled: subscription.tier == PlanTier.studio,
                  onTap: () => _selectPlan(PlanTier.studio),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        _PromoCodeField(
          controller: _promo,
          busy: _redeeming,
          error: _promoError,
          onRedeem: _redeemPromo,
        ),
      ],
    );
  }
}

class _AdminModeBanner extends StatelessWidget {
  const _AdminModeBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        gradient: AppTheme.brandGradient,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.all_inclusive, size: 18, color: AppTheme.onAccent),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Admin mode active',
                  style: AppTheme.ui(
                    size: 13.5,
                    weight: FontWeight.w700,
                    color: AppTheme.onAccent,
                  ),
                ),
                Text(
                  'Unlimited analyses and projects. No monthly cap.',
                  style: AppTheme.ui(
                    size: 12,
                    color: AppTheme.onAccent.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PromoCodeField extends StatelessWidget {
  const _PromoCodeField({
    required this.controller,
    required this.busy,
    required this.error,
    required this.onRedeem,
  });

  final TextEditingController controller;
  final bool busy;
  final String? error;
  final VoidCallback onRedeem;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('PROMO CODE', style: AppTheme.sectionLabel()),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Container(
                height: 40,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceHigh,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: error == null
                        ? AppTheme.borderSubtle
                        : AppTheme.signalRed,
                  ),
                ),
                alignment: Alignment.centerLeft,
                child: TextField(
                  controller: controller,
                  onSubmitted: (_) => onRedeem(),
                  textCapitalization: TextCapitalization.characters,
                  style: AppTheme.mono(size: 13, color: AppTheme.textPrimary),
                  cursorColor: AppTheme.accent,
                  decoration: InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    hintText: 'Enter code',
                    hintStyle: AppTheme.mono(size: 13, color: AppTheme.textDim),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            PressableScale(
              onTap: busy ? () {} : onRedeem,
              child: Opacity(
                opacity: busy ? 0.6 : 1,
                child: Container(
                  height: 40,
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: AppTheme.brandGradient,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: busy
                      ? const SizedBox(
                          width: 15,
                          height: 15,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation(
                              AppTheme.onAccent,
                            ),
                          ),
                        )
                      : Text(
                          'Redeem',
                          style: AppTheme.ui(
                            size: 13,
                            weight: FontWeight.w700,
                            color: AppTheme.onAccent,
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
        if (error != null) ...[
          const SizedBox(height: 6),
          Text(
            error!,
            style: AppTheme.ui(size: 12, color: AppTheme.signalRed),
          ),
        ],
      ],
    );
  }
}

class _BillingStatusCard extends StatelessWidget {
  const _BillingStatusCard({required this.subscription});

  final SubscriptionState subscription;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: AppTheme.card(radius: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.workspace_premium_outlined,
                size: 17,
                color: AppTheme.accent,
              ),
              const SizedBox(width: 8),
              Text(
                subscription.headline,
                style: AppTheme.ui(size: 14, weight: FontWeight.w700),
              ),
              const Spacer(),
              Text(
                '${subscription.remainingAnalyses} left',
                style: AppTheme.ui(size: 12, color: AppTheme.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              minHeight: 6,
              value: subscription.usageRatio,
              backgroundColor: AppTheme.textDim.withValues(alpha: 0.16),
              valueColor: const AlwaysStoppedAnimation(AppTheme.accent),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlanAction extends StatelessWidget {
  const _PlanAction({
    required this.label,
    required this.onTap,
    this.filled = false,
    this.disabled = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool filled;
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: disabled ? 0.62 : 1,
      child: PressableScale(
        onTap: disabled ? () {} : onTap,
        child: Container(
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: filled ? AppTheme.brandGradient : null,
            borderRadius: BorderRadius.circular(10),
            border: filled ? null : Border.all(color: AppTheme.borderSubtle),
          ),
          child: Text(
            label,
            style: AppTheme.ui(
              size: 13,
              weight: FontWeight.w600,
              color: filled ? AppTheme.onAccent : AppTheme.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.subtitle,
    required this.title,
    required this.price,
    required this.features,
    required this.footer,
    this.popular = false,
    this.current = false,
  });

  final String subtitle;
  final String title;
  final String price;
  final List<String> features;
  final Widget footer;
  final bool popular;
  final bool current;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: current || popular
              ? AppTheme.borderFocus
              : AppTheme.borderSubtle,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  subtitle,
                  style: AppTheme.ui(size: 11, color: AppTheme.textDim),
                ),
              ),
              if (current)
                const PillTag('Current', filled: true)
              else if (popular)
                const PillTag('Most popular', filled: true),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            title,
            style: AppTheme.display(size: 22, weight: FontWeight.w700),
          ),
          if (popular)
            IridescentText(
              price,
              style: AppTheme.ui(size: 13, weight: FontWeight.w700),
            )
          else
            Text(
              price,
              style: AppTheme.ui(size: 13, color: AppTheme.textSecondary),
            ),
          const SizedBox(height: 12),
          for (final f in features)
            Padding(
              padding: const EdgeInsets.only(bottom: 7),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 2),
                    child: Icon(Icons.check, size: 13, color: AppTheme.accent),
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      f,
                      style: AppTheme.ui(size: 12, color: AppTheme.textPrimary),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 10),
          footer,
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Screen 12 — Data & Privacy.
// -----------------------------------------------------------------------------

class _PrivacyTab extends StatelessWidget {
  const _PrivacyTab({required this.state});
  final AppState state;

  Future<void> _exportJson(BuildContext context) async {
    final entries = state.allHistory();
    final json = const JsonEncoder.withIndent(
      '  ',
    ).convert(entries.map((e) => e.toMap()).toList());
    final path = await FilePicker.platform.saveFile(
      dialogTitle: 'Export analysis history',
      fileName: 'extra-ai-history.json',
    );
    if (path == null) return;
    await File(path).writeAsString(json);
  }

  Future<void> _confirmClear(BuildContext context) async {
    final n = state.allHistory().length;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceHigh,
        title: Text(
          'Are you sure?',
          style: AppTheme.ui(size: 15, weight: FontWeight.w600),
        ),
        content: Text(
          'This will delete all $n stored analyses. This cannot be undone.',
          style: AppTheme.ui(size: 13, color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancel',
              style: AppTheme.ui(size: 13, color: AppTheme.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'Clear All',
              style: AppTheme.ui(size: 13, color: AppTheme.signalRed),
            ),
          ),
        ],
      ),
    );
    if (ok == true) await state.clearAllHistory();
  }

  @override
  Widget build(BuildContext context) {
    final count = state.allHistory().length;
    final sync = state.syncOutboxSummary;
    final report = state.productHealthReport;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ProductHealthSettingsCard(report: report),
        _SettingCard(
          title: 'Cloud sync queue',
          subtitle:
              '${sync.label} · ${sync.total} safe metadata events stored locally',
          trailing: GhostButtonSmall(
            label: sync.pending > 0 ? 'Flush local queue' : 'Ready',
            onTap: () {
              state.flushSyncOutbox();
            },
          ),
        ),
        _SettingCard(
          title: 'Export history',
          subtitle: '$count entries stored locally',
          trailing: GhostButtonSmall(
            label: 'Export JSON',
            onTap: () => _exportJson(context),
          ),
        ),
        _SettingCard(
          title: 'Clear all history',
          subtitle: 'This cannot be undone',
          trailing: PressableScale(
            onTap: () => _confirmClear(context),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppTheme.signalRed.withValues(alpha: 0.6),
                ),
              ),
              child: Text(
                'Clear All',
                style: AppTheme.ui(size: 13, color: AppTheme.signalRed),
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Everything stays on your device — secrets are redacted before any '
          'request leaves it.',
          style: AppTheme.ui(size: 11.5, color: AppTheme.textDim),
        ),
      ],
    );
  }
}

class _ProductHealthSettingsCard extends StatelessWidget {
  const _ProductHealthSettingsCard({required this.report});

  final ProductHealthReport report;

  @override
  Widget build(BuildContext context) {
    final color = _healthColor(report.severity);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.health_and_safety_outlined, size: 17, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Product health · ${report.label}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.ui(
                    size: 14,
                    weight: FontWeight.w800,
                    color: color,
                  ),
                ),
              ),
              Text(
                report.readyForAnalysis ? 'Ready' : 'Action needed',
                style: AppTheme.ui(
                  size: 11,
                  weight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            report.summary,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTheme.ui(size: 12, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final item in report.items) _HealthStatusPill(item: item),
            ],
          ),
        ],
      ),
    );
  }
}

class _HealthStatusPill extends StatelessWidget {
  const _HealthStatusPill({required this.item});

  final ProductHealthItem item;

  @override
  Widget build(BuildContext context) {
    final color = _healthColor(item.severity);
    final icon = switch (item.severity) {
      ProductHealthSeverity.ok => Icons.check_circle_outline_rounded,
      ProductHealthSeverity.info => Icons.info_outline_rounded,
      ProductHealthSeverity.warning => Icons.warning_amber_rounded,
      ProductHealthSeverity.critical => Icons.error_outline_rounded,
    };
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: Tooltip(
        key: ValueKey('${item.title}-${item.severity.name}'),
        message: '${item.title}\n${item.detail}',
        child: Container(
          constraints: const BoxConstraints(maxWidth: 215),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: color.withValues(alpha: 0.22)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 13, color: color),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.ui(
                    size: 11.5,
                    weight: FontWeight.w600,
                    color: item.needsAttention ? color : AppTheme.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Color _healthColor(ProductHealthSeverity severity) => switch (severity) {
  ProductHealthSeverity.ok => AppTheme.success,
  ProductHealthSeverity.info => AppTheme.textSecondary,
  ProductHealthSeverity.warning => AppTheme.signalOrange,
  ProductHealthSeverity.critical => AppTheme.signalRed,
};

// -----------------------------------------------------------------------------
// Screen 13 — Updates.
// -----------------------------------------------------------------------------

class _UpdatesTab extends StatefulWidget {
  const _UpdatesTab();

  @override
  State<_UpdatesTab> createState() => _UpdatesTabState();
}

class _UpdatesTabState extends State<_UpdatesTab> {
  bool _showUpToDate = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SettingCard(
          title: 'Version',
          subtitle: _SettingsModalState._appVersion,
          trailing: SizedBox.shrink(),
        ),
        GhostButtonSmall(
          label: 'Check for updates',
          onTap: () {
            setState(() => _showUpToDate = true);
            Future.delayed(const Duration(seconds: 2), () {
              if (mounted) setState(() => _showUpToDate = false);
            });
          },
        ),
        if (_showUpToDate)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Center(
              child: Text(
                "You're up to date",
                style: AppTheme.ui(size: 12, color: AppTheme.accent),
              ),
            ),
          ),
      ],
    );
  }
}
