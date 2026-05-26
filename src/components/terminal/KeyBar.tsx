import { Ionicons } from '@expo/vector-icons';
import * as Clipboard from 'expo-clipboard';
import { useRef, useState } from 'react';
import { Modal, Pressable, ScrollView, StyleSheet, Text, View } from 'react-native';

import { bytesToBase64, stringToBase64 } from '@/lib/base64';
import { useTokens } from '@/theme';

import { Joystick, type JoystickDirection } from './Joystick';
import { type Modifier, useModifierStore } from './modifierState';

const MODIFIER_OPTIONS: { id: Modifier; label: string; symbol: string }[] = [
  { id: 'ctrl', label: 'ctrl', symbol: '⌃' },
  { id: 'shift', label: 'shift', symbol: '⇧' },
  { id: 'alt', label: 'alt', symbol: '⌥' },
  { id: 'meta', label: 'cmd', symbol: '⌘' },
];

const ESC = new Uint8Array([0x1b]);
const TAB = new Uint8Array([0x09]);
const TILDE = new Uint8Array([0x7e]);
const SLASH = new Uint8Array([0x2f]);
const PIPE = new Uint8Array([0x7c]);
const DASH = new Uint8Array([0x2d]);
const ARROW_UP = new Uint8Array([0x1b, 0x5b, 0x41]);
const ARROW_DOWN = new Uint8Array([0x1b, 0x5b, 0x42]);
const ARROW_RIGHT = new Uint8Array([0x1b, 0x5b, 0x43]);
const ARROW_LEFT = new Uint8Array([0x1b, 0x5b, 0x44]);

export function KeyBar({
  onBytes,
}: {
  onBytes: (base64: string) => void;
}) {
  const tokens = useTokens();
  const active = useModifierStore((s) => s.active);
  const locked = useModifierStore((s) => s.locked);
  const slot = useModifierStore((s) => s.slot);
  const arm = useModifierStore((s) => s.arm);
  const setSlot = useModifierStore((s) => s.setSlot);

  const send = (bytes: Uint8Array) => onBytes(bytesToBase64(bytes));

  const onJoystick = (dir: JoystickDirection) => {
    switch (dir) {
      case 'up':
        return send(ARROW_UP);
      case 'down':
        return send(ARROW_DOWN);
      case 'left':
        return send(ARROW_LEFT);
      case 'right':
        return send(ARROW_RIGHT);
    }
  };

  const onPaste = async () => {
    try {
      const text = await Clipboard.getStringAsync();
      if (text) onBytes(stringToBase64(text));
    } catch {
      void 0;
    }
  };

  return (
    <View style={styles.row}>
      <View
        style={[
          styles.capsule,
          { backgroundColor: tokens.surface.secondary, borderColor: tokens.border.subtle },
        ]}>
        <ScrollView
          horizontal
          showsHorizontalScrollIndicator={false}
          showsVerticalScrollIndicator={false}
          alwaysBounceVertical={false}
          directionalLockEnabled
          keyboardShouldPersistTaps="always"
          contentContainerStyle={styles.capsuleContent}>
          <CapsuleButton label="esc" onPress={() => send(ESC)} />
          <ModifierKey
            slot={slot}
            active={active}
            locked={locked}
            onArm={arm}
            onPickFromMenu={(m) => {
              setSlot(m);
              arm(m);
            }}
          />
          <CapsuleButton label="tab" onPress={() => send(TAB)} />
          <CapsuleButton label="~" onPress={() => send(TILDE)} />
          <CapsuleButton label="/" onPress={() => send(SLASH)} />
          <CapsuleIconButton icon="clipboard-outline" accessibilityLabel="Paste" onPress={onPaste} />
          <CapsuleButton label="|" onPress={() => send(PIPE)} />
          <CapsuleButton label="-" onPress={() => send(DASH)} />
        </ScrollView>
      </View>

      <Joystick size={48} onDirection={onJoystick} />
    </View>
  );
}

function CapsuleButton({ label, onPress }: { label: string; onPress: () => void }) {
  const tokens = useTokens();
  return (
    <Pressable
      onPress={onPress}
      hitSlop={6}
      style={({ pressed }) => [
        styles.capsuleBtn,
        { opacity: pressed ? 0.7 : 1 },
      ]}>
      <Text style={[styles.capsuleLabel, { color: tokens.text.primary }]}>{label}</Text>
    </Pressable>
  );
}

function CapsuleIconButton({
  icon,
  accessibilityLabel,
  onPress,
}: {
  icon: keyof typeof Ionicons.glyphMap;
  accessibilityLabel: string;
  onPress: () => void;
}) {
  const tokens = useTokens();
  return (
    <Pressable
      onPress={onPress}
      hitSlop={6}
      accessibilityRole="button"
      accessibilityLabel={accessibilityLabel}
      style={({ pressed }) => [styles.capsuleBtn, { opacity: pressed ? 0.7 : 1 }]}>
      <Ionicons name={icon} size={18} color={tokens.text.primary} />
    </Pressable>
  );
}

const DOUBLE_TAP_MS = 280;

function ModifierKey({
  slot,
  active,
  locked,
  onArm,
  onPickFromMenu,
}: {
  slot: Modifier;
  active: Modifier | null;
  locked: boolean;
  onArm: (m: Modifier | null, locked: boolean) => void;
  onPickFromMenu: (m: Modifier) => void;
}) {
  const tokens = useTokens();
  const [menuOpen, setMenuOpen] = useState(false);
  const [anchor, setAnchor] = useState<{ x: number; y: number; width: number } | null>(null);
  const buttonRef = useRef<View>(null);
  const lastTapAtRef = useRef(0);

  const slotOption = MODIFIER_OPTIONS.find((o) => o.id === slot) ?? MODIFIER_OPTIONS[0]!;
  const isArmed = active === slot;
  const isLocked = isArmed && locked;

  const openMenu = () => {
    buttonRef.current?.measureInWindow((x, y, width) => {
      setAnchor({ x, y, width });
      setMenuOpen(true);
    });
  };

  const handleTap = () => {
    const now = Date.now();
    const isDoubleTap = now - lastTapAtRef.current < DOUBLE_TAP_MS;
    lastTapAtRef.current = now;
    if (isDoubleTap) {
      onArm(slot, true);
      return;
    }
    if (isLocked || isArmed) {
      onArm(null, false);
      return;
    }
    onArm(slot, false);
  };

  return (
    <>
      <Pressable
        ref={buttonRef}
        onPress={handleTap}
        onLongPress={openMenu}
        delayLongPress={300}
        style={({ pressed }) => [
          styles.capsuleBtn,
          {
            backgroundColor: isLocked ? 'transparent' : isArmed ? tokens.accent.primary : 'transparent',
            borderWidth: isLocked ? 1.5 : 0,
            borderColor: isLocked ? tokens.accent.primary : 'transparent',
            borderRadius: 999,
            opacity: pressed ? 0.7 : 1,
          },
        ]}>
        <View style={styles.modifierLabelRow}>
          <Text
            style={[
              styles.capsuleLabel,
              { color: isLocked ? tokens.accent.primary : isArmed ? tokens.accent.contrast : tokens.text.primary },
            ]}>
            {slotOption.label}
          </Text>
          <Ionicons
            name="chevron-up"
            size={11}
            color={isLocked ? tokens.accent.primary : isArmed ? tokens.accent.contrast : tokens.text.muted}
          />
        </View>
      </Pressable>

      <Modal
        visible={menuOpen}
        transparent
        animationType="fade"
        onRequestClose={() => setMenuOpen(false)}>
        <Pressable style={StyleSheet.absoluteFill} onPress={() => setMenuOpen(false)} />
        {anchor ? (
          <View
            style={[
              styles.menu,
              {
                left: Math.max(8, anchor.x - 20),
                bottom: undefined,
                top: anchor.y - MENU_HEIGHT - 8,
                backgroundColor: tokens.surface.secondary,
                borderColor: tokens.border.subtle,
              },
            ]}>
            {MODIFIER_OPTIONS.map((opt) => {
              const isCurrent = slot === opt.id;
              return (
                <Pressable
                  key={opt.id}
                  onPress={() => {
                    onPickFromMenu(opt.id);
                    setMenuOpen(false);
                  }}
                  style={({ pressed }) => [
                    styles.menuItem,
                    {
                      backgroundColor: pressed ? tokens.surface.tertiary : 'transparent',
                    },
                  ]}>
                  <Text
                    style={[
                      styles.menuSymbol,
                      {
                        color: isCurrent ? tokens.accent.primary : tokens.text.muted,
                      },
                    ]}>
                    {opt.symbol}
                  </Text>
                  <Text
                    style={[
                      styles.menuLabel,
                      {
                        color: isCurrent ? tokens.accent.primary : tokens.text.primary,
                      },
                    ]}>
                    {opt.label}
                  </Text>
                </Pressable>
              );
            })}
          </View>
        ) : null}
      </Modal>
    </>
  );
}

const MENU_HEIGHT = 4 * 44 + 12;

const styles = StyleSheet.create({
  row: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 10,
    paddingHorizontal: 16,
    paddingVertical: 8,
  },
  capsule: {
    flex: 1,
    height: 48,
    borderRadius: 999,
    borderWidth: StyleSheet.hairlineWidth,
    overflow: 'hidden',
  },
  capsuleContent: {
    paddingHorizontal: 6,
    alignItems: 'center',
    gap: 2,
  },
  capsuleBtn: {
    minWidth: 44,
    height: 36,
    borderRadius: 999,
    alignItems: 'center',
    justifyContent: 'center',
    paddingHorizontal: 10,
  },
  capsuleLabel: { fontSize: 13, fontWeight: '600' },
  modifierLabelRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 3,
  },
  menu: {
    position: 'absolute',
    minWidth: 160,
    paddingVertical: 6,
    borderRadius: 12,
    borderWidth: StyleSheet.hairlineWidth,
  },
  menuItem: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 12,
    paddingHorizontal: 14,
    paddingVertical: 10,
  },
  menuSymbol: { fontSize: 14, fontWeight: '500', width: 18, textAlign: 'center' },
  menuLabel: { fontSize: 14, fontWeight: '500' },
});
