const DATA_PATH = "../data/fujixweekly/x-trans-v-recipes.json";

const state = {
  recipes: [],
  filtered: [],
  selectedId: null,
  loadout: Array(7).fill(null),  // C1–C7 slots
  favorites: new Set(),
  compare: [],  // recipe IDs selected for comparison
  sortMode: "name",  // "name" | "filmSim" | "date"
};

// Load saved loadout from localStorage
try {
  const saved = localStorage.getItem("fuji-loadout");
  if (saved) {
    const parsed = JSON.parse(saved);
    if (Array.isArray(parsed) && parsed.length === 7) {
      state.loadout = parsed;
    }
  }
} catch (e) { /* ignore */ }

// Load saved favorites from localStorage
try {
  const favs = localStorage.getItem("fuji-favorites");
  if (favs) {
    const parsed = JSON.parse(favs);
    if (Array.isArray(parsed)) {
      state.favorites = new Set(parsed);
    }
  }
} catch (e) { /* ignore */ }

// Load saved sort mode
try {
  const sort = localStorage.getItem("fuji-sort");
  if (sort && ["name", "filmSim", "date"].includes(sort)) {
    state.sortMode = sort;
  }
} catch (e) { /* ignore */ }

const labels = {
  filmSimulation: "Film Simulation",
  dynamicRange: "Dynamic Range",
  dRangePriority: "D Range Priority",
  grainEffect: "Grain Effect",
  colorChromeEffect: "Color Chrome Effect",
  colorChromeFxBlue: "Color Chrome FX Blue",
  whiteBalance: "White Balance",
  highlight: "Highlight",
  shadow: "Shadow",
  color: "Color",
  sharpness: "Sharpness",
  highIsoNr: "High ISO NR",
  clarity: "Clarity",
  iso: "ISO",
  exposureCompensation: "Exposure Comp",
};

const preferredSettingOrder = Object.keys(labels);

// PTP property lookup from setting key
const ptpProperties = {
  filmSimulation: "0xD001",
  color: "0xD002",
  dynamicRange: "0xD007",
  dRangePriority: "0xD02E",
  whiteBalance: "0x5005",
  highlight: "0xD320",
  shadow: "0xD321",
  sharpness: "0x5015",
  highIsoNr: "0xD01C",
  grainEffect: "0xD023",
  colorChromeEffect: "0xD008",
  colorChromeFxBlue: "0xD197",
  clarity: "0xD1A2",
  iso: "0x500F",
  exposureCompensation: "0x5010",
};

const els = {
  recipeCount: document.querySelector("#recipeCount"),
  visibleCount: document.querySelector("#visibleCount"),
  list: document.querySelector("#recipeList"),
  detail: document.querySelector("#recipeDetail"),
  search: document.querySelector("#searchInput"),
  filmFilter: document.querySelector("#filmFilter"),
  sensorFilter: document.querySelector("#sensorFilter"),
  statusFilter: document.querySelector("#statusFilter"),
  template: document.querySelector("#listItemTemplate"),
};

// ---------------------------------------------------------------------------
// HTML escaping
// ---------------------------------------------------------------------------

function escapeHtml(value) {
  return String(value ?? "")
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#039;");
}

// ---------------------------------------------------------------------------
// Search text generation
// ---------------------------------------------------------------------------

function recipeSearchText(recipe) {
  return [
    recipe.name,
    recipe.title,
    recipe.date,
    recipe.parseStatus,
    ...(recipe.compatibleCameras || []),
    ...Object.values(recipe.settings || {}),
    ...Object.keys(recipe.settings || {}),
  ].join(" ").toLowerCase();
}

// ---------------------------------------------------------------------------
// Ordered settings
// ---------------------------------------------------------------------------

function settingLabel(key) {
  return labels[key] || key.replace(/([A-Z])/g, " $1").replace(/^./, (char) => char.toUpperCase());
}

function orderedSettings(settings) {
  const keys = Object.keys(settings || {});
  return [
    ...preferredSettingOrder.filter((key) => keys.includes(key)),
    ...keys.filter((key) => !preferredSettingOrder.includes(key)).sort(),
  ].map((key) => [key, settings[key]]);
}

// ---------------------------------------------------------------------------
// Highlight matching text
// ---------------------------------------------------------------------------

function highlightText(text, query) {
  if (!query || !text) return escapeHtml(text);
  const escaped = escapeHtml(text);
  const regex = new RegExp(`(${escapeRegex(query)})`, "gi");
  return escaped.replace(regex, '<mark class="search-highlight">$1</mark>');
}

function escapeRegex(str) {
  return str.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}

// ---------------------------------------------------------------------------
// Filter population
// ---------------------------------------------------------------------------

function populateFilters() {
  const filmSims = [...new Set(state.recipes.map((recipe) => recipe.settings?.filmSimulation).filter(Boolean))].sort();
  els.filmFilter.innerHTML = '<option value="">All film simulations</option>' + filmSims.map((sim) => `<option value="${escapeHtml(sim)}">${escapeHtml(sim)}</option>`).join("");
}

// ---------------------------------------------------------------------------
// Filtering & Sorting
// ---------------------------------------------------------------------------

function applyFilters() {
  const query = els.search.value.trim();
  const film = els.filmFilter.value;
  const sensor = els.sensorFilter.value;
  const status = els.statusFilter.value;

  let filtered = state.recipes.filter((recipe) => {
    if (film && recipe.settings?.filmSimulation !== film) return false;
    if (sensor && recipe.sensorGeneration !== sensor) return false;
    if (status && recipe.parseStatus !== status) return false;
    if (query && !recipeSearchText(recipe).includes(query.toLowerCase())) return false;
    return true;
  });

  // Apply sorting
  filtered.sort((a, b) => {
    switch (state.sortMode) {
      case "filmSim":
        return (a.settings?.filmSimulation || "").localeCompare(b.settings?.filmSimulation || "");
      case "date":
        return (b.date || "").localeCompare(a.date || "");
      case "name":
      default:
        return (a.name || "").localeCompare(b.name || "");
    }
  });

  state.filtered = filtered;

  if (!state.filtered.some((recipe) => recipe.id === state.selectedId)) {
    state.selectedId = state.filtered[0]?.id || null;
  }

  renderList();
  renderDetail();
}

function setSortMode(mode) {
  state.sortMode = mode;
  try { localStorage.setItem("fuji-sort", mode); } catch (e) { /* ignore */ }
  renderSortButtons();
  applyFilters();
}

// ---------------------------------------------------------------------------
// Favorites
// ---------------------------------------------------------------------------

function toggleFavorite(id) {
  if (state.favorites.has(id)) {
    state.favorites.delete(id);
  } else {
    state.favorites.add(id);
  }
  try { localStorage.setItem("fuji-favorites", JSON.stringify([...state.favorites])); } catch (e) { /* ignore */ }
  renderList();
  renderDetail();
}

function isFavorite(id) {
  return state.favorites.has(id);
}

// ---------------------------------------------------------------------------
// Compare
// ---------------------------------------------------------------------------

function toggleCompare(id) {
  const idx = state.compare.indexOf(id);
  if (idx >= 0) {
    state.compare.splice(idx, 1);
  } else if (state.compare.length < 4) {
    state.compare.push(id);
  }
  renderCompareBar();
}

function isInCompare(id) {
  return state.compare.includes(id);
}

function clearCompare() {
  state.compare = [];
  renderCompareBar();
  applyFilters();
}

// ---------------------------------------------------------------------------
// Render: List
// ---------------------------------------------------------------------------

function renderList() {
  els.recipeCount.textContent = state.recipes.length;
  els.visibleCount.textContent = state.filtered.length;
  els.list.innerHTML = "";

  // Sort controls
  const sortBar = document.createElement("div");
  sortBar.className = "sort-bar";
  sortBar.innerHTML = `<span class="sort-label">Sort:</span>${renderSortButtons()}`;
  els.list.appendChild(sortBar);

  if (!state.filtered.length) {
    els.list.innerHTML += '<div class="empty-state"><p>No recipes match.</p></div>';
    return;
  }

  const fragment = document.createDocumentFragment();
  for (const recipe of state.filtered) {
    const node = els.template.content.firstElementChild.cloneNode(true);
    node.classList.toggle("is-active", recipe.id === state.selectedId);
    const titleEl = node.querySelector(".recipe-button-title");
    const query = els.search.value.trim();
    titleEl.innerHTML = highlightText(recipe.name || recipe.title, query);
    const sensorBadge = recipe.sensorGeneration && recipe.sensorGeneration !== "X-Trans V" ? ` · ${recipe.sensorGeneration}` : "";
    const favStar = isFavorite(recipe.id) ? " ★" : " ☆";
    node.querySelector(".recipe-button-meta").innerHTML = `${recipe.settings?.filmSimulation || "Unknown sim"}${sensorBadge} · ${recipe.settingCount || 0} settings${favStar}`;

    // Check if favorite recipe is filtered out when using "favorites only"
    node.dataset.recipeId = recipe.id;
    node.addEventListener("click", () => {
      state.selectedId = recipe.id;
      updateUrlHash(recipe.id);
      renderList();
      renderDetail();
    });
    fragment.appendChild(node);
  }
  els.list.appendChild(fragment);
}

function renderSortButtons() {
  const modes = [
    { key: "name", label: "Name" },
    { key: "filmSim", label: "Film Sim" },
    { key: "date", label: "Date" },
  ];
  return modes.map(m =>
    `<button class="sort-btn ${state.sortMode === m.key ? 'active' : ''}" data-sort="${m.key}" type="button">${m.label}</button>`
  ).join("");
}

// ---------------------------------------------------------------------------
// Render: Detail
// ---------------------------------------------------------------------------

function renderDetail() {
  const recipe = state.filtered.find((item) => item.id === state.selectedId);
  if (!recipe) {
    els.detail.innerHTML = '<div class="empty-state"><p>Select a recipe.</p></div>';
    return;
  }

  const settings = orderedSettings(recipe.settings || {});
  const photos = (recipe.imageUrls || []).slice(0, 18);
  const cameras = (recipe.compatibleCameras || []).slice(0, 8);
  const statusChip = recipe.parseStatus === "ok"
    ? '<span class="chip">Parsed OK</span>'
    : '<span class="chip warn">Needs review</span>';

  const favClass = isFavorite(recipe.id) ? "is-fav" : "";
  const compClass = isInCompare(recipe.id) ? "is-comp" : "";

  els.detail.innerHTML = `
    <article>
      <header class="detail-header" style="--hero-image: url('${escapeHtml(recipe.previewImageUrl || "")}')">
        <div class="detail-kicker">
          <span class="chip">${escapeHtml(recipe.settings?.filmSimulation || "Unknown simulation")}</span>
          <span class="chip">${escapeHtml(recipe.sensorGeneration || "X-Trans V")}</span>
          ${statusChip}
          ${cameras.map((camera) => `<span class="chip">${escapeHtml(camera)}</span>`).join("")}
        </div>
        <h2 class="detail-title">${escapeHtml(recipe.name || recipe.title)}</h2>
        <div class="detail-actions">
          <a class="link-button" href="${escapeHtml(recipe.sourceUrl)}" target="_blank" rel="noreferrer">Open source page</a>
          <button class="link-button add-to-loadout" data-recipe-id="${escapeHtml(recipe.id)}" type="button">+ Add to Loadout</button>
          <button class="link-button ${favClass}" data-action="toggle-fav" data-recipe-id="${escapeHtml(recipe.id)}" type="button">${isFavorite(recipe.id) ? "★ Favorited" : "☆ Favorite"}</button>
          <button class="link-button ${compClass}" data-action="toggle-compare" data-recipe-id="${escapeHtml(recipe.id)}" type="button">${isInCompare(recipe.id) ? "✓ In Compare" : "+ Compare"}</button>
          <button class="link-button" data-action="copy-settings" data-recipe-id="${escapeHtml(recipe.id)}" type="button">📋 Copy</button>
          <button class="link-button" data-action="export-recipe" data-recipe-id="${escapeHtml(recipe.id)}" type="button">💾 Export</button>
        </div>
      </header>

      <div class="content-grid">
        <section class="panel">
          <h2>Recipe Settings</h2>
          <dl class="settings-grid">
            ${settings.map(([key, value]) => {
              const ptp = ptpProperties[key] || null;
              const badge = ptp ? `<span class="ptp-badge">${escapeHtml(ptp)}</span>` : '';
              return `
              <div class="setting">
                <dt>${escapeHtml(settingLabel(key))} ${badge}</dt>
                <dd>${escapeHtml(value)}</dd>
              </div>`;
            }).join("")}
          </dl>
          ${recipe.reviewNotes?.length ? `<div class="notes">${recipe.reviewNotes.map(escapeHtml).join("<br>")}</div>` : ""}
        </section>

        <section class="panel">
          <h2>Example Photos</h2>
          <div class="photo-grid">
            ${photos.map((src, index) => `<img src="${escapeHtml(src)}" alt="${escapeHtml(recipe.name)} example ${index + 1}" loading="lazy">`).join("")}
          </div>
          <div class="notes">
            ${escapeHtml(recipe.date || "Date unavailable")} · ${escapeHtml(recipe.source || "Source unavailable")} · ${photos.length} preview images loaded
          </div>
        </section>
      </div>
    </article>
  `;
}

// ---------------------------------------------------------------------------
// Render: Compare bar
// ---------------------------------------------------------------------------

function renderCompareBar() {
  let bar = document.querySelector("#compareBar");
  if (!state.compare.length) {
    if (bar) bar.remove();
    return;
  }
  if (!bar) {
    bar = document.createElement("div");
    bar.id = "compareBar";
    bar.className = "compare-bar";
    document.querySelector(".shell").insertBefore(bar, document.querySelector(".toolbar"));
  }

  bar.innerHTML = `
    <span class="compare-label">Compare (${state.compare.length}/4)</span>
    ${state.compare.map(id => {
      const recipe = state.recipes.find(r => r.id === id);
      return recipe ? `<span class="compare-chip">${escapeHtml(recipe.name)} <button class="compare-remove" data-id="${id}" type="button">×</button></span>` : "";
    }).join("")}
    <button class="action-button" id="clearCompare" type="button">Clear</button>
    <button class="action-button primary" id="showCompare" type="button">Show Comparison</button>
  `;

  bar.querySelector("#clearCompare")?.addEventListener("click", clearCompare);
  bar.querySelector("#showCompare")?.addEventListener("click", showComparison);
  bar.querySelectorAll(".compare-remove").forEach(btn => {
    btn.addEventListener("click", (e) => {
      e.stopPropagation();
      toggleCompare(btn.dataset.id);
    });
  });
}

function showComparison() {
  if (state.compare.length < 2) {
    alert("Select at least 2 recipes to compare.");
    return;
  }
  const recipes = state.compare.map(id => state.recipes.find(r => r.id === id)).filter(Boolean);
  const allKeys = [...new Set(recipes.flatMap(r => Object.keys(r.settings || {})))];

  // Sort keys by preferred order
  allKeys.sort((a, b) => {
    const aIdx = preferredSettingOrder.indexOf(a);
    const bIdx = preferredSettingOrder.indexOf(b);
    if (aIdx >= 0 && bIdx >= 0) return aIdx - bIdx;
    if (aIdx >= 0) return -1;
    if (bIdx >= 0) return 1;
    return a.localeCompare(b);
  });

  let html = `
    <div style="padding: 24px; overflow-x: auto;">
      <h2 style="margin-bottom: 16px;">Recipe Comparison</h2>
      <table style="width: 100%; border-collapse: collapse; font-size: 0.85rem;">
        <thead>
          <tr>
            <th style="text-align: left; padding: 8px; border-bottom: 2px solid var(--line); color: var(--muted);">Setting</th>
            ${recipes.map(r => `<th style="text-align: left; padding: 8px; border-bottom: 2px solid var(--line);">${escapeHtml(r.name)}</th>`).join("")}
          </tr>
        </thead>
        <tbody>
          ${allKeys.map(key => `
            <tr>
              <td style="padding: 6px 8px; border-bottom: 1px solid var(--line); color: var(--muted); font-weight: 600;">${escapeHtml(settingLabel(key))}</td>
              ${recipes.map(r => `<td style="padding: 6px 8px; border-bottom: 1px solid var(--line);">${escapeHtml(r.settings?.[key] || "—")}${ptpProperties[key] ? ` <span class="ptp-badge">${escapeHtml(ptpProperties[key])}</span>` : ""}</td>`).join("")}
            </tr>
          `).join("")}
        </tbody>
      </table>
      <button class="action-button" id="closeCompare" type="button" style="margin-top: 16px;">Close</button>
    </div>
  `;

  const container = document.createElement("div");
  container.innerHTML = html;
  document.querySelector(".detail").innerHTML = container.querySelector("div").innerHTML;
  document.querySelector("#closeCompare")?.addEventListener("click", () => {
    renderDetail();
  });
}

// ---------------------------------------------------------------------------
// Render: Loadout
// ---------------------------------------------------------------------------

function saveLoadout() {
  try { localStorage.setItem("fuji-loadout", JSON.stringify(state.loadout)); } catch (e) { /* ignore */ }
}

function renderLoadout() {
  const slotsEl = document.getElementById("loadoutSlots");
  const countEl = document.getElementById("loadoutCount");
  if (!slotsEl) return;

  const filled = state.loadout.filter(Boolean).length;
  countEl.textContent = `${filled}/7`;

  slotsEl.innerHTML = state.loadout.map((recipeId, index) => {
    const recipe = recipeId ? state.recipes.find(r => r.id === recipeId) : null;
    const hasRecipe = !!recipe;
    return `
      <div class="loadout-slot ${hasRecipe ? 'has-recipe' : ''}" data-slot="${index}" role="button" tabindex="0">
        <span class="loadout-slot-label">C${index + 1}</span>
        ${hasRecipe
          ? `<span class="loadout-slot-name">${escapeHtml(recipe.name)}</span>
             <span class="loadout-slot-sim">${escapeHtml(recipe.settings?.filmSimulation || '')}</span>`
          : `<span class="loadout-slot-empty">Empty</span>`
        }
      </div>
    `;
  }).join("");

  // Click handlers
  slotsEl.querySelectorAll(".loadout-slot").forEach(el => {
    el.addEventListener("click", () => {
      const slotIndex = parseInt(el.dataset.slot);
      const currentRecipeId = state.loadout[slotIndex];
      if (currentRecipeId) {
        // Clicking a filled slot selects that recipe in the detail view
        state.selectedId = currentRecipeId;
        updateUrlHash(currentRecipeId);
        renderList();
        renderDetail();
      }
    });
  });
}

function addToLoadout(recipeId) {
  // Find first empty slot
  const emptySlot = state.loadout.indexOf(null);
  if (emptySlot === -1) {
    // All slots filled — replace first
    state.loadout[0] = recipeId;
  } else {
    state.loadout[emptySlot] = recipeId;
  }
  saveLoadout();
  renderLoadout();
}

function removeFromLoadout(slotIndex) {
  state.loadout[slotIndex] = null;
  saveLoadout();
  renderLoadout();
}

function clearLoadout() {
  state.loadout = Array(7).fill(null);
  saveLoadout();
  renderLoadout();
}

function exportLoadout() {
  const filled = state.loadout.filter(Boolean);
  if (filled.length === 0) {
    alert("No recipes in loadout.");
    return;
  }
  const payload = {
    exportDate: new Date().toISOString(),
    source: "Fuji Recipes Research",
    slotCount: filled.length,
    loadout: state.loadout.map((recipeId, index) => {
      const recipe = recipeId ? state.recipes.find(r => r.id === recipeId) : null;
      return {
        slot: `C${index + 1}`,
        name: recipe ? recipe.name : null,
        filmSimulation: recipe ? recipe.settings?.filmSimulation : null,
        settings: recipe ? recipe.settings : null,
        ptpProperties: recipe ? Object.entries(recipe.settings || {}).reduce((acc, [key, val]) => {
          const ptp = ptpProperties[key];
          if (ptp) acc[ptp] = val;
          return acc;
        }, {}) : null,
      };
    }),
  };
  const blob = new Blob([JSON.stringify(payload, null, 2)], { type: "application/json" });
  const url = URL.createObjectURL(blob);
  const a = document.createElement("a");
  a.href = url;
  a.download = `fuji-loadout-${new Date().toISOString().slice(0,10)}.json`;
  a.click();
  URL.revokeObjectURL(url);
}

// ---------------------------------------------------------------------------
// Export single recipe
// ---------------------------------------------------------------------------

function exportRecipe(id) {
  const recipe = state.recipes.find(r => r.id === id);
  if (!recipe) return;
  const payload = {
    exportDate: new Date().toISOString(),
    source: "Fuji Recipes Research",
    recipe: {
      id: recipe.id,
      name: recipe.name,
      sensorGeneration: recipe.sensorGeneration,
      filmSimulation: recipe.settings?.filmSimulation,
      settings: recipe.settings,
      sourceUrl: recipe.sourceUrl,
      ptpProperties: Object.entries(recipe.settings || {}).reduce((acc, [key, val]) => {
        const ptp = ptpProperties[key];
        if (ptp) acc[key] = ptp;
        return acc;
      }, {}),
    },
  };
  const blob = new Blob([JSON.stringify(payload, null, 2)], { type: "application/json" });
  const url = URL.createObjectURL(blob);
  const a = document.createElement("a");
  a.href = url;
  a.download = `${recipe.id}.json`;
  a.click();
  URL.revokeObjectURL(url);
}

// ---------------------------------------------------------------------------
// Copy settings to clipboard
// ---------------------------------------------------------------------------

function copySettings(id) {
  const recipe = state.recipes.find(r => r.id === id);
  if (!recipe) return;
  const lines = Object.entries(recipe.settings || {}).map(([key, val]) =>
    `${settingLabel(key)}: ${val}${ptpProperties[key] ? ` [${ptpProperties[key]}]` : ""}`
  );
  const text = `${recipe.name}\n${recipe.settings?.filmSimulation || ""}\n${lines.join("\n")}`;
  navigator.clipboard.writeText(text).then(() => {
    // Show brief toast
    showToast("Settings copied to clipboard");
  }).catch(() => {
    // Fallback
    const ta = document.createElement("textarea");
    ta.value = text;
    document.body.appendChild(ta);
    ta.select();
    document.execCommand("copy");
    document.body.removeChild(ta);
    showToast("Settings copied to clipboard");
  });
}

function showToast(message) {
  let toast = document.querySelector(".toast");
  if (!toast) {
    toast = document.createElement("div");
    toast.className = "toast";
    document.querySelector(".shell").appendChild(toast);
  }
  toast.textContent = message;
  toast.classList.add("show");
  setTimeout(() => toast.classList.remove("show"), 2000);
}

// ---------------------------------------------------------------------------
// Import loadout from JSON
// ---------------------------------------------------------------------------

function importLoadout() {
  const input = document.createElement("input");
  input.type = "file";
  input.accept = ".json";
  input.addEventListener("change", (e) => {
    const file = e.target.files[0];
    if (!file) return;
    const reader = new FileReader();
    reader.onload = (ev) => {
      try {
        const data = JSON.parse(ev.target.result);
        // Support both old format (array) and new format (object with loadout key)
        let slots;
        if (Array.isArray(data)) {
          slots = data;
        } else if (data.loadout && Array.isArray(data.loadout)) {
          // New format: array of slot objects
          slots = data.loadout.map(s => s.name ? null : null); // We need IDs, not names
          // Try to match by name
          slots = data.loadout.map(s => {
            if (!s.name) return null;
            const found = state.recipes.findIndex(r => r.name === s.name);
            return found >= 0 ? state.recipes[found].id : null;
          });
        } else if (data.loadout) {
          slots = data.loadout;
        }

        if (!Array.isArray(slots) || slots.length !== 7) {
          alert("Invalid loadout file: expected 7 slots.");
          return;
        }

        state.loadout = slots.slice(0, 7);
        saveLoadout();
        renderLoadout();
        showToast("Loadout imported");
      } catch (err) {
        alert(`Failed to parse loadout file: ${err.message}`);
      }
    };
    reader.readAsText(file);
  });
  input.click();
}

// ---------------------------------------------------------------------------
// URL hash (deep linking)
// ---------------------------------------------------------------------------

function updateUrlHash(id) {
  history.replaceState(null, "", `#${id}`);
}

function loadFromUrlHash() {
  const hash = window.location.hash.slice(1);
  if (hash && state.recipes.find(r => r.id === hash)) {
    state.selectedId = hash;
  }
}

// ---------------------------------------------------------------------------
// Keyboard navigation
// ---------------------------------------------------------------------------

function handleKeyboard(e) {
  // Only handle when not in input fields
  if (e.target.tagName === "INPUT" || e.target.tagName === "SELECT" || e.target.tagName === "TEXTAREA") return;

  const list = els.list;
  const buttons = list.querySelectorAll(".recipe-button");
  if (!buttons.length) return;

  const currentIdx = Array.from(buttons).findIndex(b => b.classList.contains("is-active"));
  let nextIdx = currentIdx;

  if (e.key === "ArrowDown" || e.key === "j") {
    nextIdx = Math.min(currentIdx + 1, buttons.length - 1);
    e.preventDefault();
  } else if (e.key === "ArrowUp" || e.key === "k") {
    nextIdx = Math.max(currentIdx - 1, 0);
    e.preventDefault();
  } else if (e.key === "n" || e.key === "f") {
    nextIdx = Math.min(currentIdx + 1, buttons.length - 1);
    e.preventDefault();
  } else if (e.key === "p") {
    nextIdx = Math.max(currentIdx - 1, 0);
    e.preventDefault();
  } else {
    return;
  }

  if (nextIdx !== currentIdx) {
    buttons[nextIdx].click();
    buttons[nextIdx].scrollIntoView({ block: "nearest", behavior: "smooth" });
  }
}

// ---------------------------------------------------------------------------
// Load data
// ---------------------------------------------------------------------------

async function loadLibrary() {
  try {
    const response = await fetch(DATA_PATH);
    if (!response.ok) throw new Error(`Could not load recipe data: ${response.status}`);
    const payload = await response.json();
    state.recipes = (payload.recipes || []).map((recipe, index) => ({
      ...recipe,
      id: recipe.id || `recipe-${index}`,
    }));
    state.filtered = [...state.recipes];
    state.selectedId = state.recipes[0]?.id || null;
    populateFilters();
    loadFromUrlHash();
    applyFilters();

    // Sort button bindings
    document.querySelector(".sort-bar")?.addEventListener("click", (e) => {
      const btn = e.target.closest(".sort-btn");
      if (btn) setSortMode(btn.dataset.sort);
    });

  } catch (error) {
    els.detail.innerHTML = `
      <div class="empty-state">
        <p>${escapeHtml(error.message)}. Serve the project root with <code>python3 -m http.server 8765</code> and open <code>http://localhost:8765/site/</code>.</p>
      </div>
    `;
  }
}

// ---------------------------------------------------------------------------
// Event bindings
// ---------------------------------------------------------------------------

els.search.addEventListener("input", applyFilters);
els.filmFilter.addEventListener("change", applyFilters);
els.sensorFilter.addEventListener("change", applyFilters);
els.statusFilter.addEventListener("change", applyFilters);

document.addEventListener("keydown", handleKeyboard);

// ---- Loadout toggle ----

const loadoutToggle = document.getElementById("loadoutToggle");
const loadoutPanel = document.getElementById("loadoutPanel");
if (loadoutToggle && loadoutPanel) {
  loadoutToggle.addEventListener("click", () => {
    const isOpen = loadoutPanel.classList.toggle("is-open");
    loadoutToggle.setAttribute("aria-expanded", isOpen);
    loadoutPanel.setAttribute("aria-hidden", !isOpen);
  });
}

document.getElementById("clearLoadout")?.addEventListener("click", clearLoadout);
document.getElementById("exportLoadout")?.addEventListener("click", exportLoadout);

// ---- Loadout import button ----

const importBtn = document.getElementById("importLoadout");
if (importBtn) {
  importBtn.addEventListener("click", importLoadout);
}

// ---- Event delegation for recipe detail actions ----

document.querySelector("#recipeDetail")?.addEventListener("click", (e) => {
  const loadoutBtn = e.target.closest(".add-to-loadout");
  if (loadoutBtn) {
    addToLoadout(loadoutBtn.dataset.recipeId);
    return;
  }
  const favBtn = e.target.closest('[data-action="toggle-fav"]');
  if (favBtn) {
    toggleFavorite(favBtn.dataset.recipeId);
    return;
  }
  const compBtn = e.target.closest('[data-action="toggle-compare"]');
  if (compBtn) {
    toggleCompare(compBtn.dataset.recipeId);
    return;
  }
  const copyBtn = e.target.closest('[data-action="copy-settings"]');
  if (copyBtn) {
    copySettings(copyBtn.dataset.recipeId);
    return;
  }
  const exportBtn = e.target.closest('[data-action="export-recipe"]');
  if (exportBtn) {
    exportRecipe(exportBtn.dataset.recipeId);
    return;
  }
});

// ---- Render loadout on load ----

renderLoadout();
loadLibrary();
