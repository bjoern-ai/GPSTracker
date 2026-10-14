/*
 * Fotospur: Fotos einer Tour entlang der aufgezeichneten Strecke.
 *
 * Markup:
 *   <div class="fotospur"> mit einem <script type="application/json">-Element darin,
 *   das die Daten enthält.
 *
 * Die JSON-Daten erzeugt gpx_to_fotospur.py aus einer Tourspur-GPX-Datei:
 *   { "name": "...", "stats": {...},
 *     "track": [[lat, lon, ele, km], ...],
 *     "photos": [{ "src": "...", "title": "...", "time": "19:42", "km": 118.2 }, ...] }
 *
 * Keine externen Abhängigkeiten, keine Kartenkacheln: die Strecke wird als SVG
 * gezeichnet, es gehen also keine Daten an Dritte.
 */
(function () {
  "use strict";
  var NS = "http://www.w3.org/2000/svg";

  function el(tag, attrs, parent) {
    var e = document.createElementNS(NS, tag);
    for (var k in attrs) e.setAttribute(k, attrs[k]);
    if (parent) parent.appendChild(e);
    return e;
  }
  function h(tag, cls, parent) {
    var e = document.createElement(tag);
    if (cls) e.className = cls;
    if (parent) parent.appendChild(e);
    return e;
  }
  function fmtKm(km) {
    return km.toFixed(1).replace(".", ",") + " km";
  }

  function mount(root) {
    var src = root.querySelector('script[type="application/json"]');
    if (!src || root.dataset.fsReady) return;
    root.dataset.fsReady = "1";
    var data = JSON.parse(src.textContent);
    var track = data.track;
    var photos = (data.photos || []).slice().sort(function (a, b) { return a.km - b.km; });
    var total = track[track.length - 1][3];

    // Projektion: lokal flach, Norden oben, in 320x260 eingepasst
    var lat0 = track.reduce(function (s, p) { return s + p[0]; }, 0) / track.length;
    var kx = Math.cos(lat0 * Math.PI / 180);
    var xs = track.map(function (p) { return p[1] * kx; });
    var ys = track.map(function (p) { return -p[0]; });
    var minX = Math.min.apply(null, xs), maxX = Math.max.apply(null, xs);
    var minY = Math.min.apply(null, ys), maxY = Math.max.apply(null, ys);
    var W = 320, H = 260, PAD = 22;
    var sc = Math.min((W - 2 * PAD) / (maxX - minX || 1), (H - 2 * PAD) / (maxY - minY || 1));
    var offX = (W - (maxX - minX) * sc) / 2, offY = (H - (maxY - minY) * sc) / 2;
    var P = track.map(function (p, i) {
      return [offX + (xs[i] - minX) * sc, offY + (ys[i] - minY) * sc];
    });
    var segLen = [0];
    for (var i = 1; i < P.length; i++) {
      segLen.push(segLen[i - 1] + Math.hypot(P[i][0] - P[i - 1][0], P[i][1] - P[i - 1][1]));
    }
    var L = segLen[segLen.length - 1];

    // km -> Position auf der gezeichneten Linie
    function at(km) {
      var lo = 0, hi = track.length - 1;
      while (hi - lo > 1) {
        var mid = (lo + hi) >> 1;
        if (track[mid][3] <= km) lo = mid; else hi = mid;
      }
      var d = track[hi][3] - track[lo][3];
      var f = d > 0 ? (km - track[lo][3]) / d : 0;
      return {
        x: P[lo][0] + (P[hi][0] - P[lo][0]) * f,
        y: P[lo][1] + (P[hi][1] - P[lo][1]) * f,
        len: segLen[lo] + (segLen[hi] - segLen[lo]) * f,
        ele: track[lo][2] + (track[hi][2] - track[lo][2]) * f
      };
    }

    // Grundgerüst
    root.innerHTML = "";
    var stage = h("div", "fs-stage", root);
    var mapBox = h("div", "fs-map", stage);
    var map = el("svg", { viewBox: "0 0 " + W + " " + H, role: "img", "aria-label": "Strecke " + (data.name || "") + " mit Fotopunkten" }, mapBox);
    var photoBox = h("figure", "fs-photo", stage);
    var img = h("img", "", photoBox);
    img.decoding = "async";
    var cap = h("figcaption", "fs-cap", photoBox);
    var prof = el("svg", { class: "fs-prof", viewBox: "0 0 600 84", preserveAspectRatio: "none", "aria-hidden": "true" }, root);
    var ctl = h("div", "fs-ctl", root);
    var btn = h("button", "fs-play", ctl);
    btn.type = "button";
    btn.textContent = "Abspielen";
    var range = h("input", "fs-range", ctl);
    range.type = "range"; range.min = 0; range.max = 1000; range.value = 0;
    range.setAttribute("aria-label", "Position auf der Tour");
    var out = h("output", "fs-km", ctl);

    // Höhenlinien als Hintergrund: die Strecke mehrfach versetzt und verbreitert
    var d = "M" + P.map(function (p) { return p[0].toFixed(1) + " " + p[1].toFixed(1); }).join(" L");
    [46, 32, 20].forEach(function (w) {
      el("path", { d: d, class: "fs-contour", "stroke-width": w }, map);
    });
    el("path", { d: d, class: "fs-route-bg" }, map);
    var done = el("path", { d: d, class: "fs-route", "stroke-dasharray": L, "stroke-dashoffset": L }, map);
    el("circle", { cx: P[0][0], cy: P[0][1], r: 4, class: "fs-start" }, map);

    var pins = photos.map(function (ph, n) {
      var p = at(ph.km);
      var g = el("g", { class: "fs-pin", tabindex: 0, role: "button", "aria-label": "Foto " + (n + 1) + ": " + (ph.title || "") }, map);
      el("circle", { cx: p.x, cy: p.y, r: 9 }, g);
      var t = el("text", { x: p.x, y: p.y + 3.5, "text-anchor": "middle" }, g);
      t.textContent = n + 1;
      function jump() { stop(); set(ph.km / total * 1000); }
      g.addEventListener("click", jump);
      g.addEventListener("keydown", function (e) { if (e.key === "Enter" || e.key === " ") { e.preventDefault(); jump(); } });
      return g;
    });
    var rider = el("g", { class: "fs-rider" }, map);
    el("circle", { r: 7 }, rider);
    el("circle", { r: 2.6, class: "fs-rider-dot" }, rider);

    // Höhenprofil
    var eles = track.map(function (p) { return p[2]; });
    var eMin = Math.min.apply(null, eles), eMax = Math.max.apply(null, eles);
    function py(e) { return 78 - (e - eMin) / ((eMax - eMin) || 1) * 64; }
    var pd = track.map(function (p) { return (p[3] / total * 600).toFixed(1) + " " + py(p[2]).toFixed(1); });
    el("path", { d: "M0 84 L" + pd.join(" L") + " L600 84Z", class: "fs-prof-area" }, prof);
    el("path", { d: "M" + pd.join(" L"), class: "fs-prof-line", "vector-effect": "non-scaling-stroke" }, prof);
    photos.forEach(function (ph) {
      var x = ph.km / total * 600;
      el("line", { x1: x, x2: x, y1: 0, y2: 84, class: "fs-prof-mark", "vector-effect": "non-scaling-stroke" }, prof);
    });
    var cur = el("line", { x1: 0, x2: 0, y1: 0, y2: 84, class: "fs-prof-cur", "vector-effect": "non-scaling-stroke" }, prof);
    prof.addEventListener("click", function (e) {
      var r = prof.getBoundingClientRect();
      stop(); set((e.clientX - r.left) / r.width * 1000);
    });

    var shown = -2;
    function show(n) {
      if (n === shown) return;
      shown = n;
      pins.forEach(function (g, i) { g.classList.toggle("is-active", i === n); });
      if (n < 0) {
        img.style.opacity = 0;
        cap.innerHTML = "<b>" + (data.name || "Start") + "</b>" + fmtKm(total) + " · " + photos.length + " Fotos";
        return;
      }
      var ph = photos[n];
      img.style.opacity = 0;
      setTimeout(function () {
        img.src = ph.src;
        img.alt = ph.alt || ph.title || "";
        img.style.opacity = 1;
      }, 160);
      cap.innerHTML = "";
      var b = h("b", "", cap); b.textContent = ph.title || "Foto " + (n + 1);
      cap.appendChild(document.createTextNode(
        "Foto " + (n + 1) + " · km " + ph.km.toFixed(1).replace(".", ",") + (ph.time ? " · " + ph.time + " Uhr" : "")));
    }

    function set(v) {
      v = Math.max(0, Math.min(1000, +v));
      range.value = v;
      var km = v / 1000 * total;
      var p = at(km);
      rider.setAttribute("transform", "translate(" + p.x.toFixed(1) + " " + p.y.toFixed(1) + ")");
      done.setAttribute("stroke-dashoffset", (L - p.len).toFixed(1));
      cur.setAttribute("x1", v * 0.6); cur.setAttribute("x2", v * 0.6);
      out.textContent = fmtKm(km);
      var n = -1;
      photos.forEach(function (ph, i) { if (km >= ph.km - total * 0.03) n = i; });
      show(n);
    }

    var raf = null;
    function stop() {
      if (raf) { cancelAnimationFrame(raf); raf = null; }
      btn.textContent = "Abspielen";
    }
    btn.addEventListener("click", function () {
      if (raf) { stop(); return; }
      var v = +range.value >= 1000 ? 0 : +range.value;
      var last = performance.now();
      btn.textContent = "Pause";
      (function step(now) {
        // langsamer in der Nähe eines Fotos, damit man es sieht
        var km = v / 1000 * total, near = photos.some(function (ph) { return Math.abs(ph.km - km) < total * 0.02; });
        v += (now - last) * (near ? 0.025 : 0.08);
        last = now;
        if (v >= 1000) { set(1000); stop(); return; }
        set(v);
        raf = requestAnimationFrame(step);
      })(last);
    });
    range.addEventListener("input", function () { stop(); set(range.value); });
    set(0);
  }

  function init() {
    Array.prototype.forEach.call(document.querySelectorAll(".fotospur"), mount);
  }
  if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", init);
  else init();
})();
