import React, { useMemo } from 'react';
import { View, Text, StyleSheet, ScrollView, TouchableOpacity } from 'react-native';
import { useLocalSearchParams, useRouter } from 'expo-router';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { Ionicons } from '@expo/vector-icons';
import { LinearGradient } from 'expo-linear-gradient';
import Animated, { FadeInDown } from 'react-native-reanimated';
import { useStore } from '../../../src/store/StoreProvider';
import { COLORS, FONTS, RADIUS, SPACING } from '../../../src/constants/theme';
import { getStreakUrgency, refreshStreakAlive, getBestDiscount } from '../../../src/services/streakService';
import RewardLadder from '../../../src/components/RewardLadder';
import GradientButton from '../../../src/components/GradientButton';

export default function ShopDetailScreen() {
  const { id } = useLocalSearchParams<{ id: string }>();
  const router = useRouter();
  const insets = useSafeAreaInsets();
  const { state } = useStore();

  const shop = state.shops.find(s => s.id === id);
  const rawStreak = state.streaks.find(s => s.shopId === id);
  const streak = rawStreak && shop ? refreshStreakAlive(rawStreak, shop) : null;
  const urgency = streak && shop ? getStreakUrgency(streak, shop) : null;

  const visitDiscount = streak && shop ? getBestDiscount(streak, shop, 'visit_count') : 0;
  const streakDiscount = streak && shop ? getBestDiscount(streak, shop, 'streak_days') : 0;

  const shopVouchers = state.vouchers.filter(v => v.shopId === id && !v.isRedeemed);

  if (!shop) return null;

  return (
    <View style={[styles.container, { paddingTop: insets.top }]}>
      <View style={styles.header}>
        <TouchableOpacity onPress={() => router.back()} style={styles.backBtn}>
          <Ionicons name="chevron-back" size={24} color={COLORS.ink} />
        </TouchableOpacity>
        <Text style={styles.headerTitle} numberOfLines={1}>{shop.name}</Text>
        <View style={{ width: 40 }} />
      </View>

      <ScrollView
        contentContainerStyle={styles.content}
        showsVerticalScrollIndicator={false}
      >
        <Animated.View entering={FadeInDown.springify()}>
          <LinearGradient
            colors={['rgba(255,122,24,0.12)', 'rgba(255,61,110,0.06)', 'transparent']}
            style={styles.heroGradient}
            start={{ x: 0, y: 0 }}
            end={{ x: 1, y: 1 }}
          >
            <Text style={styles.shopEmoji}>{shop.emoji}</Text>
            <Text style={styles.shopName}>{shop.name}</Text>
            <Text style={styles.shopCategory}>{shop.category} · {shop.address}</Text>
            <Text style={styles.shopDesc}>{shop.description}</Text>
          </LinearGradient>
        </Animated.View>

        {streak && (
          <Animated.View entering={FadeInDown.delay(100).springify()} style={styles.streakSection}>
            <View style={styles.bigStreakRow}>
              <Text style={styles.bigFlame}>
                {urgency === 'dead' ? '💨' : '🔥'}
              </Text>
              <View>
                <Text style={styles.bigNumber}>{streak.currentStreakDays}</Text>
                <Text style={styles.bigLabel}>
                  {urgency === 'dead' ? 'streak broken' : 'day streak'}
                </Text>
              </View>
            </View>

            <View style={styles.miniStats}>
              <View style={styles.miniStat}>
                <Text style={styles.miniValue}>{streak.totalVisits}</Text>
                <Text style={styles.miniLabel}>visits</Text>
              </View>
              <View style={styles.miniDivider} />
              <View style={styles.miniStat}>
                <Text style={styles.miniValue}>{streak.longestStreakDays}</Text>
                <Text style={styles.miniLabel}>best streak</Text>
              </View>
              <View style={styles.miniDivider} />
              <View style={styles.miniStat}>
                <Text style={[styles.miniValue, { color: COLORS.success }]}>
                  {Math.max(visitDiscount, streakDiscount)}%
                </Text>
                <Text style={styles.miniLabel}>best discount</Text>
              </View>
            </View>

            {shopVouchers.length > 0 && (
              <View style={styles.voucherCount}>
                <Ionicons name="ticket" size={16} color={COLORS.ember2} />
                <Text style={styles.voucherCountText}>
                  {shopVouchers.length} active voucher{shopVouchers.length > 1 ? 's' : ''}
                </Text>
              </View>
            )}
          </Animated.View>
        )}

        {!streak && (
          <Animated.View entering={FadeInDown.delay(100).springify()} style={styles.noStreakCard}>
            <Text style={styles.noStreakEmoji}>👋</Text>
            <Text style={styles.noStreakTitle}>No visits yet</Text>
            <Text style={styles.noStreakText}>Scan the QR code at this shop to start a streak!</Text>
          </Animated.View>
        )}

        <Animated.View entering={FadeInDown.delay(200).springify()} style={styles.ladderSection}>
          <RewardLadder
            tiers={shop.rewardTiers}
            currentValue={streak?.currentStreakDays || 0}
            type="streak_days"
            title="Streak Rewards"
          />
        </Animated.View>

        <Animated.View entering={FadeInDown.delay(300).springify()} style={styles.ladderSection}>
          <RewardLadder
            tiers={shop.rewardTiers}
            currentValue={streak?.totalVisits || 0}
            type="visit_count"
            title="Visit Rewards"
          />
        </Animated.View>

        <View style={styles.infoCard}>
          <Ionicons name="information-circle-outline" size={18} color={COLORS.muted} />
          <Text style={styles.infoText}>
            Visit within {shop.streakWindowDays} day{shop.streakWindowDays > 1 ? 's' : ''} to keep your streak alive
          </Text>
        </View>

        <View style={{ height: 120 }} />
      </ScrollView>

      <View style={[styles.bottomBar, { paddingBottom: insets.bottom + SPACING.sm }]}>
        <GradientButton
          title="Scan QR to Check In"
          onPress={() => router.push('/(customer)/scanner')}
        />
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: COLORS.bg,
  },
  header: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: SPACING.md,
    paddingVertical: SPACING.sm,
    gap: SPACING.sm,
  },
  backBtn: {
    width: 40,
    height: 40,
    borderRadius: 20,
    backgroundColor: COLORS.card,
    alignItems: 'center',
    justifyContent: 'center',
  },
  headerTitle: {
    flex: 1,
    fontSize: 17,
    fontFamily: FONTS.headingSemiBold,
    color: COLORS.ink,
    textAlign: 'center',
  },
  content: {
    paddingHorizontal: SPACING.md,
  },
  heroGradient: {
    borderRadius: RADIUS.xl,
    padding: SPACING.lg,
    alignItems: 'center',
    gap: SPACING.xs,
    marginBottom: SPACING.lg,
    borderWidth: 1,
    borderColor: COLORS.ember2 + '15',
  },
  shopEmoji: {
    fontSize: 56,
    marginBottom: SPACING.sm,
  },
  shopName: {
    fontSize: 24,
    fontFamily: FONTS.headingBold,
    color: COLORS.ink,
  },
  shopCategory: {
    fontSize: 14,
    fontFamily: FONTS.body,
    color: COLORS.muted,
    textTransform: 'capitalize',
  },
  shopDesc: {
    fontSize: 14,
    fontFamily: FONTS.body,
    color: COLORS.muted,
    textAlign: 'center',
    marginTop: SPACING.xs,
  },
  streakSection: {
    backgroundColor: COLORS.card,
    borderRadius: RADIUS.xl,
    padding: SPACING.lg,
    marginBottom: SPACING.lg,
    borderWidth: 1,
    borderColor: COLORS.line,
    gap: SPACING.md,
  },
  bigStreakRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: SPACING.md,
  },
  bigFlame: {
    fontSize: 56,
  },
  bigNumber: {
    fontSize: 48,
    fontFamily: FONTS.headingBold,
    color: COLORS.ember2,
  },
  bigLabel: {
    fontSize: 16,
    fontFamily: FONTS.body,
    color: COLORS.muted,
    marginTop: -4,
  },
  miniStats: {
    flexDirection: 'row',
    justifyContent: 'space-around',
    paddingTop: SPACING.md,
    borderTopWidth: 1,
    borderTopColor: COLORS.line,
  },
  miniStat: {
    alignItems: 'center',
    gap: 2,
  },
  miniValue: {
    fontSize: 20,
    fontFamily: FONTS.headingSemiBold,
    color: COLORS.ink,
  },
  miniLabel: {
    fontSize: 12,
    fontFamily: FONTS.body,
    color: COLORS.muted,
  },
  miniDivider: {
    width: 1,
    backgroundColor: COLORS.line,
  },
  voucherCount: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: SPACING.sm,
    backgroundColor: COLORS.ember2 + '10',
    borderRadius: RADIUS.sm,
    paddingHorizontal: SPACING.md,
    paddingVertical: SPACING.sm,
  },
  voucherCountText: {
    fontSize: 13,
    fontFamily: FONTS.bodySemiBold,
    color: COLORS.ember2,
  },
  noStreakCard: {
    backgroundColor: COLORS.card,
    borderRadius: RADIUS.xl,
    padding: SPACING.xl,
    alignItems: 'center',
    marginBottom: SPACING.lg,
    gap: SPACING.sm,
    borderWidth: 1,
    borderColor: COLORS.line,
  },
  noStreakEmoji: {
    fontSize: 48,
  },
  noStreakTitle: {
    fontSize: 18,
    fontFamily: FONTS.headingSemiBold,
    color: COLORS.ink,
  },
  noStreakText: {
    fontSize: 14,
    fontFamily: FONTS.body,
    color: COLORS.muted,
    textAlign: 'center',
  },
  ladderSection: {
    backgroundColor: COLORS.card,
    borderRadius: RADIUS.xl,
    padding: SPACING.lg,
    marginBottom: SPACING.md,
    borderWidth: 1,
    borderColor: COLORS.line,
  },
  infoCard: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: SPACING.sm,
    backgroundColor: COLORS.card,
    borderRadius: RADIUS.md,
    paddingHorizontal: SPACING.md,
    paddingVertical: 12,
    borderWidth: 1,
    borderColor: COLORS.line,
  },
  infoText: {
    fontSize: 13,
    fontFamily: FONTS.body,
    color: COLORS.muted,
    flex: 1,
  },
  bottomBar: {
    position: 'absolute',
    bottom: 0,
    left: 0,
    right: 0,
    paddingHorizontal: SPACING.md,
    paddingTop: SPACING.sm,
    backgroundColor: COLORS.bg + 'F0',
  },
});
