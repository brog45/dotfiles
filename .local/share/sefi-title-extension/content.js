(() => {
  const TITLE = "SEFI Laptop";

  const host = location.hostname;
  const allow =
    host === "glkvm" ||
    host === "glkvm.lan" ||
    host === "glkvm.local" ||
    /^glkvm\.[^.]+\.ts\.net$/.test(host);
  if (!allow) return;

  const ensure = () => {
    if (document.title !== TITLE) document.title = TITLE;
  };

  ensure();

  const attach = () => {
    if (!document.head) return false;
    new MutationObserver(ensure).observe(document.head, {
      childList: true,
      subtree: true,
      characterData: true,
    });
    return true;
  };

  if (!attach()) {
    const wait = new MutationObserver(() => {
      if (attach()) {
        wait.disconnect();
        ensure();
      }
    });
    wait.observe(document.documentElement, { childList: true });
  }
})();
