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

// ---------------------------------------------------------------- clothing

function renderClothing(components, props, limits, currentClothing) {
    const compContainer = document.getElementById('clothing-components');
    const propContainer = document.getElementById('clothing-props');
    if (!compContainer || !propContainer) return;

    compContainer.innerHTML = '';
    propContainer.innerHTML = '';

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

        const drawableRow = makeSliderRow('Drawable', 0, maxDrawable, 1, cur.drawable, (value) => {
            cur.drawable = Number(value);
            post('component', { id: c.id, drawable: cur.drawable, texture: cur.texture });
        });
        block.appendChild(drawableRow);

        const textureRow = makeSliderRow('Texture', 0, 25, 1, cur.texture, (value) => {
            cur.texture = Number(value);
            post('component', { id: c.id, drawable: cur.drawable, texture: cur.texture });
        });
        block.appendChild(textureRow);

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

        const drawableRow = makeSliderRow('Drawable (-1 = none)', -1, maxDrawable, 1, cur.drawable, (value) => {
            cur.drawable = Number(value);
            post('prop', { id: p.id, drawable: cur.drawable, texture: cur.texture });
        });
        block.appendChild(drawableRow);

        const textureRow = makeSliderRow('Texture', 0, 25, 1, cur.texture, (value) => {
            cur.texture = Number(value);
            post('prop', { id: p.id, drawable: cur.drawable, texture: cur.texture });
        });
        block.appendChild(textureRow);

        propContainer.appendChild(block);
    });
}

function renderPresets(presets) {
    const container = document.getElementById('preset-list');
    if (!container) return;

    container.innerHTML = '';

    if (!presets || presets.length === 0) {
        container.innerHTML = '<p style="opacity:0.5;">No presets defined yet. Use /saveoutfit</p>';
        return;
    }

    presets.forEach(name => {
        const btn = document.createElement('button');
        btn.className = 'footer-btn';
        btn.textContent = name;
        btn.addEventListener('click', () => post('applyPreset', { name }));
        container.appendChild(btn);
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

        // Locker mode = only Clothing + Presets tabs
        if (data.mode === 'locker') {
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

            // Hide randomize in locker mode
            if (randomizeBtn) randomizeBtn.style.display = 'none';
        } else {
            document.querySelectorAll('.tab-btn').forEach(btn => {
                btn.style.display = '';
            });
            // Show randomize only in characterisation
            if (randomizeBtn) randomizeBtn.style.display = '';
        }

        renderFaceFeatures(data.faceFeatures || {});
        renderOverlays(data.overlays || []);

        renderClothing(
            data.clothingComponents || [],
            data.clothingProps || [],
            data.clothingLimits || { components: {}, props: {} },
            data.currentClothing || { components: {}, props: {} }
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