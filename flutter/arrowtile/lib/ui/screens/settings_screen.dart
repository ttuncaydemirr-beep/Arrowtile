// Arrowtile — settings_screen.dart: Ayarlar (ses, titreşim, oynanış, görünüm, dil, destek, yedek, reklamlar, gizlilik, sıfırla).
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/ads_config.dart';
import '../../core/save_data.dart' show kLangs;
import '../../l10n/app_localizations.dart';
import '../../l10n/l10n_lookup.dart';
import '../../state/app_controller.dart';
import '../../state/app_scope.dart';
import '../flow.dart';
import '../tokens.dart';
import '../widgets.dart';
import 'diag_screen.dart';
import 'privacy_screen.dart';
import 'shop_screen.dart' show AdsCard;

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final AppController app = AppScope.of(context);
    final AppLocalizations loc = locOf(context);
    final Palette pal = Palette.of(context);
    return ScreenScaffold(
      child: Column(children: <Widget>[
        ScreenBar(title: loc.settingsTitle, onBack: () => Navigator.of(context).maybePop()),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            children: <Widget>[
              _Group(children: <Widget>[
                _SwitchRow(label: loc.settingsSound, value: app.save.sound, onChanged: app.setSound),
                _SwitchRow(label: loc.settingsVibration, value: app.save.vibration, onChanged: app.setVibration),
              ]),
              _Group(label: loc.settingsGameplay, children: <Widget>[
                _SwitchRow(label: loc.settingsRelaxed, desc: loc.settingsRelaxedDesc, value: app.save.relaxed, onChanged: app.setRelaxed),
                _SwitchRow(label: loc.settingsAim, desc: loc.settingsAimDesc, value: app.save.aim, onChanged: app.setAim),
              ]),
              _Group(label: loc.settingsAppearance, children: <Widget>[
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(color: pal.cellC, borderRadius: BorderRadius.circular(14)),
                    child: Row(children: <Widget>[
                      for (final String m in <String>['auto', 'light', 'dark']) ...<Widget>[
                        if (m != 'auto') const SizedBox(width: 6),
                        Expanded(child: _SegBtn(
                          label: m == 'auto' ? loc.settingsAppAuto : (m == 'light' ? loc.settingsAppLight : loc.settingsAppDark),
                          on: app.save.appearance == m,
                          onTap: () {
                            app.sfx.button();
                            app.setAppearance(m);
                          },
                        )),
                      ],
                    ]),
                  ),
                ),
                // 1.2.0 (docs/17 §13): ok rengi — Renkli (varsayılan) / Tek renk (ince çizgi; açık temada koyu, koyu temada açık). Kalıcı.
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(loc.settingsArrowColor, style: TextStyle(color: pal.inkC, fontSize: 17, fontWeight: FontWeight.w700)),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(color: pal.cellC, borderRadius: BorderRadius.circular(14)),
                    child: Row(children: <Widget>[
                      for (final String m in <String>['color', 'mono']) ...<Widget>[
                        if (m != 'color') const SizedBox(width: 6),
                        Expanded(
                            child: _SegBtn(
                          key: ValueKey<String>('ac-$m'),
                          label: m == 'color' ? loc.settingsAcColor : loc.settingsAcMono,
                          lead: _ArrowColorPreview(mono: m == 'mono'),
                          on: app.save.arrowColor == m,
                          onTap: () {
                            app.sfx.button();
                            app.setArrowColor(m);
                          },
                        )),
                      ],
                    ]),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(loc.settingsArrowColorDesc, style: TextStyle(color: pal.inkSoftC, fontSize: 14)),
                ),
              ]),
              _Group(label: loc.settingsLanguage, children: <Widget>[
                Padding(
                  padding: const EdgeInsets.fromLTRB(0, 10, 0, 12),
                  child: Column(children: <Widget>[
                    for (int r = 0; r < 2; r++) ...<Widget>[
                      if (r > 0) const SizedBox(height: 8),
                      Row(children: <Widget>[
                        for (int c = 0; c < 2; c++) ...<Widget>[
                          if (c > 0) const SizedBox(width: 8),
                          Expanded(child: _LangBtn(lang: kLangs[r * 2 + c])),
                        ],
                      ]),
                    ],
                  ]),
                ),
              ]),
              _Group(label: loc.settingsSupport, children: <Widget>[
                Padding(
                  padding: const EdgeInsets.fromLTRB(0, 10, 0, 6),
                  child: Text(loc.settingsSupportText, style: TextStyle(color: pal.inkSoftC, fontSize: 17)),
                ),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: GestureDetector(
                    onTap: () => unawaited(_mail(loc)),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(0, 8, 0, 12),
                      child: Directionality(
                        textDirection: TextDirection.ltr,
                        child: Text(AppInfo.supportEmail,
                            style: TextStyle(color: pal.accentC, fontSize: 15, fontWeight: FontWeight.w800, decoration: TextDecoration.underline)),
                      ),
                    ),
                  ),
                ),
              ]),
              _Group(label: loc.settingsBackup, children: <Widget>[
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Row(children: <Widget>[
                    Expanded(child: AppButton(loc.settingsExport, onTap: () => unawaited(_openExport(context)))),
                    const SizedBox(width: 10),
                    Expanded(child: AppButton(loc.settingsImport, onTap: () => unawaited(_openImport(context)))),
                  ]),
                ),
              ]),
              _Group(label: loc.adsSection, children: <Widget>[
                const Padding(padding: EdgeInsets.only(top: 8), child: AdsCard(where: 'set', embedded: true)),
                // UMP "Gizlilik seçenekleri": yalnızca bölge gerektiriyorsa (AEA/BK/İsviçre …) görünür
                if (app.mon.privacyOptionsRequired)
                  Padding(
                    padding: const EdgeInsets.only(top: 6, bottom: 12),
                    child: AppButton(loc.adsPrivacyOptions, onTap: () => unawaited(app.mon.showPrivacyOptions().then((bool _) => app.commit()))),
                  )
                else
                  const SizedBox(height: 12),
              ]),
              AppButton(loc.privacyTitle, onTap: () => Navigator.of(context).push(fadeRoute<void>(const PrivacyScreen()))),
              const SizedBox(height: 14),
              AppButton(loc.settingsReset, kind: BtnKind.danger, onTap: () {
                confirmBox(context, loc.settingsResetConfirm, () {
                  app.resetAll();
                  app.toast(loc.settingsResetDone);
                }, yesLabel: loc.settingsReset, danger: true);
              }),
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 14, 8, 4),
                child: Text(loc.settingsPrivacy, textAlign: TextAlign.center, style: TextStyle(color: pal.inkSoftC, fontSize: 14)),
              ),
              // 1.1.4 (docs/21): sürüm metnine 7 kez dokununca gizli "Tanılama" ekranı açılır
              _VersionTap(
                child: Text(loc.settingsVersion(AppInfo.version), textAlign: TextAlign.center, style: TextStyle(color: pal.inkSoftC, fontSize: 13)),
              ),
              // 1.2.0: açık kaynak lisansları (Readex Pro OFL 1.1 + Flutter paketleri)
              Center(
                child: TextButton(
                  key: const ValueKey<String>('btn-licenses'),
                  onPressed: () => showLicensePage(context: context, applicationName: loc.appName, applicationVersion: AppInfo.version),
                  child: Text(loc.settingsLicenses, style: TextStyle(color: pal.accentC, fontSize: 14, fontWeight: FontWeight.w700)),
                ),
              ),
              if (AdsConfig.usingTestIdsInRelease)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text('AdMob: test kimlikleri (lib/config/ads_config.dart)',
                      textAlign: TextAlign.center, style: TextStyle(color: pal.coinC, fontSize: 12)),
                ),
            ],
          ),
        ),
      ]),
    );
  }

  Future<void> _mail(AppLocalizations loc) async {
    final Uri u = Uri.parse('mailto:${AppInfo.supportEmail}?subject=${Uri.encodeComponent('${loc.appName} ${AppInfo.version}')}');
    try {
      await launchUrl(u, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }
}

/// Sürüm metni: 3 sn içinde 7 dokunuş → Tanılama.
class _VersionTap extends StatefulWidget {
  final Widget child;
  const _VersionTap({required this.child});
  @override
  State<_VersionTap> createState() => _VersionTapState();
}

class _VersionTapState extends State<_VersionTap> {
  int _n = 0;
  DateTime _first = DateTime.fromMillisecondsSinceEpoch(0);

  void _tap() {
    final DateTime now = DateTime.now();
    if (now.difference(_first) > const Duration(seconds: 3)) {
      _first = now;
      _n = 0;
    }
    _n++;
    if (_n >= 7) {
      _n = 0;
      Navigator.of(context).push(fadeRoute<void>(const DiagScreen()));
    }
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
        key: const ValueKey<String>('version-tap'),
        behavior: HitTestBehavior.opaque,
        onTap: _tap,
        child: Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: widget.child),
      );
}

// ---- yedek: dışa / içe aktar (G6)
Future<void> _openExport(BuildContext context) {
  final AppController app = AppScope.read(context);
  final AppLocalizations loc = AppLocalizations.of(context);
  final String code = app.exportBackupCode();
  return showSheet<void>(context, builder: (BuildContext ctx) {
    return Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
      sheetTitle(ctx, loc.settingsExport),
      sheetText(ctx, loc.backupExportText),
      _CodeBox(controller: TextEditingController(text: code), readOnly: true, label: loc.settingsBackup),
      actionsRow(<Widget>[
        AppButton(loc.commonClose, onTap: () => Navigator.of(ctx).pop()),
        AppButton(loc.backupCopy, kind: BtnKind.primary, onTap: () async {
          await Clipboard.setData(ClipboardData(text: code));
          app.sfx.button();
          app.toast(loc.backupCopied);
        }),
      ]),
    ]);
  });
}

Future<void> _openImport(BuildContext context) {
  final AppController app = AppScope.read(context);
  final AppLocalizations loc = AppLocalizations.of(context);
  final TextEditingController tc = TextEditingController();
  return showSheet<void>(context, builder: (BuildContext ctx) {
    return Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
      sheetTitle(ctx, loc.settingsImport),
      sheetText(ctx, loc.backupImportText),
      _CodeBox(controller: tc, readOnly: false, label: loc.settingsImport),
      actionsRow(<Widget>[
        AppButton(loc.commonCancel, onTap: () => Navigator.of(ctx).pop()),
        AppButton(loc.settingsImport, kind: BtnKind.primary, onTap: () {
          final String code = tc.text;
          if (!app.isValidBackupCode(code)) {
            app.sfx.error();
            app.buzz('error');
            app.toast(loc.backupInvalid);
            return;
          }
          confirmBox(ctx, loc.backupImportConfirm, () {
            if (!app.importBackup(code)) {
              app.toast(loc.backupInvalid);
              return;
            }
            Navigator.of(ctx).pop(); // içe aktarma penceresini kapat
            app.sfx.coin();
            app.toast(loc.backupImported);
          }, yesLabel: loc.settingsImport);
        }),
      ]),
    ]);
  });
}

class _CodeBox extends StatelessWidget {
  final TextEditingController controller;
  final bool readOnly;
  final String label;
  const _CodeBox({required this.controller, required this.readOnly, required this.label});
  @override
  Widget build(BuildContext context) {
    final Palette pal = Palette.of(context);
    return Directionality(
      textDirection: TextDirection.ltr,
      child: TextField(
        controller: controller,
        readOnly: readOnly,
        minLines: 4,
        maxLines: 4,
        autocorrect: false,
        enableSuggestions: false,
        style: TextStyle(color: pal.inkC, fontSize: 13, fontWeight: FontWeight.w600, fontFamily: 'monospace'),
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: pal.cellC,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: pal.edgeC, width: 2)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: pal.edgeC, width: 2)),
        ),
      ),
    );
  }
}

class _Group extends StatelessWidget {
  final String? label;
  final List<Widget> children;
  const _Group({this.label, required this.children});
  @override
  Widget build(BuildContext context) {
    final Palette pal = Palette.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        decoration: BoxDecoration(
          color: pal.boardC,
          borderRadius: BorderRadius.circular(18),
          boxShadow: <BoxShadow>[BoxShadow(color: pal.edgeC, offset: const Offset(0, 3))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[
          if (label != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(label!, style: TextStyle(color: pal.inkC, fontSize: 17, fontWeight: FontWeight.w800)),
            ),
          ...children,
        ]),
      ),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  final String label;
  final String? desc;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _SwitchRow({required this.label, required this.value, required this.onChanged, this.desc});
  @override
  Widget build(BuildContext context) {
    final Palette pal = Palette.of(context);
    return Semantics(
      toggled: value,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onChanged(!value),
        child: Container(
          constraints: const BoxConstraints(minHeight: 60),
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(children: <Widget>[
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: <Widget>[
                Text(label, style: TextStyle(color: pal.inkC, fontSize: 17, fontWeight: FontWeight.w700)),
                if (desc != null) Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(desc!, style: TextStyle(color: pal.inkSoftC, fontSize: 13, fontWeight: FontWeight.w600)),
                ),
              ]),
            ),
            const SizedBox(width: 12),
            AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              width: 60,
              height: 34,
              padding: const EdgeInsets.all(3),
              alignment: value ? AlignmentDirectional.centerEnd : AlignmentDirectional.centerStart,
              decoration: BoxDecoration(color: value ? pal.successC : pal.starEmptyC, borderRadius: BorderRadius.circular(999)),
              child: Container(
                width: 28,
                height: 28,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: <BoxShadow>[BoxShadow(color: Color(0x40000000), blurRadius: 3, offset: Offset(0, 2))],
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

class _SegBtn extends StatelessWidget {
  final String label;
  final bool on;
  final VoidCallback onTap;
  final Widget? lead; // 1.2.0: ok rengi önizlemesi
  const _SegBtn({super.key, required this.label, required this.on, required this.onTap, this.lead});
  @override
  Widget build(BuildContext context) {
    final Palette pal = Palette.of(context);
    return Semantics(
      button: true,
      selected: on,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 46),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: on ? pal.boardC : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: on ? <BoxShadow>[BoxShadow(color: pal.edgeC, offset: const Offset(0, 2))] : null,
          ),
          child: withSelectedMark(
              pal,
              lead == null
                  ? FitText(label, style: TextStyle(color: pal.inkC, fontSize: 16, fontWeight: FontWeight.w800), minFont: 12, maxLines: 3)
                  : Row(mainAxisAlignment: MainAxisAlignment.center, children: <Widget>[
                      lead!,
                      const SizedBox(width: 8),
                      Flexible(child: FitText(label, style: TextStyle(color: pal.inkC, fontSize: 16, fontWeight: FontWeight.w800), minFont: 12, maxLines: 2)),
                    ]),
              on),
        ),
      ),
    );
  }
}

/// Ok rengi önizlemesi: üç kısa çizgi (renkli: tema renkleri; tek renk: mürekkep rengi, ince).
class _ArrowColorPreview extends StatelessWidget {
  final bool mono;
  const _ArrowColorPreview({required this.mono});
  @override
  Widget build(BuildContext context) {
    final Palette pal = Palette.of(context);
    final List<int> cols = arrowThemeById(AppScope.of(context).save.theme).colors;
    return ExcludeSemantics(
      child: Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
        for (int i = 0; i < 3; i++)
          Container(
            margin: const EdgeInsets.symmetric(vertical: 1.5),
            width: 22,
            height: mono ? 2 : 4,
            decoration: BoxDecoration(color: mono ? pal.inkC : rgba(cols[i % cols.length]), borderRadius: BorderRadius.circular(2)),
          ),
      ]),
    );
  }
}

class _LangBtn extends StatelessWidget {
  final String lang;
  const _LangBtn({required this.lang});
  @override
  Widget build(BuildContext context) {
    final AppController app = AppScope.of(context);
    final AppLocalizations loc = locOf(context);
    final Palette pal = Palette.of(context);
    final bool on = app.lang == lang;
    return Semantics(
      button: true,
      selected: on,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          app.sfx.button();
          app.setLang(lang);
        },
        child: Container(
          constraints: const BoxConstraints(minHeight: 52),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: on ? pal.boardC : pal.cellC,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: on ? pal.accentC : Colors.transparent, width: 2),
          ),
          // her dil kendi yazı yönüyle (Arapça RTL) ve kendi adıyla gösterilir
          child: Directionality(
            textDirection: lang == 'ar' ? TextDirection.rtl : TextDirection.ltr,
            child: Text(langEndonym(loc, lang),
                style: TextStyle(color: pal.inkC, fontSize: lang == 'ar' ? 18 : 17, fontWeight: FontWeight.w800)),
          ),
        ),
      ),
    );
  }
}
