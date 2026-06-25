import React, { useMemo, useCallback } from 'react';
import { View, Text, StyleSheet, ScrollView, RefreshControl } from 'react-native';
import { useRouter } from 'expo-router';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { useStore } from '../../src/store/StoreProvider';
import { COLORS, FONTS, SPACING } from '../../src/constants/theme';
import { getGreeting } from '../../src/utils/dates';
import { getStreakUrgency, refreshStreakAlive } from '../../src/services/streakService';
import StreakCard from '../../src/components/StreakCard';
import ShopCard from '../../src/components/ShopCard';
import EmptyState from '../../src/components/EmptyState';
import { StreakUrgency } from '../../src/types';

const URGENCY_ORDER: Record<StreakUrgency, number> = { critical: 0, warning: 1, safe: 2, dead: 3 };

export default function HomeScreen() {
  const router = useRouter();
  const insets = useSafeAreaInsets();
  const { state, refresh } = useStore();
  const [refreshing, setRefreshing] = React.useState(false);

  const onRefresh = useCallback(async () => {
    setRefreshing(true);
    await refresh();
    setRefreshing(false);
  }, [refresh]);

  const activeStreaks = useMemo(() => {
    return state.streaks
      .map(streak => {
        const shop = state.shops.find(s => s.id === streak.shopId);
        if (!shop) return null;
        const refreshed = refreshStreakAlive(streak, shop);
        const urgency = getStreakUrgency(refreshed, shop);
        return { streak: refreshed, shop, urgency };
      })
      .filter((s): s is NonNullable<typeof s> => s !== null && s.streak.totalVisits > 0)
      .sort((a, b) => URGENCY_ORDER[a.urgency] - URGENCY_ORDER[b.urgency]);
  }, [state.streaks, state.shops]);

  const bestStreak = activeStreaks.find(s => s.urgency !== 'dead');

  const discoveryShops = useMemo(() => {
    const visitedShopIds = new Set(state.streaks.map(s => s.shopId));
    return state.shops.filter(s => !visitedShopIds.has(s.id));
  }, [state.shops, state.streaks]);

  return (
    <ScrollView
      style={styles.container}
      contentContainerStyle={[styles.content, { paddingTop: insets.top + SPACING.md }]}
      refreshControl={
        <RefreshControl refreshing={refreshing} onRefresh={onRefresh} tintColor={COLORS.ember2} />
      }
      showsVerticalScrollIndicator={false}
    >
      <Text style={styles.greeting}>
        {getGreeting()}, {state.currentUser?.name || 'there'}
      </Text>
      <Text style={styles.subtitle}>Keep your streaks alive</Text>

      {bestStreak && (
        <View style={styles.section}>
          <StreakCard
            streak={bestStreak.streak}
            shop={bestStreak.shop}
            size="large"
            onPress={() => router.push(`/(customer)/shop/${bestStreak.shop.id}`)}
          />
        </View>
      )}

      {activeStreaks.length > 0 && (
        <View style={styles.section}>
          <Text style={styles.sectionTitle}>Your Streaks</Text>
          <View style={styles.streakList}>
            {activeStreaks.map(({ streak, shop }) => (
              <StreakCard
                key={streak.id}
                streak={streak}
                shop={shop}
                onPress={() => router.push(`/(customer)/shop/${shop.id}`)}
              />
            ))}
          </View>
        </View>
      )}

      {activeStreaks.length === 0 && (
        <EmptyState
          emoji="🔥"
          title="No streaks yet"
          subtitle="Scan a QR code at a restaurant to start your first streak!"
          actionLabel="Scan Now"
          onAction={() => router.push('/(customer)/scanner')}
        />
      )}

      {discoveryShops.length > 0 && (
        <View style={styles.section}>
          <Text style={styles.sectionTitle}>Discover Shops</Text>
          <View style={styles.shopList}>
            {discoveryShops.map((shop, i) => (
              <ShopCard
                key={shop.id}
                shop={shop}
                index={i}
                subtitle={`${shop.streakWindowDays}-day window`}
                onPress={() => router.push(`/(customer)/shop/${shop.id}`)}
              />
            ))}
          </View>
        </View>
      )}

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
  greeting: {
    fontSize: 28,
    fontFamily: FONTS.headingBold,
    color: COLORS.ink,
    marginBottom: 4,
  },
  subtitle: {
    fontSize: 15,
    fontFamily: FONTS.body,
    color: COLORS.muted,
    marginBottom: SPACING.lg,
  },
  section: {
    marginBottom: SPACING.lg,
  },
  sectionTitle: {
    fontSize: 18,
    fontFamily: FONTS.headingSemiBold,
    color: COLORS.ink,
    marginBottom: SPACING.md,
  },
  streakList: {
    gap: SPACING.sm,
  },
  shopList: {
    gap: SPACING.sm,
  },
});
