import React, { useState, useEffect, useRef, useCallback, useMemo } from 'react';
import {
  Heart, Zap, Droplets, Utensils, Shield, Wrench, Package, MapPin,
  Sun, Moon, Volume2, VolumeX, Save, RotateCcw, Hammer, Sparkles,
  Home, Compass, Crosshair, ChevronRight, Check, AlertTriangle,
  Bed, Coffee, Sprout, Box, Radio, EyeOff, Eye, Settings, Play,
  Trash2, ArrowUpRight, Layers, Plus, RefreshCw, HelpCircle, Award,
  BookOpen, Cpu, Loader2, Volume1, Palette
} from 'lucide-react';

// ============================================================================
// 0. GEMINI API INTEGRATION (TEXT, STRUCTURED JSON & TTS AUDIO)
// ============================================================================
const GEMINI_API_KEY = ""; // Provided automatically by the environment at runtime

async function fetchWithRetry(url, options, retries = 4, delay = 1000) {
  for (let attempt = 0; attempt <= retries; attempt++) {
    try {
      const res = await fetch(url, options);
      if (res.ok) return await res.json();
      if (attempt === retries) {
        const errText = await res.text();
        throw new Error(`API Error (${res.status}): ${errText}`);
      }
    } catch (err) {
      if (attempt === retries) throw err;
    }
    await new Promise(r => setTimeout(r, delay * Math.pow(2, attempt)));
  }
}

async function callGeminiStructured(systemPrompt, userPrompt, schema) {
  const apiUrl = `https://generativelanguage.googleapis.com/v1beta/models/gemini-3-flash-preview:generateContent?key=${GEMINI_API_KEY}`;
  const payload = {
    contents: [{ role: 'user', parts: [{ text: userPrompt }] }],
    systemInstruction: { parts: [{ text: systemPrompt }] },
    generationConfig: {
      responseMimeType: 'application/json',
      responseSchema: schema
    }
  };
  const result = await fetchWithRetry(apiUrl, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(payload)
  });
  const text = result?.candidates?.[0]?.content?.parts?.[0]?.text;
  if (!text) throw new Error('Empty response from Gemini');
  return JSON.parse(text);
}

function base64ToArrayBuffer(base64) {
  const binaryString = window.atob(base64);
  const len = binaryString.length;
  const bytes = new Uint8Array(len);
  for (let i = 0; i < len; i++) {
    bytes[i] = binaryString.charCodeAt(i);
  }
  return bytes.buffer;
}

function pcmToWav(pcm16, sampleRate = 24000) {
  const numChannels = 1;
  const byteRate = sampleRate * numChannels * 2;
  const blockAlign = numChannels * 2;
  const dataSize = pcm16.length * 2;
  const buffer = new ArrayBuffer(44 + dataSize);
  const view = new DataView(buffer);

  const writeString = (offset, str) => {
    for (let i = 0; i < str.length; i++) {
      view.setUint8(offset + i, str.charCodeAt(i));
    }
  };

  writeString(0, 'RIFF');
  view.setUint32(4, 36 + dataSize, true);
  writeString(8, 'WAVE');
  writeString(12, 'fmt ');
  view.setUint32(16, 16, true);
  view.setUint16(20, 1, true); // PCM format
  view.setUint16(22, numChannels, true);
  view.setUint32(24, sampleRate, true);
  view.setUint32(28, byteRate, true);
  view.setUint16(32, blockAlign, true);
  view.setUint16(34, 16, true); // 16-bit
  writeString(36, 'data');
  view.setUint32(40, dataSize, true);

  let offset = 44;
  for (let i = 0; i < pcm16.length; i++, offset += 2) {
    view.setInt16(offset, pcm16[i], true);
  }
  return new Blob([buffer], { type: 'audio/wav' });
}

async function speakYunaText(textToSpeak) {
  const apiUrl = `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash-preview-tts:generateContent?key=${GEMINI_API_KEY}`;
  const payload = {
    contents: [{
      parts: [{
        text: `Say in a soft, gentle, slightly shy and earnest young woman's voice: ${textToSpeak}`
      }]
    }],
    generationConfig: {
      responseModalities: ['AUDIO'],
      speechConfig: {
        voiceConfig: {
          prebuiltVoiceConfig: { voiceName: 'Leda' }
        }
      }
    },
    model: 'gemini-2.5-flash-preview-tts'
  };

  const result = await fetchWithRetry(apiUrl, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(payload)
  });

  const part = result?.candidates?.[0]?.content?.parts?.[0];
  const audioData = part?.inlineData?.data;
  const mimeType = part?.inlineData?.mimeType || 'audio/L16;rate=24000';

  if (audioData) {
    const rateMatch = mimeType.match(/rate=(\d+)/);
    const sampleRate = rateMatch ? parseInt(rateMatch[1], 10) : 24000;
    const pcmBuffer = base64ToArrayBuffer(audioData);
    const pcm16 = new Int16Array(pcmBuffer);
    const wavBlob = pcmToWav(pcm16, sampleRate);
    const audioUrl = URL.createObjectURL(wavBlob);
    const audio = new Audio(audioUrl);
    audio.play();
    return audio;
  }
  throw new Error('No audio returned');
}

// ============================================================================
// 1. DETERMINISTIC SEEDED PRNG & UTILITIES
// ============================================================================
class SeededRNG {
  constructor(seed = 1337) {
    this.seed = seed % 2147483647;
    if (this.seed <= 0) this.seed += 2147483646;
  }
  next() {
    this.seed = (this.seed * 16807) % 2147483647;
    return (this.seed - 1) / 2147483646;
  }
  range(min, max) {
    return min + this.next() * (max - min);
  }
  int(min, max) {
    return Math.floor(this.range(min, max + 1));
  }
  pick(arr) {
    return arr[Math.floor(this.next() * arr.length)];
  }
}

// ============================================================================
// 2. WEB AUDIO SYNTHESIZER & SOUNDSCAPE ENGINE
// ============================================================================
class SoundEngine {
  constructor() {
    this.ctx = null;
    this.muted = false;
    this.sfxVolume = 0.65;
    this.musicVolume = 0.45;
    this.ambientInterval = null;
    this.radioActive = true;
  }

  init() {
    if (!this.ctx) {
      const AudioCtx = window.AudioContext || window.webkitAudioContext;
      if (AudioCtx) this.ctx = new AudioCtx();
    }
    if (this.ctx && this.ctx.state === 'suspended') {
      this.ctx.resume();
    }
  }

  playTone(freq, type = 'sine', duration = 0.15, vol = 0.2, slideTo = null) {
    if (this.muted || !this.ctx) return;
    try {
      const now = this.ctx.currentTime;
      const osc = this.ctx.createOscillator();
      const gain = this.ctx.createGain();
      osc.type = type;
      osc.frequency.setValueAtTime(freq, now);
      if (slideTo) {
        osc.frequency.exponentialRampToValueAtTime(Math.max(20, slideTo), now + duration);
      }
      const finalVol = Math.min(1, Math.max(0.001, vol * this.sfxVolume));
      gain.gain.setValueAtTime(finalVol, now);
      gain.gain.exponentialRampToValueAtTime(0.001, now + duration);
      osc.connect(gain);
      gain.connect(this.ctx.destination);
      osc.start(now);
      osc.stop(now + duration);
    } catch (e) {
      // Ignore audio context restrictions
    }
  }

  playNoise(duration = 0.12, vol = 0.2, filterFreq = 1200) {
    if (this.muted || !this.ctx) return;
    try {
      const bufferSize = this.ctx.sampleRate * duration;
      const buffer = this.ctx.createBuffer(1, bufferSize, this.ctx.sampleRate);
      const data = buffer.getChannelData(0);
      for (let i = 0; i < bufferSize; i++) {
        data[i] = Math.random() * 2 - 1;
      }
      const noise = this.ctx.createBufferSource();
      noise.buffer = buffer;

      const filter = this.ctx.createBiquadFilter();
      filter.type = 'lowpass';
      filter.frequency.value = filterFreq;

      const gain = this.ctx.createGain();
      const now = this.ctx.currentTime;
      gain.gain.setValueAtTime(vol * this.sfxVolume, now);
      gain.gain.exponentialRampToValueAtTime(0.001, now + duration);

      noise.connect(filter);
      filter.connect(gain);
      gain.connect(this.ctx.destination);
      noise.start(now);
    } catch (e) {}
  }

  sfxPistol() {
    this.init();
    this.playNoise(0.11, 0.45, 2200);
    this.playTone(380, 'sawtooth', 0.09, 0.3, 90);
  }

  sfxRifle() {
    this.init();
    this.playNoise(0.22, 0.65, 1600);
    this.playTone(220, 'square', 0.18, 0.4, 55);
  }

  sfxReload() {
    this.init();
    this.playTone(520, 'triangle', 0.06, 0.2, 680);
    setTimeout(() => this.playTone(760, 'sine', 0.08, 0.25, 480), 140);
  }

  sfxHitRobot() {
    this.init();
    this.playTone(880, 'square', 0.05, 0.22, 240);
    this.playNoise(0.06, 0.25, 3000);
  }

  sfxRobotDestroy() {
    this.init();
    this.playNoise(0.35, 0.5, 900);
    this.playTone(190, 'sawtooth', 0.35, 0.35, 35);
  }

  sfxLoot() {
    this.init();
    this.playTone(587.33, 'sine', 0.09, 0.2, 880);
    setTimeout(() => this.playTone(880, 'sine', 0.12, 0.22, 1174.66), 70);
  }

  sfxCraft() {
    this.init();
    this.playTone(330, 'triangle', 0.1, 0.25, 440);
    setTimeout(() => this.playTone(440, 'triangle', 0.1, 0.25, 659.25), 110);
    setTimeout(() => this.playTone(659.25, 'sine', 0.18, 0.3, 880), 220);
  }

  sfxCook() {
    this.init();
    this.playNoise(0.25, 0.18, 1800);
    this.playTone(440, 'sine', 0.15, 0.2, 554.37);
  }

  sfxTic() {
    this.init();
    // Subtle soft click or gentle hum
    this.playTone(720, 'sine', 0.035, 0.09, 540);
  }

  sfxStep(isShelter) {
    if (this.muted || !this.ctx) return;
    this.playNoise(0.04, isShelter ? 0.06 : 0.1, isShelter ? 600 : 1100);
  }

  playAmbientNote(isShelter) {
    if (this.muted || !this.ctx) return;
    if (isShelter) {
      if (!this.radioActive) return;
      const warmChords = [261.63, 329.63, 392.00, 493.88, 587.33, 440.00];
      const f = warmChords[Math.floor(Math.random() * warmChords.length)];
      this.playTone(f, 'sine', 1.8, 0.06 * this.musicVolume, f * 0.998);
    } else {
      const coldDrones = [110, 130.81, 146.83, 98.0, 164.81];
      const f = coldDrones[Math.floor(Math.random() * coldDrones.length)];
      this.playTone(f, 'triangle', 2.4, 0.05 * this.musicVolume, f * 1.01);
    }
  }
}

const sound = new SoundEngine();

// ============================================================================
// 3. ITEM DEFINITIONS (24 DISTINCT ITEMS ACROSS CATEGORIES)
// ============================================================================
const ITEMS = {
  scrap_metal: {
    id: 'scrap_metal', name: 'Scrap Metal', category: 'material', stack: 50,
    color: '#94a3b8', icon: '🔩', desc: 'Oxidized structural plating stripped from autonomous chassis.'
  },
  mech_parts: {
    id: 'mech_parts', name: 'Mechanical Parts', category: 'material', stack: 40,
    color: '#cbd5e1', icon: '⚙️', desc: 'Precision actuators, bearings, and servo gears.'
  },
  elec_comp: {
    id: 'elec_comp', name: 'Electronic Components', category: 'material', stack: 40,
    color: '#38bdf8', icon: '📟', desc: 'Logic boards and solid-state relays from machine nodes.'
  },
  battery: {
    id: 'battery', name: ' Dry Cell Battery', category: 'power', stack: 25,
    color: '#facc15', icon: '🔋', desc: 'Standard industrial energy cell. Useful for shelter power and tools.'
  },
  power_cell: {
    id: 'power_cell', name: 'High-Density Power Cell', category: 'power', stack: 15,
    color: '#22d3ee', icon: '⚡', desc: 'Volatile capacitor core holding substantial charge.'
  },
  copper_wire: {
    id: 'copper_wire', name: 'Copper Wiring', category: 'material', stack: 50,
    color: '#fb923c', icon: '➰', desc: 'Braided conductive spools harvested from cable trenches.'
  },
  optical_mod: {
    id: 'optical_mod', name: 'Optical Module', category: 'material', stack: 20,
    color: '#a78bfa', icon: '👁️', desc: 'Multi-spectrum glass lens assembly from survey units.'
  },
  sensor_unit: {
    id: 'sensor_unit', name: 'Telemetry Sensor', category: 'material', stack: 20,
    color: '#34d399', icon: '📡', desc: 'Acoustic and thermal array used by patrol automata.'
  },
  coolant_filter: {
    id: 'coolant_filter', name: 'Coolant Filter', category: 'material', stack: 20,
    color: '#67e8f9', icon: '🧪', desc: 'Microporous membrane canister from the Coolant Basin.'
  },
  ind_chem: {
    id: 'ind_chem', name: 'Industrial Solvent', category: 'material', stack: 25,
    color: '#a3e635', icon: '⚗️', desc: 'Refined synthetic compounds for purification and alloys.'
  },
  fabric_insul: {
    id: 'fabric_insul', name: 'Thermal Insulation', category: 'material', stack: 40,
    color: '#fda4af', icon: '🧶', desc: 'Soft woven silica-fiber wrap. Warm enough for bedding and rugs.'
  },
  nutrient_paste: {
    id: 'nutrient_paste', name: 'Bio-Nutrient Pack', category: 'food', stack: 20,
    color: '#bef264', icon: '🥫', food: 28, water: 8, health: 5,
    desc: 'Sealed emergency ration tube found in maintenance lockers.'
  },
  root_tuber: {
    id: 'root_tuber', name: 'Cavern Tuber', category: 'food', stack: 30,
    color: '#d97706', icon: '🥔', food: 18, water: 5, health: 4,
    desc: 'Hardy pale root grown in Yuna’s sun-court planters.'
  },
  sun_berry: {
    id: 'sun_berry', name: 'Amber Sunberry', category: 'food', stack: 30,
    color: '#f59e0b', icon: '🍒', food: 15, water: 22, health: 8,
    desc: 'Sweet, translucent fruit that thrives under the sun shaft.'
  },
  clean_water: {
    id: 'clean_water', name: 'Filtered Water Flask', category: 'consumable', stack: 20,
    color: '#38bdf8', icon: '💧', food: 0, water: 48, health: 6,
    desc: 'Clean, mineral-balanced water from the shelter purifier.'
  },
  warm_stew: {
    id: 'warm_stew', name: 'Warm Root & Herb Stew', category: 'consumable', stack: 10,
    color: '#ea580c', icon: '🍲', food: 55, water: 28, health: 25, stamina: 35,
    desc: 'Yuna’s favorite comfort meal. Smells like rosemary and warm broth.'
  },
  sweet_tea: {
    id: 'sweet_tea', name: 'Sunberry Herbal Tea', category: 'consumable', stack: 10,
    color: '#fbbf24', icon: '🍵', food: 12, water: 52, health: 18, stamina: 40,
    desc: 'Calms Yuna’s nerves and warms her hands after the cold wasteland.'
  },
  seeds_pack: {
    id: 'seeds_pack', name: 'Viable Seed Packet', category: 'garden', stack: 30,
    color: '#4ade80', icon: '🌱', desc: 'Dormant botanical seeds ready for the indoor planter beds.'
  },
  pistol_ammo: {
    id: 'pistol_ammo', name: '9mm Caseless Rounds', category: 'ammo', stack: 120,
    color: '#fbbf24', icon: '🔸', desc: 'Light kinetic cartridges for Yuna’s compact pistol.'
  },
  rifle_ammo: {
    id: 'rifle_ammo', name: 'High-Velocity Slugs', category: 'ammo', stack: 80,
    color: '#f87171', icon: '🔺', desc: 'Heavy armor-piercing rounds for the scavenged rifle.'
  },
  repair_kit: {
    id: 'repair_kit', name: 'Med-Patch & Splint', category: 'consumable', stack: 15,
    color: '#f43f5e', icon: '🩹', food: 0, water: 0, health: 48,
    desc: 'Antiseptic gel and clean bandages for scrapes and burns.'
  },
  decoy_beacon: {
    id: 'decoy_beacon', name: 'Acoustic Chirper', category: 'utility', stack: 10,
    color: '#c084fc', icon: '🔔', desc: 'Emits rhythmic machine pings to distract nearby hostile patrols.'
  },
  machine_core: {
    id: 'machine_core', name: 'Intact Logic Core', category: 'rare', stack: 10,
    color: '#38bdf8', icon: '💎', desc: 'Pristine processing matrix from heavy industrial automata.'
  },
  quest_water_core: {
    id: 'quest_water_core', name: 'Osmotic Membrane Core', category: 'quest', stack: 1,
    color: '#06b6d4', icon: '💠', desc: 'KEY COMPONENT: Precision filtration heart from the Coolant Basin.'
  },
  quest_power_core: {
    id: 'quest_power_core', name: 'Cryo-Capacitor Bank', category: 'quest', stack: 1,
    color: '#eab308', icon: '⚡', desc: 'KEY COMPONENT: High-stability energy bank from the Cable Forest.'
  },
  quest_sun_mirror: {
    id: 'quest_sun_mirror', name: 'Heliostat Fokus Array', category: 'quest', stack: 1,
    color: '#fde047', icon: '☀️', desc: 'KEY COMPONENT: Calibrated solar-tracking mirror from the Dead Foundry.'
  }
};

// ============================================================================
// 4. CRAFTING RECIPES & COOKING RECIPES (20 PRACTICAL RECIPES)
// ============================================================================
const RECIPES = [
  // Survival & Consumables
  {
    id: 'craft_pistol_ammo', name: '9mm Caseless Rounds (x15)', output: { id: 'pistol_ammo', count: 15 },
    station: 'workbench', level: 1,
    cost: { scrap_metal: 3, ind_chem: 1 },
    desc: 'Press light kinetic rounds from scrap casing and propellant.'
  },
  {
    id: 'craft_rifle_ammo', name: 'High-Velocity Slugs (x8)', output: { id: 'rifle_ammo', count: 8 },
    station: 'workbench', level: 1,
    cost: { scrap_metal: 4, copper_wire: 2, ind_chem: 2 },
    desc: 'Assemble heavy penetrator slugs for thick robot plating.'
  },
  {
    id: 'craft_med_patch', name: 'Med-Patch & Splint', output: { id: 'repair_kit', count: 1 },
    station: 'workbench', level: 1,
    cost: { fabric_insul: 2, ind_chem: 1, clean_water: 1 },
    desc: 'Sterilize soft insulation fibers into reliable first-aid dressings.'
  },
  {
    id: 'craft_decoy', name: 'Acoustic Chirper (x2)', output: { id: 'decoy_beacon', count: 2 },
    station: 'workbench', level: 1,
    cost: { scrap_metal: 2, battery: 1, copper_wire: 1 },
    desc: 'Wind a noisy piezoelectric lure that draws robots away from Yuna.'
  },
  {
    id: 'craft_battery', name: 'Recharged Dry Cell', output: { id: 'battery', count: 2 },
    station: 'workbench', level: 1,
    cost: { copper_wire: 2, ind_chem: 1, scrap_metal: 1 },
    desc: 'Rebuild depleted chemical cells for shelter backup.'
  },
  {
    id: 'craft_power_cell', name: 'High-Density Power Cell', output: { id: 'power_cell', count: 1 },
    station: 'workbench', level: 2,
    cost: { battery: 2, elec_comp: 2, copper_wire: 3 },
    desc: 'Couple dry cells into a high-output industrial capacitor.'
  },
  {
    id: 'craft_filter', name: 'Coolant Filter Assembly', output: { id: 'coolant_filter', count: 1 },
    station: 'workbench', level: 2,
    cost: { scrap_metal: 2, fabric_insul: 2, ind_chem: 2 },
    desc: 'Layer thermal fiber and charcoal into a clean filtration cartridge.'
  },
  {
    id: 'craft_seeds', name: 'Extracted Seed Packet (x2)', output: { id: 'seeds_pack', count: 2 },
    station: 'cooking', level: 1,
    cost: { root_tuber: 1, sun_berry: 1 },
    desc: 'Carefully dry and sort viable seeds from harvested crops.'
  },
  // Cooking Station
  {
    id: 'cook_water', name: 'Boil & Filter Water (x2)', output: { id: 'clean_water', count: 2 },
    station: 'cooking', level: 1,
    cost: { battery: 1 },
    desc: 'Draw condensation from the purifier reserve and sterilize it.'
  },
  {
    id: 'cook_stew', name: 'Warm Root & Herb Stew', output: { id: 'warm_stew', count: 1 },
    station: 'cooking', level: 1,
    cost: { root_tuber: 2, clean_water: 1 },
    desc: 'Simmer sliced cavern tubers into a thick, comforting soup.'
  },
  {
    id: 'cook_tea', name: 'Sunberry Herbal Tea', output: { id: 'sweet_tea', count: 1 },
    station: 'cooking', level: 1,
    cost: { sun_berry: 2, clean_water: 1 },
    desc: 'Steep sweet amber berries into a soothing, aromatic infusion.'
  },
  {
    id: 'cook_ration_feast', name: 'Spiced Skillet Hash', output: { id: 'warm_stew', count: 2 },
    station: 'cooking', level: 2,
    cost: { nutrient_paste: 1, root_tuber: 1, sun_berry: 1 },
    desc: 'Turn bland ration paste and fresh produce into two hearty meals.'
  }
];

// ============================================================================
// 5. SHELTER FURNITURE & DECORATION CATALOG (15 MEANINGFUL ITEMS)
// ============================================================================
const FURNITURE_CATALOG = [
  {
    id: 'cozy_bed', name: 'Quilted Patchwork Bed', w: 2, h: 1, color: '#be123c', accent: '#fda4af',
    cost: { fabric_insul: 4, scrap_metal: 2 }, category: 'comfort',
    desc: 'Soft mattress piled with hand-stitched thermal quilts. Restores full energy when sleeping.'
  },
  {
    id: 'woven_rug', name: 'Woven Crimson Rug', w: 2, h: 2, color: '#9f1239', accent: '#fecdd3',
    cost: { fabric_insul: 3 }, category: 'decor', walkable: true,
    desc: 'Warm braided floor rug that keeps Yuna’s feet off the cold mesa stone.'
  },
  {
    id: 'amber_lamp', name: 'Amber Filament Lamp', w: 1, h: 1, color: '#f59e0b', accent: '#fef08a',
    cost: { copper_wire: 2, battery: 1, scrap_metal: 1 }, category: 'lighting', lightRadius: 150,
    desc: 'Salvaged vacuum tube wired to cast a gentle, golden-amber glow.'
  },
  {
    id: 'storage_locker', name: 'Painted Storage Cabinet', w: 1, h: 1, color: '#475569', accent: '#94a3b8',
    cost: { scrap_metal: 5, mech_parts: 1 }, category: 'utility', bonusStorage: 15,
    desc: 'Sturdy metal cabinet painted with little hand-drawn stars. Increases shelter storage.'
  },
  {
    id: 'book_nook', name: 'Reading Corner Chair', w: 1, h: 1, color: '#78350f', accent: '#fcd34d',
    cost: { fabric_insul: 3, scrap_metal: 2 }, category: 'comfort',
    desc: 'Cushioned armchair stacked with old technical manuals and picture books.'
  },
  {
    id: 'terracotta_planter', name: 'Decorative Moss Planter', w: 1, h: 1, color: '#15803d', accent: '#86efac',
    cost: { seeds_pack: 1, scrap_metal: 2 }, category: 'decor',
    desc: 'Small basin of glowing cave moss and tiny white blossoms.'
  },
  {
    id: 'radio_console', name: 'Repaired Vacuum Radio', w: 1, h: 1, color: '#0369a1', accent: '#7dd3fc',
    cost: { elec_comp: 2, copper_wire: 2, battery: 1 }, category: 'audio',
    desc: 'Hums with soft static and gentle melodic synth chords inside the shelter.'
  },
  {
    id: 'wall_curtain', name: 'Draped Thermal Curtain', w: 2, h: 1, color: '#b45309', accent: '#fde68a',
    cost: { fabric_insul: 3, copper_wire: 1 }, category: 'decor',
    desc: 'Heavy amber fabric that softens echoes and hides rough rock walls.'
  },
  {
    id: 'clockwork_owl', name: 'Polished Drone Sculpture', w: 1, h: 1, color: '#0d9488', accent: '#99f6e4',
    cost: { optical_mod: 1, mech_parts: 2 }, category: 'keepsake',
    desc: 'A harmless little survey frame Yuna polished and gave painted wooden wings.'
  },
  {
    id: 'tea_table', name: 'Low Crate Tea Table', w: 1, h: 1, color: '#92400e', accent: '#fde047',
    cost: { scrap_metal: 3, fabric_insul: 1 }, category: 'comfort',
    desc: 'Small wooden-topped crate with a tin teapot and two mismatched cups.'
  },
  {
    id: 'wall_shelf', name: 'Trinket & Jar Shelf', w: 2, h: 1, color: '#57534e', accent: '#fdba74',
    cost: { scrap_metal: 3, optical_mod: 1 }, category: 'decor',
    desc: 'Displays colored glass lenses, dried herbs, and shiny machine gears.'
  },
  {
    id: 'workshop_stool', name: 'Padded Swivel Stool', w: 1, h: 1, color: '#64748b', accent: '#cbd5e1',
    cost: { mech_parts: 2, fabric_insul: 1 }, category: 'utility',
    desc: 'Lets Yuna rest her legs while tinkering with delicate circuit boards.'
  },
  {
    id: 'string_lights', name: 'Copper Fairy Garland', w: 2, h: 1, color: '#eab308', accent: '#fef9c3',
    cost: { copper_wire: 3, battery: 1 }, category: 'lighting', lightRadius: 130,
    desc: 'Tiny low-voltage indicator bulbs strung along a braided copper wire.'
  },
  {
    id: 'mothers_locket_stand', name: 'Memory Keepsake Box', w: 1, h: 1, color: '#c084fc', accent: '#f3e8ff',
    cost: { elec_comp: 1, fabric_insul: 2, optical_mod: 1 }, category: 'keepsake',
    desc: 'Velvet-lined tin holding a faded ribbon and an old schematic handwriting note.'
  },
  {
    id: 'mini_heater', name: 'Coil Space Warmer', w: 1, h: 1, color: '#ea580c', accent: '#fed7aa',
    cost: { copper_wire: 3, mech_parts: 2, battery: 1 }, category: 'comfort', lightRadius: 110,
    desc: 'Radiates a toasted, comforting warmth across the lower living room.'
  }
];

// ============================================================================
// 6. REGIONS & MACHINE CIVILIZATION DATA
// ============================================================================
const REGIONS = {
  shelter: {
    id: 'shelter',
    name: 'Mesa Cavity Shelter',
    subtitle: 'Yuna’s Hidden Home Below the Machines',
    danger: 0,
    palette: { bg: '#261c17', floor: '#3d2c22', upperFloor: '#47362b', wall: '#5c4333', accent: '#f59e0b' },
    desc: 'A warm, hand-wired sanctuary carved inside a hollowed stone mesa.'
  },
  ash_flats: {
    id: 'ash_flats',
    name: 'Region A — The Ash Flats',
    subtitle: 'Low-Risk Salvage Perimeter & Buried Conduits',
    danger: 1,
    palette: { bg: '#272a2e', grid: '#32363b', metal: '#525861', rust: '#8c583a', glow: '#38bdf8' },
    lootPool: ['scrap_metal', 'mech_parts', 'battery', 'copper_wire', 'fabric_insul', 'nutrient_paste', 'pistol_ammo', 'seeds_pack'],
    enemies: ['scuttler', 'drone'],
    landmarkName: 'Collapsed Relay Truss #04',
    desc: 'Scattered autonomous chassis and surface conduit trenches dusted in pale silica ash.'
  },
  cable_forest: {
    id: 'cable_forest',
    name: 'Region B — The Cable Forest',
    subtitle: 'High-Voltage Pylons & Hanging Conduit Thickets',
    danger: 2,
    palette: { bg: '#1e242b', grid: '#262e36', metal: '#43505c', rust: '#6e5638', glow: '#facc15' },
    lootPool: ['copper_wire', 'elec_comp', 'battery', 'power_cell', 'sensor_unit', 'optical_mod', 'pistol_ammo', 'rifle_ammo'],
    enemies: ['scuttler', 'drone', 'guardian'],
    questItem: 'quest_power_core',
    landmarkName: 'Substation Vault Sigma',
    desc: 'Towering transmission pylons draped in swaying, humming braided power cables.'
  },
  dead_foundry: {
    id: 'dead_foundry',
    name: 'Region C — The Dead Foundry',
    subtitle: 'Automated Assembly Lines & Heavy Stamping Bays',
    danger: 3,
    palette: { bg: '#261f1e', grid: '#332927', metal: '#574845', rust: '#9a4629', glow: '#fb923c' },
    lootPool: ['mech_parts', 'scrap_metal', 'elec_comp', 'power_cell', 'rifle_ammo', 'repair_kit', 'machine_core', 'fabric_insul'],
    enemies: ['drone', 'guardian', 'reclaimer'],
    questItem: 'quest_sun_mirror',
    landmarkName: 'Solar Calibration Rotunda',
    desc: 'Colossal dormant robotic arms, slag conveyors, and armored security frames.'
  },
  coolant_basin: {
    id: 'coolant_basin',
    name: 'Region D — The Coolant Basin',
    subtitle: 'Synthetic Reservoirs & Thermal Siphon Pipelines',
    danger: 3,
    palette: { bg: '#162629', grid: '#1d3236', metal: '#3b595e', rust: '#4f7770', glow: '#22d3ee' },
    lootPool: ['coolant_filter', 'ind_chem', 'sensor_unit', 'optical_mod', 'clean_water', 'nutrient_paste', 'rifle_ammo', 'machine_core'],
    enemies: ['scuttler', 'guardian', 'reclaimer'],
    questItem: 'quest_water_core',
    landmarkName: 'Primary Osmosis Pumping Rig',
    desc: 'Mist-shrouded artificial reservoirs, cyan coolant pools, and submerged siphon assemblies.'
  }
};

const YUNA_QUOTES = {
  shelterIdle: [
    "Okay... okay. It's warm in here.",
    "*click* ...Should check the water filter soon.",
    "Just five more minutes by the lamp...",
    "Little solder joint held up nicely!",
    "*soft hum* ...Everything's quiet.",
    "Braid's getting frayed again... that's okay."
  ],
  wastelandIdle: [
    "Okay, stay quiet... stay small.",
    "*click-click* ...Don't look at me, please.",
    "I really should head back before dark.",
    "Just one more salvage crate... just one.",
    "Cold wind through those pylons...",
    "Hold the strap tight. Deep breath, Yuna."
  ],
  lootSuccess: [
    "There we go! Still usable.",
    "Oh! Good wiring in this one.",
    "Careful, sharp edges... got it!",
    "That'll help back home."
  ],
  combatAlert: [
    "Oh, that's not good—!",
    "Please go away, please go away!",
    "Stay back! I—I have a pistol!",
    "*sharp breath* Okay, aim steady..."
  ],
  craftSuccess: [
    "Please work... oh! It works!",
    "Neat and tidy. Mother would approve.",
    "There we go!"
  ],
  cookSuccess: [
    "Smells so good...",
    "Warm food makes everything better.",
    "Not burnt this time! Yay."
  ]
};

const OPTIONAL_DISCOVERIES = [
  { id: 'disc_bot', name: 'Little Sweeper Unit', region: 'ash_flats', desc: 'Repaired a harmless three-wheeled maintenance bot so it can hum happily in place.' },
  { id: 'disc_archive', name: 'Memory Tape Spool', region: 'cable_forest', desc: 'Recovered an old calibration log containing a warm lullaby frequency.' },
  { id: 'disc_orchid', name: 'Thermal Vent Glass-Bloom', region: 'coolant_basin', desc: 'Found a resilient crystalline plant thriving beside a warm coolant pipe.' },
  { id: 'disc_music', name: 'Harmonic Chime Cylinder', region: 'dead_foundry', desc: 'Salvaged a precision brass acoustic cylinder for the shelter radio.' },
  { id: 'disc_mother', name: 'Hand-Annotated Schematic', region: 'cable_forest', desc: 'Found a waterproofed blueprint corner with familiar gentle handwriting: "Keep the sun-shaft clean, little bird."' },
  { id: 'disc_scenic', name: 'High Mesa Overlook', region: 'ash_flats', desc: 'Paused at a quiet ridge where golden sunset light reflects off distant cooling towers.' }
];

// ============================================================================
// 7. INDEXEDDB PERSISTENCE ENGINE
// ============================================================================
const DB_NAME = 'YunaWarmthBelowDB';
const DB_VERSION = 1;
const STORE_NAME = 'saves';

function openSaveDB() {
  return new Promise((resolve, reject) => {
    const req = indexedDB.open(DB_NAME, DB_VERSION);
    req.onupgradeneeded = (e) => {
      const db = e.target.result;
      if (!db.objectStoreNames.contains(STORE_NAME)) {
        db.createObjectStore(STORE_NAME, { keyPath: 'slot' });
      }
    };
    req.onsuccess = () => resolve(req.result);
    req.onerror = () => reject(req.error);
  });
}

async function saveToSlot(slot, data) {
  try {
    const db = await openSaveDB();
    return new Promise((resolve, reject) => {
      const tx = db.transaction(STORE_NAME, 'readwrite');
      tx.objectStore(STORE_NAME).put({ slot, updatedAt: Date.now(), data });
      tx.oncomplete = () => resolve(true);
      tx.onerror = () => reject(tx.error);
    });
  } catch (e) {
    console.warn('IndexedDB save fallback:', e);
    return false;
  }
}

async function loadFromSlot(slot) {
  try {
    const db = await openSaveDB();
    return new Promise((resolve, reject) => {
      const tx = db.transaction(STORE_NAME, 'readonly');
      const req = tx.objectStore(STORE_NAME).get(slot);
      req.onsuccess = () => resolve(req.result ? req.result.data : null);
      req.onerror = () => reject(req.error);
    });
  } catch (e) {
    return null;
  }
}

async function listSaveSlots() {
  try {
    const db = await openSaveDB();
    return new Promise((resolve) => {
      const tx = db.transaction(STORE_NAME, 'readonly');
      const req = tx.objectStore(STORE_NAME).getAll();
      req.onsuccess = () => resolve(req.result || []);
      req.onerror = () => resolve([]);
    });
  } catch (e) {
    return [];
  }
}

// ============================================================================
// 8. INITIAL STATE & PROCEDURAL REGION GENERATOR
// ============================================================================
function createInitialState(seed = Math.floor(Math.random() * 899999 + 100000)) {
  return {
    worldSeed: seed,
    day: 1,
    timeOfDay: 8.0, // 0.0 to 24.0 hours (8:00 AM start)
    region: 'shelter',
    player: {
      x: 420,
      y: 440,
      hp: 100,
      maxHp: 100,
      stamina: 100,
      maxStamina: 100,
      food: 88,
      water: 86,
      activeWeapon: 'pistol', // 'pistol' | 'rifle'
      pistolMag: 10,
      pistolMaxMag: 10,
      rifleMag: 5,
      rifleMaxMag: 5,
      crouching: false,
      facing: 0
    },
    inventory: [
      { id: 'pistol_ammo', count: 32 },
      { id: 'rifle_ammo', count: 10 },
      { id: 'clean_water', count: 2 },
      { id: 'warm_stew', count: 1 },
      { id: 'repair_kit', count: 2 },
      { id: 'scrap_metal', count: 6 },
      { id: 'fabric_insul', count: 4 },
      { id: 'copper_wire', count: 3 },
      { id: 'battery', count: 2 },
      { id: 'seeds_pack', count: 3 },
      { id: 'decoy_beacon', count: 2 }
    ],
    storage: [
      { id: 'root_tuber', count: 3 },
      { id: 'sun_berry', count: 2 },
      { id: 'mech_parts', count: 3 },
      { id: 'elec_comp', count: 2 },
      { id: 'ind_chem', count: 2 }
    ],
    facilities: {
      waterPurifier: 1,    // 1 -> 2 -> 3 (Restored)
      powerSupply: 1,      // 1 -> 2 -> 3 (Restored)
      cookingStation: 1,   // 1 -> 2
      workbench: 1,        // 1 -> 2
      growingSystem: 1,    // 1 -> 2 -> 3 (Restored)
      storageLevel: 1
    },
    equipmentUpgrades: {
      pistolLevel: 1,
      rifleLevel: 1,
      backpackLevel: 1,
      scannerLevel: 1
    },
    mainRestore: {
      waterRestored: false,
      powerRestored: false,
      sunlightRestored: false,
      endingSeen: false
    },
    shelterPower: 78,
    shelterWater: 72,
    gardenPlots: [
      { id: 0, crop: 'root_tuber', stage: 2, watered: true, x: 250, y: 175 },
      { id: 1, crop: 'sun_berry', stage: 1, watered: true, x: 310, y: 175 },
      { id: 2, crop: null, stage: 0, watered: false, x: 370, y: 175 },
      { id: 3, crop: null, stage: 0, watered: false, x: 430, y: 175 }
    ],
    furniture: [
      { uid: 'f_bed_1', id: 'cozy_bed', gx: 3, gy: 7, rot: 0 },
      { uid: 'f_rug_1', id: 'woven_rug', gx: 6, gy: 7, rot: 0 },
      { uid: 'f_lamp_1', id: 'amber_lamp', gx: 5, gy: 6, rot: 0 },
      { uid: 'f_radio_1', id: 'radio_console', gx: 11, gy: 6, rot: 0 },
      { uid: 'f_chair_1', id: 'book_nook', gx: 8, gy: 8, rot: 0 },
      { uid: 'f_table_1', id: 'tea_table', gx: 7, gy: 8, rot: 0 }
    ],
    discoveredRegions: ['shelter', 'ash_flats'],
    discoveries: [],
    journalEntries: [
      {
        id: 'entry_initial',
        day: 1,
        title: 'Still Warm Down Here',
        mood: 'Quietly Hopeful',
        content: "Checked the seals on the upper sun-shaft this morning. *click* The osmosis filter is starting to rattle a little, and the capacitor bank is running low, so I'll need to brave the Ash Flats soon. At least the amber lamp is glowing and my braid stayed neat today.",
        sketchNote: '[Sketch: A tiny sprouting cavern tuber under a beam of light]'
      }
    ],
    decodedSignals: [],
    persistedRegions: {}, // Stores looted containers & defeated enemies per region
    settings: {
      zoom: 1.0,
      damageNumbers: true,
      reducedShake: false,
      reducedFlash: false,
      mobileControls: 'auto' // 'auto' | 'on' | 'off'
    }
  };
}

// Generate deterministic Wasteland Region Layout (1800 x 1300 world space)
function generateRegionMap(regionId, worldSeed, day, persisted = {}) {
  const rng = new SeededRNG(worldSeed + regionId.split('').reduce((a, c) => a + c.charCodeAt(0) * 37, 0));
  const regConfig = REGIONS[regionId];
  const width = 1800;
  const height = 1300;

  const structures = [];
  const containers = [];
  const enemies = [];
  const hazards = [];

  // Entry gate back to shelter / region transition on West edge
  const exitZone = { x: 110, y: 650, r: 58, label: 'Return to Shelter Passage' };

  // 1. Generate Industrial Machine Structures (walls/pillars/conduits)
  const structCount = regionId === 'cable_forest' ? 28 : regionId === 'dead_foundry' ? 24 : 20;
  for (let i = 0; i < structCount; i++) {
    const sx = rng.int(240, width - 180);
    const sy = rng.int(140, height - 160);
    // Keep clear of spawn & landmark center
    if (Math.hypot(sx - 150, sy - 650) < 180) continue;
    if (Math.hypot(sx - 1420, sy - 620) < 200) continue;

    const w = rng.int(55, 130);
    const h = rng.int(45, 110);
    const kind = rng.pick(['pylon', 'turbine', 'conduit_block', 'stamping_press', 'cooling_vat']);
    structures.push({ id: `st_${i}`, x: sx, y: sy, w, h, kind });
  }

  // 2. Authored Region Landmark on East sector
  const landmark = {
    x: 1420,
    y: 620,
    w: 160,
    h: 130,
    name: regConfig.landmarkName,
    questItem: regConfig.questItem || null
  };

  // 3. Salvage Containers (14 to 18 per region)
  const lootedMap = persisted.lootedContainers || {};
  const containerCount = 16;
  for (let i = 0; i < containerCount; i++) {
    const cid = `${regionId}_cont_${i}`;
    let cx = rng.int(260, width - 140);
    let cy = rng.int(130, height - 130);
    if (i === 0 && regConfig.questItem) {
      // Guaranteed Quest Component Container at the Landmark!
      cx = landmark.x - 30;
      cy = landmark.y + 95;
    }

    // Check if looted recently (refreshes after 3 in-game days, except quest container)
    const lootedDay = lootedMap[cid];
    const isLooted = lootedDay !== undefined && (i === 0 || day - lootedDay < 3);

    const loot = [];
    if (i === 0 && regConfig.questItem && !lootedMap[cid]) {
      loot.push({ id: regConfig.questItem, count: 1 });
      loot.push({ id: 'machine_core', count: 1 });
      loot.push({ id: 'power_cell', count: 2 });
    } else {
      const itemCount = rng.int(2, 4);
      for (let k = 0; k < itemCount; k++) {
        const itemId = rng.pick(regConfig.lootPool);
        const qty = itemId.includes('ammo') ? rng.int(8, 18) : rng.int(1, 4);
        loot.push({ id: itemId, count: qty });
      }
    }

    containers.push({
      id: cid,
      x: cx,
      y: cy,
      isRare: i === 0 || i % 5 === 0,
      looted: isLooted,
      loot
    });
  }

  // 4. Optional Discovery Node in Region
  const discList = OPTIONAL_DISCOVERIES.filter(d => d.region === regionId);
  const discoveryNodes = discList.map((d, idx) => ({
    ...d,
    x: 520 + idx * 440,
    y: idx % 2 === 0 ? 260 : 1020
  }));

  // 5. Environmental Hazards (Electrical arcs or Coolant pools)
  for (let i = 0; i < 7; i++) {
    hazards.push({
      id: `haz_${i}`,
      x: rng.int(340, width - 220),
      y: rng.int(180, height - 180),
      r: rng.int(42, 68),
      type: regionId === 'coolant_basin' ? 'coolant' : 'electric'
    });
  }

  // 6. Enemy Robots & Harmless Maintenance Units
  const defeatedMap = persisted.defeatedEnemies || {};
  const enemyCount = 7 + regConfig.danger * 3;
  for (let i = 0; i < enemyCount; i++) {
    const eid = `${regionId}_enemy_${i}`;
    if (defeatedMap[eid] !== undefined && day - defeatedMap[eid] < 2) continue;

    let ex = rng.int(420, width - 160);
    let ey = rng.int(160, height - 160);
    const type = rng.pick(regConfig.enemies);

    const stats = {
      scuttler: { hp: 38, maxHp: 38, speed: 125, range: 42, dmg: 9, radius: 18, name: 'Scuttler' },
      drone: { hp: 45, maxHp: 45, speed: 105, range: 270, dmg: 11, radius: 20, name: 'Survey Drone' },
      guardian: { hp: 95, maxHp: 95, speed: 78, range: 190, dmg: 16, radius: 26, name: 'Maintenance Guardian' },
      reclaimer: { hp: 185, maxHp: 185, speed: 54, range: 230, dmg: 26, radius: 34, name: 'Heavy Reclaimer' }
    }[type];

    enemies.push({
      id: eid,
      type,
      ...stats,
      x: ex,
      y: ey,
      homeX: ex,
      homeY: ey,
      vx: 0,
      vy: 0,
      state: 'patrol', // 'patrol' | 'investigate' | 'chase' | 'attack'
      alertTimer: 0,
      attackCooldown: 0,
      telegraphTimer: 0,
      patrolAngle: rng.range(0, Math.PI * 2),
      hitFlash: 0
    });
  }

  // Add 2 Neutral Harmless Sweepers so not every machine is hostile
  for (let n = 0; n < 2; n++) {
    enemies.push({
      id: `${regionId}_neutral_${n}`,
      type: 'neutral_sweeper',
      name: 'Autonomous Conduit Sweeper',
      neutral: true,
      hp: 60,
      maxHp: 60,
      speed: 45,
      range: 0,
      dmg: 0,
      radius: 19,
      x: rng.int(320, 1200),
      y: rng.int(250, 950),
      homeX: 600,
      homeY: 600,
      state: 'patrol',
      patrolAngle: n * 2.1,
      hitFlash: 0
    });
  }

  return { width, height, exitZone, landmark, structures, containers, enemies, hazards, discoveryNodes };
}

// ============================================================================
// 9. SPRITE ATLAS & MULTI-FRAME SPRITESHEET ENGINE (PRE-BAKED 2D ART)
// ============================================================================
const GENERATED_MASTER_SHEET_URL = "watermarked_img_2893481083748969373.jpg";

// NormalizedUV crop regions [u, v, uw, vh] mapped to the generated Master Pixel Art Sheet
const MASTER_SHEET_REGIONS = {
  yuna_down_idle1: [0.008, 0.010, 0.055, 0.165],
  yuna_down_idle2: [0.082, 0.010, 0.055, 0.165],
  yuna_right_walk1: [0.162, 0.010, 0.062, 0.165],
  yuna_right_walk2: [0.248, 0.010, 0.062, 0.165],
  yuna_right_walk3: [0.332, 0.010, 0.062, 0.165],
  yuna_right_pistol: [0.415, 0.010, 0.068, 0.165],
  yuna_crouch_pistol: [0.505, 0.015, 0.085, 0.135],
  yuna_up_idle: [0.082, 0.175, 0.058, 0.165],
  yuna_left_walk: [0.165, 0.175, 0.065, 0.165],
  yuna_up_pack: [0.252, 0.175, 0.060, 0.165],
  yuna_crouch_rifle: [0.610, 0.145, 0.085, 0.130],
  robot_scuttler: [0.015, 0.355, 0.105, 0.135],
  robot_drone: [0.150, 0.335, 0.100, 0.155],
  robot_guardian: [0.310, 0.320, 0.155, 0.185],
  robot_reclaimer: [0.510, 0.265, 0.190, 0.240],
  robot_sweeper: [0.705, 0.365, 0.135, 0.135],
  wrecked_salvage: [0.850, 0.355, 0.140, 0.145],
  cozy_bed: [0.005, 0.575, 0.118, 0.185],
  amber_lamp: [0.125, 0.600, 0.060, 0.105],
  radio_console: [0.188, 0.585, 0.060, 0.120],
  woven_rug: [0.130, 0.680, 0.115, 0.085],
  workbench: [0.255, 0.600, 0.160, 0.105],
  wall_shelf: [0.415, 0.525, 0.085, 0.155],
  planter_box: [0.006, 0.850, 0.118, 0.140],
  shelter_hatch: [0.505, 0.840, 0.115, 0.155],
  tile_stone: [0.750, 0.005, 0.120, 0.160],
  tile_wasteland: [0.875, 0.005, 0.120, 0.160]
};

class SpriteAtlasEngine {
  constructor() {
    this.ready = false;
    this.yunaSheet = null;      // 4 directions x 8 animation frames (64x64 each)
    this.robotSheet = null;     // 5 archetypes x 4 animation frames (64x64 each)
    this.furnitureSheet = null; // Detailed 3/4 view sprites for all 15 furniture items
    this.propSheet = null;      // Containers, crops, stations, and industrial props
    this.patterns = {};         // Seamless tileable surface textures
    this.masterImage = null;    // Loaded external/custom pixel-art master sheet
    this.masterSprites = {};    // Chroma-keyed cropped sprites from masterImage
    this.useMasterSheet = true;
  }

  init() {
    if (this.ready || typeof document === 'undefined') return;
    this.buildSurfacePatterns();
    this.buildYunaSpritesheet();
    this.buildRobotSpritesheet();
    this.buildFurnitureSpritesheet();
    this.buildPropsSpritesheet();
    this.loadMasterPixelSheet(GENERATED_MASTER_SHEET_URL);
    this.ready = true;
  }

  // Loads the generated pixel-art master sheet, removes the dark grid background via chroma key,
  // and slices each region into individual crisp offscreen sprite canvases
  loadMasterPixelSheet(srcUrl) {
    if (typeof Image === 'undefined') return;
    const img = new Image();
    img.crossOrigin = 'anonymous';
    img.onload = () => {
      this.masterImage = img;
      this.sliceMasterSheet(img);
    };
    img.onerror = () => {
      // Fallback cleanly to our baked pixel-art canvases if external URL is unavailable
    };
    img.src = srcUrl;
  }

  sliceMasterSheet(img) {
    const iw = img.naturalWidth || img.width;
    const ih = img.naturalHeight || img.height;
    if (!iw || !ih) return;

    const extractSprite = ([u, v, uw, vh], removeBg = true) => {
      const sx = Math.floor(u * iw);
      const sy = Math.floor(v * ih);
      const sw = Math.max(1, Math.floor(uw * iw));
      const sh = Math.max(1, Math.floor(vh * ih));
      const c = document.createElement('canvas');
      c.width = sw;
      c.height = sh;
      const ctx = c.getContext('2d');
      ctx.imageSmoothingEnabled = false;
      ctx.drawImage(img, sx, sy, sw, sh, 0, 0, sw, sh);

      if (removeBg) {
        try {
          const imgData = ctx.getImageData(0, 0, sw, sh);
          const d = imgData.data;
          for (let i = 0; i < d.length; i += 4) {
            const r = d[i];
            const g = d[i + 1];
            const b = d[i + 2];
            // Chroma-key out the dark charcoal grid background (#1a1a22 / #23232b)
            const maxC = Math.max(r, g, b);
            const minC = Math.min(r, g, b);
            if (maxC < 44 && maxC - minC < 14) {
              d[i + 3] = 0;
            }
          }
          ctx.putImageData(imgData, 0, 0);
        } catch (e) {
          // Ignore CORS taint if loaded from external origin without headers
        }
      }
      return c;
    };

    Object.entries(MASTER_SHEET_REGIONS).forEach(([key, rect]) => {
      const isTile = key.startsWith('tile_');
      this.masterSprites[key] = extractSprite(rect, !isTile);
    });

    // Override furniture sprites with sliced master pixel-art sprites when available
    if (this.masterSprites.cozy_bed) this.furnitureSprites.cozy_bed = this.masterSprites.cozy_bed;
    if (this.masterSprites.amber_lamp) this.furnitureSprites.amber_lamp = this.masterSprites.amber_lamp;
    if (this.masterSprites.radio_console) this.furnitureSprites.radio_console = this.masterSprites.radio_console;
    if (this.masterSprites.woven_rug) this.furnitureSprites.woven_rug = this.masterSprites.woven_rug;
    if (this.masterSprites.wall_shelf) this.furnitureSprites.wall_shelf = this.masterSprites.wall_shelf;
  }

  // 1. Pre-bake seamless tileable textures for floors & wasteland biomes
  buildSurfacePatterns() {
    const makePatternCanvas = (w, h, drawFn) => {
      const c = document.createElement('canvas');
      c.width = w;
      c.height = h;
      drawFn(c.getContext('2d'), w, h);
      return c;
    };

    // Shelter Warm Stone & Timber Plank Tile (64x64)
    this.patterns.shelterLower = makePatternCanvas(64, 64, (ctx) => {
      ctx.fillStyle = '#3a281e';
      ctx.fillRect(0, 0, 64, 64);
      // Warm fitted flagstones with subtle bevels
      const stones = [
        [2, 2, 28, 28, '#443024'],
        [32, 2, 30, 18, '#3f2c21'],
        [32, 22, 30, 20, '#493427'],
        [2, 32, 28, 30, '#3e2b20'],
        [32, 44, 30, 18, '#432f23']
      ];
      stones.forEach(([x, y, w, h, col]) => {
        ctx.fillStyle = col;
        ctx.beginPath();
        ctx.roundRect(x, y, w, h, 3);
        ctx.fill();
        ctx.fillStyle = 'rgba(255,210,160,0.06)';
        ctx.fillRect(x + 1, y + 1, w - 2, 2);
      });
    });

    // Shelter Upper Sun-Court Flagstone & Moss Tile (64x64)
    this.patterns.shelterUpper = makePatternCanvas(64, 64, (ctx) => {
      ctx.fillStyle = '#47362b';
      ctx.fillRect(0, 0, 64, 64);
      ctx.strokeStyle = '#36271e';
      ctx.lineWidth = 2;
      ctx.strokeRect(1, 1, 30, 30);
      ctx.strokeRect(33, 1, 30, 30);
      ctx.strokeRect(1, 33, 30, 30);
      ctx.strokeRect(33, 33, 30, 30);
      // Tiny moss specks in crevices
      ctx.fillStyle = 'rgba(74, 222, 128, 0.25)';
      ctx.fillRect(30, 12, 4, 4);
      ctx.fillRect(14, 31, 5, 3);
    });

    // Wasteland Industrial Biome Tiles (96x96)
    const biomeColors = {
      ash_flats: { base: '#24282c', plate: '#2d3238', grit: '#3c424a', seam: '#1a1d20', accent: '#64748b' },
      cable_forest: { base: '#1b2229', plate: '#232c35', grit: '#313d49', seam: '#12171c', accent: '#eab308' },
      dead_foundry: { base: '#251e1d', plate: '#312725', grit: '#453532', seam: '#181312', accent: '#ea580c' },
      coolant_basin: { base: '#142326', plate: '#1c3034', grit: '#264247', seam: '#0d181a', accent: '#06b6d4' }
    };

    Object.entries(biomeColors).forEach(([id, pal]) => {
      this.patterns[id] = makePatternCanvas(96, 96, (ctx) => {
        ctx.fillStyle = pal.base;
        ctx.fillRect(0, 0, 96, 96);
        // Sub-surface metal deck plating
        ctx.fillStyle = pal.plate;
        ctx.fillRect(4, 4, 42, 42);
        ctx.fillRect(50, 4, 42, 42);
        ctx.fillRect(4, 50, 42, 42);
        ctx.fillRect(50, 50, 42, 42);
        // Rivets & recessed conduit channels
        ctx.fillStyle = pal.seam;
        ctx.fillRect(0, 46, 96, 4);
        ctx.fillRect(46, 0, 4, 96);
        ctx.fillStyle = pal.grit;
        for (let r = 8; r < 90; r += 20) {
          ctx.fillRect(r, 8, 2, 2);
          ctx.fillRect(r, 54, 2, 2);
        }
        // Subtle micro-conduit trace
        ctx.fillStyle = pal.accent;
        ctx.globalAlpha = 0.22;
        ctx.fillRect(22, 0, 2, 96);
        ctx.globalAlpha = 1.0;
      });
    });
  }

  // 2. Build Yuna's Multi-Frame Character Spritesheet (Cols: 8 Frames, Rows: 4 Directions)
  // Row 0: Down (Front), Row 1: Up (Back), Row 2: Left, Row 3: Right
  // Cols 0..1: Idle Breathe, Cols 2..5: 4-Step Walk Cycle, Col 6: Tic/Braid Fidget, Col 7: Sneak/Crouch
  buildYunaSpritesheet() {
    const fw = 64;
    const fh = 64;
    const cols = 8;
    const rows = 4;
    const c = document.createElement('canvas');
    c.width = fw * cols;
    c.height = fh * rows;
    const ctx = c.getContext('2d');

    for (let dir = 0; dir < rows; dir++) {
      for (let frame = 0; frame < cols; frame++) {
        ctx.save();
        ctx.translate(frame * fw + fw / 2, dir * fh + fh / 2 + 6);

        const isIdle = frame < 2;
        const isWalk = frame >= 2 && frame <= 5;
        const isTic = frame === 6;
        const isCrouch = frame === 7;

        const walkPhase = isWalk ? ((frame - 2) / 4) * Math.PI * 2 : 0;
        const bob = isIdle
          ? (frame === 1 ? -1.2 : 0)
          : isWalk
          ? Math.abs(Math.sin(walkPhase)) * -3
          : isCrouch
          ? 4
          : -1;
        const leftLegY = isWalk ? Math.sin(walkPhase) * 4.5 : 0;
        const rightLegY = isWalk ? -Math.sin(walkPhase) * 4.5 : 0;

        if (isCrouch) ctx.scale(1.04, 0.86);

        // Soft ambient ground shadow
        ctx.fillStyle = 'rgba(0, 0, 0, 0.36)';
        ctx.beginPath();
        ctx.ellipse(0, 17, 14, 6.5, 0, 0, Math.PI * 2);
        ctx.fill();

        // Backpack (drawn behind when facing Down, Left, Right)
        if (dir !== 0) {
          const bx = dir === 2 ? 5 : dir === 3 ? -17 : -12;
          const bw = dir === 1 ? 24 : 12;
          ctx.fillStyle = '#5c3a28';
          ctx.beginPath();
          ctx.roundRect(bx, -14 + bob, bw, 20, 4);
          ctx.fill();
          ctx.fillStyle = '#7c5038';
          ctx.fillRect(bx + 2, -12 + bob, bw - 4, 6);
          // Bedroll strapped to top of pack
          ctx.fillStyle = '#9f1239';
          ctx.beginPath();
          ctx.roundRect(bx + 1, -17 + bob, bw - 2, 4, 2);
          ctx.fill();
        }

        // Legs: Pale skin + Tattered Knee-High Socks + Worn Red/Cream Sneakers
        const drawLeg = (lx, lyOffset) => {
          // Bare knee/thigh
          ctx.fillStyle = '#fbeee4';
          ctx.fillRect(lx, 4 + bob + lyOffset * 0.4, 5, 5);
          // Tattered charcoal knee-high sock with uneven top cuff
          ctx.fillStyle = '#3f4756';
          ctx.fillRect(lx, 8 + bob + lyOffset * 0.7, 5, 6);
          ctx.fillStyle = '#525c6e';
          ctx.fillRect(lx, 8 + bob + lyOffset * 0.7, 5, 1.5);
          // Old worn sneaker with white toe cap
          ctx.fillStyle = '#991b1b';
          ctx.beginPath();
          ctx.roundRect(lx - 1, 13 + bob + lyOffset, 7, 4.5, 2);
          ctx.fill();
          ctx.fillStyle = '#e2e8f0';
          ctx.fillRect(lx - 1, 15.5 + bob + lyOffset, 7, 1.8);
        };

        if (dir === 2 || dir === 3) {
          drawLeg(-2 + (leftLegY * 0.3), leftLegY * 0.7);
          drawLeg(-3 - (leftLegY * 0.3), rightLegY * 0.7);
        } else {
          drawLeg(-7, leftLegY);
          drawLeg(2, rightLegY);
        }

        // Torso: Soft Petite Worn Tunic & Olive/Brown Field Vest
        // Under-tunic skirt hem (faded warm berry red)
        ctx.fillStyle = '#88292f';
        ctx.beginPath();
        ctx.roundRect(-12, 0 + bob, 24, 7, 3);
        ctx.fill();

        // Main tunic & jacket body
        const torsoGrad = ctx.createLinearGradient(0, -13 + bob, 0, 5 + bob);
        torsoGrad.addColorStop(0, '#b0463c');
        torsoGrad.addColorStop(1, '#7f2923');
        ctx.fillStyle = torsoGrad;
        ctx.beginPath();
        ctx.roundRect(-11.5, -12 + bob, 23, 16, 6);
        ctx.fill();
        ctx.strokeStyle = '#3b1310';
        ctx.lineWidth = 1.2;
        ctx.stroke();

        // Soft cream collar scarf & belt
        ctx.fillStyle = '#f5e6d3';
        ctx.beginPath();
        ctx.roundRect(-7, -13 + bob, 14, 4, 2);
        ctx.fill();

        // Utility waist belt & brass buckle
        ctx.fillStyle = '#3d2516';
        ctx.fillRect(-11, 0 + bob, 22, 3);
        ctx.fillStyle = '#eab308';
        ctx.fillRect(-2.5, -0.5 + bob, 5, 4);

        // Head & Hair (with subtle tilt on Frame 6 tic)
        ctx.save();
        ctx.translate(0, -21 + bob);
        if (isTic) ctx.rotate(0.14);

        // Back hair volume (Muted Auburn / Reddish-Brown)
        ctx.fillStyle = '#7c2d12';
        ctx.beginPath();
        ctx.arc(0, 0, 13, 0, Math.PI * 2);
        ctx.fill();

        // Long Loose Practical Braid (Swinging with walk or held during tic)
        const braidSwing = isWalk ? Math.sin(walkPhase) * 3.5 : isTic ? -3 : 0;
        const drawBraid = (bx, by) => {
          ctx.fillStyle = '#8c3318';
          // Segmented plait circles for authentic braided sprite look
          for (let s = 0; s < 5; s++) {
            ctx.beginPath();
            ctx.ellipse(
              bx + braidSwing * (s * 0.25),
              by + s * 3.6,
              3.6 - s * 0.3,
              2.8,
              0.2,
              0,
              Math.PI * 2
            );
            ctx.fill();
          }
          // Yellow ribbon tie + loose tuft
          ctx.fillStyle = '#facc15';
          ctx.fillRect(bx + braidSwing - 2, by + 17, 4.5, 2.5);
          ctx.fillStyle = '#7c2d12';
          ctx.beginPath();
          ctx.arc(bx + braidSwing, by + 21, 2.5, 0, Math.PI * 2);
          ctx.fill();
        };

        if (dir === 1) {
          // Facing Up: Braid hangs down center back
          drawBraid(0, 4);
        } else {
          // Braid hangs over left shoulder
          drawBraid(-9, 3);
        }

        // Face (Shown when Down, Left, Right)
        if (dir !== 1) {
          const faceOffsetX = dir === 2 ? -2.5 : dir === 3 ? 2.5 : 0;
          ctx.fillStyle = '#fdf2e9'; // Very pale porcelain skin
          ctx.beginPath();
          ctx.arc(faceOffsetX, 1, 10.8, 0, Math.PI * 2);
          ctx.fill();

          // Soft rosy cheeks & subtle Irish-English freckles
          ctx.fillStyle = 'rgba(244, 114, 182, 0.26)';
          ctx.beginPath();
          ctx.arc(faceOffsetX - 5.5, 3.8, 2.6, 0, Math.PI * 2);
          ctx.arc(faceOffsetX + 5.5, 3.8, 2.6, 0, Math.PI * 2);
          ctx.fill();

          ctx.fillStyle = 'rgba(180, 83, 9, 0.48)';
          [-5.5, -3.8, 3.8, 5.5].forEach((fx, idx) => {
            ctx.fillRect(faceOffsetX + fx, 3 + (idx % 2), 1.1, 1.1);
          });

          // Light Green Expressive Eyes
          const eyeShift = dir === 2 ? -2 : dir === 3 ? 2 : 0;
          if (isTic) {
            // Gentle blink/squint on tic frame
            ctx.strokeStyle = '#3f2314';
            ctx.lineWidth = 1.6;
            ctx.beginPath();
            ctx.moveTo(faceOffsetX - 6 + eyeShift, 1.5);
            ctx.lineTo(faceOffsetX - 2 + eyeShift, 1.5);
            ctx.moveTo(faceOffsetX + 2 + eyeShift, 1.5);
            ctx.lineTo(faceOffsetX + 6 + eyeShift, 1.5);
            ctx.stroke();
          } else {
            // Sclera
            ctx.fillStyle = '#ffffff';
            ctx.fillRect(faceOffsetX - 6.2 + eyeShift, -0.8, 4.4, 4.4);
            ctx.fillRect(faceOffsetX + 1.8 + eyeShift, -0.8, 4.4, 4.4);
            // Light green iris
            ctx.fillStyle = '#16a34a';
            ctx.fillRect(faceOffsetX - 5.2 + eyeShift, -0.2, 3.0, 3.4);
            ctx.fillRect(faceOffsetX + 2.4 + eyeShift, -0.2, 3.0, 3.4);
            // Pupil
            ctx.fillStyle = '#052e16';
            ctx.fillRect(faceOffsetX - 4.4 + eyeShift, 0.6, 1.6, 1.8);
            ctx.fillRect(faceOffsetX + 3.2 + eyeShift, 0.6, 1.6, 1.8);
            // Eye catchlight sparkle
            ctx.fillStyle = '#ffffff';
            ctx.fillRect(faceOffsetX - 5.0 + eyeShift, 0, 1.3, 1.3);
            ctx.fillRect(faceOffsetX + 2.6 + eyeShift, 0, 1.3, 1.3);
          }

          // Parted Muted Auburn Bangs across forehead
          ctx.fillStyle = '#9a3412';
          ctx.beginPath();
          ctx.arc(0, -2.5, 11.5, Math.PI * 0.92, Math.PI * 2.08);
          ctx.fill();
          // Hair highlight strand
          ctx.strokeStyle = '#c2410c';
          ctx.lineWidth = 1.5;
          ctx.beginPath();
          ctx.arc(0, -3.5, 9.5, Math.PI * 1.15, Math.PI * 1.85);
          ctx.stroke();
        } else {
          // Back of head hair detail when facing Up
          ctx.fillStyle = '#9a3412';
          ctx.beginPath();
          ctx.arc(0, -1, 12, 0, Math.PI * 2);
          ctx.fill();
        }

        ctx.restore(); // End Head
        ctx.restore(); // End Frame Cell
      }
    }
    this.yunaSheet = c;
  }

  // 3. Build Enemy Robot Spritesheet (5 Rows x 4 Animation Frames, 64x64 each)
  // Row 0: Scuttler, Row 1: Survey Drone, Row 2: Maintenance Guardian, Row 3: Heavy Reclaimer, Row 4: Neutral Sweeper
  buildRobotSpritesheet() {
    const fw = 64;
    const fh = 64;
    const c = document.createElement('canvas');
    c.width = fw * 4;
    c.height = fh * 5;
    const ctx = c.getContext('2d');

    for (let row = 0; row < 5; row++) {
      for (let col = 0; col < 4; col++) {
        ctx.save();
        ctx.translate(col * fw + 32, row * fh + 32);
        const phase = (col / 4) * Math.PI * 2;

        if (row === 0) {
          // SCUTTLER: 6-legged articulated crab automaton with rusted carapace
          const scurry = Math.sin(phase) * 4;
          ctx.strokeStyle = '#94a3b8';
          ctx.lineWidth = 2.5;
          [-1, 1].forEach(side => {
            for (let leg = -1; leg <= 1; leg++) {
              ctx.beginPath();
              ctx.moveTo(side * 8, leg * 5);
              ctx.lineTo(side * 17, leg * 7 + scurry * side * leg);
              ctx.lineTo(side * 22, leg * 10 + 4);
              ctx.stroke();
            }
          });
          const shellGrad = ctx.createRadialGradient(-3, -4, 2, 0, 0, 15);
          shellGrad.addColorStop(0, '#64748b');
          shellGrad.addColorStop(1, '#1e293b');
          ctx.fillStyle = shellGrad;
          ctx.beginPath();
          ctx.ellipse(0, 0, 14, 11, 0, 0, Math.PI * 2);
          ctx.fill();
          ctx.strokeStyle = '#cbd5e1';
          ctx.lineWidth = 1.2;
          ctx.stroke();
          // Tri-optic sensor cluster
          ctx.fillStyle = '#f59e0b';
          ctx.beginPath();
          ctx.arc(-4, 3, 2.2, 0, Math.PI * 2);
          ctx.arc(4, 3, 2.2, 0, Math.PI * 2);
          ctx.arc(0, 5, 3, 0, Math.PI * 2);
          ctx.fill();
        } else if (row === 1) {
          // SURVEY DRONE: Twin-turbine gyroscope sphere with cyan telemetry ring
          const hover = Math.sin(phase) * 3;
          ctx.translate(0, hover);
          // Outer rotor ring
          ctx.strokeStyle = '#38bdf8';
          ctx.lineWidth = 2;
          ctx.beginPath();
          ctx.ellipse(0, 0, 21, 9, phase * 0.25, 0, Math.PI * 2);
          ctx.stroke();
          // Spherical chassis
          const droneGrad = ctx.createRadialGradient(-4, -5, 2, 0, 0, 15);
          droneGrad.addColorStop(0, '#475569');
          droneGrad.addColorStop(1, '#0f172a');
          ctx.fillStyle = droneGrad;
          ctx.beginPath();
          ctx.arc(0, 0, 14, 0, Math.PI * 2);
          ctx.fill();
          // Aperture lens
          ctx.fillStyle = '#0284c7';
          ctx.beginPath();
          ctx.arc(0, 2, 6, 0, Math.PI * 2);
          ctx.fill();
          ctx.fillStyle = '#7dd3fc';
          ctx.beginPath();
          ctx.arc(1.5, 0.5, 2.2, 0, Math.PI * 2);
          ctx.fill();
        } else if (row === 2) {
          // MAINTENANCE GUARDIAN: Heavy bipedal security frame with shoulder pauldrons
          const march = Math.sin(phase) * 2.5;
          // Piston legs
          ctx.fillStyle = '#334155';
          ctx.fillRect(-11, 8 + march, 7, 12);
          ctx.fillRect(4, 8 - march, 7, 12);
          // Armored torso hull
          ctx.fillStyle = '#475569';
          ctx.beginPath();
          ctx.roundRect(-18, -18, 36, 28, 6);
          ctx.fill();
          ctx.strokeStyle = '#94a3b8';
          ctx.lineWidth = 1.5;
          ctx.stroke();
          // Hazard stripes
          ctx.fillStyle = '#d97706';
          ctx.fillRect(-14, 2, 28, 4);
          // Recessed glowing visor slit
          ctx.fillStyle = '#0f172a';
          ctx.fillRect(-12, -11, 24, 6);
          ctx.fillStyle = '#ef4444';
          ctx.fillRect(-10 + Math.sin(phase) * 3, -9.5, 14, 3);
        } else if (row === 3) {
          // HEAVY RECLAIMER: Tracked industrial siege harvester with dual claws
          const rumble = (col % 2) * 1.2;
          ctx.translate(0, rumble);
          // Armored caterpillar treads
          ctx.fillStyle = '#1c1917';
          ctx.fillRect(-26, -16, 10, 38);
          ctx.fillRect(16, -16, 10, 38);
          // Chassis body
          const recGrad = ctx.createLinearGradient(0, -24, 0, 20);
          recGrad.addColorStop(0, '#573b2e');
          recGrad.addColorStop(1, '#291d18');
          ctx.fillStyle = recGrad;
          ctx.beginPath();
          ctx.roundRect(-20, -22, 40, 40, 7);
          ctx.fill();
          ctx.strokeStyle = '#ea580c';
          ctx.lineWidth = 2;
          ctx.stroke();
          // Furnace core eye
          ctx.fillStyle = '#fb923c';
          ctx.beginPath();
          ctx.arc(0, -4, 8, 0, Math.PI * 2);
          ctx.fill();
          ctx.fillStyle = '#fef08a';
          ctx.beginPath();
          ctx.arc(0, -4, 3.5, 0, Math.PI * 2);
          ctx.fill();
        } else {
          // HARMLESS CONDUIT SWEEPER: Cute rounded teal maintenance dome bot
          ctx.fillStyle = '#115e59';
          ctx.beginPath();
          ctx.arc(0, 2, 14, 0, Math.PI * 2);
          ctx.fill();
          ctx.strokeStyle = '#2dd4bf';
          ctx.lineWidth = 1.5;
          ctx.stroke();
          // Little antenna
          ctx.beginPath();
          ctx.moveTo(0, -12);
          ctx.lineTo(0, -19);
          ctx.stroke();
          ctx.fillStyle = '#5eead4';
          ctx.beginPath();
          ctx.arc(0, -20, 2.5, 0, Math.PI * 2);
          ctx.fill();
          // Friendly dual pixel eyes
          ctx.fillStyle = '#99f6e4';
          ctx.fillRect(-6, -1, 4, 4);
          ctx.fillRect(2, -1, 4, 4);
        }

        ctx.restore();
      }
    }
    this.robotSheet = c;
  }

  // 4. Build Detailed 3/4 Perspective Furniture Spritesheet
  buildFurnitureSpritesheet() {
    this.furnitureSprites = {};
    FURNITURE_CATALOG.forEach((furn) => {
      const pw = furn.w * 40;
      const ph = furn.h * 40 + 20; // Extra top headroom for 3/4 depth
      const c = document.createElement('canvas');
      c.width = pw;
      c.height = ph;
      const ctx = c.getContext('2d');
      ctx.translate(0, 16);

      // Base drop shadow
      if (!furn.walkable) {
        ctx.fillStyle = 'rgba(0, 0, 0, 0.38)';
        ctx.beginPath();
        ctx.roundRect(4, 6, pw - 6, furn.h * 40 - 4, 6);
        ctx.fill();
      }

      if (furn.id === 'cozy_bed') {
        // Wooden frame & headboard
        ctx.fillStyle = '#5c341d';
        ctx.beginPath();
        ctx.roundRect(2, -8, pw - 4, 44, 6);
        ctx.fill();
        // Cream sheet & fluffy pillow
        ctx.fillStyle = '#fef3c7';
        ctx.beginPath();
        ctx.roundRect(6, -3, 24, 34, 4);
        ctx.fill();
        // Patchwork crimson & amber quilt
        ctx.fillStyle = '#be123c';
        ctx.beginPath();
        ctx.roundRect(24, -3, pw - 30, 34, 5);
        ctx.fill();
        ctx.fillStyle = '#f59e0b';
        ctx.fillRect(32, 2, 14, 12);
        ctx.fillRect(50, 15, 14, 12);
        ctx.fillStyle = '#fda4af';
        ctx.fillRect(50, 2, 14, 12);
        ctx.fillRect(32, 15, 14, 12);
      } else if (furn.id === 'woven_rug') {
        // Braided oval crimson & cream rug with tassels
        ctx.fillStyle = '#881337';
        ctx.beginPath();
        ctx.roundRect(4, 4, pw - 8, furn.h * 40 - 8, 12);
        ctx.fill();
        ctx.strokeStyle = '#fda4af';
        ctx.lineWidth = 2.5;
        ctx.strokeRect(10, 10, pw - 20, furn.h * 40 - 20);
        ctx.strokeStyle = '#fde047';
        ctx.lineWidth = 1.5;
        ctx.strokeRect(18, 18, pw - 36, furn.h * 40 - 36);
      } else if (furn.id === 'amber_lamp') {
        // Brass base + glowing glass vacuum bulb
        ctx.fillStyle = '#78350f';
        ctx.beginPath();
        ctx.ellipse(20, 26, 11, 6, 0, 0, Math.PI * 2);
        ctx.fill();
        const lampGrad = ctx.createRadialGradient(20, 12, 2, 20, 12, 13);
        lampGrad.addColorStop(0, '#fef9c3');
        lampGrad.addColorStop(0.6, '#f59e0b');
        lampGrad.addColorStop(1, '#b45309');
        ctx.fillStyle = lampGrad;
        ctx.beginPath();
        ctx.arc(20, 12, 11, 0, Math.PI * 2);
        ctx.fill();
      } else if (furn.id === 'radio_console') {
        // Vintage steel transceiver with glowing cyan dial & whip antenna
        ctx.fillStyle = '#1e293b';
        ctx.beginPath();
        ctx.roundRect(4, 2, 32, 30, 5);
        ctx.fill();
        ctx.strokeStyle = '#64748b';
        ctx.strokeRect(4, 2, 32, 30);
        ctx.fillStyle = '#38bdf8';
        ctx.fillRect(8, 7, 15, 8);
        ctx.fillStyle = '#f59e0b';
        ctx.beginPath();
        ctx.arc(29, 11, 3, 0, Math.PI * 2);
        ctx.fill();
        // Speaker grille lines
        ctx.fillStyle = '#0f172a';
        for (let y = 19; y <= 27; y += 3) ctx.fillRect(8, y, 24, 1.5);
      } else {
        // Rich stylized 3/4 furniture sprite for remaining items
        ctx.fillStyle = furn.color;
        ctx.beginPath();
        ctx.roundRect(3, 0, pw - 6, furn.h * 40 - 4, 6);
        ctx.fill();
        ctx.fillStyle = furn.accent;
        ctx.beginPath();
        ctx.roundRect(6, 3, pw - 12, Math.max(8, furn.h * 14), 4);
        ctx.fill();
        ctx.strokeStyle = 'rgba(255,255,255,0.22)';
        ctx.lineWidth = 1.5;
        ctx.strokeRect(3, 0, pw - 6, furn.h * 40 - 4);
      }

      this.furnitureSprites[furn.id] = c;
    });
  }

  // 5. Build Props & Interactive Station Spritesheet (Salvage Crates, Planters, Workbench, Stove)
  buildPropsSpritesheet() {
    const c = document.createElement('canvas');
    c.width = 256;
    c.height = 64;
    const ctx = c.getContext('2d');

    // Cell 0 (0..64): Standard Salvage Crate
    ctx.fillStyle = '#713f12';
    ctx.beginPath();
    ctx.roundRect(10, 14, 44, 36, 5);
    ctx.fill();
    ctx.strokeStyle = '#facc15';
    ctx.lineWidth = 2;
    ctx.strokeRect(10, 14, 44, 36);
    ctx.fillStyle = '#422006';
    ctx.fillRect(14, 28, 36, 4);

    // Cell 1 (64..128): Rare High-Priority Machine Cache
    ctx.save();
    ctx.translate(64, 0);
    ctx.fillStyle = '#0f172a';
    ctx.beginPath();
    ctx.roundRect(8, 12, 48, 38, 6);
    ctx.fill();
    ctx.strokeStyle = '#38bdf8';
    ctx.lineWidth = 2.5;
    ctx.strokeRect(8, 12, 48, 38);
    ctx.fillStyle = '#22d3ee';
    ctx.fillRect(18, 26, 28, 6);
    ctx.restore();

    // Cell 2 (128..192): Looted Open Container
    ctx.save();
    ctx.translate(128, 0);
    ctx.fillStyle = '#1e293b';
    ctx.beginPath();
    ctx.roundRect(10, 16, 44, 34, 4);
    ctx.fill();
    ctx.strokeStyle = '#475569';
    ctx.strokeRect(10, 16, 44, 34);
    ctx.restore();

    this.propSheet = c;
  }
}

const spriteAtlas = new SpriteAtlasEngine();

// ============================================================================
// 9B. SPRITE-DRIVEN 2.5D / 3/4 PERSPECTIVE RENDER HELPERS
// ============================================================================
function drawYunaCharacter(ctx, x, y, facing, animTime, isMoving, isCrouching, weapon, isShelter, ticActive, hitFlash) {
  spriteAtlas.init();
  ctx.save();
  ctx.translate(x, y);
  ctx.imageSmoothingEnabled = false;

  // Determine 4-way directional row from facing angle
  // Row 0: Down, Row 1: Up, Row 2: Left, Row 3: Right
  let dirRow = 0;
  const deg = ((facing * 180) / Math.PI + 360) % 360;
  if (deg >= 45 && deg < 135) dirRow = 0;       // Down
  else if (deg >= 135 && deg < 225) dirRow = 2; // Left
  else if (deg >= 225 && deg < 315) dirRow = 1; // Up
  else dirRow = 3;                              // Right

  // Check if sliced Master Pixel-Art Sheet sprites are loaded & active
  const ms = spriteAtlas.masterSprites;
  if (spriteAtlas.useMasterSheet && ms && ms.yuna_down_idle1) {
    let chosenSprite = ms.yuna_down_idle1;
    let flipX = false;

    if (isCrouching) {
      chosenSprite = weapon === 'rifle' ? ms.yuna_crouch_rifle : ms.yuna_crouch_pistol;
      if (dirRow === 2) flipX = true;
    } else if (dirRow === 1) {
      chosenSprite = isMoving && (Math.floor(animTime * 8) % 2 === 0) ? ms.yuna_up_pack : ms.yuna_up_idle;
    } else if (dirRow === 2) {
      chosenSprite = ms.yuna_left_walk;
    } else if (dirRow === 3) {
      const walkFrames = [ms.yuna_right_walk1, ms.yuna_right_walk2, ms.yuna_right_walk3];
      chosenSprite = !isShelter && !isMoving
        ? ms.yuna_right_pistol
        : isMoving
        ? walkFrames[Math.floor(animTime * 9) % walkFrames.length]
        : ms.yuna_right_walk1;
    } else {
      chosenSprite = Math.floor(animTime * 3) % 2 === 0 ? ms.yuna_down_idle1 : ms.yuna_down_idle2;
    }

    if (chosenSprite) {
      ctx.save();
      if (flipX) ctx.scale(-1, 1);
      if (hitFlash > 0) ctx.filter = 'brightness(2.2)';
      const bob = isMoving ? Math.abs(Math.sin(animTime * 12)) * -2.5 : 0;
      ctx.drawImage(chosenSprite, -26, -42 + bob, 52, 62);
      ctx.restore();
      ctx.restore();
      return;
    }
  }

  // Determine animation frame column (0..7) on procedural pixel-art atlas
  let frameCol = 0;
  if (isCrouching) {
    frameCol = 7;
  } else if (ticActive) {
    frameCol = 6;
  } else if (isMoving) {
    frameCol = 2 + (Math.floor(animTime * 9) % 4);
  } else {
    frameCol = Math.floor(animTime * 2) % 2;
  }

  if (spriteAtlas.yunaSheet) {
    if (hitFlash > 0) ctx.filter = 'brightness(2.2)';
    ctx.drawImage(
      spriteAtlas.yunaSheet,
      frameCol * 64,
      dirRow * 64,
      64,
      64,
      -32,
      -38,
      64,
      64
    );
    ctx.filter = 'none';
  }

  // Draw Aimed Weapon Sprite Overlay when outside the shelter
  if (!isShelter) {
    const bob = isMoving ? Math.sin(animTime * 14) * 2 : 0;
    ctx.save();
    ctx.translate(0, -4 + bob);
    ctx.rotate(facing);
    if (weapon === 'pistol') {
      ctx.fillStyle = '#334155';
      ctx.fillRect(6, -2, 8, 5);
      ctx.fillStyle = '#cbd5e1';
      ctx.fillRect(8, -3.5, 13, 4);
      ctx.fillStyle = '#38bdf8';
      ctx.fillRect(15, -3, 4, 1.5);
    } else {
      ctx.fillStyle = '#78350f';
      ctx.fillRect(3, -3, 12, 5.5);
      ctx.fillStyle = '#64748b';
      ctx.fillRect(12, -2.8, 19, 4.2);
      ctx.fillStyle = '#22d3ee';
      ctx.fillRect(16, -2.2, 8, 2);
      ctx.fillStyle = '#f97316';
      ctx.fillRect(28, -2.5, 3, 3.5);
    }
    ctx.restore();
  }

  ctx.restore();
}

function drawRobotEnemy(ctx, e, animTime) {
  spriteAtlas.init();
  ctx.save();
  ctx.translate(e.x, e.y);
  ctx.imageSmoothingEnabled = false;

  // Soft ground shadow
  ctx.fillStyle = 'rgba(0,0,0,0.45)';
  ctx.beginPath();
  ctx.ellipse(0, e.radius * 0.78, e.radius * 0.92, e.radius * 0.45, 0, 0, Math.PI * 2);
  ctx.fill();

  if (e.telegraphTimer > 0) {
    ctx.strokeStyle = 'rgba(239, 68, 68, 0.78)';
    ctx.lineWidth = 3;
    ctx.beginPath();
    ctx.arc(0, 0, e.radius + 15, 0, Math.PI * 2);
    ctx.stroke();
  }

  // Use sliced Master Pixel-Art Sheet robot sprites when available
  const ms = spriteAtlas.masterSprites;
  const masterKeyMap = {
    scuttler: 'robot_scuttler',
    drone: 'robot_drone',
    guardian: 'robot_guardian',
    reclaimer: 'robot_reclaimer',
    neutral_sweeper: 'robot_sweeper'
  };
  const mSpr = spriteAtlas.useMasterSheet && ms ? ms[masterKeyMap[e.type]] : null;

  if (mSpr) {
    const drawSize = e.type === 'reclaimer' ? 88 : e.type === 'guardian' ? 68 : 52;
    const hoverY = Math.sin(animTime * 7 + e.x) * (e.type === 'drone' ? 4 : 1.5);
    if (e.hitFlash > 0) ctx.filter = 'brightness(2.5)';
    ctx.drawImage(mSpr, -drawSize / 2, -drawSize * 0.62 + hoverY, drawSize, drawSize);
    ctx.filter = 'none';
  } else {
    const rowMap = {
      scuttler: 0,
      drone: 1,
      guardian: 2,
      reclaimer: 3,
      neutral_sweeper: 4
    };
    const row = rowMap[e.type] ?? 0;
    const col = Math.floor(animTime * 8 + e.x * 0.1) % 4;

    if (spriteAtlas.robotSheet) {
      const scale = e.type === 'reclaimer' ? 1.28 : e.type === 'guardian' ? 1.12 : 1.0;
      if (e.hitFlash > 0) ctx.filter = 'brightness(2.5)';
      ctx.drawImage(
        spriteAtlas.robotSheet,
        col * 64,
        row * 64,
        64,
        64,
        -32 * scale,
        -34 * scale,
        64 * scale,
        64 * scale
      );
      ctx.filter = 'none';
    }
  }

  // Health Bar if damaged or alerted
  if (!e.neutral && (e.hp < e.maxHp || e.state === 'chase')) {
    const bw = 36;
    ctx.fillStyle = 'rgba(0,0,0,0.75)';
    ctx.fillRect(-bw / 2, -e.radius - 18, bw, 5);
    ctx.fillStyle = '#ef4444';
    ctx.fillRect(-bw / 2, -e.radius - 18, bw * Math.max(0, e.hp / e.maxHp), 5);
  }

  ctx.restore();
}

// ============================================================================
// 10. MAIN APPLICATION COMPONENT
// ============================================================================
export default function App() {
  const [gameState, setGameState] = useState(() => createInitialState(402918));
  const [activeModal, setActiveModal] = useState(null); // 'inventory' | 'crafting' | 'cooking' | 'decorate' | 'map' | 'upgrades' | 'saves' | 'ending' | 'journal' | 'radio'
  const [placingFurniture, setPlacingFurniture] = useState(null); // { id, rot }
  const [openContainer, setOpenContainer] = useState(null);
  const [speechBubble, setSpeechBubble] = useState({ text: "Okay... morning check. Let's see how the shelter's holding up.", timer: 5 });
  const [notification, setNotification] = useState(null);
  const [saveSlots, setSaveSlots] = useState([]);
  const [muted, setMuted] = useState(false);

  // Gemini AI Interactive States
  const [aiLoading, setAiLoading] = useState(false);
  const [ttsLoadingId, setTtsLoadingId] = useState(null);
  const [itemAnalysis, setItemAnalysis] = useState(null);
  const [analyzingItemId, setAnalyzingItemId] = useState(null);
  const [isSmallScreen, setIsSmallScreen] = useState(false);
  const [sprintToggle, setSprintToggle] = useState(false);
  const [joyVisual, setJoyVisual] = useState({ active: false, dx: 0, dy: 0 });
  const [aimJoyVisual, setAimJoyVisual] = useState({ active: false, dx: 0, dy: 0 });

  const canvasRef = useRef(null);
  const keysRef = useRef({});
  const touchMoveRef = useRef({ dx: 0, dy: 0, active: false });
  const touchAimRef = useRef({ angle: 0, firing: false, active: false });
  const mouseRef = useRef({ x: 0, y: 0, worldX: 0, worldY: 0, down: false });
  const runtimeRef = useRef({
    state: gameState,
    regionData: null,
    bullets: [],
    enemyBullets: [],
    particles: [],
    decoys: [],
    floatTexts: [],
    camera: { x: 420, y: 440, zoom: 1.25 },
    animTime: 0,
    lastStepTime: 0,
    lastTicTime: 0,
    ticVisualTimer: 0,
    fireCooldown: 0,
    reloadTimer: 0,
    hitInvuln: 0,
    screenShake: 0,
    promptText: null
  });

  // Sync React state to mutable runtime ref
  useEffect(() => {
    runtimeRef.current.state = gameState;
  }, [gameState]);

  useEffect(() => {
    const checkViewport = () => {
      const hasTouch = 'ontouchstart' in window || navigator.maxTouchPoints > 0;
      const narrow = window.innerWidth < 1024;
      setIsSmallScreen(narrow || (hasTouch && window.innerWidth <= 1280));
    };
    checkViewport();
    window.addEventListener('resize', checkViewport);
    return () => window.removeEventListener('resize', checkViewport);
  }, []);

  const showMobileControls = useMemo(() => {
    const mode = gameState.settings?.mobileControls || 'auto';
    if (mode === 'on') return true;
    if (mode === 'off') return false;
    return isSmallScreen;
  }, [gameState.settings?.mobileControls, isSmallScreen]);

  const showToast = useCallback((msg) => {
    setNotification(msg);
    setTimeout(() => {
      setNotification(prev => (prev === msg ? null : prev));
    }, 3200);
  }, []);

  const triggerSpeech = useCallback((text, duration = 4.2) => {
    setSpeechBubble({ text, timer: duration });
  }, []);

  // Refresh IndexedDB save slot list
  const refreshSlots = useCallback(async () => {
    const slots = await listSaveSlots();
    setSaveSlots(slots);
  }, []);

  useEffect(() => {
    refreshSlots();
    // Auto-load slot 1 if available on startup
    loadFromSlot(1).then((saved) => {
      if (saved && saved.player && saved.inventory) {
        setGameState(saved);
        runtimeRef.current.state = saved;
        showToast('Loaded your saved shelter from Slot 1.');
      }
    });
  }, [refreshSlots, showToast]);

  // Ambient music & soundscape timer
  useEffect(() => {
    const id = setInterval(() => {
      const isShelter = runtimeRef.current.state.region === 'shelter';
      sound.playAmbientNote(isShelter);
    }, 3200);
    return () => clearInterval(id);
  }, []);

  // ============================================================================
  // INVENTORY & ITEM HELPERS
  // ============================================================================
  const maxBackpackSlots = useMemo(() => {
    return 14 + (gameState.equipmentUpgrades.backpackLevel - 1) * 5;
  }, [gameState.equipmentUpgrades.backpackLevel]);

  const maxStorageSlots = useMemo(() => {
    const lockerBonus = gameState.furniture.filter(f => f.id === 'storage_locker').length * 6;
    return 24 + (gameState.facilities.storageLevel - 1) * 10 + lockerBonus;
  }, [gameState.facilities.storageLevel, gameState.furniture]);

  const getItemCount = useCallback((inv, itemId) => {
    return inv.reduce((sum, slot) => (slot.id === itemId ? sum + slot.count : sum), 0);
  }, []);

  const hasMaterials = useCallback((costObj, includeStorage = true) => {
    const st = runtimeRef.current.state;
    for (const [itemId, needed] of Object.entries(costObj)) {
      const inPack = getItemCount(st.inventory, itemId);
      const inBox = includeStorage ? getItemCount(st.storage, itemId) : 0;
      if (inPack + inBox < needed) return false;
    }
    return true;
  }, [getItemCount]);

  const addItemsToList = (list, itemId, count, maxSlots) => {
    const def = ITEMS[itemId];
    if (!def) return { list, added: 0 };
    const next = list.map(i => ({ ...i }));
    let rem = count;

    for (const slot of next) {
      if (slot.id === itemId && slot.count < def.stack) {
        const take = Math.min(rem, def.stack - slot.count);
        slot.count += take;
        rem -= take;
        if (rem <= 0) break;
      }
    }
    while (rem > 0 && next.length < maxSlots) {
      const take = Math.min(rem, def.stack);
      next.push({ id: itemId, count: take });
      rem -= take;
    }
    return { list: next, added: count - rem };
  };

  const removeItemsFromLists = (inv, storage, costObj, useStorage = true) => {
    let nextInv = inv.map(i => ({ ...i }));
    let nextStorage = storage.map(i => ({ ...i }));

    for (const [itemId, needed] of Object.entries(costObj)) {
      let rem = needed;
      for (let i = nextInv.length - 1; i >= 0 && rem > 0; i--) {
        if (nextInv[i].id === itemId) {
          const take = Math.min(rem, nextInv[i].count);
          nextInv[i].count -= take;
          rem -= take;
          if (nextInv[i].count <= 0) nextInv.splice(i, 1);
        }
      }
      if (useStorage && rem > 0) {
        for (let i = nextStorage.length - 1; i >= 0 && rem > 0; i--) {
          if (nextStorage[i].id === itemId) {
            const take = Math.min(rem, nextStorage[i].count);
            nextStorage[i].count -= take;
            rem -= take;
            if (nextStorage[i].count <= 0) nextStorage.splice(i, 1);
          }
        }
      }
    }
    return { nextInv, nextStorage };
  };

  // Use a consumable item (food, water, med-patch, or decoy)
  const useItem = useCallback((itemId, fromStorage = false) => {
    const def = ITEMS[itemId];
    if (!def) return;

    if (itemId === 'decoy_beacon') {
      if (runtimeRef.current.state.region === 'shelter') {
        showToast("Yuna doesn't need to deploy a decoy inside her safe shelter.");
        return;
      }
      setGameState(prev => {
        const { nextInv, nextStorage } = removeItemsFromLists(prev.inventory, prev.storage, { decoy_beacon: 1 }, false);
        runtimeRef.current.decoys.push({
          x: prev.player.x + Math.cos(prev.player.facing) * 45,
          y: prev.player.y + Math.sin(prev.player.facing) * 45,
          timer: 9.0
        });
        sound.sfxReload();
        triggerSpeech("Go chase that noise instead, please...", 3);
        return { ...prev, inventory: nextInv, storage: nextStorage };
      });
      return;
    }

    if (!def.food && !def.water && !def.health) return;

    setGameState(prev => {
      const { nextInv, nextStorage } = removeItemsFromLists(
        prev.inventory,
        prev.storage,
        { [itemId]: 1 },
        fromStorage
      );
      sound.sfxCook();
      if (itemId === 'warm_stew' || itemId === 'sweet_tea') {
        triggerSpeech(YUNA_QUOTES.cookSuccess[Math.floor(Math.random() * YUNA_QUOTES.cookSuccess.length)], 3.5);
      }
      return {
        ...prev,
        inventory: nextInv,
        storage: nextStorage,
        player: {
          ...prev.player,
          hp: Math.min(prev.player.maxHp, prev.player.hp + (def.health || 0)),
          stamina: Math.min(prev.player.maxStamina, prev.player.stamina + (def.stamina || 15)),
          food: Math.min(100, prev.player.food + (def.food || 0)),
          water: Math.min(100, prev.player.water + (def.water || 0))
        }
      };
    });
  }, [showToast, triggerSpeech]);

  const handleCraft = (recipe) => {
    if (!hasMaterials(recipe.cost, true)) {
      showToast('Missing required components.');
      return;
    }
    setGameState(prev => {
      const { nextInv, nextStorage } = removeItemsFromLists(prev.inventory, prev.storage, recipe.cost, true);
      const { list: updatedInv, added } = addItemsToList(nextInv, recipe.output.id, recipe.output.count, maxBackpackSlots);
      let finalStorage = nextStorage;
      if (added < recipe.output.count) {
        const res = addItemsToList(nextStorage, recipe.output.id, recipe.output.count - added, maxStorageSlots);
        finalStorage = res.list;
      }
      sound.sfxCraft();
      triggerSpeech(YUNA_QUOTES.craftSuccess[Math.floor(Math.random() * YUNA_QUOTES.craftSuccess.length)], 3.5);
      showToast(`Crafted ${ITEMS[recipe.output.id].name} x${recipe.output.count}`);
      return { ...prev, inventory: updatedInv, storage: finalStorage };
    });
  };

  // ============================================================================
  // REGION TRANSITIONS, SLEEPING & GARDENING
  // ============================================================================
  const travelToRegion = useCallback((targetRegion) => {
    setOpenContainer(null);
    setActiveModal(null);
    setPlacingFurniture(null);

    setGameState(prev => {
      const isEnteringShelter = targetRegion === 'shelter';
      const nextDiscovered = prev.discoveredRegions.includes(targetRegion)
        ? prev.discoveredRegions
        : [...prev.discoveredRegions, targetRegion];

      if (!isEnteringShelter) {
        const persisted = prev.persistedRegions[targetRegion] || {};
        runtimeRef.current.regionData = generateRegionMap(targetRegion, prev.worldSeed, prev.day, persisted);
        triggerSpeech("Okay... check the scanner, stay out of sight.", 4);
      } else {
        runtimeRef.current.regionData = null;
        triggerSpeech("Home... *soft sigh* Locked the outer hatch.", 4);
      }

      runtimeRef.current.bullets = [];
      runtimeRef.current.enemyBullets = [];
      runtimeRef.current.decoys = [];

      const nextState = {
        ...prev,
        region: targetRegion,
        discoveredRegions: nextDiscovered,
        player: {
          ...prev.player,
          x: isEnteringShelter ? 420 : 165,
          y: isEnteringShelter ? 520 : 650
        }
      };

      // Autosave on region transition
      saveToSlot(1, nextState);
      return nextState;
    });
  }, [triggerSpeech]);

  const sleepInBed = useCallback(() => {
    setGameState(prev => {
      const nextDay = prev.day + 1;
      const waterProd = prev.facilities.waterPurifier * 14 + (prev.mainRestore.waterRestored ? 25 : 0);
      const powerProd = prev.facilities.powerSupply * 12 + (prev.mainRestore.powerRestored ? 30 : 0);

      // Advance garden plots
      const nextPlots = prev.gardenPlots.map(plot => {
        if (!plot.crop) return plot;
        const growthBoost = prev.mainRestore.sunlightRestored ? 2 : 1;
        const nextStage = plot.watered ? Math.min(3, plot.stage + growthBoost) : plot.stage;
        return { ...plot, stage: nextStage, watered: false };
      });

      const nextState = {
        ...prev,
        day: nextDay,
        timeOfDay: 7.5,
        shelterWater: Math.min(100, prev.shelterWater + waterProd - 8),
        shelterPower: Math.min(100, prev.shelterPower + powerProd - 10),
        gardenPlots: nextPlots,
        player: {
          ...prev.player,
          hp: prev.player.maxHp,
          stamina: prev.player.maxStamina,
          food: Math.max(25, prev.player.food - 14),
          water: Math.max(25, prev.player.water - 16)
        }
      };
      saveToSlot(1, nextState);
      sound.sfxCraft();
      triggerSpeech(`Day ${nextDay}... Slept warmly. Let's check the sun-court planters.`, 4.5);
      showToast(`Slept until dawn (Day ${nextDay}). Progress autosaved.`);
      return nextState;
    });
  }, [showToast, triggerSpeech]);

  const interactGardenPlot = useCallback((plotIndex) => {
    setGameState(prev => {
      const plot = prev.gardenPlots[plotIndex];
      if (!plot) return prev;

      // Harvest if stage 3
      if (plot.crop && plot.stage >= 3) {
        const yieldCount = prev.mainRestore.sunlightRestored ? 4 : 3;
        const { list: nextInv } = addItemsToList(prev.inventory, plot.crop, yieldCount, maxBackpackSlots);
        const { list: withSeeds } = addItemsToList(nextInv, 'seeds_pack', 1, maxBackpackSlots);
        const nextPlots = prev.gardenPlots.map((p, i) =>
          i === plotIndex ? { ...p, crop: null, stage: 0, watered: false } : p
        );
        sound.sfxLoot();
        triggerSpeech(`Harvested fresh ${ITEMS[plot.crop].name}!`, 3.5);
        return { ...prev, inventory: withSeeds, gardenPlots: nextPlots };
      }

      // Water if planted and unwatered
      if (plot.crop && !plot.watered) {
        const nextPlots = prev.gardenPlots.map((p, i) =>
          i === plotIndex ? { ...p, watered: true } : p
        );
        sound.sfxCook();
        triggerSpeech("There you go, little sprouts. Drink up.", 3);
        return {
          ...prev,
          shelterWater: Math.max(0, prev.shelterWater - 4),
          gardenPlots: nextPlots
        };
      }

      // Plant seeds if empty
      if (!plot.crop) {
        if (!hasMaterials({ seeds_pack: 1 }, true)) {
          showToast('Need a Viable Seed Packet to plant here.');
          return prev;
        }
        const { nextInv, nextStorage } = removeItemsFromLists(prev.inventory, prev.storage, { seeds_pack: 1 }, true);
        const cropType = plotIndex % 2 === 0 ? 'root_tuber' : 'sun_berry';
        const nextPlots = prev.gardenPlots.map((p, i) =>
          i === plotIndex ? { ...p, crop: cropType, stage: 1, watered: true } : p
        );
        sound.sfxLoot();
        triggerSpeech(`Planted ${ITEMS[cropType].name} seeds in the sun-court.`, 3.5);
        return { ...prev, inventory: nextInv, storage: nextStorage, gardenPlots: nextPlots };
      }

      return prev;
    });
  }, [hasMaterials, maxBackpackSlots, showToast, triggerSpeech]);

  // ============================================================================
  // KEYBOARD & MOUSE INPUT LISTENERS
  // ============================================================================
  useEffect(() => {
    const onKeyDown = (e) => {
      const k = e.key.toLowerCase();
      keysRef.current[k] = true;

      if (k === 'escape') {
        setActiveModal(null);
        setOpenContainer(null);
        setPlacingFurniture(null);
      } else if (k === 'tab') {
        e.preventDefault();
        setActiveModal(prev => (prev === 'inventory' ? null : 'inventory'));
      } else if (k === 'm') {
        setActiveModal(prev => (prev === 'map' ? null : 'map'));
      } else if (k === '1') {
        setGameState(prev => ({ ...prev, player: { ...prev.player, activeWeapon: 'pistol' } }));
      } else if (k === '2') {
        setGameState(prev => ({ ...prev, player: { ...prev.player, activeWeapon: 'rifle' } }));
      } else if (k === 'c') {
        setGameState(prev => ({
          ...prev,
          player: { ...prev.player, crouching: !prev.player.crouching }
        }));
      } else if (k === 'r') {
        // Reload active weapon
        const rt = runtimeRef.current;
        if (rt.reloadTimer <= 0 && rt.state.region !== 'shelter') {
          const isPistol = rt.state.player.activeWeapon === 'pistol';
          const ammoId = isPistol ? 'pistol_ammo' : 'rifle_ammo';
          const mag = isPistol ? rt.state.player.pistolMag : rt.state.player.rifleMag;
          const maxMag = isPistol ? rt.state.player.pistolMaxMag : rt.state.player.rifleMaxMag;
          if (mag < maxMag && getItemCount(rt.state.inventory, ammoId) > 0) {
            rt.reloadTimer = isPistol ? 0.9 : 1.5;
            sound.sfxReload();
          }
        }
      } else if (k === 'e') {
        handleContextInteract();
      }
    };

    const onKeyUp = (e) => {
      keysRef.current[e.key.toLowerCase()] = false;
    };

    window.addEventListener('keydown', onKeyDown);
    window.addEventListener('keyup', onKeyUp);
    return () => {
      window.removeEventListener('keydown', onKeyDown);
      window.removeEventListener('keyup', onKeyUp);
    };
  });

  // Contextual Interaction Handler ('E' Key or HUD button)
  const handleContextInteract = () => {
    const rt = runtimeRef.current;
    const st = rt.state;
    const px = st.player.x;
    const py = st.player.y;

    if (st.region === 'shelter') {
      // Check shelter interactive stations
      if (Math.hypot(px - 240, py - 410) < 75) {
        setActiveModal('cooking');
        return;
      }
      if (Math.hypot(px - 610, py - 410) < 75) {
        setActiveModal('crafting');
        return;
      }
      if (Math.hypot(px - 530, py - 375) < 75) {
        setActiveModal('inventory');
        return;
      }
      if (Math.hypot(px - 630, py - 210) < 80) {
        setActiveModal('upgrades');
        return;
      }
      // Check Garden Plots in Upper Sun Court
      for (let i = 0; i < st.gardenPlots.length; i++) {
        const gp = st.gardenPlots[i];
        if (Math.hypot(px - gp.x, py - gp.y) < 52) {
          interactGardenPlot(i);
          return;
        }
      }
      // Check Bed for sleeping
      const bed = st.furniture.find(f => f.id === 'cozy_bed');
      if (bed) {
        const bx = 180 + bed.gx * 40 + 40;
        const by = 120 + bed.gy * 40 + 20;
        if (Math.hypot(px - bx, py - by) < 75) {
          sleepInBed();
          return;
        }
      }
      // Check Radio toggle
      const radio = st.furniture.find(f => f.id === 'radio_console');
      if (radio) {
        const rx = 180 + radio.gx * 40 + 20;
        const ry = 120 + radio.gy * 40 + 20;
        if (Math.hypot(px - rx, py - ry) < 68) {
          setActiveModal('radio');
          sound.sfxTic();
          return;
        }
      }
      // Check Reading Chair for Yuna's Journal
      const chair = st.furniture.find(f => f.id === 'book_nook');
      if (chair) {
        const cx = 180 + chair.gx * 40 + 20;
        const cy = 120 + chair.gy * 40 + 20;
        if (Math.hypot(px - cx, py - cy) < 68) {
          setActiveModal('journal');
          sound.sfxTic();
          return;
        }
      }
      // Check Exit Hatch to Wasteland
      if (Math.hypot(px - 420, py - 560) < 75) {
        setActiveModal('map');
        return;
      }
    } else if (rt.regionData) {
      // Check Exit back to Shelter
      const ez = rt.regionData.exitZone;
      if (Math.hypot(px - ez.x, py - ez.y) < ez.r + 28) {
        travelToRegion('shelter');
        return;
      }
      // Check Salvage Containers
      for (const c of rt.regionData.containers) {
        if (!c.looted && Math.hypot(px - c.x, py - c.y) < 62) {
          setOpenContainer(c);
          sound.sfxLoot();
          return;
        }
      }
      // Check Optional Discoveries
      for (const d of rt.regionData.discoveryNodes) {
        if (!st.discoveries.includes(d.id) && Math.hypot(px - d.x, py - d.y) < 68) {
          setGameState(prev => ({
            ...prev,
            discoveries: [...prev.discoveries, d.id]
          }));
          sound.sfxCraft();
          triggerSpeech(`Oh! Look at this... (${d.name})`, 4.5);
          showToast(`Discovery Unlocked: ${d.name}`);
          return;
        }
      }
    }
  };

  // ============================================================================
  // MAIN GAME ENGINE LOOP (60FPS CANVAS SIMULATION & RENDERING)
  // ============================================================================
  useEffect(() => {
    let frameId;
    let lastTime = performance.now();

    const loop = (now) => {
      const dt = Math.min(0.05, (now - lastTime) / 1000);
      lastTime = now;

      const rt = runtimeRef.current;
      const st = rt.state;
      rt.animTime += dt;

      // Update Speech Bubble Timer
      setSpeechBubble(prev => (prev && prev.timer > 0 ? { ...prev, timer: prev.timer - dt } : null));

      if (!activeModal && !openContainer) {
        updateSimulation(rt, st, dt);
      }

      renderScene(rt, st);
      frameId = requestAnimationFrame(loop);
    };

    frameId = requestAnimationFrame(loop);
    return () => cancelAnimationFrame(frameId);
  }, [activeModal, openContainer, placingFurniture]);

  // Core Simulation Update
  const updateSimulation = (rt, st, dt) => {
    const keys = keysRef.current;
    let dx = 0;
    let dy = 0;
    if (keys['w'] || keys['arrowup']) dy -= 1;
    if (keys['s'] || keys['arrowdown']) dy += 1;
    if (keys['a'] || keys['arrowleft']) dx -= 1;
    if (keys['d'] || keys['arrowright']) dx += 1;

    // Blend in Virtual Touch Joystick movement vector
    if (touchMoveRef.current.active) {
      dx += touchMoveRef.current.dx;
      dy += touchMoveRef.current.dy;
    }

    const isMoving = Math.hypot(dx, dy) > 0.08;
    if (isMoving) {
      const len = Math.hypot(dx, dy);
      if (len > 1) {
        dx /= len;
        dy /= len;
      }
    } else {
      dx = 0;
      dy = 0;
    }

    const sprinting = (keys['shift'] || sprintToggle) && isMoving && st.player.stamina > 5 && !st.player.crouching;
    const baseSpeed = st.player.crouching ? 95 : sprinting ? 215 : 150;

    let nextX = st.player.x + dx * baseSpeed * dt;
    let nextY = st.player.y + dy * baseSpeed * dt;

    // World bounds & obstacle collision
    if (st.region === 'shelter') {
      // Shelter Bounds: Upper Sun Court (y: 135..265) + Lower Living Space (y: 265..565), x: 195..645
      nextX = Math.max(205, Math.min(635, nextX));
      nextY = Math.max(145, Math.min(555, nextY));
    } else if (rt.regionData) {
      nextX = Math.max(40, Math.min(rt.regionData.width - 40, nextX));
      nextY = Math.max(40, Math.min(rt.regionData.height - 40, nextY));

      // Collide with machine structures
      for (const s of rt.regionData.structures) {
        if (
          nextX + 14 > s.x &&
          nextX - 14 < s.x + s.w &&
          nextY + 14 > s.y &&
          nextY - 14 < s.y + s.h
        ) {
          // Resolve axis separately
          if (st.player.x + 14 <= s.x || st.player.x - 14 >= s.x + s.w) nextX = st.player.x;
          if (st.player.y + 14 <= s.y || st.player.y - 14 >= s.y + s.h) nextY = st.player.y;
        }
      }
    }

    // Footstep Audio
    if (isMoving && rt.animTime - rt.lastStepTime > (sprinting ? 0.28 : 0.42)) {
      rt.lastStepTime = rt.animTime;
      sound.sfxStep(st.region === 'shelter');
    }

    // Yuna's Subtle Natural Vocal/Motor Tics & Quiet Thoughts (Non-punishing!)
    if (rt.animTime - rt.lastTicTime > 19) {
      rt.lastTicTime = rt.animTime + Math.random() * 12;
      rt.ticVisualTimer = 0.45;
      sound.sfxTic();
      if (Math.random() < 0.55) {
        const pool = st.region === 'shelter' ? YUNA_QUOTES.shelterIdle : YUNA_QUOTES.wastelandIdle;
        triggerSpeech(pool[Math.floor(Math.random() * pool.length)], 3.8);
      }
    }
    if (rt.ticVisualTimer > 0) rt.ticVisualTimer -= dt;
    if (rt.hitInvuln > 0) rt.hitInvuln -= dt;
    if (rt.screenShake > 0) rt.screenShake = Math.max(0, rt.screenShake - dt * 20);

    // Aim angle toward mouse cursor or mobile aim joystick / movement direction
    let facing = st.player.facing;
    if (touchAimRef.current.active) {
      facing = touchAimRef.current.angle;
    } else if (touchMoveRef.current.active && isMoving) {
      facing = Math.atan2(dy, dx);
    } else if (!showMobileControls || mouseRef.current.down) {
      facing = Math.atan2(
        mouseRef.current.worldY - nextY,
        mouseRef.current.worldX - nextX
      );
    }

    // Handle Reload Completion
    let pistolMag = st.player.pistolMag;
    let rifleMag = st.player.rifleMag;
    let nextInv = st.inventory;

    if (rt.reloadTimer > 0) {
      rt.reloadTimer -= dt;
      if (rt.reloadTimer <= 0) {
        const isPistol = st.player.activeWeapon === 'pistol';
        const ammoId = isPistol ? 'pistol_ammo' : 'rifle_ammo';
        const currentMag = isPistol ? pistolMag : rifleMag;
        const maxMag = isPistol
          ? st.player.pistolMaxMag + (st.equipmentUpgrades.pistolLevel - 1) * 3
          : st.player.rifleMaxMag + (st.equipmentUpgrades.rifleLevel - 1) * 2;
        const available = getItemCount(nextInv, ammoId);
        const toLoad = Math.min(maxMag - currentMag, available);
        if (toLoad > 0) {
          const res = removeItemsFromLists(nextInv, st.storage, { [ammoId]: toLoad }, false);
          nextInv = res.nextInv;
          if (isPistol) pistolMag += toLoad;
          else rifleMag += toLoad;
        }
      }
    }

    // Handle Firing Weapon in Wasteland
    if (rt.fireCooldown > 0) rt.fireCooldown -= dt;
    const isFiringInput = mouseRef.current.down || touchAimRef.current.firing;
    if (
      isFiringInput &&
      st.region !== 'shelter' &&
      rt.fireCooldown <= 0 &&
      rt.reloadTimer <= 0 &&
      !placingFurniture
    ) {
      const isPistol = st.player.activeWeapon === 'pistol';
      const hasRound = isPistol ? pistolMag > 0 : rifleMag > 0;
      if (hasRound) {
        if (isPistol) {
          pistolMag -= 1;
          rt.fireCooldown = 0.28;
          sound.sfxPistol();
        } else {
          rifleMag -= 1;
          rt.fireCooldown = 0.62;
          sound.sfxRifle();
        }
        const spread = (isPistol ? 0.05 : 0.02) / st.equipmentUpgrades.pistolLevel;
        const angle = facing + (Math.random() - 0.5) * spread;
        const dmg = isPistol
          ? 20 + (st.equipmentUpgrades.pistolLevel - 1) * 6
          : 52 + (st.equipmentUpgrades.rifleLevel - 1) * 14;

        rt.bullets.push({
          x: nextX + Math.cos(angle) * 20,
          y: nextY + Math.sin(angle) * 20,
          vx: Math.cos(angle) * (isPistol ? 640 : 860),
          vy: Math.sin(angle) * (isPistol ? 640 : 860),
          dmg,
          life: isPistol ? 0.65 : 1.1
        });
        if (!st.settings.reducedShake) rt.screenShake = isPistol ? 2.5 : 5.5;
      } else {
        // Auto-trigger reload if magazine empty
        const ammoId = isPistol ? 'pistol_ammo' : 'rifle_ammo';
        if (getItemCount(nextInv, ammoId) > 0) {
          rt.reloadTimer = isPistol ? 0.9 : 1.5;
          sound.sfxReload();
        }
        rt.fireCooldown = 0.35;
      }
    }

    // Update Player Projectiles
    if (rt.regionData) {
      for (let i = rt.bullets.length - 1; i >= 0; i--) {
        const b = rt.bullets[i];
        b.x += b.vx * dt;
        b.y += b.vy * dt;
        b.life -= dt;
        let hit = false;

        // Obstacle hit check
        for (const s of rt.regionData.structures) {
          if (b.x > s.x && b.x < s.x + s.w && b.y > s.y && b.y < s.y + s.h) {
            hit = true;
            break;
          }
        }

        // Enemy hit check
        if (!hit) {
          for (let j = rt.regionData.enemies.length - 1; j >= 0; j--) {
            const e = rt.regionData.enemies[j];
            if (Math.hypot(b.x - e.x, b.y - e.y) < e.radius + 6) {
              hit = true;
              e.hp -= b.dmg;
              e.hitFlash = 0.14;
              e.state = 'chase';
              sound.sfxHitRobot();

              if (st.settings.damageNumbers) {
                rt.floatTexts.push({
                  x: e.x,
                  y: e.y - 20,
                  text: `-${Math.round(b.dmg)}`,
                  color: '#facc15',
                  life: 0.75
                });
              }

              // Spawn hit sparks
              for (let p = 0; p < 5; p++) {
                rt.particles.push({
                  x: b.x,
                  y: b.y,
                  vx: (Math.random() - 0.5) * 160,
                  vy: (Math.random() - 0.5) * 160,
                  color: '#38bdf8',
                  life: 0.28
                });
              }

              if (e.hp <= 0) {
                sound.sfxRobotDestroy();
                // Drop salvage container on robot destruction
                const dropLoot = e.type === 'reclaimer'
                  ? [{ id: 'machine_core', count: 1 }, { id: 'mech_parts', count: 3 }]
                  : e.type === 'guardian'
                  ? [{ id: 'elec_comp', count: 2 }, { id: 'scrap_metal', count: 3 }]
                  : e.type === 'drone'
                  ? [{ id: 'sensor_unit', count: 1 }, { id: 'optical_mod', count: 1 }]
                  : [{ id: 'scrap_metal', count: 2 }, { id: 'mech_parts', count: 1 }];

                rt.regionData.containers.push({
                  id: `drop_${e.id}_${Date.now()}`,
                  x: e.x,
                  y: e.y,
                  isRare: e.type === 'reclaimer',
                  looted: false,
                  loot: dropLoot
                });

                // Persist defeated enemy
                const regPersisted = st.persistedRegions[st.region] || { lootedContainers: {}, defeatedEnemies: {} };
                regPersisted.defeatedEnemies = { ...(regPersisted.defeatedEnemies || {}), [e.id]: st.day };
                st.persistedRegions[st.region] = regPersisted;

                rt.regionData.enemies.splice(j, 1);
              }
              break;
            }
          }
        }

        if (hit || b.life <= 0) rt.bullets.splice(i, 1);
      }

      // Update Decoys
      for (let i = rt.decoys.length - 1; i >= 0; i--) {
        rt.decoys[i].timer -= dt;
        if (rt.decoys[i].timer <= 0) rt.decoys.splice(i, 1);
      }

      // Line of Sight helper (checks if segment intersects any solid structure)
      const hasLineOfSight = (x1, y1, x2, y2) => {
        for (const s of rt.regionData.structures) {
          // Sample 6 points along segment
          for (let t = 0.15; t <= 0.85; t += 0.17) {
            const sx = x1 + (x2 - x1) * t;
            const sy = y1 + (y2 - y1) * t;
            if (sx > s.x && sx < s.x + s.w && sy > s.y && sy < s.y + s.h) return false;
          }
        }
        return true;
      };

      // Update Enemy Robot AI
      for (const e of rt.regionData.enemies) {
        if (e.hitFlash > 0) e.hitFlash -= dt;
        if (e.attackCooldown > 0) e.attackCooldown -= dt;
        if (e.telegraphTimer > 0) e.telegraphTimer -= dt;

        if (e.neutral) {
          e.patrolAngle += dt * 0.5;
          e.x += Math.cos(e.patrolAngle) * e.speed * dt;
          e.y += Math.sin(e.patrolAngle) * e.speed * dt;
          continue;
        }

        // Check if distracted by Acoustic Chirper decoy
        const activeDecoy = rt.decoys[0];
        const targetX = activeDecoy ? activeDecoy.x : nextX;
        const targetY = activeDecoy ? activeDecoy.y : nextY;
        const distToTarget = Math.hypot(targetX - e.x, targetY - e.y);

        const isNight = st.timeOfDay >= 20 || st.timeOfDay < 5.5;
        const detectRadius = (st.player.crouching ? 165 : sprinting ? 310 : 235) * (isNight ? 1.2 : 1.0);

        if (activeDecoy && distToTarget < 380) {
          e.state = 'chase';
        } else if (distToTarget < detectRadius && hasLineOfSight(e.x, e.y, nextX, nextY)) {
          if (e.state !== 'chase') {
            triggerSpeech(YUNA_QUOTES.combatAlert[Math.floor(Math.random() * YUNA_QUOTES.combatAlert.length)], 3);
          }
          e.state = 'chase';
          e.alertTimer = 5.0;
        } else if (e.state === 'chase') {
          e.alertTimer -= dt;
          if (e.alertTimer <= 0) e.state = 'patrol';
        }

        if (e.state === 'patrol') {
          e.patrolAngle += dt * 0.4;
          const vx = Math.cos(e.patrolAngle) * e.speed * 0.45;
          const vy = Math.sin(e.patrolAngle) * e.speed * 0.45;
          e.x = Math.max(80, Math.min(rt.regionData.width - 80, e.x + vx * dt));
          e.y = Math.max(80, Math.min(rt.regionData.height - 80, e.y + vy * dt));
        } else if (e.state === 'chase') {
          const ang = Math.atan2(targetY - e.y, targetX - e.x);
          e.patrolAngle = ang;

          if (distToTarget > e.range * 0.75) {
            e.x += Math.cos(ang) * e.speed * dt;
            e.y += Math.sin(ang) * e.speed * dt;
          }

          // Attack behavior
          if (distToTarget <= e.range && e.attackCooldown <= 0 && !activeDecoy) {
            if (e.type === 'scuttler') {
              // Melee bite
              if (distToTarget < 46 && rt.hitInvuln <= 0) {
                st.player.hp -= e.dmg;
                rt.hitInvuln = 0.65;
                rt.screenShake = 5;
                sound.sfxHitRobot();
              }
              e.attackCooldown = 1.1;
            } else {
              // Ranged plasma/kinetic bolt
              if (e.type === 'reclaimer' && e.telegraphTimer <= 0) {
                e.telegraphTimer = 0.55;
                e.attackCooldown = 2.0;
              } else {
                rt.enemyBullets.push({
                  x: e.x,
                  y: e.y,
                  vx: Math.cos(ang) * 320,
                  vy: Math.sin(ang) * 320,
                  dmg: e.dmg,
                  life: 1.4
                });
                e.attackCooldown = e.type === 'drone' ? 1.4 : 1.7;
              }
            }
          }
        }
      }

      // Update Enemy Projectiles
      for (let i = rt.enemyBullets.length - 1; i >= 0; i--) {
        const eb = rt.enemyBullets[i];
        eb.x += eb.vx * dt;
        eb.y += eb.vy * dt;
        eb.life -= dt;

        let remove = eb.life <= 0;
        for (const s of rt.regionData.structures) {
          if (eb.x > s.x && eb.x < s.x + s.w && eb.y > s.y && eb.y < s.y + s.h) {
            remove = true;
            break;
          }
        }

        if (!remove && Math.hypot(eb.x - nextX, eb.y - nextY) < 16 && rt.hitInvuln <= 0) {
          st.player.hp -= eb.dmg;
          rt.hitInvuln = 0.65;
          if (!st.settings.reducedShake) rt.screenShake = 6;
          sound.sfxHitRobot();
          remove = true;
        }
        if (remove) rt.enemyBullets.splice(i, 1);
      }

      // Check Environmental Hazards
      for (const h of rt.regionData.hazards) {
        if (Math.hypot(nextX - h.x, nextY - h.y) < h.r && rt.hitInvuln <= 0) {
          st.player.hp -= 5;
          rt.hitInvuln = 0.8;
          rt.floatTexts.push({ x: nextX, y: nextY - 25, text: 'HAZARD!', color: '#38bdf8', life: 0.7 });
        }
      }
    }

    // Update Particles & Floating Numbers
    for (let i = rt.particles.length - 1; i >= 0; i--) {
      const p = rt.particles[i];
      p.x += p.vx * dt;
      p.y += p.vy * dt;
      p.life -= dt;
      if (p.life <= 0) rt.particles.splice(i, 1);
    }
    for (let i = rt.floatTexts.length - 1; i >= 0; i--) {
      const ft = rt.floatTexts[i];
      ft.y -= 28 * dt;
      ft.life -= dt;
      if (ft.life <= 0) rt.floatTexts.splice(i, 1);
    }

    // Update Contextual Interaction Prompt Text
    rt.promptText = null;
    if (st.region === 'shelter') {
      if (Math.hypot(nextX - 240, nextY - 410) < 75) rt.promptText = '[E] Cooking Corner (Prepare Warm Meals)';
      else if (Math.hypot(nextX - 610, nextY - 410) < 75) rt.promptText = '[E] Workbench (Craft Ammo, Filters & Tools)';
      else if (Math.hypot(nextX - 530, nextY - 375) < 75) rt.promptText = '[E] Shelter Storage Lockers';
      else if (Math.hypot(nextX - 630, nextY - 210) < 80) rt.promptText = '[E] Environmental Support Console (Upgrades)';
      else if (Math.hypot(nextX - 420, nextY - 560) < 75) rt.promptText = '[E] Concealed Wasteland Exit Passage';
      else {
        for (let i = 0; i < st.gardenPlots.length; i++) {
          const gp = st.gardenPlots[i];
          if (Math.hypot(nextX - gp.x, nextY - gp.y) < 52) {
            rt.promptText = gp.crop
              ? gp.stage >= 3
                ? `[E] Harvest ${ITEMS[gp.crop].name}`
                : !gp.watered
                ? `[E] Water ${ITEMS[gp.crop].name} Sprouts`
                : 'Growing nicely under the sun-shaft'
              : '[E] Plant Viable Seeds';
          }
        }
      }
    } else if (rt.regionData) {
      if (Math.hypot(nextX - rt.regionData.exitZone.x, nextY - rt.regionData.exitZone.y) < 82) {
        rt.promptText = '[E] Return Safely to Underground Shelter';
      }
      for (const c of rt.regionData.containers) {
        if (!c.looted && Math.hypot(nextX - c.x, nextY - c.y) < 62) {
          rt.promptText = c.isRare ? '[E] Search High-Priority Machine Cache' : '[E] Scavenge Salvage Container';
          break;
        }
      }
      for (const d of rt.regionData.discoveryNodes) {
        if (!st.discoveries.includes(d.id) && Math.hypot(nextX - d.x, nextY - d.y) < 68) {
          rt.promptText = `[E] Inspect Anomaly: ${d.name}`;
          break;
        }
      }
    }

    // Survival-Lite Needs & Day/Night Progression (24 minutes per full day = 1 hour per 60s)
    const nextTime = (st.timeOfDay + dt * 0.022) % 24;
    const nextFood = Math.max(0, st.player.food - dt * 0.045);
    const nextWater = Math.max(0, st.player.water - dt * 0.055);
    const nextStamina = sprinting
      ? Math.max(0, st.player.stamina - dt * 18)
      : Math.min(st.player.maxStamina, st.player.stamina + dt * (st.player.food > 20 ? 16 : 9));

    // Defeat / Recovery Check (No Permadeath! Returns Yuna to her cozy bed safely)
    if (st.player.hp <= 0) {
      rt.bullets = [];
      rt.enemyBullets = [];
      triggerSpeech("Ugh... my head. Glad I crawled back inside the hatch...", 5);
      showToast('Yuna was overwhelmed and retreated safely to her shelter bed.');
      setGameState(prev => ({
        ...prev,
        region: 'shelter',
        timeOfDay: (prev.timeOfDay + 3) % 24,
        player: {
          ...prev.player,
          x: 340,
          y: 430,
          hp: Math.round(prev.player.maxHp * 0.65),
          stamina: prev.player.maxStamina
        }
      }));
      return;
    }

    // Commit continuous player state updates
    setGameState(prev => ({
      ...prev,
      timeOfDay: nextTime,
      inventory: nextInv,
      player: {
        ...prev.player,
        x: nextX,
        y: nextY,
        facing,
        stamina: nextStamina,
        food: nextFood,
        water: nextWater,
        pistolMag,
        rifleMag
      }
    }));
  };

  // ============================================================================
  // CANVAS SCENE RENDERER (SHELTER DOLLHOUSE & WASTELAND)
  // ============================================================================
  const renderScene = (rt, st) => {
    const canvas = canvasRef.current;
    if (!canvas) return;
    const ctx = canvas.getContext('2d');
    const cw = canvas.width;
    const ch = canvas.height;

    const targetZoom = (st.region === 'shelter' ? 1.32 : 1.05) * st.settings.zoom;
    rt.camera.zoom += (targetZoom - rt.camera.zoom) * 0.1;
    rt.camera.x += (st.player.x - rt.camera.x) * 0.14;
    rt.camera.y += (st.player.y - rt.camera.y) * 0.14;

    const shakeX = (Math.random() - 0.5) * rt.screenShake;
    const shakeY = (Math.random() - 0.5) * rt.screenShake;

    // Update world mouse coordinates
    mouseRef.current.worldX = (mouseRef.current.x - cw / 2) / rt.camera.zoom + rt.camera.x;
    mouseRef.current.worldY = (mouseRef.current.y - ch / 2) / rt.camera.zoom + rt.camera.y;

    ctx.save();
    ctx.fillStyle = st.region === 'shelter' ? '#18110d' : REGIONS[st.region].palette.bg;
    ctx.fillRect(0, 0, cw, ch);

    ctx.translate(cw / 2 + shakeX, ch / 2 + shakeY);
    ctx.scale(rt.camera.zoom, rt.camera.zoom);
    ctx.translate(-rt.camera.x, -rt.camera.y);

    if (st.region === 'shelter') {
      renderShelterInterior(ctx, rt, st);
    } else if (rt.regionData) {
      renderWastelandRegion(ctx, rt, st);
    }

    // Floating Damage & Status Numbers
    for (const ft of rt.floatTexts) {
      ctx.fillStyle = ft.color;
      ctx.font = 'bold 13px Inter, sans-serif';
      ctx.fillText(ft.text, ft.x - 10, ft.y);
    }

    ctx.restore();
  };

  // Render Cozy Two-Level Mesa Cavity Shelter
  const renderShelterInterior = (ctx, rt, st) => {
    spriteAtlas.init();
    // Surrounding rocky mesa cavern
    ctx.fillStyle = '#231914';
    ctx.fillRect(80, 40, 680, 600);

    // UPPER LEVEL: Fortified Sun Court & Growing Area (y: 120..265) with tiled flagstone sprite texture
    if (spriteAtlas.patterns.shelterUpper) {
      ctx.fillStyle = ctx.createPattern(spriteAtlas.patterns.shelterUpper, 'repeat');
    } else {
      ctx.fillStyle = '#47362b';
    }
    ctx.beginPath();
    ctx.roundRect(180, 120, 480, 150, 10);
    ctx.fill();
    ctx.strokeStyle = '#6e503b';
    ctx.lineWidth = 4;
    ctx.stroke();

    // Protected Sunlight Shaft Beam
    const sunIntensity = st.mainRestore.sunlightRestored ? 0.34 : 0.15;
    const sunGrad = ctx.createRadialGradient(340, 185, 15, 340, 185, 145);
    sunGrad.addColorStop(0, `rgba(253, 224, 71, ${sunIntensity})`);
    sunGrad.addColorStop(1, 'rgba(253, 224, 71, 0)');
    ctx.fillStyle = sunGrad;
    ctx.beginPath();
    ctx.arc(340, 185, 145, 0, Math.PI * 2);
    ctx.fill();

    // Draw 4 Planter Beds in Upper Sun Court
    for (let i = 0; i < st.gardenPlots.length; i++) {
      const gp = st.gardenPlots[i];
      ctx.fillStyle = gp.watered ? '#3b2618' : '#573b26';
      ctx.beginPath();
      ctx.roundRect(gp.x - 24, gp.y - 18, 48, 36, 5);
      ctx.fill();
      ctx.strokeStyle = '#78553a';
      ctx.lineWidth = 2;
      ctx.stroke();

      if (gp.crop) {
        const isBerry = gp.crop === 'sun_berry';
        ctx.fillStyle = '#22c55e';
        const r = 4 + gp.stage * 3;
        ctx.beginPath();
        ctx.arc(gp.x - 8, gp.y, r, 0, Math.PI * 2);
        ctx.arc(gp.x + 8, gp.y, r, 0, Math.PI * 2);
        ctx.fill();
        if (gp.stage >= 3) {
          ctx.fillStyle = isBerry ? '#f59e0b' : '#d97706';
          ctx.beginPath();
          ctx.arc(gp.x - 8, gp.y - 3, 4, 0, Math.PI * 2);
          ctx.arc(gp.x + 8, gp.y - 3, 4, 0, Math.PI * 2);
          ctx.fill();
        }
      }
    }

    // Environmental Support Console in Upper Right
    ctx.fillStyle = '#1e293b';
    ctx.fillRect(595, 155, 52, 42);
    ctx.fillStyle = st.mainRestore.powerRestored ? '#22d3ee' : '#f59e0b';
    ctx.fillRect(603, 163, 36, 14);

    // LOWER LEVEL: Warm Living Space (y: 270..565) with pre-baked warm stone & timber texture
    if (spriteAtlas.patterns.shelterLower) {
      ctx.fillStyle = ctx.createPattern(spriteAtlas.patterns.shelterLower, 'repeat');
    } else {
      ctx.fillStyle = '#3b2a20';
    }
    ctx.beginPath();
    ctx.roundRect(180, 270, 480, 300, 10);
    ctx.fill();
    ctx.strokeStyle = '#6e503b';
    ctx.lineWidth = 4;
    ctx.stroke();

    // Connecting Stairs between Upper Sun Court & Lower Living Space
    ctx.fillStyle = '#5c4333';
    for (let s = 0; s < 4; s++) {
      ctx.fillRect(480, 250 + s * 8, 46, 6);
    }

    // Subtle Placement Grid when Decorating Mode is Active
    if (placingFurniture) {
      ctx.strokeStyle = 'rgba(251, 191, 36, 0.22)';
      ctx.lineWidth = 1;
      for (let gx = 0; gx < 12; gx++) {
        for (let gy = 0; gy < 11; gy++) {
          ctx.strokeRect(180 + gx * 40, 120 + gy * 40, 40, 40);
        }
      }
    }

    // Fixed Core Stations in Lower Level
    // 1. Cooking Corner (Left)
    ctx.fillStyle = '#7c2d12';
    ctx.beginPath();
    ctx.roundRect(195, 380, 56, 46, 6);
    ctx.fill();
    ctx.fillStyle = '#ea580c';
    ctx.beginPath();
    ctx.arc(223, 402, 11, 0, Math.PI * 2);
    ctx.fill();

    // 2. Workbench (Right)
    ctx.fillStyle = '#334155';
    ctx.beginPath();
    ctx.roundRect(580, 380, 62, 48, 6);
    ctx.fill();
    ctx.fillStyle = '#38bdf8';
    ctx.fillRect(592, 390, 24, 14);

    // 3. Main Storage Locker
    ctx.fillStyle = '#475569';
    ctx.beginPath();
    ctx.roundRect(510, 350, 42, 34, 4);
    ctx.fill();

    // 4. Concealed Exit Hatch at Bottom Center
    ctx.fillStyle = '#27272a';
    ctx.beginPath();
    ctx.roundRect(385, 535, 70, 28, 5);
    ctx.fill();
    ctx.strokeStyle = '#f59e0b';
    ctx.lineWidth = 2;
    ctx.strokeRect(385, 535, 70, 28);

    // Render Placed Walkable Rugs First (Using Baked Sprite Texture)
    for (const f of st.furniture) {
      const def = FURNITURE_CATALOG.find(item => item.id === f.id);
      if (!def || !def.walkable) continue;
      const fx = 180 + f.gx * 40;
      const fy = 120 + f.gy * 40;
      const spr = spriteAtlas.furnitureSprites?.[f.id];
      if (spr) {
        ctx.drawImage(spr, fx, fy - 16);
      }
    }

    // Depth-Sort Yuna and Non-Walkable Furniture Sprites
    const renderList = [];
    for (const f of st.furniture) {
      const def = FURNITURE_CATALOG.find(item => item.id === f.id);
      if (!def || def.walkable) continue;
      const fx = 180 + f.gx * 40;
      const fy = 120 + f.gy * 40;
      renderList.push({
        sortY: fy + def.h * 40,
        draw: () => {
          // Warm Lamp Glow
          if (def.lightRadius) {
            const g = ctx.createRadialGradient(fx + 20, fy + 20, 6, fx + 20, fy + 20, def.lightRadius);
            g.addColorStop(0, 'rgba(251, 191, 36, 0.30)');
            g.addColorStop(1, 'rgba(251, 191, 36, 0)');
            ctx.fillStyle = g;
            ctx.beginPath();
            ctx.arc(fx + 20, fy + 20, def.lightRadius, 0, Math.PI * 2);
            ctx.fill();
          }
          const spr = spriteAtlas.furnitureSprites?.[f.id];
          if (spr) {
            ctx.drawImage(spr, fx, fy - 16);
          }
        }
      });
    }

    const isMoving =
      keysRef.current['w'] || keysRef.current['a'] || keysRef.current['s'] || keysRef.current['d'] || touchMoveRef.current.active;
    renderList.push({
      sortY: st.player.y + 16,
      draw: () =>
        drawYunaCharacter(
          ctx,
          st.player.x,
          st.player.y,
          st.player.facing,
          rt.animTime,
          isMoving,
          st.player.crouching,
          st.player.activeWeapon,
          true,
          rt.ticVisualTimer > 0,
          rt.hitInvuln
        )
    });

    renderList.sort((a, b) => a.sortY - b.sortY);
    for (const item of renderList) item.draw();

    // Preview Furniture Placement under Cursor
    if (placingFurniture) {
      const def = FURNITURE_CATALOG.find(i => i.id === placingFurniture.id);
      if (def) {
        const gx = Math.floor((mouseRef.current.worldX - 180) / 40);
        const gy = Math.floor((mouseRef.current.worldY - 120) / 40);
        const valid = gx >= 0 && gy >= 0 && gx + def.w <= 12 && gy + def.h <= 11;
        ctx.fillStyle = valid ? 'rgba(52, 211, 153, 0.45)' : 'rgba(248, 113, 113, 0.45)';
        ctx.fillRect(180 + gx * 40, 120 + gy * 40, def.w * 40, def.h * 40);
      }
    }

    // Station Labels
    ctx.fillStyle = 'rgba(254, 243, 199, 0.78)';
    ctx.font = '11px Inter, sans-serif';
    ctx.fillText('Sun-Court Planters', 295, 142);
    ctx.fillText('Support Console', 580, 145);
    ctx.fillText('Cooking Corner', 192, 372);
    ctx.fillText('Workbench', 582, 372);
    ctx.fillText('Storage', 512, 344);
    ctx.fillText('Wasteland Passage', 374, 528);
  };

  // Render Machine Civilization Exterior Region
  const renderWastelandRegion = (ctx, rt, st) => {
    spriteAtlas.init();
    const reg = REGIONS[st.region];
    const data = rt.regionData;

    // Seamless Tiled Biome Surface Texture
    const biomePat = spriteAtlas.patterns[st.region];
    if (biomePat) {
      ctx.fillStyle = ctx.createPattern(biomePat, 'repeat');
      ctx.fillRect(0, 0, data.width, data.height);
    }

    // Environmental Hazards
    for (const h of data.hazards) {
      ctx.fillStyle = h.type === 'coolant' ? 'rgba(34, 211, 238, 0.25)' : 'rgba(250, 204, 21, 0.22)';
      ctx.beginPath();
      ctx.arc(h.x, h.y, h.r, 0, Math.PI * 2);
      ctx.fill();
      ctx.strokeStyle = h.type === 'coolant' ? '#06b6d4' : '#eab308';
      ctx.lineWidth = 1.5;
      ctx.stroke();
    }

    // Return to Shelter Passage Zone
    ctx.fillStyle = 'rgba(245, 158, 11, 0.18)';
    ctx.beginPath();
    ctx.arc(data.exitZone.x, data.exitZone.y, data.exitZone.r, 0, Math.PI * 2);
    ctx.fill();
    ctx.strokeStyle = '#f59e0b';
    ctx.lineWidth = 2.5;
    ctx.stroke();
    ctx.fillStyle = '#fde68a';
    ctx.font = 'bold 12px Inter, sans-serif';
    ctx.fillText('Shelter Hatch', data.exitZone.x - 38, data.exitZone.y + 4);

    // Optional Discovery Nodes
    for (const d of data.discoveryNodes) {
      const done = st.discoveries.includes(d.id);
      ctx.fillStyle = done ? 'rgba(148, 163, 184, 0.25)' : 'rgba(167, 139, 250, 0.35)';
      ctx.beginPath();
      ctx.arc(d.x, d.y, 22, 0, Math.PI * 2);
      ctx.fill();
      ctx.fillStyle = done ? '#94a3b8' : '#e9d5ff';
      ctx.font = '11px Inter, sans-serif';
      ctx.fillText(done ? `✓ ${d.name}` : `? ${d.name}`, d.x - 42, d.y - 28);
    }

    // Collect Depth-Sorted Entities (Structures, Containers, Enemies, Yuna)
    const renderables = [];

    // 1. Machine Structures (3/4 View with Top Roof & Front Wall)
    for (const s of data.structures) {
      const playerBehind =
        st.player.x > s.x - 10 &&
        st.player.x < s.x + s.w + 10 &&
        st.player.y < s.y + s.h &&
        st.player.y > s.y - 35;

      renderables.push({
        sortY: s.y + s.h,
        draw: () => {
          ctx.save();
          if (playerBehind) ctx.globalAlpha = 0.42; // Fade obstructing tall structure!
          // Shadow
          ctx.fillStyle = 'rgba(0,0,0,0.42)';
          ctx.fillRect(s.x + 8, s.y + 10, s.w, s.h);
          // Main body
          ctx.fillStyle = reg.palette.metal;
          ctx.beginPath();
          ctx.roundRect(s.x, s.y - 24, s.w, s.h + 24, 6);
          ctx.fill();
          // Rust/detail trim
          ctx.fillStyle = reg.palette.rust;
          ctx.fillRect(s.x + 6, s.y - 16, s.w - 12, 10);
          // Glowing machine status diode
          ctx.fillStyle = reg.palette.glow;
          ctx.fillRect(s.x + s.w - 16, s.y + s.h - 14, 8, 4);
          ctx.restore();
        }
      });
    }

    // 2. Authored Region Landmark
    const lm = data.landmark;
    renderables.push({
      sortY: lm.y + lm.h,
      draw: () => {
        ctx.fillStyle = '#1e293b';
        ctx.beginPath();
        ctx.roundRect(lm.x - lm.w / 2, lm.y - lm.h / 2, lm.w, lm.h, 10);
        ctx.fill();
        ctx.strokeStyle = reg.palette.glow;
        ctx.lineWidth = 3;
        ctx.stroke();
        ctx.fillStyle = '#f8fafc';
        ctx.font = 'bold 12px Inter, sans-serif';
        ctx.fillText(lm.name, lm.x - lm.w / 2 + 12, lm.y - lm.h / 2 - 10);
      }
    });

    // 3. Salvage Containers (Rendered from Prop Spritesheet)
    for (const c of data.containers) {
      renderables.push({
        sortY: c.y + 12,
        draw: () => {
          if (spriteAtlas.propSheet) {
            const sx = c.looted ? 128 : c.isRare ? 64 : 0;
            ctx.drawImage(spriteAtlas.propSheet, sx, 0, 64, 64, c.x - 32, c.y - 32, 64, 64);
          }
        }
      });
    }

    // 4. Enemies
    for (const e of data.enemies) {
      renderables.push({
        sortY: e.y + e.radius,
        draw: () => drawRobotEnemy(ctx, e, rt.animTime)
      });
    }

    // 5. Yuna
    const isMoving =
      keysRef.current['w'] || keysRef.current['a'] || keysRef.current['s'] || keysRef.current['d'] || touchMoveRef.current.active;
    renderables.push({
      sortY: st.player.y + 18,
      draw: () =>
        drawYunaCharacter(
          ctx,
          st.player.x,
          st.player.y,
          st.player.facing,
          rt.animTime,
          isMoving,
          st.player.crouching,
          st.player.activeWeapon,
          false,
          rt.ticVisualTimer > 0,
          rt.hitInvuln
        )
    });

    renderables.sort((a, b) => a.sortY - b.sortY);
    for (const r of renderables) r.draw();

    // Active Decoys
    for (const d of rt.decoys) {
      ctx.strokeStyle = '#c084fc';
      ctx.lineWidth = 2;
      ctx.beginPath();
      ctx.arc(d.x, d.y, 12 + Math.sin(rt.animTime * 18) * 8, 0, Math.PI * 2);
      ctx.stroke();
    }

    // Projectiles
    ctx.fillStyle = '#fef08a';
    for (const b of rt.bullets) {
      ctx.beginPath();
      ctx.arc(b.x, b.y, 3.5, 0, Math.PI * 2);
      ctx.fill();
    }
    ctx.fillStyle = '#f87171';
    for (const eb of rt.enemyBullets) {
      ctx.beginPath();
      ctx.arc(eb.x, eb.y, 4.5, 0, Math.PI * 2);
      ctx.fill();
    }

    // Particles
    for (const p of rt.particles) {
      ctx.fillStyle = p.color;
      ctx.fillRect(p.x, p.y, 3, 3);
    }

    // Day/Night Exterior Atmospheric Tint
    const hr = st.timeOfDay;
    let darkness = 0;
    if (hr >= 20 || hr < 5) darkness = 0.48;
    else if (hr >= 17.5 && hr < 20) darkness = ((hr - 17.5) / 2.5) * 0.48;
    else if (hr >= 5 && hr < 7.5) darkness = (1 - (hr - 5) / 2.5) * 0.48;

    if (darkness > 0.02) {
      ctx.fillStyle = `rgba(8, 12, 24, ${darkness})`;
      ctx.fillRect(0, 0, data.width, data.height);
    }
  };

  // ============================================================================
  // LOOTING, DECORATING & RESTORATION HANDLERS
  // ============================================================================
  const takeContainerLoot = (item, idx) => {
    if (!openContainer) return;
    setGameState(prev => {
      const { list: nextInv, added } = addItemsToList(prev.inventory, item.id, item.count, maxBackpackSlots);
      if (added <= 0) {
        showToast('Backpack is full! Return home or upgrade your pack.');
        return prev;
      }
      sound.sfxLoot();
      triggerSpeech(YUNA_QUOTES.lootSuccess[Math.floor(Math.random() * YUNA_QUOTES.lootSuccess.length)], 3);

      const remainingLoot = openContainer.loot.filter((_, i) => i !== idx);
      const isNowEmpty = remainingLoot.length === 0;

      if (isNowEmpty) {
        openContainer.looted = true;
        setOpenContainer(null);
      } else {
        setOpenContainer({ ...openContainer, loot: remainingLoot });
      }

      const regPersisted = prev.persistedRegions[prev.region] || { lootedContainers: {}, defeatedEnemies: {} };
      if (isNowEmpty) {
        regPersisted.lootedContainers = { ...(regPersisted.lootedContainers || {}), [openContainer.id]: prev.day };
      }

      return {
        ...prev,
        inventory: nextInv,
        persistedRegions: { ...prev.persistedRegions, [prev.region]: regPersisted }
      };
    });
  };

  const handleCanvasClick = () => {
    sound.init();
    if (!placingFurniture || gameState.region !== 'shelter') return;

    const def = FURNITURE_CATALOG.find(f => f.id === placingFurniture.id);
    if (!def) return;

    const gx = Math.floor((mouseRef.current.worldX - 180) / 40);
    const gy = Math.floor((mouseRef.current.worldY - 120) / 40);
    if (gx < 0 || gy < 0 || gx + def.w > 12 || gy + def.h > 11) {
      showToast('Please place inside the shelter floor grid.');
      return;
    }

    if (!hasMaterials(def.cost, true)) {
      showToast('Not enough materials for this furnishing.');
      return;
    }

    setGameState(prev => {
      const { nextInv, nextStorage } = removeItemsFromLists(prev.inventory, prev.storage, def.cost, true);
      const newFurn = {
        uid: `f_${Date.now()}`,
        id: def.id,
        gx,
        gy,
        rot: placingFurniture.rot || 0
      };
      sound.sfxCraft();
      triggerSpeech("That looks really cozy right there!", 3.5);
      return {
        ...prev,
        inventory: nextInv,
        storage: nextStorage,
        furniture: [...prev.furniture, newFurn]
      };
    });
    setPlacingFurniture(null);
  };

  // ============================================================================
  // GEMINI LLM FEATURE 1: YUNA'S PERSONAL JOURNAL GENERATOR + TTS
  // ============================================================================
  const generateYunaJournalEntry = async () => {
    if (aiLoading) return;
    setAiLoading(true);
    try {
      const st = gameState;
      const furnNames = st.furniture
        .map(f => FURNITURE_CATALOG.find(c => c.id === f.id)?.name)
        .filter(Boolean)
        .join(', ');
      const cropsPlanted = st.gardenPlots
        .filter(p => p.crop)
        .map(p => ITEMS[p.crop]?.name)
        .join(', ') || 'none yet';
      const restoredList = [
        st.mainRestore.waterRestored && 'Water Osmosis Purifier',
        st.mainRestore.powerRestored && 'Cryo-Capacitor Bank',
        st.mainRestore.sunlightRestored && 'Heliostat Sun Mirror'
      ].filter(Boolean).join(', ') || 'none yet';

      const systemPrompt = `You are writing an intimate first-person journal entry as Yuna, the 20-year-old protagonist of "YUNA: The Warmth Below".
Yuna is sweet, gentle, shy, fearful of hostile machines, but deeply intelligent with electronics and mechanics.
She lives alone in a warm underground shelter carved inside a mesa, surrounded by a vast, indifferent machine-only civilization (no human ruins or cars—only pylons, coolant basins, conduits, and automata).
Include her natural, endearing habits subtly (like holding her braid, a soft "*click*", or talking kindly to her appliances) without making them a joke.
Keep the entry between 3 and 5 sentences, grounded in her exact current state.`;

      const userPrompt = `Write Yuna's new journal entry for Day ${st.day} (${REGIONS[st.region].name}).
- Yuna's Health: ${Math.round(st.player.hp)}/100, Nourishment: ${Math.round(st.player.food)}%, Water: ${Math.round(st.player.water)}%
- Shelter Furnishings present: ${furnNames}
- Crops growing in Sun-Court: ${cropsPlanted}
- Major Life-Support Systems Restored: ${restoredList}
- Discoveries found: ${st.discoveries.length}
Return a title, mood, the diary content, and a short margin sketch description.`;

      const schema = {
        type: 'OBJECT',
        properties: {
          title: { type: 'STRING' },
          mood: { type: 'STRING' },
          content: { type: 'STRING' },
          sketchNote: { type: 'STRING' }
        },
        required: ['title', 'mood', 'content', 'sketchNote']
      };

      const data = await callGeminiStructured(systemPrompt, userPrompt, schema);
      const newEntry = {
        id: `entry_${Date.now()}`,
        day: st.day,
        title: data.title,
        mood: data.mood,
        content: data.content,
        sketchNote: data.sketchNote
      };

      setGameState(prev => {
        const nextState = {
          ...prev,
          journalEntries: [newEntry, ...(prev.journalEntries || [])],
          player: {
            ...prev.player,
            stamina: Math.min(prev.player.maxStamina, prev.player.stamina + 25)
          }
        };
        saveToSlot(1, nextState);
        return nextState;
      });
      sound.sfxCraft();
      triggerSpeech("Wrote down today's thoughts... I feel a little calmer now.", 4);
      showToast('New Journal Entry written! (+25 Stamina from quiet reflection)');
    } catch (err) {
      showToast('Could not write entry right now. Check connection.');
    } finally {
      setAiLoading(false);
    }
  };

  const handlePlayJournalTTS = async (entry) => {
    if (ttsLoadingId) return;
    setTtsLoadingId(entry.id);
    try {
      await speakYunaText(`${entry.title}. ${entry.content}`);
    } catch (e) {
      showToast('Voice synthesis unavailable right now.');
    } finally {
      setTtsLoadingId(null);
    }
  };

  // ============================================================================
  // GEMINI LLM FEATURE 2: VACUUM RADIO SIGNAL DECODER & SALVAGE DROP
  // ============================================================================
  const decodeRadioTransmission = async () => {
    if (aiLoading) return;
    setAiLoading(true);
    try {
      const targetRegion = ['ash_flats', 'cable_forest', 'dead_foundry', 'coolant_basin'][
        Math.floor(Math.random() * 4)
      ];
      const regName = REGIONS[targetRegion].name;
      const bonusPool = REGIONS[targetRegion].lootPool;
      const bonusItem = bonusPool[Math.floor(Math.random() * bonusPool.length)];

      const systemPrompt = `You generate atmospheric radio transmissions intercepted by Yuna's repaired vacuum-tube radio in "YUNA: The Warmth Below".
Remember the strict world rule: the surface is an ancient, autonomous Machine Civilization (conduits, cooling reservoirs, fabrication bays, telemetry relays, harmless sweepers, and patrol units—NO human cities, roads, or cars).
Generate:
1. A frequency string (e.g. "142.8 MHz - Low-Band Telemetry")
2. The raw intercepted transmission (either an eerie poetic machine-network status log, a weather/coolant mist advisory, or a warm fragmented audio memo left years ago by Mother about maintaining the shelter).
3. Yuna's quiet, intelligent whispered reaction and how she triangulated a salvage drop from the signal.`;

      const userPrompt = `Intercept a transmission originating from ${regName}.
It should pinpoint a dropped supply/salvage cache containing ${ITEMS[bonusItem]?.name}.`;

      const schema = {
        type: 'OBJECT',
        properties: {
          frequency: { type: 'STRING' },
          sourceType: { type: 'STRING' },
          transmissionText: { type: 'STRING' },
          yunaComment: { type: 'STRING' }
        },
        required: ['frequency', 'sourceType', 'transmissionText', 'yunaComment']
      };

      const data = await callGeminiStructured(systemPrompt, userPrompt, schema);

      const signalRecord = {
        id: `sig_${Date.now()}`,
        day: gameState.day,
        regionId: targetRegion,
        regionName: regName,
        rewardItem: bonusItem,
        ...data
      };

      // Deliver a salvaged sample directly or log coordinates
      setGameState(prev => {
        const { list: nextInv } = addItemsToList(prev.inventory, bonusItem, 2, maxBackpackSlots);
        return {
          ...prev,
          inventory: nextInv,
          decodedSignals: [signalRecord, ...(prev.decodedSignals || [])]
        };
      });

      sound.sfxLoot();
      triggerSpeech(data.yunaComment, 4.5);
      showToast(`Signal Decoded! Recovered 2x ${ITEMS[bonusItem]?.name} via telemetry lock.`);
    } catch (e) {
      showToast('Static interference blocked the signal. Try again shortly.');
    } finally {
      setAiLoading(false);
    }
  };

  // ============================================================================
  // GEMINI LLM FEATURE 3: WORKBENCH ARTIFACT ANALYZER & TINKERING
  // ============================================================================
  const analyzeArtifactWithYuna = async (itemId) => {
    const def = ITEMS[itemId];
    if (!def || analyzingItemId) return;
    setAnalyzingItemId(itemId);
    try {
      const systemPrompt = `You are Yuna from "YUNA: The Warmth Below", a shy but brilliant 20-year-old electronics and mechanics tinkerer living in a cozy mesa shelter beneath a machine civilization.
When inspecting an item, explain in 2-3 warm, nerdy, slightly nervous sentences how the machine component or supply works and a clever trick you just noticed while examining it.`;

      const userPrompt = `Inspect this item: ${def.name} (${def.desc}). Give Yuna's technical observation and a tiny tinkering discovery.`;

      const schema = {
        type: 'OBJECT',
        properties: {
          observation: { type: 'STRING' },
          tinkerTip: { type: 'STRING' }
        },
        required: ['observation', 'tinkerTip']
      };

      const data = await callGeminiStructured(systemPrompt, userPrompt, schema);
      setItemAnalysis({
        itemId,
        itemName: def.name,
        icon: def.icon,
        observation: data.observation,
        tinkerTip: data.tinkerTip
      });
      sound.sfxTic();
      triggerSpeech(data.observation, 5);
    } catch (e) {
      showToast('Yuna lost her train of thought while inspecting the component.');
    } finally {
      setAnalyzingItemId(null);
    }
  };

  const restoreMajorSystem = (systemKey) => {
    const configs = {
      water: {
        cost: { quest_water_core: 1, coolant_filter: 2, mech_parts: 3 },
        field: 'waterRestored',
        title: 'Clean Water Osmosis System'
      },
      power: {
        cost: { quest_power_core: 1, power_cell: 2, elec_comp: 3 },
        field: 'powerRestored',
        title: 'Cryo-Capacitor Energy Storage'
      },
      sunlight: {
        cost: { quest_sun_mirror: 1, optical_mod: 2, copper_wire: 4 },
        field: 'sunlightRestored',
        title: 'Upper Sunlight Heliostat Array'
      }
    };
    const cfg = configs[systemKey];
    if (!cfg || !hasMaterials(cfg.cost, true)) {
      showToast('Missing required rare component or materials.');
      return;
    }

    setGameState(prev => {
      const { nextInv, nextStorage } = removeItemsFromLists(prev.inventory, prev.storage, cfg.cost, true);
      const nextMain = { ...prev.mainRestore, [cfg.field]: true };
      const allThreeDone = nextMain.waterRestored && nextMain.powerRestored && nextMain.sunlightRestored;

      sound.sfxCraft();
      if (allThreeDone && !nextMain.endingSeen) {
        nextMain.endingSeen = true;
        setTimeout(() => setActiveModal('ending'), 600);
      } else {
        triggerSpeech(`Restored the ${cfg.title}! Everything sounds so much smoother now.`, 4.5);
      }

      const nextState = {
        ...prev,
        inventory: nextInv,
        storage: nextStorage,
        mainRestore: nextMain
      };
      saveToSlot(1, nextState);
      return nextState;
    });
  };

  const formattedTime = useMemo(() => {
    const hrs = Math.floor(gameState.timeOfDay);
    const mins = Math.floor((gameState.timeOfDay - hrs) * 60);
    const ampm = hrs >= 12 ? 'PM' : 'AM';
    const h12 = hrs % 12 === 0 ? 12 : hrs % 12;
    return `${h12}:${mins.toString().padStart(2, '0')} ${ampm}`;
  }, [gameState.timeOfDay]);

  const completedRestorations = [
    gameState.mainRestore.waterRestored,
    gameState.mainRestore.powerRestored,
    gameState.mainRestore.sunlightRestored
  ].filter(Boolean).length;

  const triggerManualReload = () => {
    const rt = runtimeRef.current;
    if (rt.reloadTimer <= 0 && rt.state.region !== 'shelter') {
      const isPistol = rt.state.player.activeWeapon === 'pistol';
      const ammoId = isPistol ? 'pistol_ammo' : 'rifle_ammo';
      const mag = isPistol ? rt.state.player.pistolMag : rt.state.player.rifleMag;
      const maxMag = isPistol ? rt.state.player.pistolMaxMag : rt.state.player.rifleMaxMag;
      if (mag < maxMag && getItemCount(rt.state.inventory, ammoId) > 0) {
        rt.reloadTimer = isPistol ? 0.9 : 1.5;
        sound.sfxReload();
      } else {
        showToast('Magazine is already full or out of ammo.');
      }
    }
  };

  const handleMoveTouch = (e) => {
    sound.init();
    const touch = e.touches[0];
    if (!touch) return;
    const rect = e.currentTarget.getBoundingClientRect();
    const cx = rect.left + rect.width / 2;
    const cy = rect.top + rect.height / 2;
    const maxR = rect.width / 2;
    let dx = (touch.clientX - cx) / maxR;
    let dy = (touch.clientY - cy) / maxR;
    const len = Math.hypot(dx, dy);
    if (len > 1) {
      dx /= len;
      dy /= len;
    }
    touchMoveRef.current = { dx, dy, active: true };
    setJoyVisual({ active: true, dx: dx * (maxR * 0.55), dy: dy * (maxR * 0.55) });
  };

  const handleMoveTouchEnd = () => {
    touchMoveRef.current = { dx: 0, dy: 0, active: false };
    setJoyVisual({ active: false, dx: 0, dy: 0 });
  };

  const handleAimTouch = (e) => {
    sound.init();
    const touch = e.touches[0];
    if (!touch) return;
    const rect = e.currentTarget.getBoundingClientRect();
    const cx = rect.left + rect.width / 2;
    const cy = rect.top + rect.height / 2;
    const maxR = rect.width / 2;
    let dx = (touch.clientX - cx) / maxR;
    let dy = (touch.clientY - cy) / maxR;
    const len = Math.hypot(dx, dy);
    if (len > 1) {
      dx /= len;
      dy /= len;
    }
    const angle = len > 0.15 ? Math.atan2(dy, dx) : runtimeRef.current.state.player.facing;
    touchAimRef.current = { angle, firing: len > 0.25, active: true };
    setAimJoyVisual({ active: true, dx: dx * (maxR * 0.55), dy: dy * (maxR * 0.55) });
  };

  const handleAimTouchEnd = () => {
    touchAimRef.current = { ...touchAimRef.current, firing: false, active: false };
    setAimJoyVisual({ active: false, dx: 0, dy: 0 });
  };

  return (
    <div className="relative w-screen h-[100dvh] overflow-hidden bg-stone-950 text-stone-100 select-none font-sans touch-none">
      {/* MAIN INTERACTIVE GAME CANVAS */}
      <canvas
        ref={canvasRef}
        width={1280}
        height={760}
        onClick={handleCanvasClick}
        onTouchStart={(e) => {
          sound.init();
          if (placingFurniture && e.touches[0]) {
            const rect = e.currentTarget.getBoundingClientRect();
            mouseRef.current.x = ((e.touches[0].clientX - rect.left) / rect.width) * 1280;
            mouseRef.current.y = ((e.touches[0].clientY - rect.top) / rect.height) * 760;
            mouseRef.current.worldX =
              (mouseRef.current.x - 640) / runtimeRef.current.camera.zoom + runtimeRef.current.camera.x;
            mouseRef.current.worldY =
              (mouseRef.current.y - 380) / runtimeRef.current.camera.zoom + runtimeRef.current.camera.y;
            handleCanvasClick();
          }
        }}
        onMouseMove={(e) => {
          const rect = e.currentTarget.getBoundingClientRect();
          mouseRef.current.x = ((e.clientX - rect.left) / rect.width) * 1280;
          mouseRef.current.y = ((e.clientY - rect.top) / rect.height) * 760;
        }}
        onMouseDown={() => {
          sound.init();
          mouseRef.current.down = true;
        }}
        onMouseUp={() => {
          mouseRef.current.down = false;
        }}
        className="w-full h-full object-cover cursor-crosshair"
      />

      {/* TOP-LEFT HUD: YUNA VITALS & SHELTER RESERVES (Responsive for Mobile & Desktop) */}
      <div className="absolute top-2 left-2 sm:top-3 sm:left-3 flex flex-col gap-1.5 sm:gap-2 pointer-events-none max-w-[205px] sm:max-w-xs z-10">
        <div className="bg-stone-900/90 border border-amber-500/30 rounded-xl p-2 sm:p-3 shadow-xl backdrop-blur-md">
          <div className="flex items-center justify-between gap-2 sm:gap-4 mb-1.5 sm:mb-2">
            <div className="truncate">
              <div className="text-[10px] sm:text-xs uppercase tracking-wider text-amber-400 font-semibold truncate">
                YUNA: Warmth Below
              </div>
              <div className="text-xs sm:text-sm font-bold text-stone-100 flex items-center gap-1 truncate">
                {gameState.region === 'shelter' ? (
                  <Home className="w-3.5 h-3.5 sm:w-4 sm:h-4 text-amber-400 shrink-0" />
                ) : (
                  <Compass className="w-3.5 h-3.5 sm:w-4 sm:h-4 text-sky-400 shrink-0" />
                )}
                <span className="truncate">{REGIONS[gameState.region].name}</span>
              </div>
            </div>
            <div className="text-right shrink-0">
              <div className="text-[10px] sm:text-xs text-stone-400">Day {gameState.day}</div>
              <div className="text-[10px] sm:text-xs font-mono text-amber-300 flex items-center gap-1">
                {gameState.timeOfDay >= 6 && gameState.timeOfDay < 19.5 ? (
                  <Sun className="w-3 h-3 sm:w-3.5 sm:h-3.5 text-amber-400" />
                ) : (
                  <Moon className="w-3 h-3 sm:w-3.5 sm:h-3.5 text-sky-300" />
                )}
                {formattedTime}
              </div>
            </div>
          </div>

          {/* Health, Stamina, Nourishment, Hydration Bars */}
          <div className="grid grid-cols-2 gap-1.5 sm:gap-2 text-[10px] sm:text-xs">
            <div>
              <div className="flex justify-between text-rose-300 mb-0.5">
                <span className="flex items-center gap-1"><Heart className="w-2.5 h-2.5 sm:w-3 sm:h-3" /> HP</span>
                <span>{Math.round(gameState.player.hp)}</span>
              </div>
              <div className="h-1.5 sm:h-2 bg-stone-800 rounded-full overflow-hidden">
                <div
                  className="h-full bg-rose-500 transition-all"
                  style={{ width: `${(gameState.player.hp / gameState.player.maxHp) * 100}%` }}
                />
              </div>
            </div>

            <div>
              <div className="flex justify-between text-amber-300 mb-0.5">
                <span className="flex items-center gap-1"><Zap className="w-2.5 h-2.5 sm:w-3 sm:h-3" /> Stam</span>
                <span>{Math.round(gameState.player.stamina)}%</span>
              </div>
              <div className="h-1.5 sm:h-2 bg-stone-800 rounded-full overflow-hidden">
                <div
                  className="h-full bg-amber-400 transition-all"
                  style={{ width: `${gameState.player.stamina}%` }}
                />
              </div>
            </div>

            <div>
              <div className="flex justify-between text-orange-300 mb-0.5">
                <span className="flex items-center gap-1"><Utensils className="w-2.5 h-2.5 sm:w-3 sm:h-3" /> Food</span>
                <span>{Math.round(gameState.player.food)}%</span>
              </div>
              <div className="h-1 sm:h-1.5 bg-stone-800 rounded-full overflow-hidden">
                <div className="h-full bg-orange-400" style={{ width: `${gameState.player.food}%` }} />
              </div>
            </div>

            <div>
              <div className="flex justify-between text-sky-300 mb-0.5">
                <span className="flex items-center gap-1"><Droplets className="w-2.5 h-2.5 sm:w-3 sm:h-3" /> H2O</span>
                <span>{Math.round(gameState.player.water)}%</span>
              </div>
              <div className="h-1 sm:h-1.5 bg-stone-800 rounded-full overflow-hidden">
                <div className="h-full bg-sky-400" style={{ width: `${gameState.player.water}%` }} />
              </div>
            </div>
          </div>
        </div>

        {/* Minimal Objective Reminder (Hidden on tiny screens to save space, visible on sm+) */}
        <div className="hidden sm:block bg-stone-900/85 border border-stone-700/80 rounded-xl px-3 py-2 text-xs shadow-lg">
          <div className="font-semibold text-amber-300 flex items-center justify-between">
            <span>Shelter Life-Support Restoration</span>
            <span>{completedRestorations}/3</span>
          </div>
          <div className="mt-1 space-y-0.5 text-stone-300">
            <div className={gameState.mainRestore.waterRestored ? 'line-through text-emerald-400' : ''}>
              • Clean Water Osmosis (Coolant Basin)
            </div>
            <div className={gameState.mainRestore.powerRestored ? 'line-through text-emerald-400' : ''}>
              • Cryo-Capacitor Bank (Cable Forest)
            </div>
            <div className={gameState.mainRestore.sunlightRestored ? 'line-through text-emerald-400' : ''}>
              • Heliostat Sun Mirror (Dead Foundry)
            </div>
          </div>
        </div>
      </div>

      {/* YUNA DIALOGUE / THOUGHT BUBBLE */}
      {speechBubble && (
        <div className="absolute top-14 sm:top-4 left-1/2 -translate-x-1/2 bg-amber-950/95 border border-amber-400/50 text-amber-100 px-3 sm:px-4 py-1.5 sm:py-2 rounded-2xl shadow-xl text-xs sm:text-sm italic max-w-[85vw] sm:max-w-md text-center pointer-events-none z-20">
          “{speechBubble.text}”
        </div>
      )}

      {/* TOAST NOTIFICATION */}
      {notification && (
        <div className="absolute top-24 sm:top-16 left-1/2 -translate-x-1/2 bg-stone-900/95 border border-emerald-400/50 text-emerald-200 px-3 sm:px-4 py-1 sm:py-1.5 rounded-full shadow-lg text-[11px] sm:text-xs font-medium pointer-events-none z-20 whitespace-nowrap">
          {notification}
        </div>
      )}

      {/* TOP-RIGHT ACTION BAR (Compact & Scrollable on Mobile) */}
      <div className="absolute top-2 right-2 sm:top-3 sm:right-3 flex flex-wrap justify-end gap-1 sm:gap-1.5 max-w-[52vw] sm:max-w-none z-10">
        <button
          onClick={() => setActiveModal(prev => (prev === 'inventory' ? null : 'inventory'))}
          className="bg-stone-900/90 hover:bg-stone-800 border border-stone-700 px-2 sm:px-3 py-1.5 sm:py-2 rounded-xl text-[11px] sm:text-xs font-medium flex items-center gap-1 shadow-lg"
        >
          <Package className="w-3.5 h-3.5 sm:w-4 sm:h-4 text-amber-400" />
          <span className="hidden md:inline">Backpack</span> ({gameState.inventory.length}/{maxBackpackSlots})
        </button>

        {gameState.region === 'shelter' && (
          <>
            <button
              onClick={() => setActiveModal(prev => (prev === 'cooking' ? null : 'cooking'))}
              className="bg-stone-900/90 hover:bg-stone-800 border border-stone-700 px-2 sm:px-3 py-1.5 sm:py-2 rounded-xl text-[11px] sm:text-xs font-medium flex items-center gap-1 shadow-lg"
            >
              <Coffee className="w-3.5 h-3.5 sm:w-4 sm:h-4 text-orange-400" />
              <span className="hidden sm:inline">Cook</span>
            </button>
            <button
              onClick={() => setActiveModal(prev => (prev === 'crafting' ? null : 'crafting'))}
              className="bg-stone-900/90 hover:bg-stone-800 border border-stone-700 px-2 sm:px-3 py-1.5 sm:py-2 rounded-xl text-[11px] sm:text-xs font-medium flex items-center gap-1 shadow-lg"
            >
              <Hammer className="w-3.5 h-3.5 sm:w-4 sm:h-4 text-sky-400" />
              <span className="hidden sm:inline">Craft</span>
            </button>
            <button
              onClick={() => setActiveModal(prev => (prev === 'decorate' ? null : 'decorate'))}
              className="bg-stone-900/90 hover:bg-stone-800 border border-stone-700 px-2 sm:px-3 py-1.5 sm:py-2 rounded-xl text-[11px] sm:text-xs font-medium flex items-center gap-1 shadow-lg"
            >
              <Sparkles className="w-3.5 h-3.5 sm:w-4 sm:h-4 text-pink-400" />
              <span className="hidden sm:inline">Decorate</span>
            </button>
            <button
              onClick={() => setActiveModal(prev => (prev === 'upgrades' ? null : 'upgrades'))}
              className="bg-stone-900/90 hover:bg-stone-800 border border-amber-500/40 px-2 sm:px-3 py-1.5 sm:py-2 rounded-xl text-[11px] sm:text-xs font-medium flex items-center gap-1 shadow-lg"
            >
              <Wrench className="w-3.5 h-3.5 sm:w-4 sm:h-4 text-emerald-400" />
              <span className="hidden sm:inline">Systems</span>
            </button>
          </>
        )}

        <button
          onClick={() => setActiveModal(prev => (prev === 'journal' ? null : 'journal'))}
          className="bg-amber-950/90 hover:bg-amber-900 border border-amber-500/50 px-2 sm:px-3 py-1.5 sm:py-2 rounded-xl text-[11px] sm:text-xs font-medium flex items-center gap-1 shadow-lg text-amber-200"
          title="Yuna's AI Journal & Voice Reflections"
        >
          <BookOpen className="w-3.5 h-3.5 sm:w-4 sm:h-4 text-amber-400" />
          <span className="hidden sm:inline">✨ Journal</span>
        </button>

        <button
          onClick={() => setActiveModal(prev => (prev === 'radio' ? null : 'radio'))}
          className="bg-sky-950/90 hover:bg-sky-900 border border-sky-500/50 px-2 sm:px-3 py-1.5 sm:py-2 rounded-xl text-[11px] sm:text-xs font-medium flex items-center gap-1 shadow-lg text-sky-200"
          title="Vacuum Radio Telemetry Decoder"
        >
          <Radio className="w-3.5 h-3.5 sm:w-4 sm:h-4 text-sky-400" />
          <span className="hidden sm:inline">✨ Radio</span>
        </button>

        <button
          onClick={() => setActiveModal(prev => (prev === 'map' ? null : 'map'))}
          className="bg-stone-900/90 hover:bg-stone-800 border border-stone-700 px-2 sm:px-3 py-1.5 sm:py-2 rounded-xl text-[11px] sm:text-xs font-medium flex items-center gap-1 shadow-lg"
        >
          <MapPin className="w-3.5 h-3.5 sm:w-4 sm:h-4 text-cyan-400" />
          <span className="hidden sm:inline">Regions</span>
        </button>

        <button
          onClick={() => {
            spriteAtlas.init();
            setActiveModal(prev => (prev === 'sprites' ? null : 'sprites'));
          }}
          className="bg-stone-900/90 hover:bg-stone-800 border border-pink-500/40 px-2 sm:px-3 py-1.5 sm:py-2 rounded-xl text-[11px] sm:text-xs font-medium flex items-center gap-1 shadow-lg text-pink-200"
          title="Inspect Pre-Baked Game Spritesheets & Atlas"
        >
          <Palette className="w-3.5 h-3.5 sm:w-4 sm:h-4 text-pink-400" />
          <span className="hidden md:inline">Sprites</span>
        </button>

        <button
          onClick={() => {
            refreshSlots();
            setActiveModal(prev => (prev === 'saves' ? null : 'saves'));
          }}
          className="bg-stone-900/90 hover:bg-stone-800 border border-stone-700 px-2 sm:px-3 py-1.5 sm:py-2 rounded-xl text-[11px] sm:text-xs font-medium flex items-center gap-1 shadow-lg"
        >
          <Settings className="w-3.5 h-3.5 sm:w-4 sm:h-4 text-emerald-400" />
          <span className="hidden md:inline">Settings</span>
        </button>

        <button
          onClick={() => {
            sound.muted = !muted;
            setMuted(!muted);
          }}
          className="bg-stone-900/90 hover:bg-stone-800 border border-stone-700 p-1.5 sm:p-2 rounded-xl text-xs shadow-lg"
          title="Toggle Sound"
        >
          {muted ? <VolumeX className="w-3.5 h-3.5 sm:w-4 sm:h-4 text-rose-400" /> : <Volume2 className="w-3.5 h-3.5 sm:w-4 sm:h-4 text-amber-400" />}
        </button>
      </div>

      {/* CONTEXTUAL INTERACTION BANNER */}
      {runtimeRef.current.promptText && (
        <div className="absolute bottom-20 sm:bottom-24 left-1/2 -translate-x-1/2 bg-stone-900/95 border border-amber-400/60 px-3 sm:px-4 py-1.5 sm:py-2 rounded-xl text-[11px] sm:text-xs font-semibold text-amber-200 shadow-xl flex items-center gap-2 z-20 max-w-[92vw]">
          <span className="truncate">{runtimeRef.current.promptText}</span>
          <button
            onClick={handleContextInteract}
            className="bg-amber-500 hover:bg-amber-400 active:scale-95 text-stone-950 px-2.5 py-1 rounded-lg font-bold shrink-0"
          >
            Interact
          </button>
        </div>
      )}

      {/* PLACEMENT MODE ACTIVE BANNER */}
      {placingFurniture && (
        <div className="absolute bottom-20 sm:bottom-24 left-1/2 -translate-x-1/2 bg-amber-950/95 border border-amber-400 px-3 sm:px-4 py-2 rounded-xl text-xs text-amber-100 flex items-center gap-3 shadow-2xl z-20 max-w-[90vw]">
          <span>Tap or click inside the shelter floor to place furnishing</span>
          <button
            onClick={() => setPlacingFurniture(null)}
            className="bg-rose-600 hover:bg-rose-500 text-white px-2.5 py-1 rounded-lg font-semibold shrink-0"
          >
            Cancel
          </button>
        </div>
      )}

      {/* =====================================================================
          VIRTUAL MOBILE TOUCH CONTROLS (VISIBLE ON SMALL SCREENS OR WHEN ENABLED)
         ===================================================================== */}
      {showMobileControls && !activeModal && !openContainer && (
        <>
          {/* LEFT VIRTUAL THUMBSTICK: MOVEMENT */}
          <div className="absolute bottom-16 left-4 sm:bottom-20 sm:left-6 z-20 flex flex-col items-center gap-2">
            <div
              onTouchStart={handleMoveTouch}
              onTouchMove={handleMoveTouch}
              onTouchEnd={handleMoveTouchEnd}
              onTouchCancel={handleMoveTouchEnd}
              className="w-28 h-28 sm:w-32 sm:h-32 rounded-full bg-stone-900/65 border-2 border-amber-400/40 backdrop-blur-xs relative flex items-center justify-center shadow-2xl active:border-amber-400"
            >
              <div className="text-[9px] uppercase tracking-widest text-amber-200/40 font-bold pointer-events-none">
                Move
              </div>
              <div
                style={{
                  transform: `translate(${joyVisual.dx}px, ${joyVisual.dy}px)`
                }}
                className="w-11 h-11 rounded-full bg-amber-500/80 border-2 border-amber-200 shadow-lg pointer-events-none transition-transform duration-75"
              />
            </div>

            {/* Sprint & Sneak Mobile Toggles */}
            <div className="flex gap-1.5">
              <button
                onTouchStart={(e) => {
                  e.preventDefault();
                  setSprintToggle(prev => !prev);
                }}
                onClick={() => setSprintToggle(prev => !prev)}
                className={`px-2.5 py-1 rounded-lg text-[10px] font-bold border shadow ${
                  sprintToggle
                    ? 'bg-amber-500 text-stone-950 border-amber-300'
                    : 'bg-stone-900/85 text-stone-300 border-stone-700'
                }`}
              >
                Sprint {sprintToggle ? 'ON' : 'OFF'}
              </button>
              <button
                onTouchStart={(e) => {
                  e.preventDefault();
                  setGameState(prev => ({
                    ...prev,
                    player: { ...prev.player, crouching: !prev.player.crouching }
                  }));
                }}
                onClick={() =>
                  setGameState(prev => ({
                    ...prev,
                    player: { ...prev.player, crouching: !prev.player.crouching }
                  }))
                }
                className={`px-2.5 py-1 rounded-lg text-[10px] font-bold border shadow ${
                  gameState.player.crouching
                    ? 'bg-sky-500 text-stone-950 border-sky-300'
                    : 'bg-stone-900/85 text-stone-300 border-stone-700'
                }`}
              >
                {gameState.player.crouching ? 'Sneaking' : 'Sneak'}
              </button>
            </div>
          </div>

          {/* RIGHT VIRTUAL CONTROLS: AIM/FIRE JOYSTICK + INTERACT & RELOAD BUTTONS */}
          <div className="absolute bottom-16 right-4 sm:bottom-20 sm:right-6 z-20 flex flex-col items-end gap-2">
            {/* Quick Action Buttons Row */}
            <div className="flex items-center gap-2">
              {gameState.region !== 'shelter' && (
                <button
                  onTouchStart={(e) => {
                    e.preventDefault();
                    triggerManualReload();
                  }}
                  onClick={triggerManualReload}
                  className="bg-stone-900/90 active:bg-amber-500 active:text-stone-950 border border-amber-400/50 text-amber-200 px-3 py-2 rounded-xl text-xs font-bold shadow-lg flex items-center gap-1"
                >
                  <RotateCcw className="w-3.5 h-3.5" /> Reload
                </button>
              )}
              <button
                onTouchStart={(e) => {
                  e.preventDefault();
                  handleContextInteract();
                }}
                onClick={handleContextInteract}
                className="bg-amber-500 active:bg-amber-400 text-stone-950 border border-amber-300 px-3.5 py-2 rounded-xl text-xs font-bold shadow-xl flex items-center gap-1"
              >
                <Sparkles className="w-3.5 h-3.5" /> Interact
              </button>
            </div>

            {/* Aim & Fire Dual-Stick (Outside Shelter) or Quick Sleep/Decorate (Inside Shelter) */}
            {gameState.region !== 'shelter' ? (
              <div
                onTouchStart={handleAimTouch}
                onTouchMove={handleAimTouch}
                onTouchEnd={handleAimTouchEnd}
                onTouchCancel={handleAimTouchEnd}
                className="w-28 h-28 sm:w-32 sm:h-32 rounded-full bg-rose-950/60 border-2 border-rose-400/50 backdrop-blur-xs relative flex items-center justify-center shadow-2xl active:border-rose-400"
              >
                <div className="text-[9px] uppercase tracking-widest text-rose-200/60 font-bold text-center pointer-events-none">
                  Aim &<br />Fire
                </div>
                <div
                  style={{
                    transform: `translate(${aimJoyVisual.dx}px, ${aimJoyVisual.dy}px)`
                  }}
                  className="w-11 h-11 rounded-full bg-rose-500/85 border-2 border-rose-200 shadow-lg pointer-events-none transition-transform duration-75"
                />
              </div>
            ) : (
              <div className="flex gap-1.5">
                <button
                  onClick={() => setActiveModal('map')}
                  className="bg-sky-600 hover:bg-sky-500 text-white px-3 py-2 rounded-xl text-xs font-bold shadow-lg flex items-center gap-1"
                >
                  <Compass className="w-3.5 h-3.5" /> Map
                </button>
                <button
                  onClick={sleepInBed}
                  className="bg-amber-600 hover:bg-amber-500 text-stone-950 px-3 py-2 rounded-xl text-xs font-bold shadow-lg flex items-center gap-1"
                >
                  <Bed className="w-3.5 h-3.5" /> Sleep
                </button>
              </div>
            )}
          </div>
        </>
      )}

      {/* BOTTOM HUD BAR: WEAPONS, STEALTH & QUICK CONSUMABLES (Responsive & Compact on Mobile) */}
      <div className="absolute bottom-2 sm:bottom-3 left-1/2 -translate-x-1/2 flex items-center gap-1 sm:gap-2 bg-stone-900/90 border border-stone-700/90 px-2.5 sm:px-4 py-1.5 sm:py-2 rounded-2xl shadow-2xl backdrop-blur-md max-w-[96vw] overflow-x-auto z-10">
        {/* Weapon 1: Pistol */}
        <button
          onClick={() => setGameState(prev => ({ ...prev, player: { ...prev.player, activeWeapon: 'pistol' } }))}
          className={`px-2 sm:px-3 py-1 sm:py-1.5 rounded-xl text-[11px] sm:text-xs flex items-center gap-1.5 border transition shrink-0 ${
            gameState.player.activeWeapon === 'pistol'
              ? 'bg-amber-500/20 border-amber-400 text-amber-200'
              : 'bg-stone-800/70 border-stone-700 text-stone-400'
          }`}
        >
          <Crosshair className="w-3 h-3 sm:w-3.5 sm:h-3.5" />
          <div className="text-left">
            <div className="font-bold">Pistol</div>
            <div className="text-[9px] sm:text-[10px]">
              {gameState.player.pistolMag}/{getItemCount(gameState.inventory, 'pistol_ammo')}
            </div>
          </div>
        </button>

        {/* Weapon 2: Rifle */}
        <button
          onClick={() => setGameState(prev => ({ ...prev, player: { ...prev.player, activeWeapon: 'rifle' } }))}
          className={`px-2 sm:px-3 py-1 sm:py-1.5 rounded-xl text-[11px] sm:text-xs flex items-center gap-1.5 border transition shrink-0 ${
            gameState.player.activeWeapon === 'rifle'
              ? 'bg-amber-500/20 border-amber-400 text-amber-200'
              : 'bg-stone-800/70 border-stone-700 text-stone-400'
          }`}
        >
          <Crosshair className="w-3 h-3 sm:w-3.5 sm:h-3.5" />
          <div className="text-left">
            <div className="font-bold">Rifle</div>
            <div className="text-[9px] sm:text-[10px]">
              {gameState.player.rifleMag}/{getItemCount(gameState.inventory, 'rifle_ammo')}
            </div>
          </div>
        </button>

        {/* Stealth Crouch Toggle (Hidden on mobile bar when mobile controls already show it) */}
        <button
          onClick={() =>
            setGameState(prev => ({ ...prev, player: { ...prev.player, crouching: !prev.player.crouching } }))
          }
          className={`hidden sm:flex px-3 py-1.5 rounded-xl text-xs items-center gap-1.5 border shrink-0 ${
            gameState.player.crouching
              ? 'bg-sky-500/25 border-sky-400 text-sky-200'
              : 'bg-stone-800/70 border-stone-700 text-stone-400'
          }`}
        >
          {gameState.player.crouching ? <EyeOff className="w-3.5 h-3.5" /> : <Eye className="w-3.5 h-3.5" />}
          [C] {gameState.player.crouching ? 'Sneaking' : 'Standing'}
        </button>

        <div className="h-5 w-px bg-stone-700 mx-0.5 shrink-0" />

        {/* Quick-Use Slots */}
        {['repair_kit', 'warm_stew', 'clean_water', 'decoy_beacon'].map(itemId => {
          const count = getItemCount(gameState.inventory, itemId);
          const def = ITEMS[itemId];
          return (
            <button
              key={itemId}
              disabled={count <= 0}
              onClick={() => useItem(itemId, false)}
              className={`px-2 sm:px-2.5 py-1 sm:py-1.5 rounded-xl text-[11px] sm:text-xs flex items-center gap-1 border shrink-0 ${
                count > 0
                  ? 'bg-stone-800 hover:bg-stone-700 border-stone-600 text-stone-100'
                  : 'bg-stone-900/50 border-stone-800 text-stone-600 cursor-not-allowed'
              }`}
              title={`Use ${def.name}`}
            >
              <span>{def.icon}</span>
              <span className="font-mono font-bold">x{count}</span>
            </button>
          );
        })}

        {gameState.region === 'shelter' && !showMobileControls && (
          <button
            onClick={sleepInBed}
            className="bg-amber-600 hover:bg-amber-500 text-stone-950 font-bold px-3 py-1.5 rounded-xl text-xs flex items-center gap-1.5 ml-1 shrink-0"
          >
            <Bed className="w-3.5 h-3.5" /> Sleep
          </button>
        )}
      </div>

      {/* =====================================================================
          MODAL 1: LOOTING SALVAGE CONTAINER
         ===================================================================== */}
      {openContainer && (
        <div className="fixed inset-0 bg-black/60 backdrop-blur-xs flex items-center justify-center z-50 p-4">
          <div className="bg-stone-900 border border-amber-500/40 rounded-2xl max-w-md w-full p-5 shadow-2xl">
            <div className="flex justify-between items-center mb-3">
              <h3 className="text-base font-bold text-amber-300 flex items-center gap-2">
                <Box className="w-5 h-5" />
                {openContainer.isRare ? 'High-Priority Machine Cache' : 'Salvage Container'}
              </h3>
              <button
                onClick={() => setOpenContainer(null)}
                className="text-stone-400 hover:text-white text-xs px-2 py-1 rounded bg-stone-800"
              >
                Close [Esc]
              </button>
            </div>
            <div className="space-y-2 mb-4">
              {openContainer.loot.map((item, idx) => {
                const def = ITEMS[item.id];
                return (
                  <div
                    key={idx}
                    className="flex items-center justify-between bg-stone-800/90 border border-stone-700 p-2.5 rounded-xl"
                  >
                    <div className="flex items-center gap-2.5">
                      <span className="text-xl">{def?.icon}</span>
                      <div>
                        <div className="text-sm font-semibold text-stone-100">
                          {def?.name} <span className="text-amber-400">x{item.count}</span>
                        </div>
                        <div className="text-xs text-stone-400">{def?.desc}</div>
                      </div>
                    </div>
                    <button
                      onClick={() => takeContainerLoot(item, idx)}
                      className="bg-amber-500 hover:bg-amber-400 text-stone-950 font-bold text-xs px-3 py-1.5 rounded-lg"
                    >
                      Take
                    </button>
                  </div>
                );
              })}
            </div>
          </div>
        </div>
      )}

      {/* =====================================================================
          MODAL 2: BACKPACK & SHELTER STORAGE LOCKER
         ===================================================================== */}
      {activeModal === 'inventory' && (
        <div className="fixed inset-0 bg-black/65 backdrop-blur-xs flex items-center justify-center z-50 p-4">
          <div className="bg-stone-900 border border-stone-700 rounded-2xl max-w-4xl w-full p-6 shadow-2xl max-h-[86vh] overflow-y-auto">
            <div className="flex justify-between items-center mb-4">
              <div>
                <h2 className="text-lg font-bold text-amber-300">Yuna’s Backpack & Shelter Storage</h2>
                <p className="text-xs text-stone-400">
                  Click items to use consumables or transfer between your backpack and shelter cabinets.
                </p>
              </div>
              <button
                onClick={() => setActiveModal(null)}
                className="bg-stone-800 hover:bg-stone-700 px-3 py-1.5 rounded-xl text-xs"
              >
                Close [Tab / Esc]
              </button>
            </div>

            <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
              {/* Backpack Column */}
              <div className="bg-stone-950/70 border border-stone-800 rounded-xl p-4">
                <h3 className="text-sm font-bold text-stone-200 mb-3 flex justify-between">
                  <span>Compact Backpack</span>
                  <span className="text-amber-400">{gameState.inventory.length} / {maxBackpackSlots} Slots</span>
                </h3>
                <div className="space-y-2">
                  {gameState.inventory.map((slot, i) => {
                    const def = ITEMS[slot.id];
                    return (
                      <div
                        key={i}
                        className="flex items-center justify-between bg-stone-900 border border-stone-800 px-3 py-2 rounded-xl"
                      >
                        <div className="flex items-center gap-2.5">
                          <span className="text-lg">{def?.icon}</span>
                          <div>
                            <div className="text-xs font-bold text-stone-100">
                              {def?.name} <span className="text-amber-400">x{slot.count}</span>
                            </div>
                            <div className="text-[11px] text-stone-400">{def?.desc}</div>
                          </div>
                        </div>
                        <div className="flex items-center gap-1.5">
                          <button
                            disabled={analyzingItemId === slot.id}
                            onClick={() => analyzeArtifactWithYuna(slot.id)}
                            className="bg-amber-950/80 hover:bg-amber-900 border border-amber-500/40 text-amber-200 text-[11px] px-2 py-1 rounded-lg flex items-center gap-1"
                            title="Ask Yuna to inspect & analyze this item with Gemini"
                          >
                            {analyzingItemId === slot.id ? (
                              <Loader2 className="w-3 h-3 animate-spin" />
                            ) : (
                              <Sparkles className="w-3 h-3 text-amber-400" />
                            )}
                            Inspect
                          </button>
                          {(def?.food || def?.water || def?.health || slot.id === 'decoy_beacon') && (
                            <button
                              onClick={() => useItem(slot.id, false)}
                              className="bg-emerald-600 hover:bg-emerald-500 text-white text-[11px] px-2.5 py-1 rounded-lg font-semibold"
                            >
                              Use
                            </button>
                          )}
                          {gameState.region === 'shelter' && (
                            <button
                              onClick={() => {
                                setGameState(prev => {
                                  const { list: nextSt, added } = addItemsToList(
                                    prev.storage,
                                    slot.id,
                                    slot.count,
                                    maxStorageSlots
                                  );
                                  if (added <= 0) return prev;
                                  const nextInv = prev.inventory.filter((_, idx) => idx !== i);
                                  return { ...prev, inventory: nextInv, storage: nextSt };
                                });
                              }}
                              className="bg-stone-700 hover:bg-stone-600 text-stone-200 text-[11px] px-2.5 py-1 rounded-lg"
                            >
                              Store →
                            </button>
                          )}
                        </div>
                      </div>
                    );
                  })}
                </div>
              </div>

              {/* Shelter Storage Column */}
              <div className="bg-stone-950/70 border border-stone-800 rounded-xl p-4">
                <h3 className="text-sm font-bold text-stone-200 mb-3 flex justify-between">
                  <span>Shelter Storage Lockers</span>
                  <span className="text-sky-400">{gameState.storage.length} / {maxStorageSlots} Slots</span>
                </h3>
                {gameState.region !== 'shelter' ? (
                  <p className="text-xs text-stone-400 italic py-8 text-center">
                    Return inside the shelter to transfer supplies to or from your cabinets.
                  </p>
                ) : (
                  <div className="space-y-2">
                    {gameState.storage.map((slot, i) => {
                      const def = ITEMS[slot.id];
                      return (
                        <div
                          key={i}
                          className="flex items-center justify-between bg-stone-900 border border-stone-800 px-3 py-2 rounded-xl"
                        >
                          <div className="flex items-center gap-2.5">
                            <span className="text-lg">{def?.icon}</span>
                            <div>
                              <div className="text-xs font-bold text-stone-100">
                                {def?.name} <span className="text-sky-400">x{slot.count}</span>
                              </div>
                              <div className="text-[11px] text-stone-400">{def?.desc}</div>
                            </div>
                          </div>
                          <button
                            onClick={() => {
                              setGameState(prev => {
                                const { list: nextInv, added } = addItemsToList(
                                  prev.inventory,
                                  slot.id,
                                  slot.count,
                                  maxBackpackSlots
                                );
                                if (added <= 0) return prev;
                                const nextSt = prev.storage.filter((_, idx) => idx !== i);
                                return { ...prev, inventory: nextInv, storage: nextSt };
                              });
                            }}
                            className="bg-amber-600 hover:bg-amber-500 text-stone-950 font-semibold text-[11px] px-2.5 py-1 rounded-lg"
                          >
                            ← Take
                          </button>
                        </div>
                      );
                    })}
                  </div>
                )}
              </div>
            </div>

            {/* Gemini Item Inspection Insight Card */}
            {itemAnalysis && (
              <div className="mt-4 bg-amber-950/40 border border-amber-500/40 rounded-xl p-4 flex items-start justify-between gap-4">
                <div className="flex items-start gap-3">
                  <span className="text-2xl">{itemAnalysis.icon}</span>
                  <div>
                    <div className="text-xs font-bold uppercase tracking-wider text-amber-300 flex items-center gap-1.5">
                      <Sparkles className="w-3.5 h-3.5" /> Yuna’s Technical Inspection: {itemAnalysis.itemName}
                    </div>
                    <p className="text-xs text-stone-200 italic mt-1">“{itemAnalysis.observation}”</p>
                    <p className="text-[11px] text-emerald-300 mt-1 font-medium">
                      💡 Tinkerer’s Note: {itemAnalysis.tinkerTip}
                    </p>
                  </div>
                </div>
                <button
                  onClick={() => setItemAnalysis(null)}
                  className="text-xs text-stone-400 hover:text-white px-2 py-1 bg-stone-800 rounded"
                >
                  Dismiss
                </button>
              </div>
            )}
          </div>
        </div>
      )}

      {/* =====================================================================
          MODAL 3: CRAFTING & COOKING STATIONS
         ===================================================================== */}
      {(activeModal === 'crafting' || activeModal === 'cooking') && (
        <div className="fixed inset-0 bg-black/65 backdrop-blur-xs flex items-center justify-center z-50 p-4">
          <div className="bg-stone-900 border border-stone-700 rounded-2xl max-w-2xl w-full p-6 shadow-2xl max-h-[85vh] overflow-y-auto">
            <div className="flex justify-between items-center mb-4">
              <div>
                <h2 className="text-lg font-bold text-amber-300">
                  {activeModal === 'cooking' ? 'Cooking Corner & Kettle' : 'Shelter Workbench & Electronics'}
                </h2>
                <p className="text-xs text-stone-400">
                  Uses materials from both Yuna’s backpack and shelter storage lockers.
                </p>
              </div>
              <button
                onClick={() => setActiveModal(null)}
                className="bg-stone-800 hover:bg-stone-700 px-3 py-1.5 rounded-xl text-xs"
              >
                Close [Esc]
              </button>
            </div>

            <div className="space-y-2.5">
              {RECIPES.filter(r => (activeModal === 'cooking' ? r.station === 'cooking' : r.station === 'workbench')).map(
                recipe => {
                  const canMake = hasMaterials(recipe.cost, true);
                  const outDef = ITEMS[recipe.output.id];
                  return (
                    <div
                      key={recipe.id}
                      className="flex items-center justify-between bg-stone-950/80 border border-stone-800 p-3.5 rounded-xl"
                    >
                      <div className="flex items-center gap-3">
                        <span className="text-2xl">{outDef?.icon}</span>
                        <div>
                          <div className="text-sm font-bold text-stone-100">{recipe.name}</div>
                          <div className="text-xs text-stone-400 mb-1.5">{recipe.desc}</div>
                          <div className="flex flex-wrap gap-2">
                            {Object.entries(recipe.cost).map(([cid, qty]) => {
                              const have =
                                getItemCount(gameState.inventory, cid) + getItemCount(gameState.storage, cid);
                              return (
                                <span
                                  key={cid}
                                  className={`text-[11px] px-2 py-0.5 rounded-md border ${
                                    have >= qty
                                      ? 'bg-emerald-950/60 border-emerald-700 text-emerald-300'
                                      : 'bg-rose-950/60 border-rose-800 text-rose-300'
                                  }`}
                                >
                                  {ITEMS[cid]?.icon} {ITEMS[cid]?.name}: {have}/{qty}
                                </span>
                              );
                            })}
                          </div>
                        </div>
                      </div>
                      <button
                        disabled={!canMake}
                        onClick={() => handleCraft(recipe)}
                        className={`px-4 py-2 rounded-xl text-xs font-bold ${
                          canMake
                            ? 'bg-amber-500 hover:bg-amber-400 text-stone-950'
                            : 'bg-stone-800 text-stone-500 cursor-not-allowed'
                        }`}
                      >
                        {activeModal === 'cooking' ? 'Cook' : 'Craft'}
                      </button>
                    </div>
                  );
                }
              )}
            </div>
          </div>
        </div>
      )}

      {/* =====================================================================
          MODAL 4: SHELTER DECORATION CATALOG (15 ITEMS)
         ===================================================================== */}
      {activeModal === 'decorate' && (
        <div className="fixed inset-0 bg-black/65 backdrop-blur-xs flex items-center justify-center z-50 p-4">
          <div className="bg-stone-900 border border-stone-700 rounded-2xl max-w-3xl w-full p-6 shadow-2xl max-h-[85vh] overflow-y-auto">
            <div className="flex justify-between items-center mb-4">
              <div>
                <h2 className="text-lg font-bold text-amber-300">Cozy Shelter Furnishings & Decor</h2>
                <p className="text-xs text-stone-400">
                  Craft and place warm lamps, rugs, planters, and keepsakes inside Yuna’s home.
                </p>
              </div>
              <button
                onClick={() => setActiveModal(null)}
                className="bg-stone-800 hover:bg-stone-700 px-3 py-1.5 rounded-xl text-xs"
              >
                Close [Esc]
              </button>
            </div>

            <div className="grid grid-cols-1 md:grid-cols-2 gap-3 mb-6">
              {FURNITURE_CATALOG.map(furn => {
                const affordable = hasMaterials(furn.cost, true);
                return (
                  <div
                    key={furn.id}
                    className="bg-stone-950/80 border border-stone-800 p-3 rounded-xl flex flex-col justify-between"
                  >
                    <div>
                      <div className="flex items-center justify-between mb-1">
                        <span className="text-sm font-bold text-stone-100">{furn.name}</span>
                        <span className="text-[10px] uppercase px-2 py-0.5 rounded bg-stone-800 text-amber-300">
                          {furn.w}x{furn.h} Grid
                        </span>
                      </div>
                      <p className="text-xs text-stone-400 mb-2">{furn.desc}</p>
                      <div className="flex flex-wrap gap-1.5 mb-3">
                        {Object.entries(furn.cost).map(([cid, qty]) => {
                          const have =
                            getItemCount(gameState.inventory, cid) + getItemCount(gameState.storage, cid);
                          return (
                            <span
                              key={cid}
                              className={`text-[10px] px-1.5 py-0.5 rounded ${
                                have >= qty ? 'bg-stone-800 text-emerald-300' : 'bg-stone-900 text-rose-400'
                              }`}
                            >
                              {ITEMS[cid]?.name}: {have}/{qty}
                            </span>
                          );
                        })}
                      </div>
                    </div>
                    <button
                      disabled={!affordable}
                      onClick={() => {
                        setPlacingFurniture({ id: furn.id, rot: 0 });
                        setActiveModal(null);
                      }}
                      className={`w-full py-1.5 rounded-lg text-xs font-bold ${
                        affordable
                          ? 'bg-amber-500 hover:bg-amber-400 text-stone-950'
                          : 'bg-stone-800 text-stone-500 cursor-not-allowed'
                      }`}
                    >
                      Select & Place in Shelter
                    </button>
                  </div>
                );
              })}
            </div>

            {/* Placed Furnishings List (Allow Rearranging/Removing) */}
            <h3 className="text-xs font-bold uppercase tracking-wider text-stone-400 mb-2">
              Currently Placed in Shelter ({gameState.furniture.length})
            </h3>
            <div className="flex flex-wrap gap-2">
              {gameState.furniture.map(f => {
                const def = FURNITURE_CATALOG.find(item => item.id === f.id);
                return (
                  <div
                    key={f.uid}
                    className="bg-stone-800 border border-stone-700 px-3 py-1 rounded-lg text-xs flex items-center gap-2"
                  >
                    <span>{def?.name}</span>
                    {f.id !== 'cozy_bed' && (
                      <button
                        onClick={() => {
                          setGameState(prev => ({
                            ...prev,
                            furniture: prev.furniture.filter(item => item.uid !== f.uid)
                          }));
                        }}
                        className="text-rose-400 hover:text-rose-300"
                        title="Remove"
                      >
                        <Trash2 className="w-3.5 h-3.5" />
                      </button>
                    )}
                  </div>
                );
              })}
            </div>
          </div>
        </div>
      )}

      {/* =====================================================================
          MODAL 5: ENVIRONMENTAL RESTORATION & EQUIPMENT UPGRADES
         ===================================================================== */}
      {activeModal === 'upgrades' && (
        <div className="fixed inset-0 bg-black/65 backdrop-blur-xs flex items-center justify-center z-50 p-4">
          <div className="bg-stone-900 border border-stone-700 rounded-2xl max-w-3xl w-full p-6 shadow-2xl max-h-[86vh] overflow-y-auto">
            <div className="flex justify-between items-center mb-4">
              <div>
                <h2 className="text-lg font-bold text-amber-300">
                  Shelter Environmental Restoration & Equipment Tuning
                </h2>
                <p className="text-xs text-stone-400">
                  Restore the three degrading life-support systems to make Yuna’s underground home truly self-sustaining.
                </p>
              </div>
              <button
                onClick={() => setActiveModal(null)}
                className="bg-stone-800 hover:bg-stone-700 px-3 py-1.5 rounded-xl text-xs"
              >
                Close [Esc]
              </button>
            </div>

            {/* 3 Primary Story Restoration Objectives */}
            <div className="space-y-3 mb-6">
              {[
                {
                  key: 'water',
                  done: gameState.mainRestore.waterRestored,
                  title: '1. Clean Water Osmosis Purifier',
                  desc: 'Requires the Osmotic Membrane Core from the Coolant Basin plus 2 Coolant Filters & 3 Mechanical Parts.',
                  cost: { quest_water_core: 1, coolant_filter: 2, mech_parts: 3 }
                },
                {
                  key: 'power',
                  done: gameState.mainRestore.powerRestored,
                  title: '2. Reliable Cryo-Capacitor Energy Storage',
                  desc: 'Requires the Cryo-Capacitor Bank from the Cable Forest plus 2 High-Density Power Cells & 3 Electronic Components.',
                  cost: { quest_power_core: 1, power_cell: 2, elec_comp: 3 }
                },
                {
                  key: 'sunlight',
                  done: gameState.mainRestore.sunlightRestored,
                  title: '3. Protected Upper Sunlight Heliostat Array',
                  desc: 'Requires the Heliostat Fokus Array from the Dead Foundry plus 2 Optical Modules & 4 Copper Wiring.',
                  cost: { quest_sun_mirror: 1, optical_mod: 2, copper_wire: 4 }
                }
              ].map(sys => {
                const ready = hasMaterials(sys.cost, true);
                return (
                  <div
                    key={sys.key}
                    className={`p-4 rounded-xl border flex items-center justify-between ${
                      sys.done
                        ? 'bg-emerald-950/35 border-emerald-600/50'
                        : 'bg-stone-950/80 border-stone-800'
                    }`}
                  >
                    <div>
                      <div className="text-sm font-bold text-stone-100 flex items-center gap-2">
                        {sys.title}
                        {sys.done && <span className="text-xs text-emerald-400">(RESTORED ✓)</span>}
                      </div>
                      <p className="text-xs text-stone-400 mt-0.5">{sys.desc}</p>
                    </div>
                    {!sys.done && (
                      <button
                        disabled={!ready}
                        onClick={() => restoreMajorSystem(sys.key)}
                        className={`px-4 py-2 rounded-xl text-xs font-bold shrink-0 ${
                          ready
                            ? 'bg-emerald-500 hover:bg-emerald-400 text-stone-950'
                            : 'bg-stone-800 text-stone-500 cursor-not-allowed'
                        }`}
                      >
                        Restore System
                      </button>
                    )}
                  </div>
                );
              })}
            </div>

            {/* Equipment Upgrades */}
            <h3 className="text-sm font-bold text-amber-300 mb-3">Yuna’s Equipment & Weapon Upgrades</h3>
            <div className="grid grid-cols-1 md:grid-cols-3 gap-3">
              {[
                {
                  key: 'pistolLevel',
                  name: '9mm Pistol Tuning',
                  cost: { mech_parts: 3, scrap_metal: 4 },
                  desc: 'Improves damage, recoil stability, and magazine capacity.'
                },
                {
                  key: 'rifleLevel',
                  name: 'Rifle Barrel Calibration',
                  cost: { mech_parts: 4, optical_mod: 1, elec_comp: 2 },
                  desc: 'Increases slug velocity, armor penetration, and clip size.'
                },
                {
                  key: 'backpackLevel',
                  name: 'Expanded Pack Frame',
                  cost: { fabric_insul: 4, scrap_metal: 3 },
                  desc: 'Adds +5 carrying capacity slots to Yuna’s scavenging backpack.'
                }
              ].map(up => {
                const lvl = gameState.equipmentUpgrades[up.key];
                const canUp = lvl < 3 && hasMaterials(up.cost, true);
                return (
                  <div key={up.key} className="bg-stone-950/80 border border-stone-800 p-3.5 rounded-xl flex flex-col justify-between">
                    <div>
                      <div className="text-xs font-bold text-stone-100 flex justify-between">
                        <span>{up.name}</span>
                        <span className="text-amber-400">Lv.{lvl}/3</span>
                      </div>
                      <p className="text-[11px] text-stone-400 my-1.5">{up.desc}</p>
                    </div>
                    <button
                      disabled={!canUp}
                      onClick={() => {
                        setGameState(prev => {
                          const { nextInv, nextStorage } = removeItemsFromLists(prev.inventory, prev.storage, up.cost, true);
                          sound.sfxCraft();
                          return {
                            ...prev,
                            inventory: nextInv,
                            storage: nextStorage,
                            equipmentUpgrades: {
                              ...prev.equipmentUpgrades,
                              [up.key]: prev.equipmentUpgrades[up.key] + 1
                            }
                          };
                        });
                      }}
                      className={`w-full py-1.5 rounded-lg text-xs font-bold mt-2 ${
                        lvl >= 3
                          ? 'bg-emerald-950 text-emerald-400'
                          : canUp
                          ? 'bg-amber-500 hover:bg-amber-400 text-stone-950'
                          : 'bg-stone-800 text-stone-500'
                      }`}
                    >
                      {lvl >= 3 ? 'Max Level' : 'Upgrade'}
                    </button>
                  </div>
                );
              })}
            </div>
          </div>
        </div>
      )}

      {/* =====================================================================
          MODAL 6: MACHINE WASTELAND REGION MAP
         ===================================================================== */}
      {activeModal === 'map' && (
        <div className="fixed inset-0 bg-black/65 backdrop-blur-xs flex items-center justify-center z-50 p-4">
          <div className="bg-stone-900 border border-stone-700 rounded-2xl max-w-3xl w-full p-6 shadow-2xl max-h-[86vh] overflow-y-auto">
            <div className="flex justify-between items-center mb-4">
              <div>
                <h2 className="text-lg font-bold text-amber-300">Machine Civilization Surface Map</h2>
                <p className="text-xs text-stone-400">
                  Choose a destination to travel. Explored salvage states and landmarks persist across your journey.
                </p>
              </div>
              <button
                onClick={() => setActiveModal(null)}
                className="bg-stone-800 hover:bg-stone-700 px-3 py-1.5 rounded-xl text-xs"
              >
                Close [M / Esc]
              </button>
            </div>

            <div className="grid grid-cols-1 md:grid-cols-2 gap-3.5">
              {Object.values(REGIONS).map(reg => {
                const isCurrent = gameState.region === reg.id;
                return (
                  <div
                    key={reg.id}
                    className={`p-4 rounded-xl border flex flex-col justify-between ${
                      isCurrent ? 'bg-amber-950/30 border-amber-400' : 'bg-stone-950/80 border-stone-800'
                    }`}
                  >
                    <div>
                      <div className="flex items-center justify-between mb-1">
                        <span className="text-sm font-bold text-stone-100">{reg.name}</span>
                        <span className="text-[11px] px-2 py-0.5 rounded bg-stone-800 text-amber-300">
                          {reg.danger === 0 ? 'Safe Sanctuary' : `Hazard Tier ${reg.danger}`}
                        </span>
                      </div>
                      <div className="text-xs text-sky-300 font-medium mb-1">{reg.subtitle}</div>
                      <p className="text-xs text-stone-400 mb-3">{reg.desc}</p>
                    </div>
                    <button
                      disabled={isCurrent}
                      onClick={() => travelToRegion(reg.id)}
                      className={`w-full py-2 rounded-xl text-xs font-bold ${
                        isCurrent
                          ? 'bg-stone-800 text-amber-300 cursor-default'
                          : 'bg-amber-500 hover:bg-amber-400 text-stone-950'
                      }`}
                    >
                      {isCurrent ? 'Current Location' : `Travel to ${reg.name}`}
                    </button>
                  </div>
                );
              })}
            </div>

            {/* Optional Discoveries Log */}
            <div className="mt-5 pt-4 border-t border-stone-800">
              <h3 className="text-xs font-bold uppercase tracking-wider text-stone-400 mb-2">
                Environmental Discoveries & Keepsakes ({gameState.discoveries.length}/{OPTIONAL_DISCOVERIES.length})
              </h3>
              <div className="grid grid-cols-1 md:grid-cols-2 gap-2">
                {OPTIONAL_DISCOVERIES.map(d => {
                  const found = gameState.discoveries.includes(d.id);
                  return (
                    <div
                      key={d.id}
                      className={`p-2.5 rounded-lg border text-xs ${
                        found ? 'bg-stone-800/90 border-amber-500/40 text-stone-200' : 'bg-stone-950/50 border-stone-800 text-stone-500'
                      }`}
                    >
                      <div className="font-bold">{found ? `✓ ${d.name}` : `??? (${REGIONS[d.region].name})`}</div>
                      {found && <div className="text-[11px] text-stone-400 mt-0.5">{d.desc}</div>}
                    </div>
                  );
                })}
              </div>
            </div>
          </div>
        </div>
      )}

      {/* =====================================================================
          MODAL 7: SAVE SLOTS (INDEXEDDB) & ACCESSIBILITY SETTINGS
         ===================================================================== */}
      {activeModal === 'saves' && (
        <div className="fixed inset-0 bg-black/65 backdrop-blur-xs flex items-center justify-center z-50 p-4">
          <div className="bg-stone-900 border border-stone-700 rounded-2xl max-w-xl w-full p-6 shadow-2xl">
            <div className="flex justify-between items-center mb-4">
              <h2 className="text-lg font-bold text-amber-300">IndexedDB Save Slots & Comfort Settings</h2>
              <button
                onClick={() => setActiveModal(null)}
                className="bg-stone-800 hover:bg-stone-700 px-3 py-1.5 rounded-xl text-xs"
              >
                Close [Esc]
              </button>
            </div>

            <div className="space-y-2.5 mb-6">
              {[1, 2, 3].map(slotNum => {
                const existing = saveSlots.find(s => s.slot === slotNum);
                return (
                  <div
                    key={slotNum}
                    className="bg-stone-950 border border-stone-800 p-3.5 rounded-xl flex items-center justify-between"
                  >
                    <div>
                      <div className="text-sm font-bold text-stone-100">Save Slot {slotNum}</div>
                      <div className="text-xs text-stone-400">
                        {existing
                          ? `Day ${existing.data.day} • ${REGIONS[existing.data.region]?.name} • Seed #${existing.data.worldSeed}`
                          : 'Empty Slot'}
                      </div>
                    </div>
                    <div className="flex gap-2">
                      <button
                        onClick={async () => {
                          await saveToSlot(slotNum, gameState);
                          await refreshSlots();
                          showToast(`Saved progress to Slot ${slotNum}.`);
                        }}
                        className="bg-emerald-600 hover:bg-emerald-500 text-white text-xs font-bold px-3 py-1.5 rounded-lg"
                      >
                        Save
                      </button>
                      {existing && (
                        <button
                          onClick={async () => {
                            const data = await loadFromSlot(slotNum);
                            if (data) {
                              setGameState(data);
                              runtimeRef.current.state = data;
                              if (data.region !== 'shelter') {
                                runtimeRef.current.regionData = generateRegionMap(
                                  data.region,
                                  data.worldSeed,
                                  data.day,
                                  data.persistedRegions[data.region] || {}
                                );
                              }
                              setActiveModal(null);
                              showToast(`Loaded Slot ${slotNum}.`);
                            }
                          }}
                          className="bg-amber-500 hover:bg-amber-400 text-stone-950 text-xs font-bold px-3 py-1.5 rounded-lg"
                        >
                          Load
                        </button>
                      )}
                    </div>
                  </div>
                );
              })}
            </div>

            {/* Comfort & Accessibility */}
            <h3 className="text-xs font-bold uppercase tracking-wider text-stone-400 mb-3">
              Camera, Mobile Touch & Accessibility Options
            </h3>
            <div className="space-y-3 text-xs">
              <div className="flex items-center justify-between">
                <span>On-Screen Mobile Touch Controls</span>
                <div className="flex gap-1 bg-stone-950 p-1 rounded-xl border border-stone-800">
                  {[
                    { id: 'auto', label: 'Auto (Small Screen)' },
                    { id: 'on', label: 'Always On' },
                    { id: 'off', label: 'Off' }
                  ].map(opt => {
                    const currentMode = gameState.settings.mobileControls || 'auto';
                    return (
                      <button
                        key={opt.id}
                        onClick={() =>
                          setGameState(prev => ({
                            ...prev,
                            settings: { ...prev.settings, mobileControls: opt.id }
                          }))
                        }
                        className={`px-2.5 py-1 rounded-lg text-[11px] font-semibold transition ${
                          currentMode === opt.id
                            ? 'bg-amber-500 text-stone-950'
                            : 'text-stone-400 hover:text-stone-200'
                        }`}
                      >
                        {opt.label}
                      </button>
                    );
                  })}
                </div>
              </div>
              <div className="flex items-center justify-between">
                <span>Camera Zoom Scale ({gameState.settings.zoom.toFixed(2)}x)</span>
                <input
                  type="range"
                  min="0.8"
                  max="1.35"
                  step="0.05"
                  value={gameState.settings.zoom}
                  onChange={e =>
                    setGameState(prev => ({
                      ...prev,
                      settings: { ...prev.settings, zoom: parseFloat(e.target.value) }
                    }))
                  }
                  className=" accent-amber-500"
                />
              </div>
              <label className="flex items-center justify-between cursor-pointer">
                <span>Show Combat Damage Numbers</span>
                <input
                  type="checkbox"
                  checked={gameState.settings.damageNumbers}
                  onChange={e =>
                    setGameState(prev => ({
                      ...prev,
                      settings: { ...prev.settings, damageNumbers: e.target.checked }
                    }))
                  }
                />
              </label>
              <label className="flex items-center justify-between cursor-pointer">
                <span>Reduced Screen Shake</span>
                <input
                  type="checkbox"
                  checked={gameState.settings.reducedShake}
                  onChange={e =>
                    setGameState(prev => ({
                      ...prev,
                      settings: { ...prev.settings, reducedShake: e.target.checked }
                    }))
                  }
                />
              </label>
            </div>
          </div>
        </div>
      )}

      {/* =====================================================================
          MODAL 8: ACT III ENDING — "THE WARMTH BELOW" PAYOFF
         ===================================================================== */}
      {activeModal === 'ending' && (
        <div className="fixed inset-0 bg-black/80 backdrop-blur-md flex items-center justify-center z-50 p-4">
          <div className="bg-stone-900 border-2 border-amber-400/70 rounded-3xl max-w-lg w-full p-7 shadow-2xl text-center">
            <Award className="w-12 h-12 text-amber-400 mx-auto mb-3" />
            <div className="text-xs uppercase tracking-widest text-amber-400 font-bold mb-1">
              Act III Complete — The Warmth Below
            </div>
            <h2 className="text-2xl font-bold text-stone-100 mb-3">A Quiet Life Worth Returning To</h2>
            <p className="text-sm text-stone-300 leading-relaxed mb-4">
              Above the mesa, the colossal machine civilization continues its endless, indifferent hum.
              But down here, natural golden sunlight streams cleanly through the calibrated heliostat shaft onto
              Yuna’s thriving garden beds.
            </p>
            <p className="text-sm text-stone-300 leading-relaxed mb-6">
              The water purifier murmurs steadily, the capacitor bank glows warm amber, and Yuna sits by her
              lamp with a steaming bowl of root stew—allowing herself a quiet, genuine smile.
            </p>
            <button
              onClick={() => setActiveModal(null)}
              className="bg-amber-500 hover:bg-amber-400 text-stone-950 font-bold px-6 py-2.5 rounded-xl text-sm shadow-lg"
            >
              Continue Endless Cozy Sandbox
            </button>
          </div>
        </div>
      )}

      {}
      {/* =====================================================================
          MODAL 9: YUNA'S PERSONAL JOURNAL & GEMINI TTS VOICE DIARY
         ===================================================================== */}
      {activeModal === 'journal' && (
        <div className="fixed inset-0 bg-black/70 backdrop-blur-xs flex items-center justify-center z-50 p-4">
          <div className="bg-stone-900 border border-amber-500/40 rounded-2xl max-w-2xl w-full p-6 shadow-2xl max-h-[86vh] overflow-y-auto">
            <div className="flex justify-between items-center mb-4">
              <div>
                <h2 className="text-lg font-bold text-amber-300 flex items-center gap-2">
                  <BookOpen className="w-5 h-5 text-amber-400" />
                  Yuna’s Notebook & Sketch Journal
                </h2>
                <p className="text-xs text-stone-400">
                  Powered by Gemini — Yuna reflects on her shelter, garden, and expeditions in her own voice.
                </p>
              </div>
              <button
                onClick={() => setActiveModal(null)}
                className="bg-stone-800 hover:bg-stone-700 px-3 py-1.5 rounded-xl text-xs"
              >
                Close [Esc]
              </button>
            </div>

            <div className="mb-5 flex items-center justify-between bg-amber-950/35 border border-amber-500/30 p-3.5 rounded-xl">
              <div className="text-xs text-amber-100">
                <div className="font-bold">Write Today’s Reflection (Day {gameState.day})</div>
                <div className="text-stone-400">
                  Generates a unique diary entry based on your current furnishings, crops, and discoveries (+25 Stamina).
                </div>
              </div>
              <button
                disabled={aiLoading}
                onClick={generateYunaJournalEntry}
                className="bg-amber-500 hover:bg-amber-400 disabled:bg-stone-800 text-stone-950 disabled:text-stone-500 font-bold text-xs px-4 py-2 rounded-xl flex items-center gap-1.5 shrink-0"
              >
                {aiLoading ? <Loader2 className="w-4 h-4 animate-spin" /> : <Sparkles className="w-4 h-4" />}
                {aiLoading ? 'Writing...' : '✨ Write New Entry'}
              </button>
            </div>

            <div className="space-y-3">
              {(gameState.journalEntries || []).map(entry => (
                <div
                  key={entry.id}
                  className="bg-stone-950/85 border border-stone-800 p-4 rounded-xl"
                >
                  <div className="flex items-center justify-between mb-1.5">
                    <div className="text-sm font-bold text-amber-200">
                      Day {entry.day}: {entry.title}
                    </div>
                    <div className="flex items-center gap-2">
                      <span className="text-[11px] px-2 py-0.5 rounded-full bg-stone-800 text-amber-300">
                        Mood: {entry.mood}
                      </span>
                      <button
                        disabled={ttsLoadingId === entry.id}
                        onClick={() => handlePlayJournalTTS(entry)}
                        className="bg-stone-800 hover:bg-stone-700 border border-amber-500/40 text-amber-200 text-xs px-2.5 py-1 rounded-lg flex items-center gap-1"
                        title="Listen to Yuna read this entry aloud (Gemini TTS)"
                      >
                        {ttsLoadingId === entry.id ? (
                          <Loader2 className="w-3.5 h-3.5 animate-spin" />
                        ) : (
                          <Volume1 className="w-3.5 h-3.5 text-amber-400" />
                        )}
                        Listen
                      </button>
                    </div>
                  </div>
                  <p className="text-xs text-stone-200 leading-relaxed italic mb-2">
                    “{entry.content}”
                  </p>
                  <div className="text-[11px] font-mono text-stone-400 bg-stone-900/80 px-2.5 py-1 rounded border border-stone-800">
                    ✏️ {entry.sketchNote}
                  </div>
                </div>
              ))}
            </div>
          </div>
        </div>
      )}

      {/* =====================================================================
          MODAL 10: REPAIRED VACUUM RADIO & MACHINE TELEMETRY DECODER
         ===================================================================== */}
      {activeModal === 'radio' && (
        <div className="fixed inset-0 bg-black/70 backdrop-blur-xs flex items-center justify-center z-50 p-4">
          <div className="bg-stone-900 border border-sky-500/40 rounded-2xl max-w-2xl w-full p-6 shadow-2xl max-h-[86vh] overflow-y-auto">
            <div className="flex justify-between items-center mb-4">
              <div>
                <h2 className="text-lg font-bold text-sky-300 flex items-center gap-2">
                  <Radio className="w-5 h-5 text-sky-400" />
                  Repaired Vacuum-Tube Radio & Telemetry Decoder
                </h2>
                <p className="text-xs text-stone-400">
                  Scan machine-civilization frequencies for lore transmissions, weather alerts, and triangulated salvage drops.
                </p>
              </div>
              <div className="flex items-center gap-2">
                <button
                  onClick={() => {
                    sound.radioActive = !sound.radioActive;
                    sound.sfxTic();
                    showToast(sound.radioActive ? 'Shelter radio synth hum enabled.' : 'Shelter radio muted.');
                  }}
                  className="bg-stone-800 hover:bg-stone-700 px-3 py-1.5 rounded-xl text-xs text-amber-300"
                >
                  {sound.radioActive ? '🔊 Synth Chords: ON' : '🔇 Synth Chords: OFF'}
                </button>
                <button
                  onClick={() => setActiveModal(null)}
                  className="bg-stone-800 hover:bg-stone-700 px-3 py-1.5 rounded-xl text-xs"
                >
                  Close [Esc]
                </button>
              </div>
            </div>

            <div className="mb-5 flex items-center justify-between bg-sky-950/35 border border-sky-500/30 p-3.5 rounded-xl">
              <div className="text-xs text-sky-100">
                <div className="font-bold">Scan Surface Conduit Frequencies</div>
                <div className="text-stone-400">
                  Uses Gemini to decode automated machine logs or old maintenance notes and triangulate bonus salvage.
                </div>
              </div>
              <button
                disabled={aiLoading}
                onClick={decodeRadioTransmission}
                className="bg-sky-500 hover:bg-sky-400 disabled:bg-stone-800 text-stone-950 disabled:text-stone-500 font-bold text-xs px-4 py-2 rounded-xl flex items-center gap-1.5 shrink-0"
              >
                {aiLoading ? <Loader2 className="w-4 h-4 animate-spin" /> : <Cpu className="w-4 h-4" />}
                {aiLoading ? 'Decoding...' : '✨ Scan Frequency'}
              </button>
            </div>

            <div className="space-y-3">
              {(!gameState.decodedSignals || gameState.decodedSignals.length === 0) ? (
                <p className="text-xs text-stone-400 italic text-center py-6">
                  No surface transmissions decoded yet. Click “Scan Frequency” to tune the vacuum tubes.
                </p>
              ) : (
                gameState.decodedSignals.map(sig => (
                  <div
                    key={sig.id}
                    className="bg-stone-950/85 border border-stone-800 p-4 rounded-xl"
                  >
                    <div className="flex items-center justify-between mb-1">
                      <span className="text-xs font-mono font-bold text-sky-400">
                        {sig.frequency} • {sig.regionName}
                      </span>
                      <span className="text-[11px] bg-stone-800 text-emerald-300 px-2 py-0.5 rounded">
                        +2 {ITEMS[sig.rewardItem]?.name}
                      </span>
                    </div>
                    <div className="text-xs font-mono text-stone-300 bg-stone-900 p-2.5 rounded-lg border border-stone-800 my-2">
                      {sig.transmissionText}
                    </div>
                    <div className="text-xs text-amber-200 italic">
                      Yuna: “{sig.yunaComment}”
                    </div>
                  </div>
                ))
              )}
            </div>
          </div>
        </div>
      )}

      {/* =====================================================================
          MODAL 11: LIVE SPRITESHEET & TEXTURE ATLAS INSPECTOR
         ===================================================================== */}
      {activeModal === 'sprites' && (
        <div className="fixed inset-0 bg-black/75 backdrop-blur-xs flex items-center justify-center z-50 p-4">
          <div className="bg-stone-900 border border-pink-500/40 rounded-2xl max-w-4xl w-full p-6 shadow-2xl max-h-[88vh] overflow-y-auto">
            <div className="flex justify-between items-center mb-4">
              <div>
                <h2 className="text-lg font-bold text-pink-300 flex items-center gap-2">
                  <Palette className="w-5 h-5 text-pink-400" />
                  Master Pixel-Art Spritesheet & Texture Atlas Manager
                </h2>
                <p className="text-xs text-stone-400">
                  Automatically slices and chroma-keys the generated Master Pixel-Art Sheet (`{GENERATED_MASTER_SHEET_URL}`) or lets you load the image directly if your browser blocks local file paths.
                </p>
              </div>
              <button
                onClick={() => setActiveModal(null)}
                className="bg-stone-800 hover:bg-stone-700 px-3 py-1.5 rounded-xl text-xs"
              >
                Close [Esc]
              </button>
            </div>

            {/* Master Pixel-Art Sheet Loader & Toggle */}
            <div className="bg-pink-950/30 border border-pink-500/40 p-4 rounded-xl mb-5 flex flex-wrap items-center justify-between gap-3">
              <div>
                <div className="text-xs font-bold text-pink-200">
                  Generated Master Pixel-Art Sheet Integration
                </div>
                <div className="text-[11px] text-stone-300 mt-0.5">
                  Status: {spriteAtlas.masterImage ? '✅ Master Pixel Sheet Active & Sliced!' : '⚡ Using Built-In Pixel Atlas (Upload Master Sheet image below if local path is sandboxed)'}
                </div>
              </div>
              <div className="flex items-center gap-2">
                <label className="bg-pink-600 hover:bg-pink-500 text-white text-xs font-bold px-3 py-1.5 rounded-xl cursor-pointer shadow">
                  Load Master Sheet Image
                  <input
                    type="file"
                    accept="image/*"
                    className="hidden"
                    onChange={(e) => {
                      const file = e.target.files?.[0];
                      if (!file) return;
                      const reader = new FileReader();
                      reader.onload = (ev) => {
                        if (ev.target?.result) {
                          spriteAtlas.loadMasterPixelSheet(ev.target.result);
                          showToast('Master Pixel-Art Spritesheet sliced and applied to game!');
                          setTimeout(() => setGameState(prev => ({ ...prev })), 200);
                        }
                      };
                      reader.readAsDataURL(file);
                    }}
                  />
                </label>
              </div>
            </div>

            <div className="space-y-5">
              {/* 1. Yuna 32-Frame Character Spritesheet */}
              <div className="bg-stone-950/90 border border-stone-800 p-4 rounded-xl">
                <div className="text-xs font-bold text-amber-300 mb-1">
                  1. Yuna Character Spritesheet (4 Directions × 8 Frames = 32 Sprites @ 64×64px)
                </div>
                <div className="text-[11px] text-stone-400 mb-3">
                  Rows: Down, Up, Left, Right • Columns: Idle (0-1), Walk Cycle (2-5), Braid/Tic Blink (6), Sneak Crouch (7)
                </div>
                <div className="overflow-x-auto bg-stone-900/90 p-3 rounded-lg border border-stone-800 flex justify-center">
                  {spriteAtlas.yunaSheet && (
                    <img
                      src={spriteAtlas.yunaSheet.toDataURL()}
                      alt="Yuna Spritesheet"
                      className="max-w-full h-auto"
                    />
                  )}
                </div>
              </div>

              {/* 2. Robot Archetypes Spritesheet */}
              <div className="bg-stone-950/90 border border-stone-800 p-4 rounded-xl">
                <div className="text-xs font-bold text-sky-300 mb-1">
                  2. Machine Civilization Automata Spritesheet (5 Archetypes × 4 Animation Frames)
                </div>
                <div className="text-[11px] text-stone-400 mb-3">
                  Rows: Scuttler, Survey Drone, Maintenance Guardian, Heavy Reclaimer, and Harmless Conduit Sweeper
                </div>
                <div className="overflow-x-auto bg-stone-900/90 p-3 rounded-lg border border-stone-800 flex justify-center">
                  {spriteAtlas.robotSheet && (
                    <img
                      src={spriteAtlas.robotSheet.toDataURL()}
                      alt="Robot Spritesheet"
                      className="max-w-full h-auto"
                    />
                  )}
                </div>
              </div>

              {/* 3. Salvage Containers & Props Sheet */}
              <div className="bg-stone-950/90 border border-stone-800 p-4 rounded-xl">
                <div className="text-xs font-bold text-emerald-300 mb-2">
                  3. Interactive Salvage Containers & Surface Tiles
                </div>
                <div className="flex flex-wrap items-center gap-4">
                  {spriteAtlas.propSheet && (
                    <img
                      src={spriteAtlas.propSheet.toDataURL()}
                      alt="Props Spritesheet"
                      className="bg-stone-900 p-2 rounded-lg border border-stone-800"
                    />
                  )}
                  {['shelterLower', 'shelterUpper', 'ash_flats', 'cable_forest', 'dead_foundry', 'coolant_basin'].map(
                    patKey =>
                      spriteAtlas.patterns[patKey] && (
                        <div key={patKey} className="text-center">
                          <img
                            src={spriteAtlas.patterns[patKey].toDataURL()}
                            alt={patKey}
                            className="w-16 h-16 rounded-lg border border-stone-700 mx-auto"
                          />
                          <div className="text-[10px] text-stone-400 mt-1">{patKey}</div>
                        </div>
                      )
                  )}
                </div>
              </div>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}