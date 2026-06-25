import React, { useState, useEffect } from 'react';
import { View, Text, StyleSheet, ScrollView, TextInput, TouchableOpacity, Alert } from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { Ionicons } from '@expo/vector-icons';
import Animated, { FadeInDown } from 'react-native-reanimated';
import { useStore } from '../../src/store/StoreProvider';
import { useToast } from '../../src/components/Toast';
import { COLORS, FONTS, RADIUS, SPACING } from '../../src/constants/theme';
import { RewardTier } from '../../src/types';
import { generateId } from '../../src/utils/formatters';
import GradientButton from '../../src/components/GradientButton';
import * as Haptics from 'expo-haptics';

export default function RewardsScreen() {
  const insets = useSafeAreaInsets();
  const { state, updateShop } = useStore();
  const { showToast } = useToast();
  const ownerShop = state.shops.find(s => s.ownerId === state.currentUser?.id);
  const [tiers, setTiers] = useState<RewardTier[]>(ownerShop?.rewardTiers || []);
  const [windowDays, setWindowDays] = useState(ownerShop?.streakWindowDays.toString() || '3');
  const [initialized, setInitialized] = useState(false);

  useEffect(() => {
    if (ownerShop && !initialized) {
      setTiers(ownerShop.rewardTiers);
      setWindowDays(ownerShop.streakWindowDays.toString());
      setInitialized(true);
    }
  }, [ownerShop, initialized]);

  if (!ownerShop) return null;

  const streakTiers = tiers.filter(t => t.type === 'streak_days').sort((a, b) => a.threshold - b.threshold);
  const visitTiers = tiers.filter(t => t.type === 'visit_count').sort((a, b) => a.threshold - b.threshold);

  const updateTier = (id: string, field: string, value: string) => {
    setTiers(prev =>
      prev.map(t => {
        if (t.id !== id) return t;
        if (field === 'threshold' || field === 'discountPercent') {
          return { ...t, [field]: parseInt(value) || 0 };
        }
        return { ...t, [field]: value };
      })
    );
  };

  const addTier = (type: 'visit_count' | 'streak_days') => {
    const newTier: RewardTier = {
      id: generateId(),
      shopId: ownerShop.id,
      type,
      threshold: type === 'visit_count' ? 5 : 3,
      discountPercent: 10,
      label: 'New Tier',
      description: 'Discount on your meal',
      emoji: '🔥',
    };
    setTiers(prev => [...prev, newTier]);
  };

  const deleteTier = (id: string) => {
    Alert.alert('Delete Tier', 'Remove this reward tier?', [
      { text: 'Cancel', style: 'cancel' },
      { text: 'Delete', style: 'destructive', onPress: () => setTiers(prev => prev.filter(t => t.id !== id)) },
    ]);
  };

  const handleSave = async () => {
    const updated = {
      ...ownerShop,
      rewardTiers: tiers,
      streakWindowDays: parseInt(windowDays) || 3,
    };
    await updateShop(updated);
    Haptics.notificationAsync(Haptics.NotificationFeedbackType.Success);
    showToast({ message: 'Rewards saved!', type: 'success' });
  };

  const renderTierCard = (tier: RewardTier) => (
    <View key={tier.id} style={styles.tierCard}>
      <View style={styles.tierHeader}>
        <TextInput
          style={styles.tierLabelInput}
          value={tier.label}
          onChangeText={v => updateTier(tier.id, 'label', v)}
          placeholder="Tier name"
          placeholderTextColor={COLORS.muted2}
        />
        <TouchableOpacity onPress={() => deleteTier(tier.id)} style={styles.deleteBtn}>
          <Ionicons name="trash-outline" size={18} color={COLORS.error} />
        </TouchableOpacity>
      </View>
      <View style={styles.tierFields}>
        <View style={styles.field}>
          <Text style={styles.fieldLabel}>{tier.type === 'visit_count' ? 'Visits' : 'Days'}</Text>
          <TextInput
            style={styles.fieldInput}
            value={tier.threshold.toString()}
            onChangeText={v => updateTier(tier.id, 'threshold', v)}
            keyboardType="numeric"
            placeholderTextColor={COLORS.muted2}
          />
        </View>
        <View style={styles.field}>
          <Text style={styles.fieldLabel}>Discount %</Text>
          <TextInput
            style={styles.fieldInput}
            value={tier.discountPercent.toString()}
            onChangeText={v => updateTier(tier.id, 'discountPercent', v)}
            keyboardType="numeric"
            placeholderTextColor={COLORS.muted2}
          />
        </View>
      </View>
    </View>
  );

  return (
    <ScrollView
      style={styles.container}
      contentContainerStyle={[styles.content, { paddingTop: insets.top + SPACING.md }]}
      showsVerticalScrollIndicator={false}
      keyboardShouldPersistTaps="handled"
    >
      <Text style={styles.title}>Reward Tiers</Text>

      <Animated.View entering={FadeInDown.springify()} style={styles.windowCard}>
        <Text style={styles.windowLabel}>Streak window (days)</Text>
        <Text style={styles.windowDesc}>Customers must revisit within this many days to keep their streak</Text>
        <TextInput
          style={styles.windowInput}
          value={windowDays}
          onChangeText={setWindowDays}
          keyboardType="numeric"
          placeholderTextColor={COLORS.muted2}
        />
      </Animated.View>

      <Animated.View entering={FadeInDown.delay(100).springify()}>
        <Text style={styles.sectionTitle}>Streak Day Rewards</Text>
        {streakTiers.map(renderTierCard)}
        <TouchableOpacity style={styles.addBtn} onPress={() => addTier('streak_days')}>
          <Ionicons name="add-circle-outline" size={20} color={COLORS.ember2} />
          <Text style={styles.addText}>Add streak tier</Text>
        </TouchableOpacity>
      </Animated.View>

      <Animated.View entering={FadeInDown.delay(200).springify()}>
        <Text style={styles.sectionTitle}>Visit Count Rewards</Text>
        {visitTiers.map(renderTierCard)}
        <TouchableOpacity style={styles.addBtn} onPress={() => addTier('visit_count')}>
          <Ionicons name="add-circle-outline" size={20} color={COLORS.ember2} />
          <Text style={styles.addText}>Add visit tier</Text>
        </TouchableOpacity>
      </Animated.View>

      <GradientButton title="Save Changes" onPress={handleSave} style={styles.saveBtn} />
      <View style={{ height: 100 }} />
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: COLORS.bg,
  },
  content: {
    paddingHorizontal: SPACING.md,
  },
  title: {
    fontSize: 28,
    fontFamily: FONTS.headingBold,
    color: COLORS.ink,
    marginBottom: SPACING.md,
  },
  windowCard: {
    backgroundColor: COLORS.card,
    borderRadius: RADIUS.lg,
    padding: SPACING.md,
    marginBottom: SPACING.lg,
    borderWidth: 1,
    borderColor: COLORS.line,
    gap: SPACING.xs,
  },
  windowLabel: {
    fontSize: 15,
    fontFamily: FONTS.headingSemiBold,
    color: COLORS.ink,
  },
  windowDesc: {
    fontSize: 13,
    fontFamily: FONTS.body,
    color: COLORS.muted,
  },
  windowInput: {
    backgroundColor: COLORS.bg,
    borderRadius: RADIUS.sm,
    paddingHorizontal: SPACING.md,
    paddingVertical: 10,
    fontSize: 18,
    fontFamily: FONTS.headingSemiBold,
    color: COLORS.ink,
    borderWidth: 1,
    borderColor: COLORS.line,
    width: 80,
    marginTop: SPACING.xs,
    textAlign: 'center',
  },
  sectionTitle: {
    fontSize: 18,
    fontFamily: FONTS.headingSemiBold,
    color: COLORS.ink,
    marginBottom: SPACING.sm,
    marginTop: SPACING.sm,
  },
  tierCard: {
    backgroundColor: COLORS.card,
    borderRadius: RADIUS.md,
    padding: SPACING.md,
    marginBottom: SPACING.sm,
    borderWidth: 1,
    borderColor: COLORS.line,
    gap: SPACING.sm,
  },
  tierHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
  },
  tierLabelInput: {
    fontSize: 15,
    fontFamily: FONTS.headingMedium,
    color: COLORS.ink,
    flex: 1,
    paddingVertical: 4,
  },
  deleteBtn: {
    padding: 4,
  },
  tierFields: {
    flexDirection: 'row',
    gap: SPACING.md,
  },
  field: {
    flex: 1,
    gap: 4,
  },
  fieldLabel: {
    fontSize: 12,
    fontFamily: FONTS.body,
    color: COLORS.muted,
  },
  fieldInput: {
    backgroundColor: COLORS.bg,
    borderRadius: RADIUS.sm,
    paddingHorizontal: SPACING.sm,
    paddingVertical: 8,
    fontSize: 16,
    fontFamily: FONTS.headingMedium,
    color: COLORS.ink,
    borderWidth: 1,
    borderColor: COLORS.line,
  },
  addBtn: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: SPACING.sm,
    paddingVertical: SPACING.sm,
    marginBottom: SPACING.md,
  },
  addText: {
    fontSize: 14,
    fontFamily: FONTS.headingMedium,
    color: COLORS.ember2,
  },
  saveBtn: {
    marginTop: SPACING.md,
  },
});
