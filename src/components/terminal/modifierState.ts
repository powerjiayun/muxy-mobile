import { create } from 'zustand';

import { bytesToBase64 } from '@/lib/base64';

export type Modifier = 'ctrl' | 'shift' | 'alt' | 'meta';

type ModifierState = {
  active: Modifier | null;
  locked: boolean;
  slot: Modifier;
  arm: (m: Modifier | null, locked?: boolean) => void;
  setSlot: (m: Modifier) => void;
};

export const useModifierStore = create<ModifierState>((set) => ({
  active: null,
  locked: false,
  slot: 'ctrl',
  arm: (m, locked = false) => set({ active: m, locked: m ? locked : false }),
  setSlot: (m) => set({ slot: m }),
}));

export function applyModifierToBytes(bytes: Uint8Array, modifier: Modifier): Uint8Array {
  if (bytes.length === 0) return bytes;
  const ch = bytes[0]!;
  if (modifier === 'ctrl') {
    let mapped: number | null = null;
    if (ch >= 0x40 && ch <= 0x5f) mapped = ch - 0x40;
    else if (ch >= 0x60 && ch <= 0x7e) mapped = ch - 0x60;
    else if (ch === 0x20) mapped = 0x00;
    else if (ch === 0x3f) mapped = 0x7f;
    if (mapped !== null) return new Uint8Array([mapped]);
    return bytes;
  }
  if (modifier === 'alt' || modifier === 'meta') {
    const prefixed = new Uint8Array(bytes.length + 1);
    prefixed[0] = 0x1b;
    prefixed.set(bytes, 1);
    return prefixed;
  }
  return bytes;
}

export function transformWithModifiers(base64: string): string {
  const { active, locked, arm } = useModifierStore.getState();
  if (!active) return base64;

  let bytes: Uint8Array;
  try {
    const bin = globalThis.atob(base64);
    bytes = new Uint8Array(bin.length);
    for (let i = 0; i < bin.length; i++) bytes[i] = bin.charCodeAt(i);
  } catch {
    return base64;
  }

  const result = applyModifierToBytes(bytes, active);
  if (!locked) arm(null);
  return result === bytes ? base64 : bytesToBase64(result);
}
