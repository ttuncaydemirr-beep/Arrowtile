// Arrowtile — daily_dialogs.dart: günlük ödül penceresi (7 günlük döngü) ve günlük bulmaca takvimi.
import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/daily.dart' as daily;
import '../../core/economy.dart' as eco;
import '../../l10n/app_localizations.dart';
import '../../state/app_controller.dart';
import '../../state/app_scope.dart';
import '../flow.dart';
import '../tokens.dart';
import '../widgets.dart';

// ---------------------------------------------------------------- günlük ödül
Future<void> openDailyReward(BuildContext context) => showSheet<void>(context, builder: (BuildContext ctx) => const _DailyRewardBody());

class _DailyRewardBody extends StatelessWidget {
  const _DailyRewardBody();

  @override
  Widget build(BuildContext context) {
    final AppController app = AppScope.of(context);
    final AppLocalizations loc = locOf(context);
    final Palette pal = Palette.of(context);
    final eco.DailyStatus st = eco.dailyStatus(app.save, app.today());
    final int activeDay = st.canClaim ? st.day : (app.save.daily.streakDay == 0 ? 1 : app.save.daily.streakDay);

    Widget box(int d) {
      final bool past = st.canClaim ? d < st.day : (d < activeDay || (st.claimedToday && d == activeDay));
      final bool today = d == activeDay;
      final Color fg = today ? kOnGold : pal.inkC;
      final Widget content = Column(mainAxisAlignment: MainAxisAlignment.center, mainAxisSize: MainAxisSize.min, children: <Widget>[
        Text(loc.dailyDay(d), style: TextStyle(color: fg, fontSize: 13, fontWeight: FontWeight.w700)),
        const SizedBox(height: 2),
        Icon(Icons.monetization_on, size: 24, color: pal.coinInkC),
        Text('${eco.kDailyRewards[d - 1]}', style: TextStyle(color: fg, fontSize: 16, fontWeight: FontWeight.w700)),
        if (d == 7) Text(loc.dailyBonusHint, textAlign: TextAlign.center, style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.w700)),
        if (past) Icon(Icons.check, size: 20, color: fg),
      ]);
      return Opacity(
        opacity: past && !today ? 0.55 : 1,
        child: Container(
          constraints: const BoxConstraints(minHeight: 76),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          decoration: BoxDecoration(
            color: today ? pal.starC : pal.cellC,
            borderRadius: BorderRadius.circular(14),
            border: today ? Border.all(color: pal.accentC, width: 3) : null,
          ),
          child: Center(child: content),
        ),
      );
    }

    return Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
      sheetTitle(context, loc.dailyTitle),
      if (st.streakLost) sheetText(context, loc.dailyStreakLost),
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Column(children: <Widget>[
          Row(children: <Widget>[for (int d = 1; d <= 4; d++) ...<Widget>[if (d > 1) const SizedBox(width: 8), Expanded(child: box(d))]]),
          const SizedBox(height: 8),
          Row(children: <Widget>[
            Expanded(child: box(5)),
            const SizedBox(width: 8),
            Expanded(child: box(6)),
            const SizedBox(width: 8),
            Expanded(flex: 2, child: box(7)),
          ]),
        ]),
      ),
      if (!st.canClaim)
        sheetText(context, st.claimedToday ? '${loc.dailyClaimed} · ${loc.dailyComeBack}' : loc.dailyComeBack),
      actionsColumn(<Widget>[
        if (st.canClaim)
          AppButton(loc.dailyClaim, kind: BtnKind.primary, onTap: () {
            final eco.ClaimResult? r = eco.claimDaily(app.save, app.today());
            if (r != null) {
              app.commit();
              app.sfx.coin();
              app.buzz('levelWin');
              app.toast(loc.endReward(r.coins) + (r.hint > 0 ? ' · ${loc.dailyBonusHint}' : ''));
            }
          }),
        AppButton(loc.commonClose, onTap: () => Navigator.of(context).pop()),
      ]),
    ]);
  }
}

// ---------------------------------------------------------------- günlük bulmaca takvimi
Future<void> openCalendar(BuildContext context) =>
    showSheet<void>(context, builder: (BuildContext ctx) => _CalendarBody(caller: context));

String dayLabel(AppLocalizations loc, String ymd) {
  final List<String> p = ymd.split('-');
  final List<String> months = loc.calMonths.split(',');
  final int m = int.parse(p[1]);
  return '${int.parse(p[2])} ${m >= 1 && m <= months.length ? months[m - 1] : m}';
}

class DpStats extends StatelessWidget {
  final daily.StreakInfo info;
  const DpStats(this.info, {super.key});
  @override
  Widget build(BuildContext context) {
    final AppLocalizations loc = locOf(context);
    final Palette pal = Palette.of(context);
    Widget chip(String t) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(color: pal.cellC, border: pal.hcBorder, borderRadius: BorderRadius.circular(999)),
          child: Text(t, style: TextStyle(color: pal.inkC, fontSize: 14, fontWeight: FontWeight.w700)),
        );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Wrap(alignment: WrapAlignment.center, spacing: 6, runSpacing: 6, children: <Widget>[
        chip(loc.dpStreak(info.current)),
        chip(loc.dpBest(info.best)),
        chip(loc.dpTrophies(info.trophies)),
      ]),
    );
  }
}

class _CalendarBody extends StatefulWidget {
  /// Pencereyi açan ekranın bağlamı (pencere kapandıktan sonra da geçerlidir; günlük bulmacayı başlatmak için).
  final BuildContext caller;
  const _CalendarBody({required this.caller});
  @override
  State<_CalendarBody> createState() => _CalendarBodyState();
}

class _CalendarBodyState extends State<_CalendarBody> {
  String? _month; // 'YYYY-MM'

  @override
  Widget build(BuildContext context) {
    final AppController app = AppScope.of(context);
    final AppLocalizations loc = locOf(context);
    final Palette pal = Palette.of(context);
    final String today = app.today();
    final daily.StreakInfo info = daily.streakInfo(app.save.dp, today);
    final String month = _month ?? today.substring(0, 7);
    final int y = int.parse(month.substring(0, 4));
    final int m = int.parse(month.substring(5, 7));
    final List<String> months = loc.calMonths.split(',');
    String two(int v) => v < 10 ? '0$v' : '$v';
    final String pm = m == 1 ? '${y - 1}-12' : '$y-${two(m - 1)}';
    final String nm = m == 12 ? '${y + 1}-01' : '$y-${two(m + 1)}';
    final bool nextDisabled = nm.compareTo(today.substring(0, 7)) > 0;
    final int lead = daily.weekdayIndex('$month-01');
    final int days = DateTime.utc(y, m + 1, 0).day;

    Widget navBtn(IconData icon, bool mirror, bool disabled, VoidCallback onTap, String label) {
      return Opacity(
        opacity: disabled ? 0.35 : 1,
        child: Semantics(
          button: true,
          label: label,
          child: Pressable(
            onTap: disabled ? null : onTap,
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: pal.boardC,
                border: pal.hcBorder,
                borderRadius: BorderRadius.circular(14),
                boxShadow: <BoxShadow>[BoxShadow(color: pal.edgeC, offset: const Offset(0, 3))],
              ),
              child: Icon(icon, color: pal.inkC),
            ),
          ),
        ),
      );
    }

    final List<Widget> cells = <Widget>[
      for (final String w in loc.calWeekdays.split(','))
        Center(child: Text(w, maxLines: 1, style: TextStyle(color: pal.inkSoftC, fontSize: 11, fontWeight: FontWeight.w700))),
      for (int k = 0; k < lead; k++) const SizedBox.shrink(),
      for (int d = 1; d <= days; d++) _dayCell(pal, '$month-${two(d)}', d, app, today),
    ];

    return Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
      sheetTitle(context, loc.dpTitle),
      Padding(
        padding: const EdgeInsets.fromLTRB(0, 4, 0, 8),
        child: Row(children: <Widget>[
          navBtn(Icons.arrow_back, false, false, () => setState(() => _month = pm), loc.commonBack),
          Expanded(
            child: Text('${months[m - 1]} $y',
                textAlign: TextAlign.center, style: TextStyle(color: pal.inkC, fontSize: 18, fontWeight: FontWeight.w700)),
          ),
          // sonraki ay: simge aynalanır (sol ok yerine sağ ok)
          navBtn(Icons.arrow_forward, true, nextDisabled, () => setState(() => _month = nm), loc.endNext),
        ]),
      ),
      GridView.count(
        crossAxisCount: 7,
        mainAxisSpacing: 4,
        crossAxisSpacing: 4,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        childAspectRatio: 1,
        children: cells,
      ),
      DpStats(info),
      if (info.doneToday) sheetText(context, '${loc.dpDone} ${loc.dpComeBack}'),
      actionsColumn(<Widget>[
        AppButton(info.doneToday ? loc.endReplay : loc.dpPlay,
            kind: info.doneToday ? BtnKind.secondary : BtnKind.primary,
            onTap: () {
              final BuildContext caller = widget.caller;
              Navigator.of(context).pop();
              if (caller.mounted) unawaited(startDaily(caller));
            }),
        AppButton(loc.commonClose, kind: BtnKind.ghost, onTap: () => Navigator.of(context).pop()),
      ]),
    ]);
  }

  Widget _dayCell(Palette pal, String ymd, int d, AppController app, String today) {
    final bool done = (app.save.dp.done[ymd] ?? 0) > 0;
    final bool isToday = ymd == today;
    final bool future = ymd.compareTo(today) > 0;
    final Color bg = done ? Color.alphaBlend(rgba(pal.star, 0.28), pal.cellC) : pal.cellC;
    return Opacity(
      opacity: future ? 0.45 : 1,
      child: Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(10),
          border: isToday ? Border.all(color: pal.accentC, width: 3) : null,
        ),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: <Widget>[
          Text('$d', style: TextStyle(color: pal.inkC, fontSize: 14, fontWeight: FontWeight.w700)),
          if (done) Icon(Icons.emoji_events, size: 16, color: pal.starInkC),
        ]),
      ),
    );
  }
}
