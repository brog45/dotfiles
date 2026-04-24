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

  let rightCtrl = false;
  const clearRightCtrl = () => {
    rightCtrl = false;
  };
  window.addEventListener("blur", clearRightCtrl);
  document.addEventListener("visibilitychange", () => {
    if (document.hidden) {
      clearRightCtrl()
    };
  });

  window.addEventListener("keydown", (e) => {
    if (e.code === "ControlRight") {
      rightCtrl = true;
      return;
    }
    if (e.code === "KeyF" && rightCtrl && !document.fullscreenElement) {
      e.preventDefault();
      e.stopPropagation();
      document.documentElement.requestFullscreen()
        .then(() => {
            navigator?.keyboard?.lock?.();
        })
        .catch((err) => {
          console.warn("[sefi-title-extension] requestFullscreen failed:", err);
        });
    }
  }, true);

  window.addEventListener("keyup", (e) => {
    if (e.code === "ControlRight") {
      clearRightCtrl();
    }
  }, true);
})();
