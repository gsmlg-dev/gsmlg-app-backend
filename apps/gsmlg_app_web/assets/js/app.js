import "../../../../deps/phoenix_html/priv/static/phoenix_html.js";

// PageHeader scroll behavior (replaces phx-hook="PageHeader" which requires LiveSocket)
// Shows fixed nav when header scrolls out of view using IntersectionObserver
document.addEventListener("DOMContentLoaded", () => {
  const header = document.getElementById("wc-page-header-header");
  if (!header) return;

  const navId = header.dataset.navId;
  const nav = document.getElementById(navId);
  if (!nav) return;

  const thresholds = [];
  for (let i = 0; i <= 10; i++) thresholds.push(i / 10);

  new IntersectionObserver((entries) => {
    entries.forEach((entry) => {
      if (entry.intersectionRatio <= 0.5) {
        nav.classList.remove("hidden");
        nav.setAttribute("aria-hidden", "false");
        nav.style.opacity = 1 - entry.intersectionRatio;
      } else {
        nav.classList.add("hidden");
        nav.setAttribute("aria-hidden", "true");
      }
    });
  }, { root: null, rootMargin: "0px", threshold: thresholds }).observe(header);
});

