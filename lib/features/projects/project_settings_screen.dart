import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:solar_icons/solar_icons.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../data/providers/providers.dart';
import '../../shared/ui.dart';
import 'add_project_screen.dart';

class ProjectSettingsScreen extends ConsumerStatefulWidget {
  const ProjectSettingsScreen({super.key, required this.projectId});
  final String projectId;

  @override
  ConsumerState<ProjectSettingsScreen> createState() => _ProjectSettingsScreenState();
}

class _ProjectSettingsScreenState extends ConsumerState<ProjectSettingsScreen> {
  late final TextEditingController _name;
  final _key = TextEditingController();
  File? _newLogo;
  bool _removeLogo = false;
  int? _accent;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: ref.read(projectProvider(widget.projectId))?.name ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    _key.dispose();
    super.dispose();
  }

  Future<void> _pickLogo() async {
    final x = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 512, maxHeight: 512);
    if (x != null) {
      setState(() {
        _newLogo = File(x.path);
        _removeLogo = false;
      });
    }
  }

  Future<void> _save() async {
    final p = ref.read(projectProvider(widget.projectId));
    if (p == null) return;
    setState(() => _busy = true);
    await ref.read(projectsProvider.notifier).update(
          p.copyWith(name: _name.text.trim().isEmpty ? p.name : _name.text.trim(), accentIndex: _accent),
          newLogo: _newLogo,
          removeLogo: _removeLogo,
          newKey: _key.text.trim().isEmpty ? null : _key.text.trim(),
        );
    if (!mounted) return;
    showToast(context, 'Saved');
    context.pop();
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove project?'),
        content: const Text('The stored API key, logo and custom widgets on this phone will be deleted. Nothing changes in PostHog.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Remove', style: TextStyle(color: ctx.colors.negative)),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await ref.read(projectsProvider.notifier).remove(widget.projectId);
    if (mounted) context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final p = ref.watch(projectProvider(widget.projectId));
    if (p == null) return const Scaffold();
    final preview = p.copyWith(
      name: _name.text.isEmpty ? p.name : _name.text,
      accentIndex: _accent ?? p.accentIndex,
      clearLogo: _removeLogo,
    );

    return Scaffold(
      appBar: AppBar(
        leadingWidth: 76,
        leading: Padding(
          padding: const EdgeInsets.only(left: Spacing.page),
          child: Center(child: IconCircleButton(icon: SolarIconsOutline.altArrowLeft, onTap: () => context.pop())),
        ),
        titleSpacing: 12,
        title: const Text('Project settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Spacing.page, 8, Spacing.page, 40),
        children: [
          Center(
            child: Column(
              children: [
                GestureDetector(
                  onTap: _pickLogo,
                  child: ProjectAvatar(project: preview, size: 96, file: _newLogo),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextButton(onPressed: _pickLogo, child: const Text('Change logo')),
                    if (p.logoPath != null || _newLogo != null)
                      TextButton(
                        onPressed: () => setState(() {
                          _newLogo = null;
                          _removeLogo = true;
                        }),
                        child: Text('Remove', style: TextStyle(color: c.negative)),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text('NAME', style: Theme.of(context).textTheme.labelSmall),
          const SizedBox(height: 8),
          TextField(controller: _name, onChanged: (_) => setState(() {})),
          const SizedBox(height: 24),
          Text('ACCENT', style: Theme.of(context).textTheme.labelSmall),
          const SizedBox(height: 10),
          AccentPicker(value: _accent ?? p.accentIndex, onChanged: (i) => setState(() => _accent = i)),
          const SizedBox(height: 24),
          Text('CONNECTION', style: Theme.of(context).textTheme.labelSmall),
          const SizedBox(height: 8),
          Card1(
            radius: Radii.tile,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _kv(context, 'Host', p.host),
                const Divider(height: 20),
                _kv(context, 'Project ID', '${p.projectId}'),
              ],
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _key,
            obscureText: true,
            autocorrect: false,
            style: const TextStyle(fontFamily: 'Menlo', fontSize: 14),
            decoration: const InputDecoration(hintText: 'Replace API key (optional)'),
          ),
          const SizedBox(height: 32),
          FilledButton(
            onPressed: _busy ? null : _save,
            child: const Text('Save changes'),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: _delete,
            child: Text('Remove project', style: TextStyle(color: c.negative)),
          ),
        ],
      ),
    );
  }

  Widget _kv(BuildContext context, String k, String v) => Row(
        children: [
          Text(k, style: TextStyle(color: context.colors.textMuted)),
          const Spacer(),
          Flexible(child: Text(v, style: const TextStyle(fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis)),
        ],
      );
}
