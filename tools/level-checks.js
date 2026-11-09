// Arrowtile — tek seviye için ortak denetimler (tools/validate-levels.js ve tools/verify-5000.js kullanır).
// BAĞIMLI OLMAYAN çözücü (tools/solver.js) ile yapı, çözülebilirlik, par, ızgara planı, kademe bandı, başta çıkabilen.
'use strict';
const S = require('./solver');
const LG = require('../game/js/levelgen.js');

/** lv: { id, w, h, par, diff, arrows } → { errs: [...], m: LG.measure(lv), tier, spec } */
function checkLevelData(lv) {
  const errs = [];
  const id = lv.id, tier = LG.tierOf(id), T = LG.TIERS[tier], sp = LG.specFor(id);
  const se = S.checkStructure(lv); if (se.length) errs.push('yapı: ' + se.join(', '));
  const sol = S.solve(lv), m = LG.measure(lv);
  if (!sol.solvable || !m.solvable) errs.push('çözülemez');
  else if (sol.layers !== m.depth || sol.initialFree !== m.initialFree) errs.push(`çözücüler uyuşmuyor (derinlik ${sol.layers}/${m.depth})`);
  if (lv.diff !== tier) errs.push(`etiket "${lv.diff}" ama seviye ${id} kademesi "${tier}"`);
  if (lv.par !== lv.arrows.length) errs.push(`par (${lv.par}) != ok sayısı (${lv.arrows.length})`);
  if (id <= LG.TUTORIAL.length) {
    if (lv.w > 5 || lv.h > 5 || lv.arrows.length < 2 || lv.arrows.length > 4 || lv.arrows.some(a => LG.isCurved(a))) errs.push('öğretici seviye sınırı (küçük, düz oklar)');
  } else if (m.solvable) {
    if (lv.w !== sp.w || lv.h !== sp.h) errs.push(`ızgara ${lv.w}x${lv.h} ≠ plan ${sp.w}x${sp.h}`);
    if (m.fill < T.band[0] - 1e-9 || m.fill > T.band[1] + 1e-9) errs.push(`doluluk %${(m.fill * 100).toFixed(1)} bant dışı (%${(T.band[0] * 100).toFixed(0)}–${(T.band[1] * 100).toFixed(0)})`);
    const lim = Math.max(1, Math.floor(T.maxFree * m.arrows + 1e-9));
    if (m.initialFree > lim) errs.push(`başta çıkabilen ${m.initialFree} > ${lim} (%${T.maxFree * 100})`);
    if (id === 4 && !lv.arrows.some(a => LG.isCurved(a))) errs.push('seviye 4 kıvrımlı ok içermiyor');
  }
  return { errs, m, tier, spec: sp, inWindow: m.solvable && m.depth >= (sp.minDepth || 0) && (sp.maxDepth == null || m.depth <= sp.maxDepth) };
}
// Kıvrımlı oran: kademe ortalaması hedefin en çok bu kadar altında olabilir. Yoğun %88–93 tahtada 1–2 hücrelik dolgu okları
// oranı sınırlar (ölçülen Aşırı zor ≈ %52–55, hedef %65); önceki sürümdeki sınır 0,12 idi, Aşırı zor için 0,15.
const CURVE_TOL = { easy: 0.12, medium: 0.12, hard: 0.12, extreme: 0.15 };
module.exports = { checkLevelData, CURVE_TOL };
