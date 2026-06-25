import React from 'react';
import { View, Text, TouchableOpacity, StyleSheet } from 'react-native';
import { COLORS, FONTS, RADIUS, SPACING } from '../constants/theme';
import { UserRole } from '../types';

interface Props {
  currentRole: UserRole;
  onSwitch: (role: UserRole) => void;
}

export default function RoleSwitcher({ currentRole, onSwitch }: Props) {
  return (
    <View style={styles.container}>
      <TouchableOpacity
        style={[styles.option, currentRole === 'customer' && styles.active]}
        onPress={() => onSwitch('customer')}
        activeOpacity={0.8}
      >
        <Text style={[styles.label, currentRole === 'customer' && styles.activeLabel]}>Customer</Text>
      </TouchableOpacity>
      <TouchableOpacity
        style={[styles.option, currentRole === 'owner' && styles.active]}
        onPress={() => onSwitch('owner')}
        activeOpacity={0.8}
      >
        <Text style={[styles.label, currentRole === 'owner' && styles.activeLabel]}>Shop Owner</Text>
      </TouchableOpacity>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flexDirection: 'row',
    backgroundColor: COLORS.card,
    borderRadius: RADIUS.md,
    padding: 4,
    borderWidth: 1,
    borderColor: COLORS.line,
  },
  option: {
    flex: 1,
    paddingVertical: 10,
    borderRadius: RADIUS.sm,
    alignItems: 'center',
  },
  active: {
    backgroundColor: COLORS.ember2,
  },
  label: {
    fontSize: 14,
    fontFamily: FONTS.headingMedium,
    color: COLORS.muted,
  },
  activeLabel: {
    color: '#1a0d05',
  },
});
