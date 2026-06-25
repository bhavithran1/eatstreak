import React, { useMemo, useState } from 'react';
import { View, Text, StyleSheet, FlatList, TextInput } from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import Animated, { FadeInDown } from 'react-native-reanimated';
import { Ionicons } from '@expo/vector-icons';
import { useStore } from '../../src/store/StoreProvider';
import { COLORS, FONTS, RADIUS, SPACING } from '../../src/constants/theme';
import { daysBetween, toDateString, formatDate } from '../../src/utils/dates';
import EmptyState from '../../src/components/EmptyState';

interface CustomerRow {
  userId: string;
  name: string;
  initial: string;
  currentStreak: number;
  totalVisits: number;
  lastVisit: string;
  status: 'active' | 'warning' | 'lapsed';
}

export default function CustomersScreen() {
  const insets = useSafeAreaInsets();
  const { state } = useStore();
  const [search, setSearch] = useState('');

  const ownerShop = state.shops.find(s => s.ownerId === state.currentUser?.id);

  const customers = useMemo((): CustomerRow[] => {
    if (!ownerShop) return [];
    const shopStreaks = state.streaks.filter(s => s.shopId === ownerShop.id);
    const today = toDateString(new Date());

    return shopStreaks
      .map(streak => {
        const daysSince = daysBetween(streak.lastVisitDate, today);
        let status: 'active' | 'warning' | 'lapsed' = 'active';
        if (daysSince > ownerShop.streakWindowDays) status = 'lapsed';
        else if (daysSince > 0) status = 'warning';

        const user = state.shops.length > 0 ? null : null;
        const name = streak.userId === 'user_maya' ? 'Maya' : `Customer ${streak.userId.slice(-4)}`;

        return {
          userId: streak.userId,
          name,
          initial: name.charAt(0),
          currentStreak: streak.currentStreakDays,
          totalVisits: streak.totalVisits,
          lastVisit: streak.lastVisitDate,
          status,
        };
      })
      .filter(c => search === '' || c.name.toLowerCase().includes(search.toLowerCase()))
      .sort((a, b) => b.currentStreak - a.currentStreak);
  }, [state.streaks, ownerShop, search]);

  const STATUS_COLORS = {
    active: COLORS.success,
    warning: COLORS.warning,
    lapsed: COLORS.error,
  };

  return (
    <View style={[styles.container, { paddingTop: insets.top + SPACING.md }]}>
      <Text style={styles.title}>Customers</Text>

      <View style={styles.searchRow}>
        <Ionicons name="search" size={18} color={COLORS.muted2} />
        <TextInput
          style={styles.searchInput}
          placeholder="Search customers..."
          placeholderTextColor={COLORS.muted2}
          value={search}
          onChangeText={setSearch}
        />
      </View>

      <FlatList
        data={customers}
        keyExtractor={c => c.userId}
        showsVerticalScrollIndicator={false}
        contentContainerStyle={styles.list}
        renderItem={({ item, index }) => (
          <Animated.View entering={FadeInDown.delay(index * 60).springify()}>
            <View style={styles.customerCard}>
              <View style={[styles.avatar, { borderColor: STATUS_COLORS[item.status] }]}>
                <Text style={styles.avatarText}>{item.initial}</Text>
              </View>
              <View style={styles.info}>
                <View style={styles.nameRow}>
                  <Text style={styles.name}>{item.name}</Text>
                  <View style={[styles.statusBadge, { backgroundColor: STATUS_COLORS[item.status] + '20' }]}>
                    <View style={[styles.statusDot, { backgroundColor: STATUS_COLORS[item.status] }]} />
                    <Text style={[styles.statusText, { color: STATUS_COLORS[item.status] }]}>
                      {item.status === 'active' ? 'Active' : item.status === 'warning' ? 'At risk' : 'Lapsed'}
                    </Text>
                  </View>
                </View>
                <View style={styles.statsRow}>
                  <Text style={styles.statText}>🔥 {item.currentStreak} day streak</Text>
                  <Text style={styles.statText}>👣 {item.totalVisits} visits</Text>
                </View>
                <Text style={styles.lastVisit}>Last visit: {formatDate(item.lastVisit)}</Text>
              </View>
            </View>
          </Animated.View>
        )}
        ListEmptyComponent={
          <EmptyState
            emoji="👥"
            title="No customers yet"
            subtitle="Share your QR code to get your first customers!"
          />
        }
        ItemSeparatorComponent={() => <View style={{ height: SPACING.sm }} />}
      />
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: COLORS.bg,
    paddingHorizontal: SPACING.md,
  },
  title: {
    fontSize: 28,
    fontFamily: FONTS.headingBold,
    color: COLORS.ink,
    marginBottom: SPACING.md,
  },
  searchRow: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: COLORS.card,
    borderRadius: RADIUS.md,
    paddingHorizontal: SPACING.md,
    marginBottom: SPACING.md,
    borderWidth: 1,
    borderColor: COLORS.line,
    gap: SPACING.sm,
  },
  searchInput: {
    flex: 1,
    paddingVertical: 12,
    fontSize: 15,
    fontFamily: FONTS.body,
    color: COLORS.ink,
  },
  list: {
    paddingBottom: 100,
  },
  customerCard: {
    flexDirection: 'row',
    backgroundColor: COLORS.card,
    borderRadius: RADIUS.lg,
    padding: SPACING.md,
    gap: SPACING.md,
    borderWidth: 1,
    borderColor: COLORS.line,
  },
  avatar: {
    width: 44,
    height: 44,
    borderRadius: 22,
    backgroundColor: COLORS.card2,
    alignItems: 'center',
    justifyContent: 'center',
    borderWidth: 2,
  },
  avatarText: {
    fontSize: 18,
    fontFamily: FONTS.headingSemiBold,
    color: COLORS.ink,
  },
  info: {
    flex: 1,
    gap: 4,
  },
  nameRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
  },
  name: {
    fontSize: 16,
    fontFamily: FONTS.headingMedium,
    color: COLORS.ink,
  },
  statusBadge: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 4,
    paddingHorizontal: 8,
    paddingVertical: 3,
    borderRadius: RADIUS.pill,
  },
  statusDot: {
    width: 6,
    height: 6,
    borderRadius: 3,
  },
  statusText: {
    fontSize: 11,
    fontFamily: FONTS.bodySemiBold,
  },
  statsRow: {
    flexDirection: 'row',
    gap: SPACING.md,
  },
  statText: {
    fontSize: 13,
    fontFamily: FONTS.bodyMedium,
    color: COLORS.muted,
  },
  lastVisit: {
    fontSize: 12,
    fontFamily: FONTS.body,
    color: COLORS.muted2,
  },
});
