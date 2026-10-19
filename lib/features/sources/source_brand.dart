import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/i18n.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';

/// A known traffic source: display name, logo asset (Simple Icons, CC0) and
/// brand color. Brands without a public logo get a glyph or initials.
class SourceBrand {
  const SourceBrand(this.key, this.name, this.color, {this.asset, this.glyph, this.initials, this.gradient});
  final String key;
  final String name;
  final Color color;
  final String? asset;
  final IconData? glyph;
  final String? initials;
  final Gradient? gradient;
}

const _instagramGradient = LinearGradient(
  begin: Alignment.bottomLeft,
  end: Alignment.topRight,
  colors: [Color(0xFFFEDA75), Color(0xFFFA7E1E), Color(0xFFD62976), Color(0xFF962FBF), Color(0xFF4F5BD5)],
);

const Map<String, SourceBrand> sourceBrands = {
  'facebook': SourceBrand('facebook', 'Facebook', Color(0xFF0866FF), asset: 'facebook'),
  'instagram': SourceBrand('instagram', 'Instagram', Color(0xFFFF0069), asset: 'instagram', gradient: _instagramGradient),
  'messenger': SourceBrand('messenger', 'Messenger', Color(0xFF0866FF), asset: 'messenger'),
  'threads': SourceBrand('threads', 'Threads', Color(0xFF000000), asset: 'threads'),
  'whatsapp': SourceBrand('whatsapp', 'WhatsApp', Color(0xFF25D366), asset: 'whatsapp'),
  'telegram': SourceBrand('telegram', 'Telegram', Color(0xFF26A5E4), asset: 'telegram'),
  'tiktok': SourceBrand('tiktok', 'TikTok', Color(0xFF000000), asset: 'tiktok'),
  'youtube': SourceBrand('youtube', 'YouTube', Color(0xFFFF0000), asset: 'youtube'),
  'x': SourceBrand('x', 'X', Color(0xFF000000), asset: 'x'),
  'reddit': SourceBrand('reddit', 'Reddit', Color(0xFFFF4500), asset: 'reddit'),
  'pinterest': SourceBrand('pinterest', 'Pinterest', Color(0xFFBD081C), asset: 'pinterest'),
  'snapchat': SourceBrand('snapchat', 'Snapchat', Color(0xFFFFFC00), asset: 'snapchat'),
  'bluesky': SourceBrand('bluesky', 'Bluesky', Color(0xFF1185FE), asset: 'bluesky'),
  'linkedin': SourceBrand('linkedin', 'LinkedIn', Color(0xFF0A66C2), initials: 'in'),
  'chatgpt': SourceBrand('chatgpt', 'ChatGPT', Color(0xFF10A37F), glyph: Icons.auto_awesome_rounded),
  'gemini': SourceBrand('gemini', 'Gemini', Color(0xFF8E75B2), asset: 'googlegemini'),
  'claude': SourceBrand('claude', 'Claude', Color(0xFFD97757), asset: 'claude'),
  'perplexity': SourceBrand('perplexity', 'Perplexity', Color(0xFF1FB8CD), asset: 'perplexity'),
  'copilot': SourceBrand('copilot', 'Copilot', Color(0xFF000000), asset: 'githubcopilot'),
  'google': SourceBrand('google', 'Google', Color(0xFF4285F4), asset: 'google'),
  'bing': SourceBrand('bing', 'Bing', Color(0xFF008373), glyph: Icons.search_rounded),
  'duckduckgo': SourceBrand('duckduckgo', 'DuckDuckGo', Color(0xFFDE5833), asset: 'duckduckgo'),
  'ecosia': SourceBrand('ecosia', 'Ecosia', Color(0xFF008009), asset: 'ecosia'),
  'yahoo': SourceBrand('yahoo', 'Yahoo', Color(0xFF6001D2), initials: 'Y!'),
  'gmail': SourceBrand('gmail', 'Gmail', Color(0xFFEA4335), asset: 'gmail'),
  'mailchimp': SourceBrand('mailchimp', 'Mailchimp', Color(0xFFFFE01B), asset: 'mailchimp'),
  'direct': SourceBrand('direct', 'Direct', Color(0xFF6B6B6B), glyph: Icons.near_me_rounded),
};

/// Maps a session's entry UTM source and referring domain to a source key
/// and display name. Unknown sources keep their UTM value or domain.
(String key, String name) classifySource(String? utmSource, String? referringDomain) {
  final utm = (utmSource ?? '').trim().toLowerCase();
  final ref = (referringDomain ?? '').trim().toLowerCase();
  String? match(String s) {
    if (s.isEmpty) return null;
    // A domain or any of its subdomains. Substring matching would misfile
    // "chatgpt.com" under X because it contains "t.co".
    bool any(List<String> domains) => domains.any((d) => s == d || s.endsWith('.$d'));
    // For families of country domains: pinterest.fr, yahoo.co.jp…
    bool family(String prefix) => RegExp('(^|\\.)${RegExp.escape(prefix)}\\.[a-z.]+\$').hasMatch(s);
    if (['fb', 'facebook', 'meta'].contains(s) || any(['facebook.com', 'fb.com', 'fb.me'])) return 'facebook';
    if (['ig', 'instagram', 'insta'].contains(s) || any(['instagram.com'])) return 'instagram';
    if (s == 'messenger' || any(['messenger.com'])) return 'messenger';
    if (s == 'threads' || any(['threads.net', 'threads.com'])) return 'threads';
    if (['whatsapp', 'wa'].contains(s) || any(['whatsapp.com', 'wa.me'])) return 'whatsapp';
    if (s == 'telegram' || any(['telegram.org', 't.me'])) return 'telegram';
    if (s == 'tiktok' || any(['tiktok.com'])) return 'tiktok';
    if (s == 'youtube' || any(['youtube.com', 'youtu.be'])) return 'youtube';
    if (['x', 'twitter'].contains(s) || any(['x.com', 'twitter.com', 't.co'])) return 'x';
    if (s == 'reddit' || any(['reddit.com'])) return 'reddit';
    if (s == 'pinterest' || family('pinterest') || any(['pin.it'])) return 'pinterest';
    if (s == 'snapchat' || any(['snapchat.com'])) return 'snapchat';
    if (s == 'bluesky' || any(['bsky.app'])) return 'bluesky';
    if (s == 'linkedin' || any(['linkedin.com', 'lnkd.in'])) return 'linkedin';
    if (['chatgpt', 'chatgpt.com', 'openai'].contains(s) || any(['chatgpt.com', 'chat.openai.com'])) return 'chatgpt';
    if (s == 'gemini' || any(['gemini.google.com', 'bard.google.com'])) return 'gemini';
    if (s == 'claude' || any(['claude.ai'])) return 'claude';
    if (s == 'perplexity' || any(['perplexity.ai'])) return 'perplexity';
    if (s == 'copilot' || any(['copilot.microsoft.com'])) return 'copilot';
    if (s == 'google' || s.contains('googlequicksearchbox') || RegExp(r'^(www\.)?google\.[a-z.]+$').hasMatch(s)) return 'google';
    if (s == 'bing' || any(['bing.com'])) return 'bing';
    if (s == 'duckduckgo' || any(['duckduckgo.com'])) return 'duckduckgo';
    if (s == 'ecosia' || any(['ecosia.org'])) return 'ecosia';
    if (s == 'yahoo' || family('yahoo')) return 'yahoo';
    if (s == 'gmail' || any(['mail.google.com'])) return 'gmail';
    if (s == 'mailchimp' || any(['mailchimp.com', 'list-manage.com'])) return 'mailchimp';
    return null;
  }

  final known = match(utm) ?? match(ref);
  if (known != null) return (known, sourceBrands[known]!.name);
  if (utm.isNotEmpty) return ('utm:$utm', utmSource!.trim());
  if (ref.isEmpty || ref == r'$direct') return ('direct', tr('Direct'));
  final domain = ref.startsWith('www.') ? ref.substring(4) : ref;
  return ('ref:$domain', domain);
}

/// Rounded tile with the brand logo, a glyph, or initials.
class SourceLogo extends StatelessWidget {
  const SourceLogo({super.key, required this.sourceKey, required this.name, this.size = 36});
  final String sourceKey;
  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final brand = sourceBrands[sourceKey];
    final radius = BorderRadius.circular(size * 0.3);
    if (brand == null) {
      final letter = name.isEmpty ? '?' : name.replaceFirst(RegExp(r'^www\.'), '').substring(0, 1).toUpperCase();
      return Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: c.surfaceRaised, borderRadius: radius),
        child: Text(letter, style: TextStyle(fontSize: size * 0.42, fontWeight: FontWeight.w700, color: c.textMuted)),
      );
    }
    final fg = brand.color.computeLuminance() > 0.6 ? const Color(0xFF111111) : Colors.white;
    Widget inner;
    if (brand.asset != null) {
      inner = SvgPicture.asset(
        'assets/sources/${brand.asset}.svg',
        width: size * 0.56,
        height: size * 0.56,
        colorFilter: ColorFilter.mode(fg, BlendMode.srcIn),
      );
    } else if (brand.glyph != null) {
      inner = Icon(brand.glyph, size: size * 0.56, color: fg);
    } else {
      inner = Text(brand.initials ?? '', style: TextStyle(fontSize: size * 0.4, fontWeight: FontWeight.w800, color: fg, height: 1));
    }
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: brand.gradient == null ? (brand.key == 'direct' ? c.surfaceRaised : brand.color) : null,
        gradient: brand.gradient,
        borderRadius: radius,
      ),
      child: brand.key == 'direct' ? Icon(brand.glyph, size: size * 0.5, color: c.textMuted) : inner,
    );
  }
}

/// Stable colors for PostHog's channel types.
Color channelColor(String channel, AppColors c) => switch (channel) {
      'Paid Social' => const Color(0xFF0866FF),
      'Organic Social' => const Color(0xFF6EA8FE),
      'Direct' => c.textMuted,
      'Referral' => const Color(0xFF0D9488),
      'Organic Search' => const Color(0xFFF59E0B),
      'Paid Search' => const Color(0xFFD97706),
      'AI' => const Color(0xFF8B5CF6),
      'Email' => const Color(0xFFDB2777),
      'Organic Video' || 'Paid Video' => const Color(0xFFEF4444),
      _ => c.textFaint,
    };

/// Channel names as shown to the user.
String channelLabel(String channel) => tr(switch (channel) {
      'Paid Social' => 'Paid social',
      'Organic Social' => 'Social',
      'Organic Search' => 'Search',
      'Paid Search' => 'Paid search',
      'Organic Video' => 'Video',
      'Paid Video' => 'Paid video',
      'Unknown' || '' => 'Other',
      _ => channel,
    });
