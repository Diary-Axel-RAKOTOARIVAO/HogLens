import 'package:country_flags/country_flags.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:solar_icons/solar_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/i18n.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../data/providers/providers.dart';
import '../../data/providers/settings_provider.dart';
import '../../home_widget/home_widget_service.dart';
import '../../shared/ui.dart';

/// Public releases repo (downloads and issues); the source repo is private.
const _repoUrl = 'https://github.com/Diary-Axel-RAKOTOARIVAO/hoglens-releases';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final settings = ref.watch(settingsProvider);
    final update = ref.watch(updateCheckProvider);

    Widget choice<T>({required List<(T, String, Widget)> options, required T value, required ValueChanged<T> onChanged}) {
      return Row(
        children: [
          for (final (v, label, icon) in options) ...[
            Expanded(
              child: GestureDetector(
                onTap: () => onChanged(v),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: v == value ? c.text : c.surface,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      IconTheme(data: IconThemeData(size: 18, color: v == value ? c.bg : c.text), child: SizedBox(height: 20, child: Center(child: icon))),
                      const SizedBox(height: 4),
                      Text(label, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: v == value ? c.bg : c.text)),
                    ],
                  ),
                ),
              ),
            ),
            if (v != options.last.$1) const SizedBox(width: 8),
          ],
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(
        leadingWidth: 76,
        leading: Padding(
          padding: const EdgeInsets.only(left: Spacing.page),
          child: Center(child: IconCircleButton(icon: SolarIconsOutline.altArrowLeft, onTap: () => context.pop())),
        ),
        titleSpacing: 12,
        title: Text(tr('App settings')),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Spacing.page, 4, Spacing.page, 40),
        children: [
          Text(tr('Appearance').toUpperCase(), style: Theme.of(context).textTheme.labelSmall),
          const SizedBox(height: 10),
          choice<ThemeMode>(
            options: [
              (ThemeMode.system, tr('System'), const Icon(SolarIconsOutline.smartphone)),
              (ThemeMode.light, tr('Light'), const Icon(SolarIconsOutline.sun)),
              (ThemeMode.dark, tr('Dark'), const Icon(SolarIconsOutline.moon)),
            ],
            value: settings.themeMode,
            onChanged: (m) => ref.read(settingsProvider.notifier).setTheme(m),
          ),
          const SizedBox(height: 24),
          Text(tr('Language').toUpperCase(), style: Theme.of(context).textTheme.labelSmall),
          const SizedBox(height: 10),
          choice<AppLanguage>(
            options: [for (final l in AppLanguage.values) (l, l.label, CountryFlag.fromCountryCode(l.country, theme: const ImageTheme(width: 22, height: 22, shape: Circle())))],
            value: settings.language,
            onChanged: (l) => ref.read(settingsProvider.notifier).setLanguage(l),
          ),
          const SizedBox(height: 24),
          if (HomeWidgetService.supported) ...[
            Card1(
              radius: 20,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              onTap: () => context.push('/settings/widgets'),
              child: Row(
                children: [
                  Icon(SolarIconsOutline.widget, size: 20, color: c.textMuted),
                  const SizedBox(width: 12),
                  Expanded(child: Text(tr('Home screen widgets'), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15))),
                  Icon(SolarIconsOutline.altArrowRight, size: 18, color: c.textFaint),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
          Text(tr('About').toUpperCase(), style: Theme.of(context).textTheme.labelSmall),
          const SizedBox(height: 10),
          Card1(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const BrandLogo(size: 56),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('HogLens', style: Theme.of(context).textTheme.titleLarge),
                          Text(tr('All your PostHog projects. One lens.'), style: TextStyle(fontSize: 13, color: c.textMuted)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                FutureBuilder<PackageInfo>(
                  future: PackageInfo.fromPlatform(),
                  builder: (context, snap) => Row(
                    children: [
                      Expanded(child: Text(tr('Version'), style: TextStyle(color: c.textMuted, fontSize: 14))),
                      Text(
                        snap.hasData ? '${snap.data!.version} (${snap.data!.buildNumber})' : '…',
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, fontFeatures: [FontFeature.tabularFigures()]),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                update.when(
                  loading: () => const SizedBox.shrink(),
                  error: (_, _) => const SizedBox.shrink(),
                  data: (u) => Row(
                    children: [
                      Expanded(
                        child: Text(
                          u == null ? tr('You are on the latest version') : '${tr('HogLens')} ${u.version} ${tr('is out')}',
                          style: TextStyle(color: u == null ? c.textMuted : c.text, fontSize: 13),
                        ),
                      ),
                      TextButton(
                        onPressed: () => u == null
                            ? ref.invalidate(updateCheckProvider)
                            : launchUrl(Uri.parse(u.url), mode: LaunchMode.externalApplication),
                        child: Text(u == null ? tr('Check for updates') : tr('Download')),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          _LinkRow(
            icon: Icons.star_border_rounded,
            title: tr('Star HogLens on GitHub'),
            subtitle: tr('Downloads, release notes and updates'),
            onTap: () => launchUrl(Uri.parse(_repoUrl), mode: LaunchMode.externalApplication),
          ),
          const SizedBox(height: 8),
          _LinkRow(
            icon: SolarIconsOutline.bug,
            title: tr('Report a problem'),
            subtitle: 'github.com/Diary-Axel-RAKOTOARIVAO/hoglens-releases/issues',
            onTap: () => launchUrl(Uri.parse('$_repoUrl/issues/new'), mode: LaunchMode.externalApplication),
          ),
        ],
      ),
    );
  }
}

class _LinkRow extends StatelessWidget {
  const _LinkRow({required this.icon, required this.title, required this.subtitle, required this.onTap});
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Card1(
      radius: 20,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: c.bg, borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, size: 19, color: c.text),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12.5, color: c.textMuted)),
              ],
            ),
          ),
          Icon(SolarIconsOutline.arrowRightUp, size: 18, color: c.textFaint),
        ],
      ),
    );
  }
}
