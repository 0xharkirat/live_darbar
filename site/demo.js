/* The demo film on darbar.live, for / and /pa/.

   The film is one video with its sound baked in: the app, the taps and the
   click sounds. What the script adds is the control bar, and a cursor drawn on
   top. The cursor, the ripple at each click and the chapter bar are all drawn
   from one number, video.currentTime. So a replay, a jump to a chapter and a
   drag of the playhead all show the same cursor and the same clicks, and the
   sound comes from the video itself.

   The film never starts by itself. With no script the page still shows the
   poster, and the video keeps the browser's own controls.

   The film's times come from the video's data-film file (see tool/site_film.dart):
     chapters  [{ start, end }]              seconds
     cursor    [[t, x, y], ...]              x and y are fractions of the screen
     clicks    [t, ...]                      seconds */
(function () {
  'use strict';

  var video = document.getElementById('film');
  var screen = document.getElementById('screen');
  var playBtn = document.getElementById('play');
  var replayBtn = document.getElementById('replay');
  var cursor = document.getElementById('cursor');
  var ripple = cursor && cursor.querySelector('.cursor-ripple');
  var chapterBtns = Array.prototype.slice.call(document.querySelectorAll('#chapters button'));
  var fills = chapterBtns.map(function (b) { return b.querySelector('i'); });
  if (!video || !playBtn) return;

  var film = null;          // the data file, once it has loaded
  var screenW = 0;
  var screenH = 0;
  var shown = -1;           // the chapter whose label is lit
  var raf = 0;

  video.controls = false;

  // ---- Labels ----
  function label(state) {
    var key = state === 'playing' ? 'pause' : state === 'paused' ? 'resume' : 'play';
    var text = playBtn.getAttribute('data-l-' + key);
    playBtn.querySelector('.play-label').textContent = text;
    playBtn.setAttribute('aria-label', text);
    playBtn.setAttribute('data-state', state === 'playing' ? 'playing' : 'idle');
    screen.setAttribute('data-state', state);
  }

  // ---- The clock-driven drawing ----
  function ease(p) {
    return p < 0.5 ? 4 * p * p * p : 1 - Math.pow(-2 * p + 2, 3) / 2;
  }
  function clamp(v, lo, hi) { return v < lo ? lo : v > hi ? hi : v; }

  function cursorAt(t) {
    var k = film.cursor;
    if (t <= k[0][0]) return [k[0][1], k[0][2]];
    for (var i = 0; i < k.length - 1; i++) {
      if (t < k[i + 1][0]) {
        var p = (t - k[i][0]) / (k[i + 1][0] - k[i][0]);
        var e = ease(p);
        return [k[i][1] + (k[i + 1][1] - k[i][1]) * e, k[i][2] + (k[i + 1][2] - k[i][2]) * e];
      }
    }
    var last = k[k.length - 1];
    return [last[1], last[2]];
  }

  function chapterAt(t) {
    var c = film.chapters;
    for (var i = c.length - 1; i >= 0; i--) if (t >= c[i].start) return i;
    return 0;
  }

  // 0 at the click, then back to 1: the cursor sinks a little.
  var PRESS = 0.22;
  var RIPPLE = 0.5;

  // [time] is the media time of the frame on screen, when the browser tells us.
  // Otherwise the video's own clock.
  function draw(time) {
    if (!film) return;
    var t = typeof time === 'number' ? time : video.currentTime;

    // The cursor.
    var started = t > 0.05 || !video.paused;
    cursor.classList.toggle('on', started);
    var pos = cursorAt(t);
    cursor.style.transform = 'translate3d(' + (pos[0] * screenW).toFixed(1) + 'px,' + (pos[1] * screenH).toFixed(1) + 'px,0)';

    // The click: the cursor sinks, and a ring spreads and fades.
    var press = 1;
    var ring = -1;
    for (var i = 0; i < film.clicks.length; i++) {
      var d = t - film.clicks[i];
      if (d >= 0 && d < RIPPLE) {
        if (d < PRESS) press = Math.min(press, 1 - 0.14 * Math.sin((d / PRESS) * Math.PI));
        ring = d / RIPPLE;
        break;
      }
    }
    cursor.style.setProperty('--press', press.toFixed(3));
    if (ring < 0) {
      ripple.style.opacity = '0';
    } else {
      var out = 1 - Math.pow(1 - ring, 3);
      ripple.style.opacity = (0.8 * (1 - ring)).toFixed(3);
      ripple.style.transform = 'scale(' + (0.35 + 0.95 * out).toFixed(3) + ')';
    }

    // The chapter bar.
    var now = chapterAt(t);
    for (var j = 0; j < film.chapters.length; j++) {
      var c = film.chapters[j];
      var f = clamp((t - c.start) / (c.end - c.start), 0, 1);
      fills[j].style.transform = 'scaleX(' + f.toFixed(4) + ')';
    }
    if (now !== shown) {
      shown = now;
      chapterBtns.forEach(function (b, n) {
        if (n === now) b.setAttribute('aria-current', 'true'); else b.removeAttribute('aria-current');
      });
    }
  }

  // Draw on the video's own frames where the browser says when they show.
  function loop(now, frame) {
    draw(frame && frame.mediaTime);
    if (video.paused || video.ended) { raf = 0; return; }
    if (video.requestVideoFrameCallback) raf = video.requestVideoFrameCallback(loop);
    else raf = requestAnimationFrame(loop);
  }
  function startLoop() {
    if (!raf) loop();
  }

  function measure() {
    var r = screen.getBoundingClientRect();
    screenW = r.width;
    screenH = r.height;
    draw();
  }
  if (window.ResizeObserver) new ResizeObserver(measure).observe(screen);
  else window.addEventListener('resize', measure);
  measure();

  // ---- The data file ----
  var url = video.getAttribute('data-film');
  if (url) {
    fetch(url).then(function (r) { return r.json(); }).then(function (d) {
      film = d;
      draw();
    }).catch(function () { /* the film still plays, without the cursor and the bar */ });
  }

  // ---- Controls ----
  function play() {
    var p = video.play();
    if (p && p.catch) p.catch(function () { label('idle'); });
  }
  function restart() {
    video.currentTime = 0;
    shown = -1;
    play();
  }
  function seekTo(seconds) {
    function go() {
      video.currentTime = seconds;
      shown = -1;
      draw();
      play();
    }
    if (video.readyState >= 1) go();
    else {
      video.addEventListener('loadedmetadata', go, { once: true });
      video.load();
    }
  }

  playBtn.addEventListener('click', function () {
    if (video.ended) restart();
    else if (video.paused) play();
    else video.pause();
  });
  screen.addEventListener('click', function () { playBtn.click(); });
  replayBtn.addEventListener('click', restart);
  chapterBtns.forEach(function (b, n) {
    b.addEventListener('click', function () {
      if (film) seekTo(film.chapters[n].start);
    });
  });

  video.addEventListener('play', function () { label('playing'); startLoop(); });
  video.addEventListener('pause', function () { if (!video.ended) label('paused'); draw(); });
  video.addEventListener('seeked', draw);
  video.addEventListener('timeupdate', function () { if (video.paused) draw(); });
  // Some browsers leave a finished film "playing". Pause it, and the next play
  // starts again from the top.
  video.addEventListener('ended', function () {
    video.pause();
    label('paused');
    draw();
  });
  // Sound is the point of the film. Do not let it run on in a hidden tab.
  document.addEventListener('visibilitychange', function () {
    if (document.hidden && !video.paused) video.pause();
  });

  label('idle');
})();
