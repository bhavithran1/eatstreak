import React, { useMemo } from 'react';
import { View, Text, StyleSheet, ScrollView } from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { LinearGradient } from 'expo-linear-gradient';
import Animated, { FadeInDown } from 'react-native-reanimated';
import Svg, { Path, Defs, LinearGradient as SvgGradient, Stop } from 'react-native-svg';
import { useStore } from '../../src/store/StoreProvider';
import { COLORS, FONTS, RADIUS, SPACING } from '../../src/constants/theme';
import { daysBetween, toDateString, dateNDaysAgo } from '../../src/utils/dates';

export default function DashboardScreen() {
  const insets = useSafeAreaInsets();
  const { state } = useStore();

  const ownerShop = state.shops.find(s => s.ownerId === state.currentUser?.id);

  const allVisits = useMemo(() => {
    if (!ownerShop) return [];
    return state.visits.filter(v => v.shopId === ownerShop.id);
  }, [state.visits, ownerShop]);

  const allStreaks = useMemo(() => {
    if (!ownerShop) return [];
    return state.streaks.filter(s => s.shopId === ownerShop.id);
  }, [state.streaks, ownerShop]);

  const kpis = useMemo(() => {
    const activeStreaks = allStreaks.filter(s => {
      if (!ownerShop) return false;
      const days = daysBetween(s.lastVisitDate, toDateString(new Date()));
      return days <= ownerShop.streakWindowDays;
    });

    const totalCustomers = allStreaks.length;
    const repeatRate = totalCustomers > 0
      ? Math.round((allStreaks.filter(s => s.totalVisits > 1).length / totalCustomers) * 100)
      : 0;

    return {
      activeStreaks: activeStreaks.length,
      repeatRate,
      totalVisits: allVisits.length,
    };
  }, [allStreaks, allVisits, ownerShop]);

  const segments = useMemo(() => {
    const today = toDateString(new Date());
    const regulars = allStreaks.filter(s => s.currentStreakDays >= 30);
    const growing = allStreaks.filter(s => s.currentStreakDays >= 7 && s.currentStreakDays < 30);
    const fresh = allStreaks.filter(s => s.currentStreakDays >= 1 && s.currentStreakDays < 7);
    const atRisk = allStreaks.filter(s => {
      if (!ownerShop) return false;
      const days = daysBetween(s.lastVisitDate, today);
      return days > ownerShop.streakWindowDays;
    });
    return { regulars, growing, fresh, atRisk };
  }, [allStreaks, ownerShop]);

  const sparklineData = useMemo(() => {
    const data: number[] = [];
    for (let i = 29; i >= 0; i--) {
      const day = dateNDaysAgo(i);
      const count = allVisits.filter(v => v.timestamp.startsWith(day)).length;
      data.push(count);
    }
    return data;
  }, [allVisits]);

  const sparklinePath = useMemo(() => {
    if (sparklineData.every(d => d === 0)) return '';
    const max = Math.max(...sparklineData, 1);
    const w = 280;
    const h = 60;
    const step = w / (sparklineData.length - 1);
    let path = '';
    sparklineData.forEach((val, i) => {
      const x = i * step;
      const y = h - (val / max) * h;
      path += i === 0 ? `M ${x} ${y}` : ` L ${x} ${y}`;
    });
    return path;
  }, [sparklineData]);

  if (!ownerShop) {
    return (
      <View style={[styles.container, { paddingTop: insets.top }]}>
        <Text style={styles.noShop}>No shop assigned to this account</Text>
      </View>
    );
  }

  return (
    <ScrollView
      style={styles.container}
      contentContainerStyle={[styles.content, { paddingTop: insets.top + SPACING.md }]}
      showsVerticalScrollIndicator={false}
    >
      <View style={styles.headerRow}>
        <View>
          <Text style={styles.shopName}>{ownerShop.emoji} {ownerShop.name}</Text>
          <Text style={styles.headerSub}>Owner Dashboard</Text>
        </View>
        <View style={styles.liveBadge}>
          <View style={styles.liveDot} />
          <Text style={styles.liveText}>Live</Text>
        </View>
      </View>

      <Animated.View entering={FadeInDown.springify()} style={styles.kpiRow}>
        {[
          { label: 'Active Streaks', value: kpis.activeStreaks, color: COLORS.ember2 },
          { label: 'Repeat Rate', value: `${kpis.repeatRate}%`, color: COLORS.success },
          { label: 'Total Visits', value: kpis.totalVisits, color: COLORS.ember1 },
        ].map((kpi) => (
          <View key={kpi.label} style={styles.kpiCard}>
            <Text style={[styles.kpiValue, { color: kpi.color }]}>{kpi.value}</Text>
            <Text style={styles.kpiLabel}>{kpi.label}</Text>
          </View>
        ))}
      </Animated.View>

      <Animated.View entering={FadeInDown.delay(100).springify()} style={styles.sparkCard}>
        <Text style={styles.cardTitle}>Visits (30 days)</Text>
        <Svg width="100%" height={60} viewBox="0 0 280 60">
          <Defs>
            <SvgGradient id="lineGrad" x1="0" y1="0" x2="1" y2="0">
              <Stop offset="0" stopColor={COLORS.ember1} />
              <Stop offset="1" stopColor={COLORS.ember3} />
            </SvgGradient>
          </Defs>
          {sparklinePath ? (
            <Path d={sparklinePath} stroke="url(#lineGrad)" strokeWidth={2.5} fill="none" strokeLinecap="round" strokeLinejoin="round" />
          ) : (
            <Path d="M 0 30 L 280 30" stroke={COLORS.muted2} strokeWidth={1} strokeDasharray="4 4" />
          )}
        </Svg>
      </Animated.View>

      <Animated.View entering={FadeInDown.delay(200).springify()} style={styles.segmentCard}>
        <Text style={styles.cardTitle}>Customer Segments</Text>
        {[
          { label: 'Regulars (30+ days)', count: segments.regulars.length, color: COLORS.success, emoji: '👑' },
          { label: 'Growing (7-29 days)', count: segments.growing.length, color: COLORS.ember2, emoji: '🔥' },
          { label: 'New (1-6 days)', count: segments.fresh.length, color: COLORS.ember1, emoji: '🌱' },
          { label: 'At risk (lapsed)', count: segments.atRisk.length, color: COLORS.error, emoji: '⚠️' },
        ].map((seg) => (
          <View key={seg.label} style={styles.segRow}>
            <Text style={styles.segEmoji}>{seg.emoji}</Text>
            <Text style={styles.segLabel}>{seg.label}</Text>
            <View style={styles.segBarBg}>
              <View
                style={[
                  styles.segBarFill,
                  {
                    backgroundColor: seg.color,
                    width: `${Math.max((seg.count / Math.max(allStreaks.length, 1)) * 100, 4)}%` as any,
                  },
                ]}
              />
            </View>
            <Text style={[styles.segCount, { color: seg.color }]}>{seg.count}</Text>
          </View>
        ))}
      </Animated.View>

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
  noShop: {
    fontSize: 16,
    fontFamily: FONTS.body,
    color: COLORS.muted,
    textAlign: 'center',
    marginTop: 100,
  },
  headerRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: SPACING.lg,
  },
  shopName: {
    fontSize: 24,
    fontFamily: FONTS.headingBold,
    color: COLORS.ink,
  },
  headerSub: {
    fontSize: 14,
    fontFamily: FONTS.body,
    color: COLORS.muted,
  },
  liveBadge: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 6,
    backgroundColor: COLORS.success + '15',
    paddingHorizontal: 12,
    paddingVertical: 6,
    borderRadius: RADIUS.pill,
    borderWidth: 1,
    borderColor: COLORS.success + '30',
  },
  liveDot: {
    width: 8,
    height: 8,
    borderRadius: 4,
    backgroundColor: COLORS.success,
  },
  liveText: {
    fontSize: 13,
    fontFamily: FONTS.bodySemiBold,
    color: COLORS.success,
  },
  kpiRow: {
    flexDirection: 'row',
    gap: SPACING.sm,
    marginBottom: SPACING.md,
  },
  kpiCard: {
    flex: 1,
    backgroundColor: COLORS.card,
    borderRadius: RADIUS.lg,
    padding: SPACING.md,
    alignItems: 'center',
    gap: 4,
    borderWidth: 1,
    borderColor: COLORS.line,
  },
  kpiValue: {
    fontSize: 28,
    fontFamily: FONTS.headingBold,
  },
  kpiLabel: {
    fontSize: 11,
    fontFamily: FONTS.body,
    color: COLORS.muted,
    textAlign: 'center',
  },
  sparkCard: {
    backgroundColor: COLORS.card,
    borderRadius: RADIUS.lg,
    padding: SPACING.md,
    marginBottom: SPACING.md,
    borderWidth: 1,
    borderColor: COLORS.line,
    gap: SPACING.sm,
  },
  cardTitle: {
    fontSize: 15,
    fontFamily: FONTS.headingSemiBold,
    color: COLORS.ink,
  },
  segmentCard: {
    backgroundColor: COLORS.card,
    borderRadius: RADIUS.lg,
    padding: SPACING.md,
    borderWidth: 1,
    borderColor: COLORS.line,
    gap: SPACING.md,
  },
  segRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: SPACING.sm,
  },
  segEmoji: {
    fontSize: 16,
    width: 24,
    textAlign: 'center',
  },
  segLabel: {
    fontSize: 13,
    fontFamily: FONTS.body,
    color: COLORS.muted,
    width: 130,
  },
  segBarBg: {
    flex: 1,
    height: 6,
    backgroundColor: COLORS.line2,
    borderRadius: 3,
    overflow: 'hidden',
  },
  segBarFill: {
    height: '100%',
    borderRadius: 3,
  },
  segCount: {
    fontSize: 14,
    fontFamily: FONTS.headingSemiBold,
    width: 24,
    textAlign: 'right',
  },
});
