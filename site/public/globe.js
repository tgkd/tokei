const vertexSource = `#version 300 es
in vec2 position;
void main() {
  gl_Position = vec4(position, 0.0, 1.0);
}`;

const fragmentSource = `#version 300 es
precision highp float;
uniform vec2 resolution;
uniform float yaw;
uniform float pitch;
uniform vec3 sun;
uniform sampler2D coast;
out vec4 outColor;

const float PI = 3.14159265;

vec3 linear(vec3 c) { return pow(c, vec3(2.2)); }

vec3 paperColor(float d, float w) {
  vec3 color = linear(vec3(0.122, 0.435, 0.498));
  color = mix(color, linear(vec3(0.165, 0.510, 0.569)), smoothstep(-12.0 - w, -12.0 + w, d));
  color = mix(color, linear(vec3(0.243, 0.600, 0.647)), smoothstep(-5.0 - w, -5.0 + w, d));
  color = mix(color, linear(vec3(0.408, 0.714, 0.737)), smoothstep(-1.8 - w, -1.8 + w, d));
  color = mix(color, linear(vec3(0.616, 0.824, 0.812)), smoothstep(-0.5 - w, -0.5 + w, d));
  color = mix(color, linear(vec3(0.937, 0.478, 0.337)), smoothstep(-w, w, d));
  color = mix(color, linear(vec3(0.953, 0.565, 0.392)), smoothstep(0.6 - w, 0.6 + w, d));
  color = mix(color, linear(vec3(0.965, 0.659, 0.455)), smoothstep(1.8 - w, 1.8 + w, d));
  color = mix(color, linear(vec3(0.973, 0.753, 0.541)), smoothstep(4.0 - w, 4.0 + w, d));
  color = mix(color, linear(vec3(0.980, 0.843, 0.651)), smoothstep(8.0 - w, 8.0 + w, d));
  return color;
}

float terraceShade(float s, float d, float w) {
  float below = smoothstep(s - 0.5, s, d) * (1.0 - smoothstep(s - w, s + w, d));
  float above = smoothstep(s - w, s + w, d) * (1.0 - smoothstep(s, s + 0.15, d));
  return 1.0 - 0.28 * below + 0.12 * above;
}

float hash(vec2 p) {
  return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void main() {
  vec2 p = (2.0 * gl_FragCoord.xy - resolution) / min(resolution.x, resolution.y) * 1.04;
  float r = length(p);
  float edge = fwidth(r);
  float coverage = 1.0 - smoothstep(1.0 - edge, 1.0, r);
  if (coverage <= 0.0) {
    outColor = vec4(0.0);
    return;
  }
  vec3 view = vec3(p, sqrt(max(1.0 - r * r, 0.0)));
  vec3 tilted = vec3(view.x, view.y * cos(pitch) + view.z * sin(pitch), -view.y * sin(pitch) + view.z * cos(pitch));
  vec3 n = vec3(tilted.x * cos(yaw) + tilted.z * sin(yaw), tilted.y, -tilted.x * sin(yaw) + tilted.z * cos(yaw));
  float lat = asin(clamp(n.y, -1.0, 1.0));
  float lon = atan(n.x, n.z);
  vec2 uv = vec2(lon / (2.0 * PI) + 0.5, 0.5 - lat / PI);
  float d = (texture(coast, uv).r * 255.0 - 128.0) / 8.0;
  float w = clamp(fwidth(d), 0.02, 0.4) * 0.75;

  vec3 paper = paperColor(d, w);
  float shade = 1.0;
  shade *= terraceShade(-12.0, d, w);
  shade *= terraceShade(-5.0, d, w);
  shade *= terraceShade(-1.8, d, w);
  shade *= terraceShade(-0.5, d, w);
  shade *= terraceShade(0.0, d, w);
  shade *= terraceShade(0.6, d, w);
  shade *= terraceShade(1.8, d, w);
  shade *= terraceShade(4.0, d, w);
  shade *= terraceShade(8.0, d, w);
  float fibre = 1.0 + 0.06 * (hash(floor(gl_FragCoord.xy / 1.5)) - 0.5);
  paper *= shade * fibre;

  float mu = dot(n, sun);
  float daylight = 0.8 + 0.2 * clamp(mu, 0.0, 1.0);
  float golden = (1.0 - smoothstep(0.0, 0.12, mu)) * step(0.0, mu);
  vec3 day = paper * daylight * mix(vec3(1.0), linear(vec3(1.0, 0.914, 0.8)), golden);

  float dusk = smoothstep(0.0, 1.0, clamp(-mu / 0.24, 0.0, 1.0));
  vec3 tint = mix(linear(vec3(0.788, 0.604, 0.722)), linear(vec3(0.514, 0.451, 0.631)), clamp(dusk * 2.0, 0.0, 1.0));
  tint = mix(tint, linear(vec3(0.271, 0.282, 0.490)), clamp(dusk * 2.0 - 1.0, 0.0, 1.0));
  vec3 luma = vec3(dot(paper, vec3(0.2126, 0.7152, 0.0722)));
  vec3 night = (0.25 * dusk + (1.0 - 0.25 * dusk) * mix(luma, paper, mix(0.9, 0.15, dusk))) * tint;
  vec3 color = mu >= 0.0 ? day : night;

  float limb = 1.0 - view.z;
  color *= mix(1.0, 0.72, limb * limb);
  color = pow(color, vec3(1.0 / 2.2));
  outColor = vec4(color * coverage, coverage);
}`;

function compile(gl, type, source) {
  const shader = gl.createShader(type);
  gl.shaderSource(shader, source);
  gl.compileShader(shader);
  if (!gl.getShaderParameter(shader, gl.COMPILE_STATUS)) {
    throw new Error(gl.getShaderInfoLog(shader));
  }
  return shader;
}

function sunDirection(date) {
  const start = Date.UTC(date.getUTCFullYear(), 0, 0);
  const day = (date.getTime() - start) / 86400000;
  const declination = -23.44 * Math.PI / 180 * Math.cos(2 * Math.PI / 365 * (day + 10));
  const hours = date.getUTCHours() + date.getUTCMinutes() / 60;
  const longitude = -15 * (hours - 12) * Math.PI / 180;
  return [
    Math.cos(declination) * Math.sin(longitude),
    Math.sin(declination),
    Math.cos(declination) * Math.cos(longitude),
  ];
}

function startGlobe(canvas) {
  const gl = canvas.getContext('webgl2', { premultipliedAlpha: true, antialias: false });
  if (!gl) {
    canvas.hidden = true;
    return;
  }
  const program = gl.createProgram();
  gl.attachShader(program, compile(gl, gl.VERTEX_SHADER, vertexSource));
  gl.attachShader(program, compile(gl, gl.FRAGMENT_SHADER, fragmentSource));
  gl.linkProgram(program);
  gl.useProgram(program);

  const buffer = gl.createBuffer();
  gl.bindBuffer(gl.ARRAY_BUFFER, buffer);
  gl.bufferData(gl.ARRAY_BUFFER, new Float32Array([-1, -1, 3, -1, -1, 3]), gl.STATIC_DRAW);
  const position = gl.getAttribLocation(program, 'position');
  gl.enableVertexAttribArray(position);
  gl.vertexAttribPointer(position, 2, gl.FLOAT, false, 0, 0);

  const uniforms = {
    resolution: gl.getUniformLocation(program, 'resolution'),
    yaw: gl.getUniformLocation(program, 'yaw'),
    pitch: gl.getUniformLocation(program, 'pitch'),
    sun: gl.getUniformLocation(program, 'sun'),
  };

  const reducedMotion = window.matchMedia('(prefers-reduced-motion: reduce)');
  const wrap = canvas.parentElement;
  const slider = document.querySelector('.shifter input');
  const shiftLabel = document.querySelector('.shifter-value');
  const state = {
    yaw: -0.35,
    pitch: 0.38,
    shiftMinutes: 0,
    dragging: false,
    lastX: 0,
    lastTime: performance.now(),
    visible: true,
    ready: false,
  };

  function resize() {
    const scale = Math.min(window.devicePixelRatio || 1, 2);
    const size = Math.round(canvas.clientWidth * scale);
    if (canvas.width !== size || canvas.height !== size) {
      canvas.width = size;
      canvas.height = size;
    }
  }

  function displayedDate() {
    return new Date(Date.now() + state.shiftMinutes * 60000);
  }

  const markers = [...wrap.querySelectorAll('.marker')].map((element) => {
    const lat = Number(element.dataset.lat) * Math.PI / 180;
    const lon = Number(element.dataset.lon) * Math.PI / 180;
    return {
      element,
      dot: element.querySelector('.marker-dot'),
      chip: element.querySelector('.marker-chip'),
      time: element.querySelector('.marker-time'),
      format: new Intl.DateTimeFormat('en-US', { timeZone: element.dataset.zone, hour: 'numeric', minute: '2-digit' }),
      point: [Math.cos(lat) * Math.sin(lon), Math.sin(lat), Math.cos(lat) * Math.cos(lon)],
    };
  });
  let shownKey = '';

  function overlaps(a, b) {
    return a.left < b.right + 2 && b.left < a.right + 2 && a.top < b.bottom + 2 && b.top < a.bottom + 2;
  }

  function candidates(x, y, width, height) {
    const rightLeft = x + 10;
    const leftLeft = x - 10 - width;
    const rows = [y - height / 2, y - height - 10, y + 10];
    const result = [];
    for (const top of rows) {
      for (const left of [rightLeft, leftLeft]) {
        result.push({ left, top, right: left + width, bottom: top + height });
      }
    }
    return result;
  }

  function placeMarkers(date) {
    const key = `${Math.floor(date.getTime() / 60000)}`;
    const size = canvas.clientWidth;
    const cy = Math.cos(state.yaw);
    const sy = Math.sin(state.yaw);
    const cp = Math.cos(state.pitch);
    const sp = Math.sin(state.pitch);
    const projected = markers.map((marker) => {
      if (key !== shownKey) {
        marker.time.textContent = marker.format.format(date);
        marker.width = marker.chip.offsetWidth;
        marker.height = marker.chip.offsetHeight;
      }
      const [x, y, z] = marker.point;
      const tx = x * cy - z * sy;
      const tz = x * sy + z * cy;
      const vy = y * cp - tz * sp;
      const vz = y * sp + tz * cp;
      return {
        marker,
        depth: vz,
        x: (tx / 1.04 + 1) / 2 * size,
        y: (1 - (vy / 1.04 + 1) / 2) * size,
        fade: Math.min(Math.max((vz - 0.12) / 0.2, 0), 1),
      };
    });
    shownKey = key;
    const placed = [];
    projected.sort((a, b) => b.depth - a.depth);
    for (const item of projected) {
      const { marker, x, y } = item;
      const options = candidates(x, y, marker.width, marker.height);
      const rect = options.find((option) => !placed.some((other) => overlaps(option, other))) ?? options[0];
      if (item.fade > 0) {
        placed.push(rect);
      }
      marker.dot.style.transform = `translate(${x - 5}px, ${y - 5}px)`;
      marker.chip.style.transform = `translate(${rect.left}px, ${rect.top}px)`;
      marker.element.style.opacity = item.fade;
    }
  }

  function draw() {
    const date = displayedDate();
    placeMarkers(date);
    resize();
    gl.viewport(0, 0, canvas.width, canvas.height);
    gl.uniform2f(uniforms.resolution, canvas.width, canvas.height);
    gl.uniform1f(uniforms.yaw, state.yaw);
    gl.uniform1f(uniforms.pitch, state.pitch);
    gl.uniform3fv(uniforms.sun, sunDirection(date));
    gl.clearColor(0, 0, 0, 0);
    gl.clear(gl.COLOR_BUFFER_BIT);
    gl.drawArrays(gl.TRIANGLES, 0, 3);
  }

  function shiftText(minutes) {
    if (minutes === 0) {
      return 'Now';
    }
    const sign = minutes > 0 ? '+' : '−';
    const hours = Math.floor(Math.abs(minutes) / 60);
    const rest = Math.abs(minutes) % 60;
    return rest === 0 ? `${sign}${hours}h` : `${sign}${hours}h ${rest}m`;
  }

  function setShift(minutes) {
    state.shiftMinutes = minutes;
    slider.value = String(minutes);
    shiftLabel.textContent = shiftText(minutes);
    shiftLabel.disabled = minutes === 0;
    if (state.ready) {
      draw();
    }
  }

  slider.addEventListener('input', () => {
    setShift(Number(slider.value));
  });
  shiftLabel.addEventListener('click', () => {
    setShift(0);
  });

  function frame(now) {
    const elapsed = Math.min((now - state.lastTime) / 1000, 0.1);
    state.lastTime = now;
    if (!state.dragging && !reducedMotion.matches) {
      state.yaw += elapsed * 0.08;
    }
    draw();
    if (state.visible && !reducedMotion.matches) {
      requestAnimationFrame(frame);
    }
  }

  function resume() {
    state.lastTime = performance.now();
    requestAnimationFrame(frame);
  }

  canvas.addEventListener('pointerdown', (event) => {
    state.dragging = true;
    state.lastX = event.clientX;
    canvas.setPointerCapture(event.pointerId);
  });
  canvas.addEventListener('pointermove', (event) => {
    if (!state.dragging) {
      return;
    }
    state.yaw -= (event.clientX - state.lastX) / canvas.clientWidth * Math.PI;
    state.lastX = event.clientX;
    if (reducedMotion.matches) {
      draw();
    }
  });
  canvas.addEventListener('pointerup', () => {
    state.dragging = false;
  });
  canvas.addEventListener('pointercancel', () => {
    state.dragging = false;
  });

  new IntersectionObserver((entries) => {
    const visible = entries[0].isIntersecting;
    if (visible && !state.visible && state.ready) {
      state.visible = true;
      resume();
    }
    state.visible = visible;
  }).observe(canvas);

  window.addEventListener('resize', draw);

  const image = new Image();
  image.onload = () => {
    const texture = gl.createTexture();
    gl.bindTexture(gl.TEXTURE_2D, texture);
    gl.pixelStorei(gl.UNPACK_ALIGNMENT, 1);
    gl.texImage2D(gl.TEXTURE_2D, 0, gl.R8, gl.RED, gl.UNSIGNED_BYTE, image);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.REPEAT);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE);
    state.ready = true;
    wrap.classList.add('is-ready');
    resume();
  };
  image.src = '/img/coast.png';
}

startGlobe(document.querySelector('.globe'));
