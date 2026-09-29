import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:home_widget/home_widget.dart';
import 'package:image_picker/image_picker.dart';
import 'package:solar_icons/solar_icons.dart';

import '../../core/i18n.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../data/providers/providers.dart';
import '../../home_widget/home_widget_service.dart';
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

  Future<void> _pickWidget(BuildContext context) async {
    final c = context.colors;
    final supported = await HomeWidget.isRequestPinWidgetSupported() ?? false;
    if (!context.mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.8,
        maxChildSize: 0.94,
        builder: (ctx, ctrl) => ListView(
          controller: ctrl,
          padding: const EdgeInsets.fromLTRB(Spacing.page, 0, Spacing.page, 28),
          children: [
            Text(tr('Home screen widgets'), style: Theme.of(ctx).textTheme.headlineMedium),
            const SizedBox(height: 4),
            Text(
              supported ? tr('Pick a size. Each shows a different slice of this project.') : tr('Long-press your home screen to add the HogLens widget.'),
              style: TextStyle(color: c.textMuted),
            ),
            const SizedBox(height: 18),
            for (final k in HomeWidgetKind.values)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Card1(
                  radius: 20,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  onTap: supported
                      ? () async {
                          Navigator.pop(ctx);
                          await HomeWidget.requestPinWidget(name: k.androidName, androidName: k.androidName);
                        }
                      : null,
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(color: c.bg, borderRadius: BorderRadius.circular(12)),
                        child: Text(k.cells, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: c.text)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(tr(k.title), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                            Text(tr(k.description), style: TextStyle(fontSize: 12.5, color: c.textMuted)),
                          ],
                        ),
                      ),
                      Icon(SolarIconsOutline.addCircle, size: 20, color: c.textFaint),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
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
    showToast(context, tr('Saved'));
    context.pop();
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('Remove project?')),
        content: Text(tr('The stored API key, logo and custom widgets on this phone will be deleted. Nothing changes in PostHog.')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(tr('Remove'), style: TextStyle(color: ctx.colors.negative)),
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
        title: Text(tr('Project settings')),
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
                    TextButton(onPressed: _pickLogo, child: Text(tr('Change logo'))),
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
          Text(tr('NAME'), style: Theme.of(context).textTheme.labelSmall),
          const SizedBox(height: 8),
          TextField(controller: _name, onChanged: (_) => setState(() {})),
          const SizedBox(height: 24),
          Text(tr('ACCENT'), style: Theme.of(context).textTheme.labelSmall),
          const SizedBox(height: 10),
          AccentPicker(value: _accent ?? p.accentIndex, onChanged: (i) => setState(() => _accent = i)),
          const SizedBox(height: 24),
          Text(tr('CONNECTION'), style: Theme.of(context).textTheme.labelSmall),
          const SizedBox(height: 8),
          Card1(
            radius: Radii.tile,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _kv(context, tr('Host'), p.host),
                const Divider(height: 20),
                _kv(context, tr('Project ID'), '${p.projectId}'),
              ],
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _key,
            obscureText: true,
            autocorrect: false,
            style: const TextStyle(fontFamily: 'Menlo', fontSize: 14),
            decoration: InputDecoration(hintText: tr('Replace API key (optional)')),
          ),
          if (HomeWidgetService.supported) ...[
            const SizedBox(height: 24),
            Text(tr('HOME SCREEN WIDGET'), style: Theme.of(context).textTheme.labelSmall),
            const SizedBox(height: 8),
            Card1(
              radius: Radii.tile,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(tr('Show this project on the widget'), style: TextStyle(fontWeight: FontWeight.w600)),
                            Text(tr('Visitors today and the last seven days, refreshed every 30 minutes.'),
                                style: TextStyle(fontSize: 12.5, color: c.textMuted)),
                          ],
                        ),
                      ),
                      Switch.adaptive(
                        value: ref.watch(storeProvider).widgetProjectId == p.id,
                        activeTrackColor: c.text,
                        onChanged: (v) async {
                          if (!v) return;
                          await ref.read(storeProvider).setWidgetProjectId(p.id);
                          final g = ref.read(glanceProvider(p.id)).value;
                          if (g != null) await HomeWidgetService.pushGlance(p, g);
                          setState(() {});
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextButton.icon(
                    onPressed: () => _pickWidget(context),
                    icon: const Icon(SolarIconsOutline.widgetAdd, size: 18),
                    label: Text(tr('Add to home screen')),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 32),
          FilledButton(
            onPressed: _busy ? null : _save,
            child: Text(tr('Save changes')),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: _delete,
            child: Text(tr('Remove project'), style: TextStyle(color: c.negative)),
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
