import React from 'react';
import { View, Text, StyleSheet } from 'react-native';
import { LinearGradient } from 'expo-linear-gradient';
import { COLORS, FONTS, RADIUS, SPACING } from '../constants/theme';
import { RewardTier } from '../types';
import { Ionicons } from '@expo/vector-icons';

interface Props {
  tiers: RewardTier[];
  currentValue: number;
  type: 'visit_count' | 'streak_days';
  title: string;
}

export default function RewardLadder({ tiers, currentValue, type, title }: Props) {
  const sorted = [...tiers].filter(t => t.type === type).sort((a, b) => a.threshold - b.threshold);

  return (
    <View style={styles.container}>
      <Text style={styles.title}>{title}</Text>
      {sorted.map((tier, i) => {
        const achieved = currentValue >= tier.threshold;
        const progress = achieved ? 1 : currentValue / tier.threshold;
        const isCurrent = !achieved && (i === 0 || currentValue >= sorted[i - 1].threshold);

        return (
          <View key={tier.id} style={[styles.tierRow, isCurrent && styles.currentRow]}>
            <View style={styles.tierLeft}>
              {achieved ? (
                <View style={styles.checkCircle}>
                  <Ionicons name="checkmark" size={14} color="#1a0d05" />
                </View>
              ) : (
                <View style={[styles.emptyCircle, isCurrent && styles.currentCircle]}>
                  <Text style={styles.tierEmoji}>{tier.emoji}</Text>
                </View>
              )}
              {i < sorted.length - 1 && (
                <View style={[styles.connector, achieved && styles.connectorDone]} />
              )}
            </View>

            <View style={styles.tierContent}>
              <View style={styles.tierHeader}>
                <Text style={[styles.tierLabel, achieved && styles.tierLabelDone]}>{tier.label}</Text>
                <Text style={[styles.tierDiscount, achieved && styles.tierDiscountDone]}>
                  {tier.discountPercent}% off
                </Text>
              </View>
              <Text style={styles.tierDesc}>{tier.description}</Text>
              {!achieved && (
                <View style={styles.tierProgress}>
                  <View style={styles.tierProgressBg}>
                    <LinearGradient
                      colors={isCurrent ? [COLORS.ember1, COLORS.ember2] : [COLORS.muted2, COLORS.muted2]}
                      start={{ x: 0, y: 0 }}
                      end={{ x: 1, y: 0 }}
                      style={[styles.tierProgressFill, { width: `${Math.min(progress * 100, 100)}%` as any }]}
                    />
                  </View>
                  <Text style={styles.tierProgressText}>
                    {currentValue}/{tier.threshold}
                  </Text>
                </View>
              )}
            </View>
          </View>
        );
      })}
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    gap: 0,
  },
  title: {
    fontSize: 16,
    fontFamily: FONTS.headingSemiBold,
    color: COLORS.ink,
    marginBottom: SPACING.md,
  },
  tierRow: {
    flexDirection: 'row',
    gap: SPACING.md,
    paddingVertical: SPACING.sm,
  },
  currentRow: {
    backgroundColor: COLORS.ember2 + '08',
    borderRadius: RADIUS.md,
    marginHorizontal: -SPACING.sm,
    paddingHorizontal: SPACING.sm,
  },
  tierLeft: {
    alignItems: 'center',
    width: 32,
  },
  checkCircle: {
    width: 24,
    height: 24,
    borderRadius: 12,
    backgroundColor: COLORS.success,
    alignItems: 'center',
    justifyContent: 'center',
  },
  emptyCircle: {
    width: 24,
    height: 24,
    borderRadius: 12,
    borderWidth: 2,
    borderColor: COLORS.line2,
    alignItems: 'center',
    justifyContent: 'center',
  },
  currentCircle: {
    borderColor: COLORS.ember2,
  },
  tierEmoji: {
    fontSize: 10,
  },
  connector: {
    width: 2,
    flex: 1,
    backgroundColor: COLORS.line2,
    marginVertical: 4,
  },
  connectorDone: {
    backgroundColor: COLORS.success + '60',
  },
  tierContent: {
    flex: 1,
    gap: 4,
    paddingBottom: SPACING.sm,
  },
  tierHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
  },
  tierLabel: {
    fontSize: 14,
    fontFamily: FONTS.headingMedium,
    color: COLORS.ink,
  },
  tierLabelDone: {
    color: COLORS.success,
  },
  tierDiscount: {
    fontSize: 14,
    fontFamily: FONTS.headingSemiBold,
    color: COLORS.ember2,
  },
  tierDiscountDone: {
    color: COLORS.success,
  },
  tierDesc: {
    fontSize: 12,
    fontFamily: FONTS.body,
    color: COLORS.muted,
  },
  tierProgress: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: SPACING.sm,
    marginTop: 4,
  },
  tierProgressBg: {
    flex: 1,
    height: 4,
    backgroundColor: COLORS.line2,
    borderRadius: 2,
    overflow: 'hidden',
  },
  tierProgressFill: {
    height: '100%',
    borderRadius: 2,
  },
  tierProgressText: {
    fontSize: 11,
    fontFamily: FONTS.bodySemiBold,
    color: COLORS.muted,
    width: 40,
    textAlign: 'right',
  },
});
