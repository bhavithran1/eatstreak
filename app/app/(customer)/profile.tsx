import React from 'react';
import { View, Text, StyleSheet, ScrollView, TouchableOpacity, Alert } from 'react-native';
import { useRouter } from 'expo-router';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { LinearGradient } from 'expo-linear-gradient';
import Animated, { FadeInDown } from 'react-native-reanimated';
import { useStore } from '../../src/store/StoreProvider';
import { COLORS, FONTS, RADIUS, SPACING } from '../../src/constants/theme';
import RoleSwitcher from '../../src/components/RoleSwitcher';
import { daysFromNow } from '../../src/utils/dates';

export default function CustomerProfileScreen() {
  const router = useRouter();
  const insets = useSafeAreaInsets();
  const { state, switchRole, resetAll } = useStore();
  const user = state.currentUser;

  const stats = {
    shopsVisited: new Set(state.streaks.map(s => s.shopId)).size,
    totalVisits: state.streaks.reduce((sum, s) => sum + s.totalVisits, 0),
    activeStreaks: state.streaks.filter(s => s.isStreakAlive).length,
    vouchersEarned: state.vouchers.length,
    activeVouchers: state.vouchers.filter(v => !v.isRedeemed && daysFromNow(v.expiresAt) > 0).length,
  };

  const handleSwitch = async (role: 'customer' | 'owner') => {
    if (role === state.currentRole) return;
    await switchRole(role);
    if (role === 'owner') {
      router.replace('/(owner)/dashboard');
    }
  };

  const handleReset = () => {
    Alert.alert(
      'Reset All Data',
      'This will clear everything and restore demo data. Are you sure?',
      [
        { text: 'Cancel', style: 'cancel' },
        {
          text: 'Reset',
          style: 'destructive',
          onPress: async () => {
            await resetAll();
            router.replace('/');
          },
        },
      ]
    );
  };

  return (
    <ScrollView
      style={styles.container}
      contentContainerStyle={[styles.content, { paddingTop: insets.top + SPACING.md }]}
      showsVerticalScrollIndicator={false}
    >
      <Text style={styles.title}>Profile</Text>

      <Animated.View entering={FadeInDown.springify()} style={styles.avatarSection}>
        <LinearGradient
          colors={[COLORS.ember1, COLORS.ember2, COLORS.ember3]}
          style={styles.avatar}
          start={{ x: 0, y: 0 }}
          end={{ x: 1, y: 1 }}
        >
          <Text style={styles.avatarText}>{user?.name?.charAt(0) || '?'}</Text>
        </LinearGradient>
        <Text style={styles.userName}>{user?.name}</Text>
        <Text style={styles.userEmail}>{user?.email}</Text>
      </Animated.View>

      <Animated.View entering={FadeInDown.delay(100).springify()} style={styles.statsGrid}>
        {[
          { label: 'Shops visited', value: stats.shopsVisited, emoji: '🏪' },
          { label: 'Total visits', value: stats.totalVisits, emoji: '👣' },
          { label: 'Active streaks', value: stats.activeStreaks, emoji: '🔥' },
          { label: 'Vouchers earned', value: stats.vouchersEarned, emoji: '🎫' },
        ].map((stat, i) => (
          <View key={stat.label} style={styles.statCard}>
            <Text style={styles.statEmoji}>{stat.emoji}</Text>
            <Text style={styles.statValue}>{stat.value}</Text>
            <Text style={styles.statLabel}>{stat.label}</Text>
          </View>
        ))}
      </Animated.View>

      <Animated.View entering={FadeInDown.delay(200).springify()}>
        <Text style={styles.sectionTitle}>Switch Role</Text>
        <RoleSwitcher currentRole={state.currentRole} onSwitch={handleSwitch} />
      </Animated.View>

      <Animated.View entering={FadeInDown.delay(300).springify()}>
        <TouchableOpacity style={styles.resetBtn} onPress={handleReset}>
          <Text style={styles.resetText}>Reset All Data</Text>
        </TouchableOpacity>
      </Animated.View>

      <Text style={styles.footer}>EatStreak v1.0 · Made with 🔥</Text>
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
    marginBottom: SPACING.lg,
  },
  avatarSection: {
    alignItems: 'center',
    marginBottom: SPACING.xl,
    gap: SPACING.sm,
  },
  avatar: {
    width: 80,
    height: 80,
    borderRadius: 40,
    alignItems: 'center',
    justifyContent: 'center',
  },
  avatarText: {
    fontSize: 32,
    fontFamily: FONTS.headingBold,
    color: '#1a0d05',
  },
  userName: {
    fontSize: 22,
    fontFamily: FONTS.headingBold,
    color: COLORS.ink,
  },
  userEmail: {
    fontSize: 14,
    fontFamily: FONTS.body,
    color: COLORS.muted,
  },
  statsGrid: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: SPACING.sm,
    marginBottom: SPACING.xl,
  },
  statCard: {
    width: '48%',
    backgroundColor: COLORS.card,
    borderRadius: RADIUS.lg,
    padding: SPACING.md,
    alignItems: 'center',
    gap: 4,
    borderWidth: 1,
    borderColor: COLORS.line,
    flexGrow: 1,
    flexBasis: '45%',
  },
  statEmoji: {
    fontSize: 24,
  },
  statValue: {
    fontSize: 28,
    fontFamily: FONTS.headingBold,
    color: COLORS.ink,
  },
  statLabel: {
    fontSize: 12,
    fontFamily: FONTS.body,
    color: COLORS.muted,
  },
  sectionTitle: {
    fontSize: 16,
    fontFamily: FONTS.headingSemiBold,
    color: COLORS.ink,
    marginBottom: SPACING.sm,
  },
  resetBtn: {
    marginTop: SPACING.xl,
    paddingVertical: 14,
    alignItems: 'center',
    borderRadius: RADIUS.md,
    borderWidth: 1,
    borderColor: COLORS.error + '40',
  },
  resetText: {
    fontSize: 14,
    fontFamily: FONTS.headingMedium,
    color: COLORS.error,
  },
  footer: {
    fontSize: 12,
    fontFamily: FONTS.body,
    color: COLORS.muted2,
    textAlign: 'center',
    marginTop: SPACING.xl,
  },
});
