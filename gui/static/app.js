const NOTES = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"];

const KNOB_GROUPS = {
  "knobs-vcf": [
    ["cutoff", "Cutoff", 0, 255],
    ["res", "Res", 0, 255],
    ["fenv", "F.env", 0, 255],
    ["fdecay", "F.dec", 1, 255],
  ],
  "knobs-adsr": [
    ["attack", "Attack", 1, 255],
    ["decay", "Decay", 1, 255],
    ["sustain", "Sustain", 0, 255],
    ["release", "Release", 1, 255],
  ],
  "knobs-tone": [
    ["drive", "Drive", 0, 255],
    ["fm_index", "FM idx", 0, 255],
    ["fm_ratio", "FM ratio", 1, 8],
    ["fold", "Fold", 0, 255],
  ],
};

const $ = (id) => document.getElementById(id);

let state = null;
let debounce = {};

async function api(path, body) {
  const opt = body === undefined
    ? {}
    : { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify(body) };
  const res = await fetch(path, opt);
  const data = await res.json();
  if (!res.ok) throw new Error(data.error || res.statusText);
  return data;
}

function pitchLabel(step) {
  if (step.rest) return "—";
  return NOTES[step.note] + (step.high ? "+" : "");
}

function renderGrid() {
  const root = $("grid");
  root.innerHTML = "";
  (state.steps || []).forEach((step, i) => {
    const el = document.createElement("div");
    el.className = "step"
      + (step.rest ? " rest" : "")
      + (step.accent ? " accent" : "")
      + (step.slide ? " slide" : "");
    el.innerHTML = `
      <span class="n">${String(i + 1).padStart(2, "0")}</span>
      <button type="button" class="pitch" data-i="${i}">${pitchLabel(step)}</button>
      <div class="flags">
        <button type="button" class="flag${step.accent ? " on" : ""}" data-i="${i}" data-f="accent">A</button>
        <button type="button" class="flag slide${step.slide ? " on" : ""}" data-i="${i}" data-f="slide">S</button>
        <button type="button" class="flag rest${step.rest ? " on" : ""}" data-i="${i}" data-f="rest">R</button>
      </div>`;
    root.appendChild(el);
  });
}

function renderKnobs() {
  Object.entries(KNOB_GROUPS).forEach(([id, list]) => {
    const box = $(id);
    box.innerHTML = "";
    list.forEach(([key, label, min, max]) => {
      const row = document.createElement("div");
      row.className = "knob";
      row.innerHTML = `
        <label for="k-${key}">${label}</label>
        <input type="range" id="k-${key}" min="${min}" max="${max}" value="${state[key]}" />
        <span class="val" id="v-${key}">${state[key]}</span>`;
      box.appendChild(row);
    });
  });
}

function applyState(s) {
  state = s;
  $("bpm").value = s.bpm;
  $("octave").value = s.octave;
  $("length").value = s.length;
  $("wave").value = String(s.wave);
  $("link-pill").textContent = s.connected ? s.port : "offline";
  $("link-pill").classList.toggle("on", !!s.connected);
  $("btn-connect").textContent = s.connected ? "Disconnect" : "Connect";
  $("btn-play").textContent = s.play ? "Stop" : "Play";
  $("btn-play").classList.toggle("playing", !!s.play);
  renderGrid();
  renderKnobs();
  bindKnobs();
}

function bindKnobs() {
  Object.values(KNOB_GROUPS).flat().forEach(([key]) => {
    const el = $("k-" + key);
    if (!el) return;
    el.oninput = () => {
      $("v-" + key).textContent = el.value;
      clearTimeout(debounce[key]);
      debounce[key] = setTimeout(() => {
        api("/api/param", { key, value: Number(el.value) }).catch(showErr);
      }, 40);
    };
  });
}

function showErr(e) {
  $("link-pill").textContent = e.message || "error";
  $("link-pill").classList.remove("on");
}

async function loadPorts() {
  const data = await api("/api/ports");
  const sel = $("port");
  sel.innerHTML = "";
  (data.ports || []).forEach((p) => {
    const o = document.createElement("option");
    o.value = p;
    o.textContent = p;
    if (p === data.port) o.selected = true;
    sel.appendChild(o);
  });
  if (!data.ports.length) {
    const o = document.createElement("option");
    o.value = data.port || "COM4";
    o.textContent = o.value + " (none listed)";
    sel.appendChild(o);
  }
}

async function pushPattern() {
  await api("/api/pattern", {
    steps: state.steps,
    bpm: Number($("bpm").value),
    length: Number($("length").value),
    octave: Number($("octave").value),
  });
}

$("grid").addEventListener("click", (ev) => {
  const t = ev.target;
  if (!(t instanceof HTMLElement)) return;
  const i = Number(t.dataset.i);
  if (Number.isNaN(i) || !state.steps[i]) return;
  const step = state.steps[i];
  if (t.classList.contains("pitch")) {
    if (step.rest) {
      step.rest = false;
    } else if (t.shiftKey) {
      step.high = !step.high;
    } else {
      step.note = (step.note + 1) % 12;
    }
  } else if (t.dataset.f) {
    step[t.dataset.f] = !step[t.dataset.f];
  } else {
    return;
  }
  renderGrid();
  clearTimeout(debounce.pat);
  debounce.pat = setTimeout(() => pushPattern().catch(showErr), 80);
});

$("btn-play").onclick = async () => {
  try {
    const s = await api("/api/param", { key: "play", value: state.play ? 0 : 1 });
    applyState(s);
  } catch (e) { showErr(e); }
};

["bpm", "octave", "length", "wave"].forEach((key) => {
  $(key).onchange = async () => {
    try {
      const s = await api("/api/param", { key, value: Number($(key).value) });
      applyState(s);
    } catch (e) { showErr(e); }
  };
});

$("btn-push").onclick = () => pushPattern().catch(showErr);
$("btn-refresh").onclick = () => loadPorts().catch(showErr);

$("btn-connect").onclick = async () => {
  try {
    if (state.connected) {
      applyState(await api("/api/disconnect", {}));
    } else {
      applyState(await api("/api/connect", { port: $("port").value }));
      await pushPattern();
      for (const key of Object.keys(KNOB_GROUPS).flatMap((g) => KNOB_GROUPS[g].map((x) => x[0]))) {
        await api("/api/param", { key, value: state[key] });
      }
      await api("/api/param", { key: "wave", value: state.wave });
      await api("/api/param", { key: "octave", value: state.octave });
      await api("/api/param", { key: "bpm", value: state.bpm });
    }
  } catch (e) { showErr(e); }
};

(async function init() {
  try {
    await loadPorts();
    applyState(await api("/api/state"));
  } catch (e) {
    showErr(e);
  }
})();
