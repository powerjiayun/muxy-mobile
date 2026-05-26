import { base64ToBytes, stringToBase64 } from '@/lib/base64';

import { applyModifierToBytes, transformWithModifiers, useModifierStore } from './modifierState';

function asBytes(base64: string): number[] {
  return Array.from(base64ToBytes(base64));
}

beforeEach(() => {
  useModifierStore.getState().arm(null);
  useModifierStore.getState().setSlot('ctrl');
});

describe('applyModifierToBytes', () => {
  it('maps ctrl + letter to the corresponding control byte', () => {
    expect(applyModifierToBytes(new Uint8Array([0x63]), 'ctrl')).toEqual(new Uint8Array([0x03]));
    expect(applyModifierToBytes(new Uint8Array([0x43]), 'ctrl')).toEqual(new Uint8Array([0x03]));
  });

  it('prefixes alt and meta with ESC', () => {
    expect(applyModifierToBytes(new Uint8Array([0x66]), 'alt')).toEqual(new Uint8Array([0x1b, 0x66]));
    expect(applyModifierToBytes(new Uint8Array([0x66]), 'meta')).toEqual(new Uint8Array([0x1b, 0x66]));
  });

  it('returns the input unchanged for shift', () => {
    const bytes = new Uint8Array([0x61]);
    expect(applyModifierToBytes(bytes, 'shift')).toBe(bytes);
  });
});

describe('transformWithModifiers', () => {
  it('passes the input through when no modifier is armed', () => {
    const input = stringToBase64('a');
    expect(transformWithModifiers(input)).toBe(input);
  });

  it('disarms a one-shot modifier after a single use', () => {
    useModifierStore.getState().arm('ctrl', false);
    const out = transformWithModifiers(stringToBase64('c'));
    expect(asBytes(out)).toEqual([0x03]);
    expect(useModifierStore.getState().active).toBeNull();
    expect(useModifierStore.getState().locked).toBe(false);
  });

  it('keeps a locked modifier armed across multiple uses', () => {
    useModifierStore.getState().arm('ctrl', true);
    expect(asBytes(transformWithModifiers(stringToBase64('c')))).toEqual([0x03]);
    expect(useModifierStore.getState().active).toBe('ctrl');
    expect(useModifierStore.getState().locked).toBe(true);
    expect(asBytes(transformWithModifiers(stringToBase64('d')))).toEqual([0x04]);
    expect(useModifierStore.getState().active).toBe('ctrl');
  });

  it('clears locked state when the modifier is disarmed', () => {
    useModifierStore.getState().arm('ctrl', true);
    useModifierStore.getState().arm(null);
    expect(useModifierStore.getState().active).toBeNull();
    expect(useModifierStore.getState().locked).toBe(false);
  });
});
