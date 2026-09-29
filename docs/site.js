(() => {
  const buttons = document.querySelectorAll('[data-language]');
  function chooseLanguage(language) {
    const locale = language === 'de' ? 'de' : 'en';
    document.documentElement.lang = locale;
    document.querySelectorAll('[data-en][data-de]').forEach(element => {
      // Only trusted repository-authored copy; no URL/user content is interpolated.
      element.replaceChildren();
      element.dataset[locale].split('<br>').forEach((line, index) => {
        if (index) element.append(document.createElement('br'));
        element.append(document.createTextNode(line));
      });
    });
    buttons.forEach(button => button.setAttribute('aria-pressed', String(button.dataset.language === locale)));
    document.title = locale === 'de' ? 'WhyWait — Deine kleine Pause.' : 'WhyWait — A little play, while you wait.';
    try { localStorage.setItem('whywait-language', locale); } catch { /* Private browsing may disable storage. */ }
  }
  buttons.forEach(button => button.addEventListener('click', () => chooseLanguage(button.dataset.language)));
  let initial = navigator.language.startsWith('de') ? 'de' : 'en';
  try { initial = localStorage.getItem('whywait-language') || initial; } catch { /* Use browser language. */ }
  chooseLanguage(initial);
})();
