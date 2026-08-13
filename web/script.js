const resourceName = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'kyr_appearance';

function post(endpoint, data) {
    return fetch(`https://${resourceName}/${endpoint}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify(data || {})
    }).then(async (r) => {
        const text = await r.text();
        if (!text) return {};
        try { return JSON.parse(text); } catch (_) { return {}; }
    }).catch(() => ({}));
}

/** After equipping a preset (or any bulk change), sync Clothing + Advanced UI from live ped. */
async function refreshClothingUI(fromResponse) {
    let clothing = fromResponse && fromResponse.clothing;
    let limits = fromResponse && fromResponse.clothingLimits;

    if (!clothing) {
        const state = await post('getClothingState', {});
        clothing = state && state.clothing;
        limits = state && state.clothingLimits;
    }
    if (!clothing) return;

    const data = lastOpenData || {};
    if (limits) {
        data.clothingLimits = limits;
        lastOpenData = data;
    }

    renderClothing(
        data.clothingComponents || [],
        data.clothingProps || [],
        data.clothingLimits || { components: {}, props: {} },
        clothing,
        data.clothingNames || clothingState.clothingNames
    );
}

const app = document.getElementById('app');
let current = {};
let lastOpenData = {}; // keep labels / limits so we can re-render after randomize

// ---------------------------------------------------------------- tabs

document.querySelectorAll('.tab-btn').forEach(btn => {
    btn.addEventListener('click', () => {
        if (btn.style.display === 'none') return;

        document.querySelectorAll('.tab-btn').forEach(b => b.classList.remove('active'));
        document.querySelectorAll('.tab-pane').forEach(p => p.classList.remove('active'));
        btn.classList.add('active');
        const pane = document.getElementById(`tab-${btn.dataset.tab}`);
        if (pane) pane.classList.add('active');

        if (btn.dataset.tab === 'clothing' || btn.dataset.tab === 'presets' || btn.dataset.tab === 'advanced') {
            post('setCamFocus', { focus: 'body' });
        } else {
            post('setCamFocus', { focus: 'head' });
        }
    });
});

// ---------------------------------------------------------------- camera

// Hold-to-rotate / hold-to-zoom for smoother camera control
function bindHoldControl(el, tickFn) {
    if (!el) return;
    let timer = null;
    let active = false;

    const start = (e) => {
        e.preventDefault();
        if (active) return;
        active = true;
        tickFn();
        timer = setInterval(tickFn, 50); // ~20 ticks/sec
    };
    const stop = () => {
        active = false;
        if (timer) {
            clearInterval(timer);
            timer = null;
        }
    };

    el.addEventListener('mousedown', start);
    el.addEventListener('touchstart', start, { passive: false });
    window.addEventListener('mouseup', stop);
    window.addEventListener('touchend', stop);
    el.addEventListener('mouseleave', stop);
}

bindHoldControl(document.getElementById('rotate-left'), () => post('rotate', { direction: -1, amount: 8 }));
bindHoldControl(document.getElementById('rotate-right'), () => post('rotate', { direction: 1, amount: 8 }));
bindHoldControl(document.getElementById('zoom-in'), () => post('zoom', { direction: -1 }));
bindHoldControl(document.getElementById('zoom-out'), () => post('zoom', { direction: 1 }));

document.querySelectorAll('.cam-focus').forEach(btn => {
    btn.addEventListener('click', () => post('setCamFocus', { focus: btn.dataset.focus }));
});

// ---------------------------------------------------------------- randomize (characterisation only)

const randomizeBtn = document.getElementById('btn-randomize');
if (randomizeBtn) {
    randomizeBtn.addEventListener('click', async () => {
        const res = await post('randomize', {});
        if (!res || !res.current) return;

        current = res.current;

        // Update heritage sliders
        if (current.headBlend) {
            document.querySelectorAll('#tab-heritage .slider-row').forEach(row => {
                const field = row.dataset.field;
                const input = row.querySelector('input[type="range"]');
                const valInput = row.querySelector('.val-input');
                if (input && current.headBlend[field] !== undefined) {
                    input.value = current.headBlend[field];
                    if (valInput) {
                        valInput.value = field.endsWith('Mix')
                            ? Number(current.headBlend[field]).toFixed(2)
                            : current.headBlend[field];
                    }
                }
            });
        }

        // Update hair + eyes
        if (current.hair) {
            const map = {
                hairStyle: current.hair.style,
                hairColor: current.hair.color,
                hairHighlight: current.hair.highlight
            };
            document.querySelectorAll('#tab-hair .slider-row').forEach(row => {
                const field = row.dataset.field;
                const input = row.querySelector('input[type="range"]');
                const valInput = row.querySelector('.val-input');
                if (input && map[field] !== undefined) {
                    input.value = map[field];
                    if (valInput) valInput.value = map[field];
                }
            });
        }

        if (current.eyeColor !== undefined) {
            const row = document.querySelector('#tab-hair [data-field="eyeColor"]');
            if (row) {
                const input = row.querySelector('input[type="range"]');
                const valInput = row.querySelector('.val-input');
                if (input) input.value = current.eyeColor;
                if (valInput) valInput.value = current.eyeColor;
            }
        }

        // Re-render face features + overlays with the new values
        if (lastOpenData.faceFeatures) {
            renderFaceFeatures(lastOpenData.faceFeatures);
        }
        if (lastOpenData.overlays) {
            renderOverlays(lastOpenData.overlays);
        }
    });
}

// ---------------------------------------------------------------- helpers

function makeValueEditable(row, isFloat = false) {
    const range = row.querySelector('input[type="range"]');
    const oldVal = row.querySelector('.val');
    if (!range || !oldVal) return;

    const val = document.createElement('input');
    val.type = 'number';
    val.className = 'val-input';
    val.min = range.min;
    val.max = range.max;
    val.step = range.step;
    val.value = oldVal.textContent || range.value;

    oldVal.replaceWith(val);

    range.addEventListener('input', () => {
        val.value = isFloat ? Number(range.value).toFixed(2) : range.value;
    });

    val.addEventListener('change', () => {
        let num = Number(val.value);
        if (isNaN(num)) num = Number(range.min);
        num = Math.max(Number(range.min), Math.min(Number(range.max), num));
        val.value = isFloat ? num.toFixed(2) : num;
        range.value = num;
        range.dispatchEvent(new Event('input'));
    });

    val.addEventListener('keydown', (e) => {
        if (e.key === 'Enter') val.blur();
    });
}

function makeSliderRow(labelText, min, max, step, initial, onInput) {
    const row = document.createElement('div');
    row.className = 'slider-row';

    const label = document.createElement('label');
    label.textContent = labelText;

    const input = document.createElement('input');
    input.type = 'range';
    input.min = min;
    input.max = max;
    input.step = step;
    input.value = initial;

    const val = document.createElement('input');
    val.type = 'number';
    val.className = 'val-input';
    val.min = min;
    val.max = max;
    val.step = step;
    val.value = step < 1 ? Number(initial).toFixed(2) : initial;

    input.addEventListener('input', () => {
        const v = step < 1 ? Number(input.value).toFixed(2) : input.value;
        val.value = v;
        onInput(input.value);
    });

    val.addEventListener('change', () => {
        let num = Number(val.value);
        if (isNaN(num)) num = Number(min);
        num = Math.max(Number(min), Math.min(Number(max), num));
        val.value = step < 1 ? num.toFixed(2) : num;
        input.value = num;
        onInput(num);
    });

    val.addEventListener('keydown', (e) => {
        if (e.key === 'Enter') val.blur();
    });

    row.appendChild(label);
    row.appendChild(input);
    row.appendChild(val);
    return row;
}

// ---------------------------------------------------------------- heritage

function bindHeritageSlider(row) {
    const field = row.dataset.field;
    const input = row.querySelector('input');
    const isMix = field.endsWith('Mix');
    input.max = isMix ? 1 : 45;

    input.addEventListener('input', () => {
        current.headBlend = current.headBlend || {};
        current.headBlend[field] = Number(input.value);
        post('headBlend', current.headBlend);
    });
}

document.querySelectorAll('#tab-heritage .slider-row').forEach(row => {
    bindHeritageSlider(row);
    makeValueEditable(row, row.dataset.field.endsWith('Mix'));
});

// ---------------------------------------------------------------- face features

function renderFaceFeatures(labels) {
    const container = document.getElementById('tab-face');
    container.innerHTML = '';

    Object.keys(labels).forEach(index => {
        const row = document.createElement('div');
        row.className = 'slider-row';

        const label = document.createElement('label');
        label.textContent = labels[index];

        const input = document.createElement('input');
        input.type = 'range';
        input.min = -1;
        input.max = 1;
        input.step = 0.05;
        input.value = (current.faceFeatures && current.faceFeatures[index]) || 0;

        const val = document.createElement('input');
        val.type = 'number';
        val.className = 'val-input';
        val.min = -1;
        val.max = 1;
        val.step = 0.05;
        val.value = Number(input.value).toFixed(2);

        input.addEventListener('input', () => {
            val.value = Number(input.value).toFixed(2);
            current.faceFeatures = current.faceFeatures || {};
            current.faceFeatures[index] = Number(input.value);
            post('faceFeature', { index, value: input.value });
        });

        val.addEventListener('change', () => {
            let num = Number(val.value);
            if (isNaN(num)) num = 0;
            num = Math.max(-1, Math.min(1, num));
            val.value = num.toFixed(2);
            input.value = num;
            current.faceFeatures = current.faceFeatures || {};
            current.faceFeatures[index] = num;
            post('faceFeature', { index, value: num });
        });

        val.addEventListener('keydown', (e) => {
            if (e.key === 'Enter') val.blur();
        });

        row.appendChild(label);
        row.appendChild(input);
        row.appendChild(val);
        container.appendChild(row);
    });
}

// ---------------------------------------------------------------- hair & eyes

function bindHairEyeSliders() {
    document.querySelectorAll('#tab-hair .slider-row').forEach(row => {
        const field = row.dataset.field;
        const input = row.querySelector('input');

        input.addEventListener('input', () => {
            if (field === 'eyeColor') {
                post('eyeColor', { colorId: input.value });
                return;
            }

            current.hair = current.hair || {};
            if (field === 'hairStyle') current.hair.style = Number(input.value);
            if (field === 'hairColor') current.hair.color = Number(input.value);
            if (field === 'hairHighlight') current.hair.highlight = Number(input.value);

            post('hair', current.hair);
        });

        makeValueEditable(row, false);
    });
}

bindHairEyeSliders();

// ---------------------------------------------------------------- overlays

function renderOverlays(overlays) {
    const container = document.getElementById('tab-overlays');
    container.innerHTML = '';

    overlays.forEach(o => {
        const block = document.createElement('div');
        block.className = 'overlay-block';

        const label = document.createElement('div');
        label.className = 'section-label';
        label.textContent = o.label;
        block.appendChild(label);

        const existing = (current.overlays && current.overlays[o.id]) || {};

        const styleRow = makeSliderRow('Style', -1, o.max, 1, existing.index ?? -1, value => {
            existing.index = Number(value);
            pushOverlay(o, existing);
        });
        block.appendChild(styleRow);

        const opacityRow = makeSliderRow('Opacity', 0, 1, 0.05, existing.opacity ?? 1, value => {
            existing.opacity = Number(value);
            pushOverlay(o, existing);
        });
        block.appendChild(opacityRow);

        if (o.hasColor) {
            const colorRow = makeSliderRow('Colour', 0, 63, 1, existing.colorIndex ?? 0, value => {
                existing.colorIndex = Number(value);
                existing.colorType = existing.colorType ?? (o.key === 'blush' || o.key === 'lipstick' ? 2 : 1);
                pushOverlay(o, existing);
            });
            block.appendChild(colorRow);
        }

        container.appendChild(block);
    });
}

function pushOverlay(o, existing) {
    current.overlays = current.overlays || {};
    current.overlays[o.id] = existing;

    post('overlay', {
        id: o.id,
        index: existing.index,
        opacity: existing.opacity,
        colorType: existing.colorType,
        colorIndex: existing.colorIndex,
        secondColorIndex: existing.secondColorIndex
    });
}

// ---------------------------------------------------------------- clothing (category | items)

// Minimal line icons (inline SVG) — no emojis
function svgIcon(paths, viewBox = '0 0 24 24') {
    return `<svg class="ui-icon" viewBox="${viewBox}" aria-hidden="true" focusable="false">${paths}</svg>`;
}

const I = {
    circle: svgIcon('<circle cx="12" cy="12" r="7" fill="none" stroke="currentColor" stroke-width="1.75"/>'),
    shirt: svgIcon('<path d="M8 4 L12 6 L16 4 L20 7 L17 10 L17 20 L7 20 L7 10 L4 7 Z" fill="none" stroke="currentColor" stroke-width="1.75" stroke-linejoin="round"/>'),
    pants: svgIcon('<path d="M8 4 H16 V11 L18 20 H14 L12 12 L10 20 H6 L8 11 Z" fill="none" stroke="currentColor" stroke-width="1.75" stroke-linejoin="round"/>'),
    shoe: svgIcon('<path d="M4 15 H14 C17 15 19 16 20 18 H4 Z M4 15 V12 H12" fill="none" stroke="currentColor" stroke-width="1.75" stroke-linejoin="round"/>'),
    bag: svgIcon('<path d="M7 9 H17 V19 H7 Z M9 9 V7 C9 5.5 10.5 4.5 12 4.5 C13.5 4.5 15 5.5 15 7 V9" fill="none" stroke="currentColor" stroke-width="1.75" stroke-linejoin="round"/>'),
    mask: svgIcon('<path d="M5 11 C5 8 8 6 12 6 C16 6 19 8 19 11 V14 C19 16 16 18 12 18 C8 18 5 16 5 14 Z M9 13 H9.01 M15 13 H15.01" fill="none" stroke="currentColor" stroke-width="1.75" stroke-linejoin="round"/>'),
    vest: svgIcon('<path d="M8 5 L12 8 L16 5 L18 8 V20 H6 V8 Z M10 12 H14" fill="none" stroke="currentColor" stroke-width="1.75" stroke-linejoin="round"/>'),
    hat: svgIcon('<path d="M4 14 H20 M7 14 C7 10 9 7 12 7 C15 7 17 10 17 14" fill="none" stroke="currentColor" stroke-width="1.75" stroke-linejoin="round"/>'),
    glasses: svgIcon('<circle cx="8" cy="13" r="3.5" fill="none" stroke="currentColor" stroke-width="1.75"/><circle cx="16" cy="13" r="3.5" fill="none" stroke="currentColor" stroke-width="1.75"/><path d="M11.5 13 H12.5 M5 13 H3 M19 13 H21" fill="none" stroke="currentColor" stroke-width="1.75"/>'),
    watch: svgIcon('<circle cx="12" cy="12" r="5" fill="none" stroke="currentColor" stroke-width="1.75"/><path d="M12 9.5 V12 L13.5 13.5 M10 4 H14 M10 20 H14" fill="none" stroke="currentColor" stroke-width="1.75" stroke-linejoin="round"/>'),
    bracelet: svgIcon('<circle cx="12" cy="12" r="6.5" fill="none" stroke="currentColor" stroke-width="1.75"/><circle cx="12" cy="12" r="3" fill="none" stroke="currentColor" stroke-width="1.75"/>'),
    ears: svgIcon('<path d="M12 6 C9 6 7 9 7 12 C7 15 9 18 12 18 M12 8 C14 8 15.5 10 15.5 12 C15.5 14 14 16 12 16" fill="none" stroke="currentColor" stroke-width="1.75" stroke-linejoin="round"/>'),
    chain: svgIcon('<circle cx="8" cy="12" r="3" fill="none" stroke="currentColor" stroke-width="1.75"/><circle cx="16" cy="12" r="3" fill="none" stroke="currentColor" stroke-width="1.75"/><path d="M11 12 H13" fill="none" stroke="currentColor" stroke-width="1.75"/>'),
    badge: svgIcon('<path d="M12 3 L14.5 9 H21 L16 13.5 L18 20 L12 16 L6 20 L8 13.5 L3 9 H9.5 Z" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linejoin="round"/>'),
    arms: svgIcon('<path d="M8 6 H16 V10 L19 18 H15 L12 12 L9 18 H5 L8 10 Z" fill="none" stroke="currentColor" stroke-width="1.75" stroke-linejoin="round"/>'),
    outfit: svgIcon('<path d="M9 4 L12 6 L15 4 L19 7 L16 10 V20 H8 V10 L5 7 Z" fill="none" stroke="currentColor" stroke-width="1.75" stroke-linejoin="round"/>'),
    none: svgIcon('<circle cx="12" cy="12" r="7" fill="none" stroke="currentColor" stroke-width="1.75"/><path d="M8 8 L16 16" fill="none" stroke="currentColor" stroke-width="1.75"/>'),
};

const CAT_ICONS = {
    'Mask': I.mask,
    'Arms / Torso': I.arms,
    'Legs': I.pants,
    'Bag / Parachute': I.bag,
    'Shoes': I.shoe,
    'Accessories': I.chain,
    'Undershirt': I.shirt,
    'Body Armor': I.vest,
    'Decals': I.badge,
    'Top / Jacket': I.shirt,
    'Hat': I.hat,
    'Glasses': I.glasses,
    'Ears': I.ears,
    'Watch': I.watch,
    'Bracelet': I.bracelet,
};

function iconForCategory(label) {
    return CAT_ICONS[label] || I.shirt;
}

let clothingState = {
    categories: [],       // { key, label, isProp, id, maxDrawable, curDrawable, curTexture, collection, localDrawable }
    selectedKey: null,
    currentClothing: { components: {}, props: {} },
    clothingNames: { components: {}, props: {} },
    textureMaxCache: {},
};

function clothingKey(isProp, id) {
    return (isProp ? 'p' : 'c') + id;
}

/** Lookup display name by collection + local drawable (stable identity). */
function lookupClothingName(isProp, slotId, collection, localDrawable) {
    const bySlot = slotBucket(isProp, slotId);
    if (!bySlot) return null;
    const col = collection == null ? '' : String(collection);
    const byCol = bySlot[col];
    if (!byCol || typeof byCol !== 'object') return null;
    const name = byCol[String(localDrawable)] ?? byCol[localDrawable];
    return name || null;
}

/** Flatten Config.ClothingNames entries for a slot into a list of catalog items. */
function slotBucket(isProp, slotId) {
    const root = clothingState.clothingNames || {};
    const bucket = isProp ? (root.props || {}) : (root.components || {});
    // Always prefer string keys (Lua normalizeClothingNames). Never treat bucket as a dense array.
    if (!bucket || Array.isArray(bucket)) return null;
    return bucket[String(slotId)] || bucket[slotId] || null;
}

function getCatalogItems(isProp, slotId) {
    const bySlot = slotBucket(isProp, slotId);
    if (!bySlot || typeof bySlot !== 'object' || Array.isArray(bySlot)) return [];

    const items = [];
    for (const collection of Object.keys(bySlot)) {
        const locals = bySlot[collection];
        if (!locals || typeof locals !== 'object') continue;
        // locals may be object {"0":"name"} or rare array
        const keys = Array.isArray(locals)
            ? Array.from({ length: locals.length }, (_, i) => String(i))
            : Object.keys(locals);
        for (const localKey of keys) {
            const localDrawable = Number(localKey);
            if (Number.isNaN(localDrawable)) continue;
            const label = locals[localKey];
            if (label == null || label === '') continue;
            items.push({
                collection,
                localDrawable,
                label: String(label),
            });
        }
    }
    items.sort((a, b) => {
        if (a.collection !== b.collection) return a.collection.localeCompare(b.collection);
        return a.localDrawable - b.localDrawable;
    });
    return items;
}

function buildCategories(components, props, limits, currentClothing) {
    const cats = [];

    (components || []).forEach(c => {
        const id = String(c.id);
        const cur = (currentClothing.components && currentClothing.components[id]) || { drawable: 0, texture: 0 };
        const maxDrawable = (limits.components && limits.components[id] && limits.components[id].maxDrawable) || 0;
        const collection = cur.collection || '';
        const localDrawable = cur.localDrawable !== undefined ? Number(cur.localDrawable) : Number(cur.drawable) || 0;
        cats.push({
            key: clothingKey(false, c.id),
            label: c.label,
            isProp: false,
            id: c.id,
            maxDrawable,
            curDrawable: Number(cur.drawable) || 0,
            curTexture: Number(cur.texture) || 0,
            collection,
            localDrawable,
        });
    });

    (props || []).forEach(p => {
        const id = String(p.id);
        const cur = (currentClothing.props && currentClothing.props[id]) || { drawable: -1, texture: 0 };
        const maxDrawable = (limits.props && limits.props[id] && limits.props[id].maxDrawable) || 0;
        const collection = cur.collection || '';
        const localDrawable = cur.localDrawable !== undefined ? Number(cur.localDrawable) : (cur.drawable === undefined ? -1 : Number(cur.drawable));
        cats.push({
            key: clothingKey(true, p.id),
            label: p.label,
            isProp: true,
            id: p.id,
            maxDrawable,
            curDrawable: cur.drawable === undefined ? -1 : Number(cur.drawable),
            curTexture: Number(cur.texture) || 0,
            collection,
            localDrawable,
        });
    });

    return cats;
}

function categorySubtitle(cat) {
    if (cat.isProp && cat.curDrawable < 0) return 'None';
    const named = lookupClothingName(cat.isProp, cat.id, cat.collection, cat.localDrawable);
    if (named) return named;
    if (cat.collection) return `${cat.collection} #${cat.localDrawable}`;
    return `Item ${cat.curDrawable}`;
}

function renderCategoryList() {
    const container = document.getElementById('clothing-categories');
    if (!container) return;
    container.innerHTML = '';

    clothingState.categories.forEach(cat => {
        const btn = document.createElement('button');
        btn.type = 'button';
        btn.className = 'cat-item' + (clothingState.selectedKey === cat.key ? ' active' : '');
        btn.dataset.key = cat.key;

        const sub = categorySubtitle(cat);

        btn.innerHTML = `
            <span class="cat-label">${cat.label}</span>
            <span class="cat-sub" title="${sub}">${sub}</span>
        `;
        btn.addEventListener('click', () => selectCategory(cat.key));
        container.appendChild(btn);
    });
}

function selectCategory(key) {
    clothingState.selectedKey = key;
    renderCategoryList();
    renderItemList();
}

function isCatalogItemEquipped(cat, item) {
    if (cat.curDrawable < 0 && item.localDrawable < 0) return true;
    return (
        String(cat.collection || '') === String(item.collection || '') &&
        Number(cat.localDrawable) === Number(item.localDrawable)
    );
}

async function renderItemList() {
    const itemsEl = document.getElementById('clothing-items');
    const titleEl = document.getElementById('clothing-items-title');
    const countEl = document.getElementById('clothing-items-count');
    const texBar = document.getElementById('clothing-texture-bar');
    if (!itemsEl || !titleEl) return;

    const cat = clothingState.categories.find(c => c.key === clothingState.selectedKey);
    if (!cat) {
        titleEl.textContent = 'Select a category';
        if (countEl) countEl.textContent = '';
        itemsEl.innerHTML = '';
        if (texBar) texBar.classList.add('hidden');
        return;
    }

    titleEl.textContent = cat.label;
    itemsEl.innerHTML = '';

    // Locker Clothing tab: ONLY Config.ClothingNames items. Empty catalog = blank list.
    const catalog = getCatalogItems(cat.isProp, cat.id);
    const icon = iconForCategory(cat.label);

    if (countEl) countEl.textContent = catalog.length > 0 ? `${catalog.length} available` : '0 available';

    if (catalog.length === 0) {
        // Still allow None even with no named items
        // (message shown below None row)
    }

    // Always offer None (props clear with -1; components use drawable 0 / empty collection)
    {
        const isNoneEquipped = cat.isProp
            ? (cat.curDrawable < 0)
            : (Number(cat.curDrawable) === 0 && !cat.collection);
        const noneBtn = document.createElement('button');
        noneBtn.type = 'button';
        noneBtn.className = 'item-row none-row' + (isNoneEquipped ? ' equipped' : '');
        noneBtn.innerHTML = `
            <span class="item-icon">${I.none}</span>
            <span class="item-meta">
                <div class="item-name">None</div>
                <div class="item-badge">${isNoneEquipped ? 'Equipped' : 'Clear this slot'}</div>
            </span>
        `;
        noneBtn.addEventListener('click', () => {
            if (cat.isProp) {
                equipCatalogItem(cat, { collection: '', localDrawable: -1 }, 0);
            } else {
                // Component "none" → global drawable 0 (typical freemode bare / empty look)
                equipGlobalItem(cat, 0, 0);
            }
        });
        itemsEl.appendChild(noneBtn);
    }

    catalog.forEach(item => {
        const equipped = isCatalogItemEquipped(cat, item);
        const row = document.createElement('button');
        row.type = 'button';
        row.className = 'item-row' + (equipped ? ' equipped' : '');
        row.innerHTML = `
            <span class="item-icon">${icon}</span>
            <span class="item-meta">
                <div class="item-name">${item.label}</div>
                <div class="item-badge">${equipped ? 'Equipped' : ''}</div>
            </span>
        `;
        row.addEventListener('click', () => {
            const tex = equipped ? cat.curTexture : 0;
            equipCatalogItem(cat, item, tex);
        });
        itemsEl.appendChild(row);
    });

    if (catalog.length === 0) {
        const empty = document.createElement('div');
        empty.className = 'preset-empty';
        empty.style.padding = '16px';
        empty.innerHTML = 'No named items for this slot.<br>Add entries under <strong>Config.Factions.*.clothingNames</strong>.';
        itemsEl.appendChild(empty);
    }

    const equippedRow = itemsEl.querySelector('.item-row.equipped');
    if (equippedRow) {
        requestAnimationFrame(() => equippedRow.scrollIntoView({ block: 'nearest' }));
    }

    await updateTextureBar(cat);
}

async function updateTextureBar(cat) {
    const texBar = document.getElementById('clothing-texture-bar');
    const range = document.getElementById('clothing-texture-range');
    const valEl = document.getElementById('clothing-texture-val');
    if (!texBar || !range) return;

    if (cat.curDrawable < 0) {
        texBar.classList.add('hidden');
        return;
    }

    // Texture max uses global drawable currently worn on the ped
    const res = await post('getTextureMax', {
        isProp: cat.isProp,
        id: cat.id,
        drawable: cat.curDrawable,
    });
    const maxT = (res && res.max !== undefined) ? Number(res.max) : 0;
    clothingState.textureMaxCache[cat.key] = maxT;

    range.min = 0;
    range.max = Math.max(0, maxT);
    range.value = Math.min(cat.curTexture, maxT);
    if (valEl) valEl.textContent = range.value;

    texBar.classList.toggle('hidden', maxT <= 0 && cat.curTexture === 0);
    if (maxT > 0) texBar.classList.remove('hidden');
}

function syncCategoryFromClothing(cat, clothing) {
    if (!clothing) return;
    const bag = cat.isProp ? clothing.props : clothing.components;
    if (!bag) return;
    const cur = bag[String(cat.id)] || bag[cat.id];
    if (!cur) return;
    cat.curDrawable = cur.drawable === undefined ? cat.curDrawable : Number(cur.drawable);
    cat.curTexture = cur.texture === undefined ? cat.curTexture : Number(cur.texture);
    cat.collection = cur.collection || '';
    cat.localDrawable = cur.localDrawable !== undefined ? Number(cur.localDrawable) : cat.localDrawable;
}

/** Equip by collection + local drawable (stable). */
async function equipCatalogItem(cat, item, texture) {
    cat.collection = item.collection || '';
    cat.localDrawable = item.localDrawable;
    cat.curTexture = texture || 0;

    renderCategoryList();
    renderItemList();

    const payload = {
        id: cat.id,
        useCollection: true,
        collection: item.collection || '',
        localDrawable: item.localDrawable,
        drawable: item.localDrawable,
        texture: cat.curTexture,
    };

    const res = cat.isProp ? await post('prop', payload) : await post('component', payload);
    if (res && res.clothing) {
        clothingState.currentClothing = res.clothing;
        syncCategoryFromClothing(cat, res.clothing);
        renderCategoryList();
        renderItemList();
    }

    await updateTextureBar(cat);
}

/** Equip by global drawable (fallback when no catalog names). */
async function equipGlobalItem(cat, drawable, texture) {
    cat.curDrawable = drawable;
    cat.curTexture = texture || 0;
    cat.collection = '';
    cat.localDrawable = drawable;

    renderCategoryList();
    renderItemList();

    const res = cat.isProp
        ? await post('prop', { id: cat.id, drawable, texture: cat.curTexture })
        : await post('component', { id: cat.id, drawable, texture: cat.curTexture });

    if (res && res.clothing) {
        clothingState.currentClothing = res.clothing;
        syncCategoryFromClothing(cat, res.clothing);
        renderCategoryList();
        renderItemList();
    }

    await updateTextureBar(cat);
}

function bindTextureBar() {
    const range = document.getElementById('clothing-texture-range');
    const valEl = document.getElementById('clothing-texture-val');
    if (!range || range.dataset.bound) return;
    range.dataset.bound = '1';

    range.addEventListener('input', () => {
        if (valEl) valEl.textContent = range.value;
        const cat = clothingState.categories.find(c => c.key === clothingState.selectedKey);
        if (!cat || cat.curDrawable < 0) return;
        cat.curTexture = Number(range.value);

        // Prefer collection path when we know stable identity
        if (cat.collection !== undefined && cat.localDrawable !== undefined && cat.localDrawable >= 0) {
            const payload = {
                id: cat.id,
                useCollection: true,
                collection: cat.collection || '',
                localDrawable: cat.localDrawable,
                drawable: cat.localDrawable,
                texture: cat.curTexture,
            };
            if (cat.isProp) post('prop', payload);
            else post('component', payload);
        } else if (cat.isProp) {
            post('prop', { id: cat.id, drawable: cat.curDrawable, texture: cat.curTexture });
        } else {
            post('component', { id: cat.id, drawable: cat.curDrawable, texture: cat.curTexture });
        }
    });
}

function renderClothing(components, props, limits, currentClothing, clothingNames) {
    clothingState.currentClothing = currentClothing || { components: {}, props: {} };
    if (clothingNames) clothingState.clothingNames = clothingNames;
    clothingState.categories = buildCategories(components, props, limits, clothingState.currentClothing);

    if (!clothingState.selectedKey || !clothingState.categories.find(c => c.key === clothingState.selectedKey)) {
        const jacket = clothingState.categories.find(c => c.id === 11 && !c.isProp);
        clothingState.selectedKey = jacket ? jacket.key : (clothingState.categories[0] && clothingState.categories[0].key);
    }

    bindTextureBar();
    renderCategoryList();
    renderItemList();

    // Old slider + typed global drawable UI (Advanced / characterisation clothing)
    renderAdvancedClothing(components, props, limits, clothingState.currentClothing);
}

/** Original characterisation clothing UI: range sliders + editable global drawable IDs. */
function renderAdvancedClothing(components, props, limits, currentClothing) {
    const compContainer = document.getElementById('clothing-components');
    const propContainer = document.getElementById('clothing-props');
    if (!compContainer || !propContainer) return;

    compContainer.innerHTML = '';
    propContainer.innerHTML = '';
    currentClothing = currentClothing || { components: {}, props: {} };

    (components || []).forEach(c => {
        const id = String(c.id);
        const cur = (currentClothing.components && currentClothing.components[id]) || { drawable: 0, texture: 0 };
        const maxDrawable = (limits.components && limits.components[id] && limits.components[id].maxDrawable) || 0;

        const block = document.createElement('div');
        block.className = 'overlay-block';

        const label = document.createElement('div');
        label.className = 'section-label';
        label.textContent = c.label;
        block.appendChild(label);

        const state = {
            drawable: Number(cur.drawable) || 0,
            texture: Number(cur.texture) || 0,
        };

        const drawableRow = makeSliderRow('Drawable', 0, maxDrawable, 1, state.drawable, (value) => {
            state.drawable = Number(value);
            post('component', { id: c.id, drawable: state.drawable, texture: state.texture }).then(res => {
                if (res && res.clothing) clothingState.currentClothing = res.clothing;
            });
        });
        block.appendChild(drawableRow);

        const textureRow = makeSliderRow('Texture', 0, 25, 1, state.texture, (value) => {
            state.texture = Number(value);
            post('component', { id: c.id, drawable: state.drawable, texture: state.texture }).then(res => {
                if (res && res.clothing) clothingState.currentClothing = res.clothing;
            });
        });
        block.appendChild(textureRow);

        // Live-update texture max when drawable changes
        const drawableInput = drawableRow.querySelector('input[type="range"]');
        if (drawableInput) {
            drawableInput.addEventListener('change', async () => {
                const res = await post('getTextureMax', { isProp: false, id: c.id, drawable: state.drawable });
                const maxT = (res && res.max !== undefined) ? Number(res.max) : 25;
                const texRange = textureRow.querySelector('input[type="range"]');
                const texNum = textureRow.querySelector('.val-input');
                if (texRange) {
                    texRange.max = Math.max(0, maxT);
                    if (Number(texRange.value) > maxT) {
                        texRange.value = maxT;
                        state.texture = maxT;
                        if (texNum) texNum.value = maxT;
                    }
                }
            });
        }

        compContainer.appendChild(block);
    });

    (props || []).forEach(p => {
        const id = String(p.id);
        const cur = (currentClothing.props && currentClothing.props[id]) || { drawable: -1, texture: 0 };
        const maxDrawable = (limits.props && limits.props[id] && limits.props[id].maxDrawable) || 0;

        const block = document.createElement('div');
        block.className = 'overlay-block';

        const label = document.createElement('div');
        label.className = 'section-label';
        label.textContent = p.label;
        block.appendChild(label);

        const state = {
            drawable: cur.drawable === undefined ? -1 : Number(cur.drawable),
            texture: Number(cur.texture) || 0,
        };

        const drawableRow = makeSliderRow('Drawable (-1 = none)', -1, maxDrawable, 1, state.drawable, (value) => {
            state.drawable = Number(value);
            post('prop', { id: p.id, drawable: state.drawable, texture: state.texture }).then(res => {
                if (res && res.clothing) clothingState.currentClothing = res.clothing;
            });
        });
        block.appendChild(drawableRow);

        const textureRow = makeSliderRow('Texture', 0, 25, 1, state.texture, (value) => {
            state.texture = Number(value);
            post('prop', { id: p.id, drawable: state.drawable, texture: state.texture }).then(res => {
                if (res && res.clothing) clothingState.currentClothing = res.clothing;
            });
        });
        block.appendChild(textureRow);

        propContainer.appendChild(block);
    });
}

function renderPresets(presets, playerPresets) {
    const container = document.getElementById('preset-list');
    if (!container) return;
    container.innerHTML = '';

    const factionList = Array.isArray(presets) ? presets : [];
    const playerList = Array.isArray(playerPresets) ? playerPresets : [];

    // Normalize faction entries to objects
    const factionCards = factionList.map(p => {
        if (typeof p === 'string') return { name: p, source: 'faction' };
        return { name: p.name, source: p.source || 'faction', outfit: p.outfit };
    });

    if (factionCards.length === 0 && playerList.length === 0) {
        container.innerHTML = `
            <div class="preset-empty">
                No presets yet.<br>
                Save your current outfit above.
            </div>`;
        return;
    }

    const section = (title) => {
        const h = document.createElement('div');
        h.className = 'section-label';
        h.style.gridColumn = '1 / -1';
        h.style.margin = '8px 0 4px';
        h.textContent = title;
        container.appendChild(h);
    };

    if (factionCards.length) {
        section('Unit presets');
        factionCards.forEach(p => addPresetCard(container, p));
    }
    if (playerList.length) {
        section('Your presets');
        playerList.forEach(p => addPresetCard(container, {
            name: p.name,
            source: 'player',
            outfit: p.outfit,
        }));
    }
}

function addPresetCard(container, preset) {
    const card = document.createElement('button');
    card.type = 'button';
    card.className = 'preset-card';
    card.innerHTML = `
        <span class="preset-icon">${I.outfit}</span>
        <span class="preset-info">
            <div class="preset-name">${preset.name}</div>
            <div class="preset-source">${preset.source === 'player' ? 'Yours' : 'Unit'}</div>
            <div class="preset-status">Click to equip</div>
        </span>
        ${preset.source === 'player' ? '<span class="preset-delete" title="Delete">×</span>' : ''}
    `;

    card.addEventListener('click', async (e) => {
        if (e.target && e.target.classList.contains('preset-delete')) return;
        container.querySelectorAll('.preset-card').forEach(c => {
            c.classList.remove('equipped');
            const st = c.querySelector('.preset-status');
            if (st) st.textContent = 'Click to equip';
        });
        card.classList.add('equipped');
        const status = card.querySelector('.preset-status');
        if (status) status.textContent = 'Equipped';

        const res = await post('applyPreset', {
            name: preset.name,
            source: preset.source,
            outfit: preset.outfit || null,
        });
        // Always refresh Clothing + Advanced from server response or live ped state
        await refreshClothingUI(res);
    });

    const del = card.querySelector('.preset-delete');
    if (del) {
        del.addEventListener('click', async (e) => {
            e.stopPropagation();
            const res = await post('deletePlayerPreset', { name: preset.name });
            if (res && res.ok) {
                // refresh player list
                const list = await post('getPlayerPresets', {});
                lastOpenData.playerPresets = (list && list.presets) || [];
                renderPresets(lastOpenData.presets || [], lastOpenData.playerPresets);
            }
        });
    }

    container.appendChild(card);
}

function bindPresetSave() {
    const btn = document.getElementById('btn-save-preset');
    const input = document.getElementById('preset-name-input');
    if (!btn || btn.dataset.bound) return;
    btn.dataset.bound = '1';

    btn.addEventListener('click', async () => {
        const name = (input && input.value || '').trim();
        if (!name) {
            if (input) input.focus();
            return;
        }
        btn.disabled = true;
        const res = await post('savePlayerPreset', { name });
        btn.disabled = false;
        if (res && res.ok) {
            if (input) input.value = '';
            const list = await post('getPlayerPresets', {});
            lastOpenData.playerPresets = (list && list.presets) || [];
            renderPresets(lastOpenData.presets || [], lastOpenData.playerPresets);
        } else if (res && res.error === 'limit') {
            // keep silent or show in status — limit reached
            btn.textContent = 'Limit reached';
            setTimeout(() => { btn.textContent = 'Save current'; }, 1500);
        }
    });

    if (input) {
        input.addEventListener('keydown', (e) => {
            if (e.key === 'Enter') btn.click();
        });
    }
}

// ---------------------------------------------------------------- footer

document.getElementById('btn-save').addEventListener('click', () => post('save', {}));
document.getElementById('btn-cancel').addEventListener('click', () => post('cancel', {}));

// ---------------------------------------------------------------- NUI messages

window.addEventListener('message', event => {
    const { action, data } = event.data;

    if (action === 'open') {
        current = data.current || {};
        lastOpenData = data;
        app.classList.remove('hidden');

        const panel = document.getElementById('panel');
        const panelTitle = document.getElementById('panel-title');

        // Reset all tab visibility first
        document.querySelectorAll('.tab-btn').forEach(btn => {
            btn.classList.remove('active');
            btn.style.display = 'none';
        });
        document.querySelectorAll('.tab-pane').forEach(p => p.classList.remove('active'));

        if (data.mode === 'locker') {
            // Locker: Clothing (catalog) | Presets | Advanced (old sliders)
            if (panel) panel.classList.add('locker-mode');
            if (panelTitle) {
                const factionLabel = data.faction ? String(data.faction).toUpperCase() : 'LOCKER';
                panelTitle.textContent = factionLabel + ' LOCKER';
            }

            document.querySelectorAll('.tab-btn.tab-locker').forEach(btn => {
                btn.style.display = '';
            });

            const clothingBtn = document.querySelector('.tab-btn.tab-locker[data-tab="clothing"]');
            if (clothingBtn) {
                clothingBtn.classList.add('active');
                document.getElementById('tab-clothing').classList.add('active');
            }
            post('setCamFocus', { focus: 'body' });
            if (randomizeBtn) randomizeBtn.style.display = 'none';
        } else {
            // Characterisation: Heritage | Face | Hair | Overlays | Clothing (advanced sliders)
            if (panel) panel.classList.remove('locker-mode');
            if (panelTitle) panelTitle.textContent = 'CHARACTERISATION';

            document.querySelectorAll('.tab-btn.tab-char').forEach(btn => {
                btn.style.display = '';
            });

            const heritageBtn = document.querySelector('.tab-btn.tab-char[data-tab="heritage"]');
            if (heritageBtn) {
                heritageBtn.classList.add('active');
                document.getElementById('tab-heritage').classList.add('active');
            }
            post('setCamFocus', { focus: 'head' });
            if (randomizeBtn) randomizeBtn.style.display = '';
        }

        renderFaceFeatures(data.faceFeatures || {});
        renderOverlays(data.overlays || []);

        clothingState.clothingNames = data.clothingNames || { components: {}, props: {} };
        renderClothing(
            data.clothingComponents || [],
            data.clothingProps || [],
            data.clothingLimits || { components: {}, props: {} },
            data.currentClothing || { components: {}, props: {} },
            data.clothingNames
        );
        bindPresetSave();
        renderPresets(data.presets || [], data.playerPresets || []);

        // Cancel visible for staff OR locker mode
        document.getElementById('btn-cancel').classList.toggle(
            'hidden',
            !data.staffMode && data.mode !== 'locker'
        );
    }

    if (action === 'close') {
        app.classList.add('hidden');
    }
});

// Esc = Cancel
document.addEventListener('keyup', e => {
    if (e.key === 'Escape' && !app.classList.contains('hidden')) {
        post('cancel', {});
    }
});