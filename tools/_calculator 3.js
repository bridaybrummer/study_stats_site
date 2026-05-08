/* StudyStats sample-size calculators — shared helpers
 *
 * No external dependencies. Provides:
 *   StudyStats.qnorm(p)       inverse standard normal CDF (Beasley-Springer-Moro)
 *   StudyStats.copyText(s)    copy to clipboard with fallback
 *   StudyStats.toast(msg)     transient confirmation
 *   StudyStats.formatN(n)     pretty-print integer with thousands separator
 *   StudyStats.svgPowerCurve(el, points, n)  draw inline SVG power curve
 */
(function (global) {
  'use strict';

  // Inverse standard normal CDF — Acklam's algorithm. Accurate to ~1e-9.
  function qnorm(p) {
    if (p <= 0 || p >= 1) {
      if (p === 0) return -Infinity;
      if (p === 1) return Infinity;
      return NaN;
    }
    var a = [-3.969683028665376e+01,  2.209460984245205e+02,
             -2.759285104469687e+02,  1.383577518672690e+02,
             -3.066479806614716e+01,  2.506628277459239e+00];
    var b = [-5.447609879822406e+01,  1.615858368580409e+02,
             -1.556989798598866e+02,  6.680131188771972e+01,
             -1.328068155288572e+01];
    var c = [-7.784894002430293e-03, -3.223964580411365e-01,
             -2.400758277161838e+00, -2.549732539343734e+00,
              4.374664141464968e+00,  2.938163982698783e+00];
    var d = [ 7.784695709041462e-03,  3.224671290700398e-01,
              2.445134137142996e+00,  3.754408661907416e+00];

    var pLow = 0.02425, pHigh = 1 - pLow, q, r;
    if (p < pLow) {
      q = Math.sqrt(-2 * Math.log(p));
      return (((((c[0] * q + c[1]) * q + c[2]) * q + c[3]) * q + c[4]) * q + c[5]) /
             ((((d[0] * q + d[1]) * q + d[2]) * q + d[3]) * q + 1);
    } else if (p <= pHigh) {
      q = p - 0.5;
      r = q * q;
      return (((((a[0] * r + a[1]) * r + a[2]) * r + a[3]) * r + a[4]) * r + a[5]) * q /
             (((((b[0] * r + b[1]) * r + b[2]) * r + b[3]) * r + b[4]) * r + 1);
    } else {
      q = Math.sqrt(-2 * Math.log(1 - p));
      return -(((((c[0] * q + c[1]) * q + c[2]) * q + c[3]) * q + c[4]) * q + c[5]) /
              ((((d[0] * q + d[1]) * q + d[2]) * q + d[3]) * q + 1);
    }
  }

  // Standard normal CDF — Abramowitz & Stegun 26.2.17 approximation.
  function pnorm(x) {
    var t = 1 / (1 + 0.2316419 * Math.abs(x));
    var d = 0.3989422804014327 * Math.exp(-x * x / 2);
    var p = d * t * (0.31938153 + t * (-0.356563782 + t *
            (1.781477937 + t * (-1.821255978 + t * 1.330274429))));
    return x > 0 ? 1 - p : p;
  }

  function copyText(s) {
    if (navigator.clipboard && navigator.clipboard.writeText) {
      return navigator.clipboard.writeText(s).then(function () { toast('Copied'); });
    }
    var ta = document.createElement('textarea');
    ta.value = s;
    ta.style.position = 'fixed';
    ta.style.opacity = '0';
    document.body.appendChild(ta);
    ta.select();
    try { document.execCommand('copy'); toast('Copied'); }
    catch (e) { toast('Copy failed'); }
    document.body.removeChild(ta);
    return Promise.resolve();
  }

  var toastEl;
  function toast(msg) {
    if (!toastEl) {
      toastEl = document.createElement('div');
      toastEl.className = 'ss-toast';
      document.body.appendChild(toastEl);
    }
    toastEl.textContent = msg;
    toastEl.classList.add('show');
    clearTimeout(toast._t);
    toast._t = setTimeout(function () { toastEl.classList.remove('show'); }, 1600);
  }

  function formatN(n) {
    return Math.round(n).toString().replace(/\B(?=(\d{3})+(?!\d))/g, ' ');
  }

  // Draw a tiny SVG line chart of {x, y} points where y is in [0, 1] (power).
  // Marks the requested-n point in accent colour.
  function svgPowerCurve(container, points, markX, markY, opts) {
    opts = opts || {};
    var W = 480, H = 240, pad = { l: 44, r: 14, t: 14, b: 36 };
    var iw = W - pad.l - pad.r, ih = H - pad.t - pad.b;
    var xs = points.map(function (p) { return p.x; });
    var xMin = Math.min.apply(null, xs), xMax = Math.max.apply(null, xs);
    var sx = function (x) { return pad.l + (x - xMin) / (xMax - xMin) * iw; };
    var sy = function (y) { return pad.t + (1 - y) * ih; };

    var path = points.map(function (p, i) {
      return (i ? 'L' : 'M') + sx(p.x).toFixed(1) + ',' + sy(p.y).toFixed(1);
    }).join(' ');

    // y-axis ticks 0, 0.5, 0.8, 1.0
    var yticks = [0, 0.5, 0.8, 1.0];
    var ytickHTML = yticks.map(function (v) {
      var y = sy(v);
      return '<line x1="' + pad.l + '" x2="' + (W - pad.r) + '" y1="' + y + '" y2="' + y +
             '" stroke="#333" stroke-dasharray="' + (v === 0.8 ? '0' : '2,3') + '"/>' +
             '<text x="' + (pad.l - 6) + '" y="' + (y + 4) + '" text-anchor="end" ' +
             'fill="#b8b8b8" font-size="11">' + v.toFixed(1) + '</text>';
    }).join('');

    // x-axis ticks
    var xtickCount = 5;
    var xtickHTML = '';
    for (var i = 0; i <= xtickCount; i++) {
      var v = xMin + (xMax - xMin) * i / xtickCount;
      var x = sx(v);
      xtickHTML += '<line x1="' + x + '" x2="' + x + '" y1="' + (H - pad.b) +
                   '" y2="' + (H - pad.b + 4) + '" stroke="#666"/>' +
                   '<text x="' + x + '" y="' + (H - pad.b + 18) + '" text-anchor="middle" ' +
                   'fill="#b8b8b8" font-size="11">' + Math.round(v) + '</text>';
    }

    var markHTML = '';
    if (markX != null && markY != null) {
      markHTML =
        '<line x1="' + sx(markX) + '" x2="' + sx(markX) + '" y1="' + pad.t + '" y2="' +
        (H - pad.b) + '" stroke="#4ECDC4" stroke-dasharray="3,3"/>' +
        '<circle cx="' + sx(markX) + '" cy="' + sy(markY) +
        '" r="5" fill="#4ECDC4" stroke="#121212" stroke-width="2"/>';
    }

    var svg =
      '<svg viewBox="0 0 ' + W + ' ' + H + '" role="img" aria-label="' +
      (opts.label || 'Power curve') + '">' +
      ytickHTML + xtickHTML +
      '<path d="' + path + '" fill="none" stroke="#FF6B6B" stroke-width="2"/>' +
      markHTML +
      '<text x="' + (pad.l + iw / 2) + '" y="' + (H - 6) +
      '" text-anchor="middle" fill="#b8b8b8" font-size="11">' +
      (opts.xlab || 'Sample size per group') + '</text>' +
      '<text transform="translate(12 ' + (pad.t + ih / 2) +
      ') rotate(-90)" text-anchor="middle" fill="#b8b8b8" font-size="11">' +
      (opts.ylab || 'Power (1 − β)') + '</text>' +
      '</svg>';
    container.innerHTML = svg;
  }

  global.StudyStats = global.StudyStats || {};
  global.StudyStats.qnorm = qnorm;
  global.StudyStats.pnorm = pnorm;
  global.StudyStats.copyText = copyText;
  global.StudyStats.toast = toast;
  global.StudyStats.formatN = formatN;
  global.StudyStats.svgPowerCurve = svgPowerCurve;
})(window);
