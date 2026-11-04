/* The feature films on darbar.live, for / and /pa/.

   Each card in "Also in the app" has a phone with a poster and a short silent
   film. A tap plays the film once. The button then shows Replay.

   Nothing starts by itself. Nothing is fetched before a tap: the video has
   preload="none" and the poster is a lazy image. Under Reduce Motion the
   films still play when they are pressed, and only the easing is off (see
   styles.css).

   One film plays at a time. The demo above has sound, so a card pauses it, and
   the demo pauses the cards.

   The state is one attribute, data-state on each .fc-film:
     idle, playing, paused, ended, failed
   styles.css draws the icon and the button from it. If a film will not load,
   the card is "failed": it keeps its poster and its words, and has no button. */
(function () {
  'use strict';

  var list = document.querySelector('.fc-list');
  if (!list) return;

  var demo = document.getElementById('film');
  var items = Array.prototype.slice.call(list.querySelectorAll('.fc-film')).map(setup);

  function word(key) {
    return list.getAttribute('data-l-' + key);
  }

  function setup(el) {
    var video = el.querySelector('video');
    var btn = el.querySelector('.fc-btn');
    var name = el.getAttribute('data-name');
    var item = { el: el, video: video };
    var resetting = false;

    function set(state) {
      el.setAttribute('data-state', state);
      var key = state === 'playing' ? 'pause' : state === 'ended' ? 'replay' : 'play';
      btn.setAttribute('aria-label', word(key) + ': ' + name);
    }

    function fail() {
      el.classList.remove('is-started');
      set('failed');
    }

    function start() {
      var p = video.play();
      if (p && p.catch) {
        p.catch(function (e) {
          // A tap on Pause while the film is still loading ends in AbortError.
          // Only a film that cannot be read is a failure.
          if (e && e.name === 'NotSupportedError') fail();
        });
      }
    }

    // A film sends its own taps here, and so does the button inside it.
    el.addEventListener('click', function () {
      var state = el.getAttribute('data-state');
      if (state === 'failed') return;
      if (state === 'ended') {
        video.currentTime = 0;
        start();
      } else if (video.paused) {
        start();
      } else {
        video.pause();
      }
    });

    video.addEventListener('play', function () {
      set('playing');
      pauseOthers(item);
    });
    // The first frame is on screen: the poster can go.
    video.addEventListener('playing', function () {
      el.classList.add('is-started');
    });
    video.addEventListener('pause', function () {
      if (resetting) {
        resetting = false;
        return;
      }
      if (!video.ended) set('paused');
    });
    video.addEventListener('ended', function () {
      set('ended');
    });
    // An error on a <source> does not bubble, but a listener in the capture
    // phase on the video still hears it.
    video.addEventListener('error', fail, true);

    // Back to the poster: used when the widget card switches phone.
    item.reset = function () {
      if (!video.paused) {
        resetting = true;
        video.pause();
      }
      if (video.readyState > 0) video.currentTime = 0;
      el.classList.remove('is-started');
      if (el.getAttribute('data-state') !== 'failed') set('idle');
    };

    set('idle');
    return item;
  }

  function pauseOthers(item) {
    items.forEach(function (other) {
      if (other !== item && !other.video.paused) other.video.pause();
    });
    if (demo && !demo.paused) demo.pause();
  }

  if (demo) {
    demo.addEventListener('play', function () {
      items.forEach(function (other) {
        if (!other.video.paused) other.video.pause();
      });
    });
  }

  // The Android | iPhone switch on the widget card.
  Array.prototype.forEach.call(list.querySelectorAll('.fc-switch'), function (sw) {
    var buttons = Array.prototype.slice.call(sw.querySelectorAll('button'));
    buttons.forEach(function (button, n) {
      button.addEventListener('click', function () {
        if (button.getAttribute('aria-pressed') === 'true') return;
        buttons.forEach(function (other) {
          var on = other === button;
          var panel = document.getElementById(other.getAttribute('aria-controls'));
          other.setAttribute('aria-pressed', on ? 'true' : 'false');
          panel.hidden = !on;
          if (!on) {
            items.forEach(function (it) {
              if (it.el === panel) it.reset();
            });
          }
        });
        sw.setAttribute('data-pos', String(n));
      });
    });
  });
})();
