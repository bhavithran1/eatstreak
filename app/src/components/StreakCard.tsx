import React, { useEffect } from 'react';
import { View, Text, StyleSheet, TouchableOpacity } from 'react-native';
import { LinearGradient } from 'expo-linear-gradient';
import Animated, {
  useSharedValue,
  useAnimatedStyle,
  withRepeat,
  withSequence,
  withTiming,
  withSpring,
  withDelay,
  Easing,
} from 'react-native-reanimated';
import { COLORS, FONTS, RADIUS, SPACING } from '../constants/theme';
import { Streak, Shop, StreakUrgency } from '../types';
import { getStreakUrgency, getNextMilestone } from '../services/streakService';

interface Props {
  streak: Streak;
  shop: Shop;
  size?: 'small' | 'large';
  onPress?: () => void;
  isNew?: boolean;
}

const URGENCY_COLORS: Record<StreakUrgency, string> = {
  safe: COLORS.success,
  warning: COLORS.warning,
  critical: COLORS.error,
  dead: COLORS.muted2,
};

export default function StreakCard({ streak, shop, size = 'small', onPress, isNew }: Props) {
  const urgency = getStreakUrgency(streak, shop);
  const nextStreak = getNextMilestone(streak, shop, 'streak_days');
  const nextVisit = getNextMilestone(streak, shop, 'visit_count');

  const flameScale = useSharedValue(1);
  const flameRotate = useSharedValue(0);
  const cardScale = useSharedValue(isNew ? 0.8 : 1);

  useEffect(() => {
    if (urgency === 'dead') return;
    const speed = urgency === 'critical' ? 300 : urgency === 'warning' ? 600 : 1200;
    flameScale.value = withRepeat(
      withSequence(
        withTiming(1.15, { duration: speed, easing: Easing.inOut(Easing.ease) }),
        withTiming(1, { duration: speed, easing: Easing.inOut(Easing.ease) })
      ),
      -1,
      true
    );
    flameRotate.value = withRepeat(
      withSequence(
        withTiming(5, { duration: speed * 0.7 }),
        withTiming(-5, { duration: speed * 0.7 }),
        withTiming(0, { duration: speed * 0.5 })
      ),
      -1,
      true
    );
  }, [urgency]);

  useEffect(() => {
    if (isNew) {
      cardScale.value = withSpring(1, { damping: 12, stiffness: 100 });
    }
  }, [isNew]);

  const flameStyle = useAnimatedStyle(() => ({
    transform: [{ scale: flameScale.value }, { rotate: `${flameRotate.value}deg` }],
  }));

  const cardAnimStyle = useAnimatedStyle(() => ({
    transform: [{ scale: cardScale.value }],
  }));

  const progress = nextStreak
    ? streak.currentStreakDays / nextStreak.threshold
    : 1;

  if (size === 'large') {
    return (
      <Animated.View style={cardAnimStyle}>
        <TouchableOpacity onPress={onPress} activeOpacity={0.85} disabled={!onPress}>
          <LinearGradient
            colors={['rgba(255,122,24,0.15)', 'rgba(255,61,110,0.08)', 'transparent']}
            start={{ x: 0, y: 0 }}
            end={{ x: 1, y: 1 }}
            style={[styles.largeCard, { borderColor: URGENCY_COLORS[urgency] + '40' }]}
          >
            <View style={styles.largeTop}>
              <Animated.Text style={[styles.flameEmoji, styles.flameLarge, flameStyle]}>
                {urgency === 'dead' ? '💨' : '🔥'}
              </Animated.Text>
              <View style={styles.largeInfo}>
                <Text style={styles.shopEmoji}>{shop.emoji}</Text>
                <Text style={styles.shopName} numberOfLines={1}>{shop.name}</Text>
              </View>
            </View>

            <View style={styles.streakRow}>
              <Text style={styles.streakNumber}>{streak.currentStreakDays}</Text>
              <Text style={styles.streakLabel}>
                {urgency === 'dead' ? 'day streak (broken)' : 'day streak'}
              </Text>
            </View>

            <View style={styles.progressContainer}>
              <View style={styles.progressBg}>
                <LinearGradient
                  colors={[COLORS.ember1, COLORS.ember2, COLORS.ember3]}
                  start={{ x: 0, y: 0 }}
                  end={{ x: 1, y: 0 }}
                  style={[styles.progressFill, { width: `${Math.min(progress * 100, 100)}%` as any }]}
                />
              </View>
              {nextStreak && (
                <Text style={styles.nextMilestone}>
                  {nextStreak.threshold - streak.currentStreakDays} more days → {nextStreak.discountPercent}% off
                </Text>
              )}
            </View>

            <View style={styles.statsRow}>
              <View style={styles.stat}>
                <Text style={styles.statValue}>{streak.totalVisits}</Text>
                <Text style={styles.statLabel}>total visits</Text>
              </View>
              <View style={styles.stat}>
                <Text style={styles.statValue}>{streak.longestStreakDays}</Text>
                <Text style={styles.statLabel}>best streak</Text>
              </View>
              <View style={styles.stat}>
                <View style={[styles.urgencyDot, { backgroundColor: URGENCY_COLORS[urgency] }]} />
                <Text style={[styles.statLabel, { color: URGENCY_COLORS[urgency] }]}>
                  {urgency === 'safe' ? 'active' : urgency === 'warning' ? 'visit soon' : urgency === 'critical' ? 'expiring!' : 'broken'}
                </Text>
              </View>
            </View>
          </LinearGradient>
        </TouchableOpacity>
      </Animated.View>
    );
  }

  return (
    <Animated.View style={cardAnimStyle}>
      <TouchableOpacity onPress={onPress} activeOpacity={0.85} disabled={!onPress}>
        <View style={[styles.smallCard, { borderColor: URGENCY_COLORS[urgency] + '30' }]}>
          <Animated.Text style={[styles.flameEmoji, flameStyle]}>
            {urgency === 'dead' ? '💨' : '🔥'}
          </Animated.Text>
          <View style={styles.smallInfo}>
            <View style={styles.smallTop}>
              <Text style={styles.smallShopName} numberOfLines={1}>{shop.emoji} {shop.name}</Text>
              <View style={[styles.urgencyBadge, { backgroundColor: URGENCY_COLORS[urgency] + '20' }]}>
                <View style={[styles.urgencyDotSmall, { backgroundColor: URGENCY_COLORS[urgency] }]} />
                <Text style={[styles.urgencyText, { color: URGENCY_COLORS[urgency] }]}>
                  {urgency === 'safe' ? 'Active' : urgency === 'warning' ? 'Visit soon' : urgency === 'critical' ? 'Expiring!' : 'Broken'}
                </Text>
              </View>
            </View>
            <View style={styles.smallBottom}>
              <Text style={styles.smallStreak}>{streak.currentStreakDays} day streak</Text>
              <Text style={styles.smallVisits}>{streak.totalVisits} visits</Text>
            </View>
            <View style={styles.smallProgress}>
              <LinearGradient
                colors={[COLORS.ember1, COLORS.ember2]}
                start={{ x: 0, y: 0 }}
                end={{ x: 1, y: 0 }}
                style={[styles.smallProgressFill, { width: `${Math.min(progress * 100, 100)}%` as any }]}
              />
            </View>
          </View>
        </View>
      </TouchableOpacity>
    </Animated.View>
  );
}

const styles = StyleSheet.create({
  largeCard: {
    borderRadius: RADIUS.xl,
    padding: SPACING.lg,
    borderWidth: 1,
    overflow: 'hidden',
  },
  largeTop: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: SPACING.md,
    marginBottom: SPACING.md,
  },
  flameEmoji: {
    fontSize: 32,
  },
  flameLarge: {
    fontSize: 48,
  },
  largeInfo: {
    flex: 1,
    flexDirection: 'row',
    alignItems: 'center',
    gap: SPACING.sm,
  },
  shopEmoji: {
    fontSize: 24,
  },
  shopName: {
    fontSize: 18,
    fontFamily: FONTS.headingSemiBold,
    color: COLORS.ink,
    flex: 1,
  },
  streakRow: {
    flexDirection: 'row',
    alignItems: 'baseline',
    gap: SPACING.sm,
    marginBottom: SPACING.md,
  },
  streakNumber: {
    fontSize: 48,
    fontFamily: FONTS.headingBold,
    color: COLORS.ember2,
  },
  streakLabel: {
    fontSize: 16,
    fontFamily: FONTS.body,
    color: COLORS.muted,
  },
  progressContainer: {
    marginBottom: SPACING.md,
  },
  progressBg: {
    height: 6,
    backgroundColor: COLORS.line2,
    borderRadius: 3,
    overflow: 'hidden',
  },
  progressFill: {
    height: '100%',
    borderRadius: 3,
  },
  nextMilestone: {
    fontSize: 13,
    fontFamily: FONTS.bodyMedium,
    color: COLORS.muted,
    marginTop: SPACING.xs,
  },
  statsRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
  },
  stat: {
    alignItems: 'center',
    gap: 4,
  },
  statValue: {
    fontSize: 20,
    fontFamily: FONTS.headingSemiBold,
    color: COLORS.ink,
  },
  statLabel: {
    fontSize: 12,
    fontFamily: FONTS.body,
    color: COLORS.muted,
  },
  urgencyDot: {
    width: 8,
    height: 8,
    borderRadius: 4,
  },
  smallCard: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: COLORS.card,
    borderRadius: RADIUS.lg,
    padding: SPACING.md,
    borderWidth: 1,
    gap: SPACING.sm,
  },
  smallInfo: {
    flex: 1,
    gap: 6,
  },
  smallTop: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
  },
  smallShopName: {
    fontSize: 15,
    fontFamily: FONTS.headingMedium,
    color: COLORS.ink,
    flex: 1,
  },
  urgencyBadge: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 4,
    paddingHorizontal: 8,
    paddingVertical: 3,
    borderRadius: RADIUS.pill,
  },
  urgencyDotSmall: {
    width: 6,
    height: 6,
    borderRadius: 3,
  },
  urgencyText: {
    fontSize: 11,
    fontFamily: FONTS.bodySemiBold,
  },
  smallBottom: {
    flexDirection: 'row',
    gap: SPACING.md,
  },
  smallStreak: {
    fontSize: 13,
    fontFamily: FONTS.bodySemiBold,
    color: COLORS.ember2,
  },
  smallVisits: {
    fontSize: 13,
    fontFamily: FONTS.body,
    color: COLORS.muted,
  },
  smallProgress: {
    height: 3,
    backgroundColor: COLORS.line2,
    borderRadius: 2,
    overflow: 'hidden',
  },
  smallProgressFill: {
    height: '100%',
    borderRadius: 2,
  },
});
