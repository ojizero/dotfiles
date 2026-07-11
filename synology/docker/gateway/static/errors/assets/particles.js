(function () {
  "use strict";

  if (window.matchMedia("(prefers-reduced-motion: reduce)").matches) {
    return;
  }

  var canvas = document.querySelector(".particles");
  if (!canvas) {
    return;
  }

  var ctx = canvas.getContext("2d");
  var particles = [];
  var width = 0;
  var height = 0;
  var centerX = 0;
  var centerY = 0;
  var rafId = 0;

  var COUNT = 90;
  var PULL_RADIUS = 280;
  var PULL_STRENGTH = 0.00008;

  function rand(min, max) {
    return min + Math.random() * (max - min);
  }

  function resize() {
    width = window.innerWidth;
    height = window.innerHeight;
    canvas.width = width;
    canvas.height = height;
    centerX = width * 0.5;
    centerY = height * 0.5;
  }

  function spawnParticle() {
    return {
      x: rand(0, width),
      y: rand(0, height),
      vx: rand(-0.15, 0.15),
      vy: rand(-0.15, 0.15),
      radius: rand(0.4, 1.8),
      alpha: rand(0.25, 0.85),
      hue: rand(210, 270),
    };
  }

  function initParticles() {
    particles = [];
    for (var i = 0; i < COUNT; i++) {
      particles.push(spawnParticle());
    }
  }

  function drawParticle(p) {
    ctx.beginPath();
    ctx.arc(p.x, p.y, p.radius, 0, Math.PI * 2);
    ctx.fillStyle = "hsla(" + p.hue + ", 55%, 78%, " + p.alpha + ")";
    ctx.fill();
  }

  function tick() {
    ctx.clearRect(0, 0, width, height);

    for (var i = 0; i < particles.length; i++) {
      var p = particles[i];
      var dx = centerX - p.x;
      var dy = centerY - p.y;
      var dist = Math.sqrt(dx * dx + dy * dy);

      if (dist < PULL_RADIUS && dist > 1) {
        var force = PULL_STRENGTH * (PULL_RADIUS - dist);
        p.vx += (dx / dist) * force;
        p.vy += (dy / dist) * force;
      }

      p.vx *= 0.998;
      p.vy *= 0.998;
      p.x += p.vx;
      p.y += p.vy;

      if (p.x < -10 || p.x > width + 10 || p.y < -10 || p.y > height + 10 || dist < 18) {
        particles[i] = spawnParticle();
        if (dist < 18) {
          particles[i].x = rand(0, width);
          particles[i].y = rand(0, height);
        }
        p = particles[i];
      }

      p.alpha += rand(-0.008, 0.008);
      if (p.alpha < 0.2) {
        p.alpha = 0.2;
      }
      if (p.alpha > 0.9) {
        p.alpha = 0.9;
      }

      drawParticle(p);
    }

    rafId = requestAnimationFrame(tick);
  }

  function start() {
    cancelAnimationFrame(rafId);
    resize();
    initParticles();
    tick();
  }

  window.addEventListener("resize", start, { passive: true });
  start();
})();
