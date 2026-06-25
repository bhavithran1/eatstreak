import React, { useMemo, useState } from 'react';
import { View, Text, StyleSheet, FlatList, TouchableOpacity, Alert } from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { useStore } from '../../src/store/StoreProvider';
import { useToast } from '../../src/components/Toast';
import { COLORS, FONTS, RADIUS, SPACING } from '../../src/constants/theme';
import VoucherCard from '../../src/components/VoucherCard';
import EmptyState from '../../src/components/EmptyState';
import { daysFromNow } from '../../src/utils/dates';
import * as Haptics from 'expo-haptics';

type Tab = 'active' | 'used' | 'expired';

export default function VouchersScreen() {
  const insets = useSafeAreaInsets();
  const { state, redeemVoucher } = useStore();
  const { showToast } = useToast();
  const [activeTab, setActiveTab] = useState<Tab>('active');

  const grouped = useMemo(() => {
    const active = state.vouchers.filter(v => !v.isRedeemed && daysFromNow(v.expiresAt) > 0);
    const used = state.vouchers.filter(v => v.isRedeemed);
    const expired = state.vouchers.filter(v => !v.isRedeemed && daysFromNow(v.expiresAt) <= 0);
    return { active, used, expired };
  }, [state.vouchers]);

  const currentList = grouped[activeTab];

  const handleRedeem = (voucherId: string) => {
    Alert.alert(
      'Use Voucher',
      'Show this to staff to apply your discount. Mark as used?',
      [
        { text: 'Cancel', style: 'cancel' },
        {
          text: 'Mark as Used',
          onPress: async () => {
            await redeemVoucher(voucherId);
            Haptics.notificationAsync(Haptics.NotificationFeedbackType.Success);
            showToast({ message: 'Voucher redeemed!', type: 'success' });
          },
        },
      ]
    );
  };

  return (
    <View style={[styles.container, { paddingTop: insets.top + SPACING.md }]}>
      <Text style={styles.title}>My Vouchers</Text>

      <View style={styles.tabs}>
        {(['active', 'used', 'expired'] as Tab[]).map(tab => (
          <TouchableOpacity
            key={tab}
            style={[styles.tab, activeTab === tab && styles.activeTab]}
            onPress={() => setActiveTab(tab)}
          >
            <Text style={[styles.tabText, activeTab === tab && styles.activeTabText]}>
              {tab.charAt(0).toUpperCase() + tab.slice(1)}
            </Text>
            <View style={[styles.tabBadge, activeTab === tab && styles.activeTabBadge]}>
              <Text style={[styles.tabBadgeText, activeTab === tab && styles.activeTabBadgeText]}>
                {grouped[tab].length}
              </Text>
            </View>
          </TouchableOpacity>
        ))}
      </View>

      <FlatList
        data={currentList}
        keyExtractor={v => v.id}
        contentContainerStyle={styles.list}
        showsVerticalScrollIndicator={false}
        renderItem={({ item, index }) => (
          <VoucherCard
            voucher={item}
            index={index}
            onRedeem={activeTab === 'active' ? () => handleRedeem(item.id) : undefined}
          />
        )}
        ListEmptyComponent={
          <EmptyState
            emoji={activeTab === 'active' ? '🎫' : activeTab === 'used' ? '✅' : '⏰'}
            title={`No ${activeTab} vouchers`}
            subtitle={
              activeTab === 'active'
                ? 'Keep your streaks alive to earn rewards!'
                : activeTab === 'used'
                ? "Vouchers you've redeemed will appear here"
                : 'Expired vouchers will show up here'
            }
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
  tabs: {
    flexDirection: 'row',
    backgroundColor: COLORS.card,
    borderRadius: RADIUS.md,
    padding: 4,
    marginBottom: SPACING.md,
    borderWidth: 1,
    borderColor: COLORS.line,
  },
  tab: {
    flex: 1,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    paddingVertical: 10,
    borderRadius: RADIUS.sm,
    gap: 6,
  },
  activeTab: {
    backgroundColor: COLORS.card2,
  },
  tabText: {
    fontSize: 13,
    fontFamily: FONTS.headingMedium,
    color: COLORS.muted2,
  },
  activeTabText: {
    color: COLORS.ink,
  },
  tabBadge: {
    backgroundColor: COLORS.line,
    borderRadius: RADIUS.pill,
    paddingHorizontal: 6,
    paddingVertical: 1,
    minWidth: 20,
    alignItems: 'center',
  },
  activeTabBadge: {
    backgroundColor: COLORS.ember2,
  },
  tabBadgeText: {
    fontSize: 11,
    fontFamily: FONTS.bodySemiBold,
    color: COLORS.muted,
  },
  activeTabBadgeText: {
    color: '#1a0d05',
  },
  list: {
    paddingBottom: 100,
  },
});
