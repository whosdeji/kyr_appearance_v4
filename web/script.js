const resourceName = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'kyr_appearance';

function post(endpoint, data) {
    return fetch(`https://${resourceName}/${endpoint}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify(data || {})
    }).then(r => r.json()).catch(() => ({}));
}

const app = document.getElementById('app');
let current = {};
let lastOpenData = {}; // keep labels / limits so we can re-render after randomize

// ---------------------------------------------------------------- tabs

document.querySelectorAll('.tab-btn').forEach(btn => {
    btn.addEventListener('click', () => {
        document.querySelectorAll('.tab-btn').forEach(b => b.classList.remove('active'));
        document.querySelectorAll('.tab-pane').forEach(p => p.classList.remove('active'));
        btn.classList.add('active');
        document.getElementById(`tab-${btn.dataset.tab}`).classList.add('active');

        if (btn.dataset.tab === 'clothing' || btn.dataset.tab === 'presets') {
            post('setCamFocus', { focus: 'body' });
        } else {
            post('setCamFocus', { focus: 'head' });
        }
    });
});

// ---------------------------------------------------------------- camera

document.getElementById('rotate-left').addEventListener('click', () => post('rotate', { direction: -1 }));
document.getElementById('rotate-right').addEventListener('click', () => post('rotate', { direction: 1 }));
document.getElementById('zoom-in').addEventListener('click', () => post('zoom', { direction: -1 }));
document.getElementById('zoom-out').addEventListener('click', () => post('zoom', { direction: 1 }));

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

const CAT_ICONS = {
    'Mask': '🎭', 'Arms / Torso': '💪', 'Legs': '👖', 'Bag / Parachute': '🎒',
    'Shoes': '👟', 'Accessories': '📿', 'Undershirt': '👕', 'Body Armor': '🦺',
    'Decals': '🎖️', 'Top / Jacket': '🧥', 'Hat': '🎩', 'Glasses': '👓',
    'Ears': '👂', 'Watch': '⌚', 'Bracelet': '💍',
};

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
    const root = clothingState.clothingNames || {};
    const bucket = isProp ? (root.props || {}) : (root.components || {});
    const bySlot = bucket[slotId] || bucket[String(slotId)];
    if (!bySlot) return null;
    const col = collection == null ? '' : String(collection);
    const byCol = bySlot[col];
    if (!byCol) return null;
    const name = byCol[localDrawable] ?? byCol[String(localDrawable)];
    return name || null;
}

/** Flatten Config.ClothingNames entries for a slot into a list of catalog items. */
function getCatalogItems(isProp, slotId) {
    const root = clothingState.clothingNames || {};
    const bucket = isProp ? (root.props || {}) : (root.components || {});
    const bySlot = bucket[slotId] || bucket[String(slotId)];
    if (!bySlot) return [];

    const items = [];
    for (const collection of Object.keys(bySlot)) {
        const locals = bySlot[collection] || {};
        for (const localKey of Object.keys(locals)) {
            const localDrawable = Number(localKey);
            if (Number.isNaN(localDrawable)) continue;
            items.push({
                collection,
                localDrawable,
                label: locals[localKey],
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

    const catalog = getCatalogItems(cat.isProp, cat.id);
    const icon = CAT_ICONS[cat.label] || '👕';

    // Prefer named catalog (collection + local drawable). Fallback: numeric global browser.
    if (catalog.length > 0) {
        if (countEl) countEl.textContent = `${catalog.length} available`;

        if (cat.isProp) {
            const noneBtn = document.createElement('button');
            noneBtn.type = 'button';
            noneBtn.className = 'item-row none-row' + (cat.curDrawable < 0 ? ' equipped' : '');
            noneBtn.innerHTML = `
                <span class="item-icon">○</span>
                <span class="item-meta">
                    <div class="item-name">None</div>
                    <div class="item-badge">${cat.curDrawable < 0 ? 'Equipped' : 'Leave this slot empty'}</div>
                </span>
            `;
            noneBtn.addEventListener('click', () => equipCatalogItem(cat, { collection: '', localDrawable: -1 }, 0));
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
    } else {
        // No names configured — numeric global list (legacy browser)
        const minD = cat.isProp ? -1 : 0;
        const total = Math.max(0, cat.maxDrawable - minD + 1);
        if (countEl) countEl.textContent = `${total} available`;

        if (cat.isProp) {
            const noneBtn = document.createElement('button');
            noneBtn.type = 'button';
            noneBtn.className = 'item-row none-row' + (cat.curDrawable < 0 ? ' equipped' : '');
            noneBtn.innerHTML = `
                <span class="item-icon">○</span>
                <span class="item-meta">
                    <div class="item-name">None</div>
                    <div class="item-badge">${cat.curDrawable < 0 ? 'Equipped' : 'Leave this slot empty'}</div>
                </span>
            `;
            noneBtn.addEventListener('click', () => equipGlobalItem(cat, -1, 0));
            itemsEl.appendChild(noneBtn);
        }

        const maxShow = Math.min(cat.maxDrawable, 400);
        for (let d = 0; d <= maxShow; d++) {
            const equipped = cat.curDrawable === d;
            const row = document.createElement('button');
            row.type = 'button';
            row.className = 'item-row' + (equipped ? ' equipped' : '');
            row.innerHTML = `
                <span class="item-icon">${icon}</span>
                <span class="item-meta">
                    <div class="item-name">${cat.label} #${d}</div>
                    <div class="item-badge">${equipped ? 'Equipped' : ''}</div>
                </span>
            `;
            row.addEventListener('click', () => equipGlobalItem(cat, d, equipped ? cat.curTexture : 0));
            itemsEl.appendChild(row);
        }
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

    // Prefer Top/Jacket as default selection if present
    if (!clothingState.selectedKey || !clothingState.categories.find(c => c.key === clothingState.selectedKey)) {
        const jacket = clothingState.categories.find(c => c.id === 11 && !c.isProp);
        clothingState.selectedKey = jacket ? jacket.key : (clothingState.categories[0] && clothingState.categories[0].key);
    }

    bindTextureBar();
    renderCategoryList();
    renderItemList();
}

function renderPresets(presets) {
    const container = document.getElementById('preset-list');
    if (!container) return;
    container.innerHTML = '';

    if (!presets || presets.length === 0) {
        container.innerHTML = `
            <div class="preset-empty">
                No presets defined yet.<br>
                Staff can use <strong>/saveoutfit name</strong> while wearing an outfit.
            </div>`;
        return;
    }

    presets.forEach(name => {
        const card = document.createElement('button');
        card.type = 'button';
        card.className = 'preset-card';
        card.dataset.name = name;
        card.innerHTML = `
            <span class="preset-icon">👔</span>
            <span class="preset-info">
                <div class="preset-name">${name}</div>
                <div class="preset-status">Click to equip</div>
            </span>
        `;
        card.addEventListener('click', async () => {
            // Instant visual feedback
            container.querySelectorAll('.preset-card').forEach(c => {
                c.classList.remove('applying', 'equipped');
                const st = c.querySelector('.preset-status');
                if (st) st.textContent = 'Click to equip';
            });
            card.classList.add('applying');
            const status = card.querySelector('.preset-status');
            if (status) status.textContent = 'Applying…';

            const res = await post('applyPreset', { name });

            card.classList.remove('applying');
            if (res && !res.error) {
                card.classList.add('equipped');
                if (status) status.textContent = 'Equipped';
                // Refresh clothing UI from server response
                if (res.clothing) {
                    const data = lastOpenData || {};
                    renderClothing(
                        data.clothingComponents || [],
                        data.clothingProps || [],
                        data.clothingLimits || { components: {}, props: {} },
                        res.clothing,
                        data.clothingNames || clothingState.clothingNames
                    );
                }
            } else {
                if (status) status.textContent = 'Failed — try again';
            }
        });
        container.appendChild(card);
    });
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

        // Locker mode = only Clothing + Presets tabs, wider panel
        if (data.mode === 'locker') {
            if (panel) panel.classList.add('locker-mode');
            if (panelTitle) {
                const factionLabel = (data.faction && lastOpenData.faction) ? String(data.faction).toUpperCase() : 'LOCKER';
                panelTitle.textContent = factionLabel + ' LOCKER';
            }

            document.querySelectorAll('.tab-btn').forEach(btn => {
                const tab = btn.dataset.tab;
                if (tab !== 'clothing' && tab !== 'presets') {
                    btn.style.display = 'none';
                } else {
                    btn.style.display = '';
                }
            });

            document.querySelectorAll('.tab-btn').forEach(b => b.classList.remove('active'));
            document.querySelectorAll('.tab-pane').forEach(p => p.classList.remove('active'));
            const clothingBtn = document.querySelector('[data-tab="clothing"]');
            if (clothingBtn) {
                clothingBtn.classList.add('active');
                document.getElementById('tab-clothing').classList.add('active');
            }
            post('setCamFocus', { focus: 'body' });

            if (randomizeBtn) randomizeBtn.style.display = 'none';
        } else {
            if (panel) panel.classList.remove('locker-mode');
            if (panelTitle) panelTitle.textContent = 'CHARACTERISATION';
            document.querySelectorAll('.tab-btn').forEach(btn => {
                btn.style.display = '';
            });
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
        renderPresets(data.presets || []);

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