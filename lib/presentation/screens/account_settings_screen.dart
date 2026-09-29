import 'dart:io';

import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../data/backend/authenticator.dart';
import '../../theme/app_typography.dart';
import '../../theme/momentum_tokens.dart';
import '../components/momentum_ui.dart';
import '../providers/auth_user_provider.dart';
import '../providers/momentum_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/user_provider.dart';

class AccountSettingsScreen extends ConsumerStatefulWidget {
  const AccountSettingsScreen({super.key});
  static const routeName = '/account-settings';

  @override
  ConsumerState<AccountSettingsScreen> createState() =>
      _AccountSettingsScreenState();
}

class _AccountSettingsScreenState extends ConsumerState<AccountSettingsScreen> {
  final _nameController = TextEditingController();
  bool _seeded = false;
  bool _saving = false;
  bool _uploading = false;
  bool _deleting = false;

  Future<void> _confirmDelete() async {
    final m = context.m;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: m.isDark ? const Color(0xFF14141C) : m.surface,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(MomentumTokens.radiusCard)),
        title: Text('Delete your account?',
            style: AppTypography.heading2.copyWith(color: m.ink)),
        content: Text(
          'Everything you have in TaskTrackr is deleted for good. Google will '
          'ask you to confirm it’s you.',
          style: AppTypography.body.copyWith(color: m.inkSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: TextStyle(color: m.inkSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Delete everything', style: TextStyle(color: m.danger)),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _deleting = true);
    try {
      final uid = ref.read(currentUidProvider);
      final deleted = await const Authenticator().deleteAccount();
      if (!deleted) return;
      // Local copies of XP, habits and focus data for this user.
      final prefs = ref.read(sharedPreferencesProvider);
      for (final k in prefs.getKeys().where((k) => k.startsWith('m.$uid.'))) {
        await prefs.remove(k);
      }
      if (mounted) showMomentumToast(context, 'Account deleted');
    } catch (e) {
      if (mounted) showMomentumToast(context, 'Could not delete account: $e');
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadImage() async {
    final image = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 60,
      maxWidth: 512,
    );
    if (image == null) return;

    setState(() => _uploading = true);
    try {
      await const Authenticator().uploadProfilePicture(File(image.path));
      if (mounted) showMomentumToast(context, 'Photo updated');
    } catch (e) {
      if (mounted) showMomentumToast(context, 'Upload failed: $e');
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    setState(() => _saving = true);
    try {
      await const Authenticator().updateDisplayName(name);
      if (mounted) {
        showMomentumToast(context, 'Profile updated');
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) showMomentumToast(context, 'Could not save: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final m = context.m;
    final user = ref.watch(userProfileProvider).value;
    final level = ref.watch(momentumProvider).level;
    if (!_seeded && user != null) {
      _nameController.text = user.displayName;
      _seeded = true;
    }

    InputDecoration deco({bool readOnly = false}) => InputDecoration(
          filled: true,
          fillColor: m.ink.withValues(alpha: readOnly ? .03 : .05),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(MomentumTokens.radiusButton),
            borderSide: BorderSide(color: m.stroke),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(MomentumTokens.radiusButton),
            borderSide: BorderSide(color: m.violet.withValues(alpha: .7)),
          ),
        );

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(title: const Text('Account')),
      body: Stack(children: [
        const Positioned.fill(child: AuroraBackground()),
        ListView(
          padding: EdgeInsets.fromLTRB(
            MomentumTokens.gutter + 4,
            MediaQuery.paddingOf(context).top + kToolbarHeight + 16,
            MomentumTokens.gutter + 4,
            40,
          ),
          children: [
            Center(
              child: GestureDetector(
                onTap: _uploading ? null : _pickAndUploadImage,
                child: Stack(clipBehavior: Clip.none, children: [
                  LevelAvatar(
                    name: user?.displayName ?? '',
                    photoUrl: user?.photoURL,
                    level: level,
                    size: 92,
                  ),
                  if (_uploading)
                    Positioned(
                      left: 2,
                      top: 2,
                      width: 92,
                      height: 92,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.black.withValues(alpha: .45),
                        ),
                        child: const Center(
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        ),
                      ),
                    ),
                  Positioned(
                    right: -2,
                    top: 64,
                    child: Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: m.isDark ? Colors.white : m.ink,
                        border: Border.all(color: m.canvas, width: 2),
                      ),
                      child: Icon(Icons.photo_camera_outlined,
                          size: 16,
                          color: m.isDark
                              ? const Color(0xFF0B0B12)
                              : Colors.white),
                    ),
                  ),
                ]),
              ),
            ),
            const SizedBox(height: 28),
            const SectionLabel('Display name'),
            const SizedBox(height: 8),
            TextField(
              controller: _nameController,
              cursorColor: m.violet,
              style: AppTypography.bodyStrong.copyWith(color: m.ink),
              decoration: deco(),
            ),
            const SizedBox(height: 18),
            const SectionLabel('Email'),
            const SizedBox(height: 8),
            TextField(
              controller: TextEditingController(text: user?.email ?? ''),
              readOnly: true,
              style: AppTypography.body.copyWith(color: m.inkSecondary),
              decoration: deco(readOnly: true),
            ),
            const SizedBox(height: 28),
            MButton(
              label: 'Save changes',
              expand: true,
              loading: _saving,
              onPressed: _save,
            ),
            const SizedBox(height: 40),
            const SectionLabel('Danger zone'),
            const SizedBox(height: 8),
            Text(
              'Deleting your account permanently removes your tasks, habits, '
              'XP, streaks and profile from every device. This can’t be undone.',
              style: AppTypography.caption.copyWith(color: m.inkSecondary),
            ),
            const SizedBox(height: 12),
            MButton(
              label: 'Delete account',
              kind: MButtonKind.destructive,
              expand: true,
              loading: _deleting,
              onPressed: _confirmDelete,
            ),
          ],
        ),
      ]),
    );
  }
}
