// Arrowtile — privacy_screen.dart: oyun içi gizlilik politikası (4 dil; metinler ARB'de, game/js/privacy.js ile aynı).
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/ads_config.dart';
import '../../l10n/app_localizations.dart';
import '../tokens.dart';
import '../widgets.dart';

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final AppLocalizations loc = locOf(context);
    final Palette pal = Palette.of(context);
    final List<List<String>> sections = <List<String>>[
      <String>[loc.privacyHData, loc.privacyPData],
      <String>[loc.privacyHAds, loc.privacyPAds],
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
              // tarih RTL'de de soldan sağa (⁦ … ⁩ yalıtım)
              Text(loc.privacyUpdated('⁦${AppInfo.privacyUpdated}⁩'), style: TextStyle(color: pal.inkSoftC, fontSize: 14)),
              for (final List<String> s in sections) ...<Widget>[
                Padding(
                  padding: const EdgeInsets.only(top: 18, bottom: 6),
                  child: Text(s[0], style: TextStyle(color: pal.inkC, fontSize: 18, fontWeight: FontWeight.w800)),
                ),
                Text(s[1], style: TextStyle(color: pal.inkC, fontSize: 17, height: 1.45)),
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
