// Arrowtile — privacy_screen.dart: oyun içi gizlilik politikası (4 dil; metinler ARB'de, game/js/privacy.js ile aynı).
import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/ads_config.dart';
import '../../l10n/app_localizations.dart';
import '../tokens.dart';
import '../widgets.dart';

final RegExp _urlRe = RegExp(r'https://[^\s<>"]+');

/// Metni (parça, bağlantı mı) çiftlerine böler: https:// adresleri bağlantıdır (web privacy.js fillLinked ile aynı kural).
List<(String, bool)> splitLinks(String text) {
  final List<(String, bool)> out = <(String, bool)>[];
  int last = 0;
  for (final RegExpMatch m in _urlRe.allMatches(text)) {
    if (m.start > last) out.add((text.substring(last, m.start), false));
    out.add((m[0]!, true));
    last = m.end;
  }
  if (last < text.length) out.add((text.substring(last), false));
  return out;
}

/// Gizlilik paragrafı: içindeki https:// adresleri (Google iş ortağı veri kullanımı sayfası) dokunulabilir bağlantıdır; adres RTL
/// metinde de soldan sağa okunur (LRI … PDI yalıtımı).
class LinkedParagraph extends StatefulWidget {
  final String text;
  final TextStyle style;
  final Color linkColor;
  const LinkedParagraph(this.text, {super.key, required this.style, required this.linkColor});

  @override
  State<LinkedParagraph> createState() => _LinkedParagraphState();
}

class _LinkedParagraphState extends State<LinkedParagraph> {
  final List<TapGestureRecognizer> _rec = <TapGestureRecognizer>[];

  @override
  void dispose() {
    for (final TapGestureRecognizer r in _rec) {
      r.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    for (final TapGestureRecognizer r in _rec) {
      r.dispose();
    }
    _rec.clear();
    final List<InlineSpan> spans = <InlineSpan>[];
    for (final (String part, bool link) in splitLinks(widget.text)) {
      if (!link) {
        spans.add(TextSpan(text: part));
        continue;
      }
      final TapGestureRecognizer r = TapGestureRecognizer()
        ..onTap = () => unawaited(launchUrl(Uri.parse(part), mode: LaunchMode.externalApplication).then<void>((bool _) {}, onError: (Object _) {}));
      _rec.add(r);
      spans.add(TextSpan(
        text: '\u2066$part\u2069',
        recognizer: r,
        style: TextStyle(color: widget.linkColor, fontWeight: FontWeight.w700, decoration: TextDecoration.underline),
      ));
    }
    return Text.rich(TextSpan(children: spans), style: widget.style);
  }
}

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final AppLocalizations loc = locOf(context);
    final Palette pal = Palette.of(context);
    final List<List<String>> sections = <List<String>>[
      <String>[loc.privacyHData, loc.privacyPData],
      <String>[loc.privacyHAds, loc.privacyPAds],
      <String>[loc.privacyHAnalytics, loc.privacyPAnalytics],
      <String>[loc.privacyHBuy, loc.privacyPBuy],
      <String>[loc.privacyHDelete, loc.privacyPDelete],
      <String>[loc.privacyHContact, loc.privacyPContact],
    ];
    return ScreenScaffold(
      child: Column(children: <Widget>[
        ScreenBar(title: loc.privacyTitle, onBack: () => Navigator.of(context).maybePop()),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            children: <Widget>[
              // tarih RTL'de de soldan sağa (LRI … PDI yalıtım: \u2066 … \u2069)
              Text(loc.privacyUpdated('\u2066${AppInfo.privacyUpdated}\u2069'), style: TextStyle(color: pal.inkSoftC, fontSize: 14)),
              for (final List<String> s in sections) ...<Widget>[
                Padding(
                  padding: const EdgeInsets.only(top: 18, bottom: 6),
                  child: Text(s[0], style: TextStyle(color: pal.inkC, fontSize: 18, fontWeight: FontWeight.w800)),
                ),
                LinkedParagraph(s[1], style: TextStyle(color: pal.inkC, fontSize: 17, height: 1.45), linkColor: pal.accentC),
              ],
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: GestureDetector(
                  onTap: () => unawaited(_mail(loc)),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(0, 8, 0, 16),
                    child: Directionality(
                      textDirection: TextDirection.ltr,
                      child: Text(AppInfo.supportEmail,
                          style: TextStyle(color: pal.accentC, fontSize: 15, fontWeight: FontWeight.w800, decoration: TextDecoration.underline)),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ]),
    );
  }

  Future<void> _mail(AppLocalizations loc) async {
    final String subject = Uri.encodeComponent('${loc.appName} — ${loc.privacyTitle}');
    try {
      await launchUrl(Uri.parse('mailto:${AppInfo.supportEmail}?subject=$subject'), mode: LaunchMode.externalApplication);
    } catch (_) {}
  }
}
