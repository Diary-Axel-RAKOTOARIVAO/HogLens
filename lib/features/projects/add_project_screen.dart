import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:solar_icons/solar_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../data/api/posthog_client.dart';
import '../../data/models/project.dart';
import '../../data/models/stats.dart';
import '../../data/providers/providers.dart';
import '../../shared/ui.dart';

/// Three-step flow: connect (host + key) → choose project → brand it.
class AddProjectScreen extends ConsumerStatefulWidget {
  const AddProjectScreen({super.key});

  @override
  ConsumerState<AddProjectScreen> createState() => _AddProjectScreenState();
}

class _AddProjectScreenState extends ConsumerState<AddProjectScreen> {
  int _step = 0;
  PhHost _host = PhHost.us;
  final _customHost = TextEditingController(text: 'https://');
  final _key = TextEditingController();
  final _manualId = TextEditingController();
  final _name = TextEditingController();
  bool _busy = false;
  bool _obscure = true;
  String? _error;
  List<RemoteProject> _remote = const [];
  RemoteProject? _picked;
  File? _logo;
  int _accent = 0;

  String get _baseUrl => _host == PhHost.custom
      ? _customHost.text.trim().replaceAll(RegExp(r'/+$'), '')
      : _host.baseUrl;

  @override
  void dispose() {
    _customHost.dispose();
    _key.dispose();
    _manualId.dispose();
    _name.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    final key = _key.text.trim();
    if (key.isEmpty) return setState(() => _error = 'Paste a personal API key.');
    if (_host == PhHost.custom && !(Uri.tryParse(_baseUrl)?.hasScheme ?? false)) {
      return setState(() => _error = 'Enter a valid host URL.');
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final client = PosthogClient(host: _baseUrl, apiKey: key);
      List<RemoteProject> list;
      try {
        list = await client.listProjects();
      } on PosthogException catch (e) {
        // Project-scoped keys cannot list projects (403). Fall through to
        // manual project-ID entry; a bad key (401) is still an error.
        if (e.statusCode != 403) rethrow;
        list = const [];
      }
      setState(() {
        _remote = list;
        _picked = list.length == 1 ? list.first : null;
        if (_picked != null) _name.text = _picked!.name;
        _step = 1;
      });
    } on PosthogException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = 'Unexpected error: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Validates that the key can actually read [p] before branding it.
  Future<void> _choose(RemoteProject p) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final client = PosthogClient(host: _baseUrl, apiKey: _key.text.trim());
      final verified = await client.getProject(p.id);
      setState(() {
        _picked = verified;
        _name.text = verified.name.isEmpty ? p.name : verified.name;
        _step = 2;
      });
    } on PosthogException catch (e) {
      setState(() => _error = e.statusCode == 403
          ? 'This key cannot read "${p.name}". Pick another project or create a key scoped to it.'
          : e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _useManualId() async {
    final id = int.tryParse(_manualId.text.trim());
    if (id == null) return setState(() => _error = 'Enter a numeric project ID.');
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final client = PosthogClient(host: _baseUrl, apiKey: _key.text.trim());
      final p = await client.getProject(id);
      setState(() {
        _picked = p;
        _name.text = p.name;
        _step = 2;
      });
    } on PosthogException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickLogo() async {
    final x = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 512, maxHeight: 512);
    if (x != null) setState(() => _logo = File(x.path));
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) return setState(() => _error = 'Give the project a name.');
    setState(() => _busy = true);
    final p = await ref.read(projectsProvider.notifier).add(
          name: name,
          host: _baseUrl,
          projectId: _picked!.id,
          apiKey: _key.text.trim(),
          logo: _logo,
          accentIndex: _accent,
        );
    if (!mounted) return;
    context.pop();
    context.push('/p/${p.id}');
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      appBar: AppBar(
        leadingWidth: 76,
        leading: Padding(
          padding: const EdgeInsets.only(left: Spacing.page),
          child: Center(
            child: IconCircleButton(
              icon: SolarIconsOutline.altArrowLeft,
              onTap: () => _step == 0 ? context.pop() : setState(() => _step--),
            ),
          ),
        ),
        titleSpacing: 12,
        title: Text(const ['Connect', 'Choose project', 'Brand it'][_step]),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: Spacing.page),
            child: Center(child: _StepDots(step: _step)),
          ),
        ],
      ),
      body: AnimatedSwitcher(
        duration: 250.ms,
        switchInCurve: Curves.easeOut,
        transitionBuilder: (child, a) => FadeTransition(
          opacity: a,
          child: SlideTransition(
            position: Tween(begin: const Offset(0.04, 0), end: Offset.zero).animate(a),
            child: child,
          ),
        ),
        child: KeyedSubtree(
          key: ValueKey(_step),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(Spacing.page, 8, Spacing.page, 40),
            children: [
              if (_step == 0) ..._connectStep(c),
              if (_step == 1) ..._chooseStep(c),
              if (_step == 2) ..._brandStep(c),
              if (_error != null) ...[
                const SizedBox(height: 16),
                ErrorCard(message: _error!),
              ],
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _connectStep(AppColors c) => [
        Text('Where does this project live?', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 6),
        Text('HogLens reads through the private API using a personal key with project:read and query:read scopes.',
            style: TextStyle(color: c.textMuted, height: 1.4)),
        const SizedBox(height: 24),
        Row(
          children: [
            for (final h in PhHost.values) ...[
              Expanded(
                child: _HostChip(
                  label: h.label,
                  selected: _host == h,
                  onTap: () => setState(() => _host = h),
                ),
              ),
              if (h != PhHost.values.last) const SizedBox(width: 8),
            ],
          ],
        ),
        if (_host == PhHost.custom) ...[
          const SizedBox(height: 12),
          TextField(
            controller: _customHost,
            keyboardType: TextInputType.url,
            autocorrect: false,
            decoration: const InputDecoration(hintText: 'https://posthog.example.com'),
          ),
        ],
        const SizedBox(height: 24),
        Text('PERSONAL API KEY', style: Theme.of(context).textTheme.labelSmall),
        const SizedBox(height: 8),
        TextField(
          controller: _key,
          obscureText: _obscure,
          autocorrect: false,
          enableSuggestions: false,
          style: const TextStyle(fontFamily: 'Menlo', fontSize: 14),
          decoration: InputDecoration(
            hintText: 'phx_…',
            suffixIcon: IconButton(
              color: c.textMuted,
              icon: Icon(_obscure ? SolarIconsOutline.eye : SolarIconsOutline.eyeClosed, size: 20),
              onPressed: () => setState(() => _obscure = !_obscure),
            ),
          ),
        ),
        const SizedBox(height: 10),
        GestureDetector(
          onTap: () => launchUrl(Uri.parse('$_baseUrl/settings/user-api-keys'), mode: LaunchMode.externalApplication),
          child: Row(
            children: [
              Icon(SolarIconsOutline.keyMinimalistic, size: 14, color: c.textMuted),
              const SizedBox(width: 6),
              Text('Create one in PostHog → Settings → Personal API keys',
                  style: TextStyle(color: c.textMuted, fontSize: 12.5, decoration: TextDecoration.underline)),
            ],
          ),
        ),
        const SizedBox(height: 28),
        FilledButton(
          onPressed: _busy ? null : _connect,
          child: _busy ? const _Spinner() : const Text('Connect'),
        ),
        const SizedBox(height: 12),
        Text('Stored in the device Keychain. Never leaves this phone except to talk to your PostHog host.',
            textAlign: TextAlign.center, style: TextStyle(color: c.textFaint, fontSize: 12)),
      ];

  List<Widget> _chooseStep(AppColors c) => [
        Text(_remote.isEmpty ? 'No projects visible' : 'Pick a project',
            style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 6),
        Text(
          _remote.isEmpty
              ? 'Could not list projects. Enter the project ID from your PostHog URL (…/project/12345/…).'
              : 'Projects on ${Uri.parse(_baseUrl).host}. A scoped key may only read some of them.',
          style: TextStyle(color: c.textMuted, height: 1.4),
        ),
        const SizedBox(height: 20),
        for (final p in _remote)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Card1(
              onTap: _busy ? null : () => _choose(p),
              radius: Radii.tile,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Expanded(child: Text(p.name, style: Theme.of(context).textTheme.titleMedium)),
                  Pill('#${p.id}'),
                  const SizedBox(width: 8),
                  Icon(SolarIconsOutline.altArrowRight, size: 18, color: c.textFaint),
                ],
              ),
            ),
          ),
        const SizedBox(height: 16),
        Text('OR BY PROJECT ID', style: Theme.of(context).textTheme.labelSmall),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _manualId,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(hintText: '12345'),
              ),
            ),
            const SizedBox(width: 10),
            FilledButton(
              onPressed: _busy ? null : _useManualId,
              style: FilledButton.styleFrom(minimumSize: const Size(96, 52)),
              child: _busy ? const _Spinner() : const Text('Use'),
            ),
          ],
        ),
      ];

  List<Widget> _brandStep(AppColors c) {
    final preview = PhProject(
      id: 'preview',
      name: _name.text.isEmpty ? 'Project' : _name.text,
      host: _baseUrl,
      projectId: _picked?.id ?? 0,
      accentIndex: _accent,
      createdAt: DateTime.now(),
    );
    return [
      Center(
        child: Column(
          children: [
            GestureDetector(
              onTap: _pickLogo,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  ProjectAvatar(project: preview, size: 96, file: _logo),
                  Positioned(
                    right: -6,
                    bottom: -6,
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: c.text,
                        shape: BoxShape.circle,
                        border: Border.all(color: c.bg, width: 3),
                      ),
                      child: Icon(SolarIconsOutline.camera, size: 16, color: c.bg),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: _logo == null ? _pickLogo : () => setState(() => _logo = null),
              child: Text(_logo == null ? 'Upload logo' : 'Remove logo'),
            ),
          ],
        ),
      ),
      const SizedBox(height: 20),
      Text('NAME', style: Theme.of(context).textTheme.labelSmall),
      const SizedBox(height: 8),
      TextField(
        controller: _name,
        textCapitalization: TextCapitalization.words,
        onChanged: (_) => setState(() {}),
        decoration: const InputDecoration(hintText: 'My app'),
      ),
      const SizedBox(height: 24),
      Text('ACCENT', style: Theme.of(context).textTheme.labelSmall),
      const SizedBox(height: 10),
      AccentPicker(value: _accent, onChanged: (i) => setState(() => _accent = i)),
      const SizedBox(height: 32),
      FilledButton(
        onPressed: _busy ? null : _save,
        child: _busy ? const _Spinner() : const Text('Add project'),
      ),
    ];
  }
}

class AccentPicker extends StatelessWidget {
  const AccentPicker({super.key, required this.value, required this.onChanged});
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (var i = 0; i < Accents.all.length; i++)
          GestureDetector(
            onTap: () => onChanged(i),
            child: AnimatedContainer(
              duration: 150.ms,
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Accents.all[i],
                shape: BoxShape.circle,
                border: Border.all(color: value == i ? c.text : Colors.transparent, width: 2.5),
              ),
              child: value == i ? const Icon(Icons.check, color: Colors.white, size: 18) : null,
            ),
          ),
      ],
    );
  }
}

class _HostChip extends StatelessWidget {
  const _HostChip({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: 150.ms,
        padding: const EdgeInsets.symmetric(vertical: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? c.text : c.surface,
          borderRadius: BorderRadius.circular(Radii.input),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? c.bg : c.text,
            fontWeight: FontWeight.w600,
            fontSize: 13.5,
          ),
        ),
      ),
    );
  }
}

class _StepDots extends StatelessWidget {
  const _StepDots({required this.step});
  final int step;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Row(
      children: [
        for (var i = 0; i < 3; i++)
          AnimatedContainer(
            duration: 200.ms,
            margin: const EdgeInsets.only(left: 5),
            width: i == step ? 18 : 6,
            height: 6,
            decoration: BoxDecoration(
              color: i <= step ? c.text : c.border,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
      ],
    );
  }
}

class _Spinner extends StatelessWidget {
  const _Spinner();
  @override
  Widget build(BuildContext context) => SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(strokeWidth: 2, color: context.colors.bg),
      );
}
