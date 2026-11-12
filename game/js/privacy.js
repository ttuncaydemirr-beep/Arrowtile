/* Arrowtile — privacy.js: gizlilik politikası metni (4 dil, i18n.js'ten).
 * Hem oyun içi "Gizlilik politikası" ekranı (main.js) hem de bağımsız privacy.html bu oluşturucuyu kullanır,
 * böylece mağazada yayımlanacak metin ile oyun içindeki metin her zaman aynıdır.
 */
(function () {
  'use strict';
  var EMAIL = 'nilkaren.tuncay.demir@gmail.com';
  var UPDATED = '2026-11-12'; // 1.2.1: geliştirici adı (Demir Games Studio) eklendi
  var SECTIONS = [['privacy.h_data', 'privacy.p_data'], ['privacy.h_ads', 'privacy.p_ads'], ['privacy.h_analytics', 'privacy.p_analytics'], ['privacy.h_buy', 'privacy.p_buy'],
                  ['privacy.h_delete', 'privacy.p_delete'], ['privacy.h_contact', 'privacy.p_contact']];
  // Metindeki https:// adresleri tıklanabilir bağlantı olur (Google iş ortağı veri kullanımı sayfası); bağlantı RTL metinde de soldan sağa okunur
  function fillLinked(p, text) {
    var re = /https:\/\/[^\s<>"]+/g, last = 0, m;
    while ((m = re.exec(text))) {
      if (m.index > last) p.appendChild(document.createTextNode(text.slice(last, m.index)));
      var a = document.createElement('a'); a.href = m[0]; a.textContent = m[0]; a.rel = 'noopener noreferrer'; a.target = '_blank'; a.className = 'privacy-link';
      a.setAttribute('dir', 'ltr'); a.style.unicodeBidi = 'isolate'; a.style.overflowWrap = 'anywhere';
      p.appendChild(a); last = m.index + m[0].length;
    }
    if (last < text.length) p.appendChild(document.createTextNode(text.slice(last)));
  }
  /** container'ı temizleyip metni yazar. t(key, vars) çeviri fonksiyonu. */
  function renderPrivacy(container, t) {
    container.textContent = '';
    var up = document.createElement('p'); up.className = 'privacy-updated'; up.textContent = t('privacy.updated', { v: '\u2066' + UPDATED + '\u2069' }); // tarih RTL'de de soldan sağa
    container.appendChild(up);
    SECTIONS.forEach(function (s) {
      var h = document.createElement('h3'); h.textContent = t(s[0]); container.appendChild(h);
      var p = document.createElement('p'); fillLinked(p, t(s[1])); container.appendChild(p);
    });
    var a = document.createElement('a'); a.href = 'mailto:' + EMAIL + '?subject=' + encodeURIComponent(t('app.name') + ' — ' + t('privacy.title'));
    a.textContent = EMAIL; a.className = 'privacy-mail'; container.appendChild(a);
  }
  window.renderPrivacy = renderPrivacy;
  window.PRIVACY_EMAIL = EMAIL;

  // Bağımsız sayfa (privacy.html): dil ?lang= parametresinden ya da cihaz dilinden
  if (document.documentElement.getAttribute('data-page') === 'privacy') {
    var LANGS = ['tr', 'en', 'de', 'ar'], lang = 'en';
    try {
      var q = /(?:^|[?&])lang=([a-z]{2})/.exec(location.search.slice(1));
      var nl = String(navigator.language || '').slice(0, 2).toLowerCase();
      lang = q && LANGS.indexOf(q[1]) >= 0 ? q[1] : (LANGS.indexOf(nl) >= 0 ? nl : 'en');
    } catch (e) {}
    var D = (window.I18N && (window.I18N[lang] || window.I18N.en)) || {};
    var t = function (k, v) { var s = D[k] || k; if (v) Object.keys(v).forEach(function (x) { s = s.split('{' + x + '}').join(String(v[x])); }); return s; };
    if (window.THEME) window.THEME.applyLang(lang);
    document.title = t('app.name') + ' — ' + t('privacy.title');
    document.getElementById('title').textContent = t('privacy.title');
    document.getElementById('brand').textContent = t('app.name');
    var nav = document.getElementById('langs');
    LANGS.forEach(function (l) {
      var a = document.createElement('a'); a.href = '?lang=' + l; a.textContent = (window.I18N[l] || {})['lang.name'] || l;
      a.setAttribute('lang', l); if (l === lang) a.setAttribute('aria-current', 'page'); nav.appendChild(a);
    });
    renderPrivacy(document.getElementById('body'), t);
  }
})();
