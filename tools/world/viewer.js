// Headless preview of the exported lobby. Approximates Roblox materials and
// dusk lighting with three.js so composition, proportion and legibility can be
// judged without Studio. It is a preview, not a match for the engine's look.
(function () {
  "use strict";
  const data = window.SCENE;
  const params = new URLSearchParams(location.hash.slice(1));
  const shot = data.shots.find((s) => s.name === params.get("shot")) || data.shots[0];
  const W = data.width || window.innerWidth;
  const H = data.height || window.innerHeight;

  const renderer = new THREE.WebGLRenderer({ antialias: true, preserveDrawingBuffer: true });
  renderer.setPixelRatio(1);
  renderer.setSize(W, H);
  renderer.outputEncoding = THREE.sRGBEncoding;
  renderer.toneMapping = THREE.ACESFilmicToneMapping;
  renderer.toneMappingExposure = 0.98;
  renderer.shadowMap.enabled = true;
  renderer.shadowMap.type = THREE.PCFSoftShadowMap;
  document.body.appendChild(renderer.domElement);

  const scene = new THREE.Scene();
  const plan = shot.type === "ortho";

  function srgb(c) {
    return new THREE.Color(c[0] / 255, c[1] / 255, c[2] / 255).convertSRGBToLinear();
  }

  // Sky ----------------------------------------------------------------------
  const sunDirection = new THREE.Vector3(-0.78, 0.36, 0.52).normalize();
  if (plan) {
    scene.background = new THREE.Color(0x26302a).convertSRGBToLinear();
  } else {
    const sky = new THREE.Mesh(
      new THREE.SphereGeometry(3000, 32, 16),
      new THREE.ShaderMaterial({
        side: THREE.BackSide,
        depthWrite: false,
        fog: false,
        uniforms: { sunDirection: { value: sunDirection } },
        vertexShader: "varying vec3 vDir; void main(){ vDir = normalize(position); gl_Position = projectionMatrix * modelViewMatrix * vec4(position, 1.0); }",
        fragmentShader: [
          "varying vec3 vDir; uniform vec3 sunDirection;",
          "void main(){",
          "  float h = clamp(vDir.y, -0.2, 1.0);",
          "  vec3 horizon = vec3(1.0, 0.74, 0.56);",
          "  vec3 mid = vec3(0.78, 0.60, 0.70);",
          "  vec3 zenith = vec3(0.36, 0.40, 0.66);",
          "  vec3 col = mix(horizon, mid, smoothstep(0.0, 0.22, h));",
          "  col = mix(col, zenith, smoothstep(0.2, 0.85, h));",
          "  float glow = pow(max(dot(normalize(vDir), sunDirection), 0.0), 6.0);",
          "  col += vec3(1.0, 0.66, 0.36) * glow * 0.35;",
          "  gl_FragColor = vec4(pow(col, vec3(2.2)), 1.0);",
          "}",
        ].join("\n"),
      })
    );
    sky.frustumCulled = false;
    scene.add(sky);
    scene.fog = new THREE.Fog(new THREE.Color(0.78, 0.6, 0.62).convertSRGBToLinear(), 260, 1500);
  }

  // Lights -------------------------------------------------------------------
  scene.add(new THREE.HemisphereLight(0xb4b0e0, 0x66705a, plan ? 1.15 : 0.86));
  const sun = new THREE.DirectionalLight(0xffc896, plan ? 1.0 : 1.25);
  sun.position.copy(sunDirection).multiplyScalar(420);
  sun.castShadow = true;
  sun.shadow.mapSize.set(4096, 4096);
  sun.shadow.camera.left = -260;
  sun.shadow.camera.right = 260;
  sun.shadow.camera.top = 260;
  sun.shadow.camera.bottom = -260;
  sun.shadow.camera.near = 50;
  sun.shadow.camera.far = 900;
  sun.shadow.bias = -0.0006;
  sun.shadow.normalBias = 0.25;
  sun.shadow.radius = 3;
  scene.add(sun);
  scene.add(sun.target);

  // Geometry -----------------------------------------------------------------
  const cylinder = new THREE.CylinderGeometry(0.5, 0.5, 1, 48);
  cylinder.rotateZ(Math.PI / 2);
  const wedge = new THREE.BufferGeometry();
  (function () {
    const A = [-0.5, -0.5, -0.5], B = [0.5, -0.5, -0.5], C = [0.5, -0.5, 0.5], D = [-0.5, -0.5, 0.5];
    const E = [-0.5, 0.5, 0.5], F = [0.5, 0.5, 0.5];
    const tris = [A, B, C, A, C, D, D, C, F, D, F, E, A, E, F, A, F, B, A, D, E, B, F, C];
    wedge.setAttribute("position", new THREE.Float32BufferAttribute(tris.flat(), 3));
    wedge.computeVertexNormals();
  })();
  const geometries = {
    block: new THREE.BoxGeometry(1, 1, 1),
    wedge: wedge,
    cylinder: cylinder,
    ball: new THREE.SphereGeometry(0.5, 28, 18),
    ellipsoid: new THREE.SphereGeometry(0.5, 32, 20),
  };

  const SURFACE = {
    Neon: null,
    Glass: { roughness: 0.12, metalness: 0.0 },
    Metal: { roughness: 0.45, metalness: 0.55 },
    SmoothPlastic: { roughness: 0.58, metalness: 0.0 },
    Wood: { roughness: 0.86, metalness: 0.0 },
    WoodPlanks: { roughness: 0.84, metalness: 0.0 },
    Fabric: { roughness: 0.96, metalness: 0.0 },
  };
  const materials = new Map();
  function materialFor(part) {
    const key = part.c.join(",") + "|" + part.m + "|" + part.t;
    let material = materials.get(key);
    if (material) return material;
    const color = srgb(part.c);
    if (part.m === "Neon") {
      material = new THREE.MeshBasicMaterial({ color: color, toneMapped: false });
    } else {
      const surface = SURFACE[part.m] || { roughness: 0.93, metalness: 0.0 };
      material = new THREE.MeshStandardMaterial({ color: color, roughness: surface.roughness, metalness: surface.metalness });
    }
    if (part.t > 0) {
      material.transparent = true;
      material.opacity = 1 - part.t;
      material.depthWrite = false;
    }
    materials.set(key, material);
    return material;
  }

  function frameMatrix(f) {
    return new THREE.Matrix4().set(f[3], f[4], f[5], f[0], f[6], f[7], f[8], f[1], f[9], f[10], f[11], f[2], 0, 0, 0, 1);
  }

  for (const part of data.parts) {
    if (part.t >= 1) continue;
    let size = part.z;
    if (part.s === "ball") {
      const d = Math.min(size[0], size[1], size[2]);
      size = [d, d, d];
    } else if (part.s === "cylinder") {
      const d = Math.min(size[1], size[2]);
      size = [size[0], d, d];
    }
    const mesh = new THREE.Mesh(geometries[part.s] || geometries.block, materialFor(part));
    mesh.matrixAutoUpdate = false;
    mesh.matrix.copy(frameMatrix(part.f)).multiply(new THREE.Matrix4().makeScale(size[0], size[1], size[2]));
    mesh.castShadow = part.sh && part.m !== "Neon" && part.t === 0;
    mesh.receiveShadow = part.m !== "Neon";
    scene.add(mesh);
  }

  // Signs --------------------------------------------------------------------
  function roundRect(ctx, x, y, w, h, r) {
    r = Math.max(0, Math.min(r, w / 2, h / 2));
    ctx.beginPath();
    ctx.moveTo(x + r, y);
    ctx.arcTo(x + w, y, x + w, y + h, r);
    ctx.arcTo(x + w, y + h, x, y + h, r);
    ctx.arcTo(x, y + h, x, y, r);
    ctx.arcTo(x, y, x + w, y, r);
    ctx.closePath();
  }
  function css(c, a) {
    return "rgba(" + c[0] + "," + c[1] + "," + c[2] + "," + (a === undefined ? 1 : a) + ")";
  }
  function drawGui(gui) {
    const canvas = document.createElement("canvas");
    canvas.width = Math.round(gui.w * gui.ppi);
    canvas.height = Math.round(gui.h * gui.ppi);
    const ctx = canvas.getContext("2d");
    for (const op of gui.ops) {
      if (op.k === "f") {
        roundRect(ctx, op.x, op.y, op.w, op.h, op.r);
        ctx.fillStyle = css(op.c, op.a);
        ctx.fill();
        if (op.sc) {
          ctx.lineWidth = op.st;
          ctx.strokeStyle = css(op.sc);
          ctx.stroke();
        }
      } else {
        // TextScaled: the largest single line that fits the box.
        let size = Math.min(op.max, op.h);
        ctx.font = op.weight + " " + size + 'px "' + op.font + '"';
        const width = ctx.measureText(op.text).width;
        if (width > op.w) size *= op.w / width;
        ctx.font = op.weight + " " + size + 'px "' + op.font + '"';
        ctx.fillStyle = css(op.c);
        ctx.textBaseline = "middle";
        let x = op.x + op.w / 2;
        ctx.textAlign = "center";
        if (op.ax === "Left") {
          x = op.x;
          ctx.textAlign = "left";
        } else if (op.ax === "Right") {
          x = op.x + op.w;
          ctx.textAlign = "right";
        }
        ctx.fillText(op.text, x, op.y + op.h / 2 + size * 0.04);
      }
    }
    const texture = new THREE.CanvasTexture(canvas);
    texture.encoding = THREE.sRGBEncoding;
    texture.anisotropy = 8;
    return texture;
  }
  // right, up, normal in part space for each face.
  const FACE_BASIS = {
    Back: [[1, 0, 0], [0, 1, 0], [0, 0, 1]],
    Front: [[-1, 0, 0], [0, 1, 0], [0, 0, -1]],
    Right: [[0, 0, -1], [0, 1, 0], [1, 0, 0]],
    Left: [[0, 0, 1], [0, 1, 0], [-1, 0, 0]],
    Top: [[1, 0, 0], [0, 0, -1], [0, 1, 0]],
    Bottom: [[1, 0, 0], [0, 0, 1], [0, -1, 0]],
  };
  function buildSigns() {
    for (const gui of data.guis) {
      const basis = FACE_BASIS[gui.face];
      const local = new THREE.Matrix4().makeBasis(
        new THREE.Vector3().fromArray(basis[0]),
        new THREE.Vector3().fromArray(basis[1]),
        new THREE.Vector3().fromArray(basis[2])
      );
      const offset = new THREE.Vector3().fromArray(basis[2]).multiplyScalar(gui.d + 0.03);
      local.setPosition(offset);
      const mesh = new THREE.Mesh(
        new THREE.PlaneGeometry(gui.w, gui.h),
        new THREE.MeshBasicMaterial({ map: drawGui(gui), transparent: true, toneMapped: false })
      );
      mesh.matrixAutoUpdate = false;
      mesh.matrix.copy(frameMatrix(gui.f)).multiply(local);
      scene.add(mesh);
    }
  }

  // Camera -------------------------------------------------------------------
  let camera;
  const target = new THREE.Vector3().fromArray(shot.target);
  if (plan) {
    const halfHeight = shot.halfHeight;
    const halfWidth = (halfHeight * W) / H;
    camera = new THREE.OrthographicCamera(-halfWidth, halfWidth, halfHeight, -halfHeight, 1, 2000);
    camera.position.set(target.x, 600, target.z);
    camera.up.set(0, 0, -1);
    camera.lookAt(target.x, 0, target.z);
  } else {
    camera = new THREE.PerspectiveCamera(shot.fov, W / H, 0.5, 4000);
    camera.position.fromArray(shot.position);
    camera.lookAt(target);
  }

  // Lantern light: real point lights for the nearest sources, soft halos for all.
  const haloCanvas = document.createElement("canvas");
  haloCanvas.width = haloCanvas.height = 128;
  (function () {
    const ctx = haloCanvas.getContext("2d");
    const gradient = ctx.createRadialGradient(64, 64, 0, 64, 64, 64);
    gradient.addColorStop(0, "rgba(255,255,255,0.9)");
    gradient.addColorStop(0.25, "rgba(255,255,255,0.32)");
    gradient.addColorStop(1, "rgba(255,255,255,0)");
    ctx.fillStyle = gradient;
    ctx.fillRect(0, 0, 128, 128);
  })();
  const haloTexture = new THREE.CanvasTexture(haloCanvas);
  const focus = plan ? target : camera.position.clone().lerp(target, 0.55);
  const ranked = data.lights
    .map((light) => ({ light: light, distance: new THREE.Vector3().fromArray(light.p).distanceTo(focus) }))
    .sort((a, b) => a.distance - b.distance);
  const realLights = plan ? 0 : 18;
  ranked.forEach((entry, index) => {
    const light = entry.light;
    const color = srgb(light.c);
    if (index < realLights) {
      const point = new THREE.PointLight(color, light.b * 1.5, light.r * 1.5, 1.4);
      point.position.fromArray(light.p);
      scene.add(point);
    }
    if (!plan) {
      const halo = new THREE.Sprite(
        new THREE.SpriteMaterial({
          map: haloTexture,
          color: color,
          blending: THREE.AdditiveBlending,
          depthWrite: false,
          transparent: true,
          opacity: 0.5,
          fog: false,
        })
      );
      const size = Math.min(14, light.r * 0.3);
      halo.scale.set(size, size, 1);
      halo.position.fromArray(light.p);
      scene.add(halo);
    }
  });

  function render() {
    buildSigns();
    renderer.render(scene, camera);
    document.title = "rendered";
  }
  if (document.fonts && document.fonts.load) {
    Promise.all([
      document.fonts.load('400 40px "Fredoka One"'),
      document.fonts.load('600 40px "Nunito"'),
      document.fonts.load('700 40px "Nunito"'),
      document.fonts.load('800 40px "Nunito"'),
    ]).then(render, render);
  } else {
    render();
  }
})();
