import React, { useEffect } from 'react';
import { View, Text, StyleSheet } from 'react-native';
import { useLocalSearchParams, useRouter } from 'expo-router';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { LinearGradient } from 'expo-linear-gradient';
import Animated, {
  useSharedValue,
  useAnimatedStyle,
  withSpring,
  withDelay,
} from 'react-native-reanimated';
import * as Haptics from 'expo-haptics';
import { COLORS, FONTS, RADIUS, SPACING } from '../../src/constants/theme';
import { useStore } from '../../src/store/StoreProvider';
import GradientButton from '../../src/components/GradientButton';

function useFadeInUp(delay: number) {
  const opacity = useSharedValue(0);
  const translateY = useSharedValue(30);
  useEffect(() => {
    opacity.value = withDelay(delay, withSpring(1, { damping: 15, stiffness: 100 }));
    translateY.value = withDelay(delay, withSpring(0, { damping: 15, stiffness: 100 }));
  }, []);
  return useAnimatedStyle(() => ({
    opacity: opacity.value,
    transform: [{ translateY: translateY.value }],
  }));
}

export default function ScanSuccessScreen() {
  const router = useRouter();
  const insets = useSafeAreaInsets();
  const { state } = useStore();
  const params = useLocalSearchParams<{
    shopId: string;
    streakDays: string;
    totalVisits: string;
    newVoucherCount: string;
  }>();

  const shop = state.shops.find(s => s.id === params.shopId);
  const streakDays = parseInt(params.streakDays || '1');
  const totalVisits = parseInt(params.totalVisits || '1');
  const newVouchers = parseInt(params.newVoucherCount || '0');

  const flameScale = useSharedValue(0);
  const numberScale = useSharedValue(0);

  useEffect(() => {
    flameScale.value = withSpring(1, { damping: 8, stiffness: 80 });
    numberScale.value = withDelay(300, withSpring(1, { damping: 8, stiffness: 80 }));
    if (newVouchers > 0) {
      Haptics.notificationAsync(Haptics.NotificationFeedbackType.Success);
    }
  }, []);

  const flameStyle = useAnimatedStyle(() => ({
    transform: [{ scale: flameScale.value }],
  }));
  const numberStyle = useAnimatedStyle(() => ({
    transform: [{ scale: numberScale.value }],
  }));

  const shopInfoStyle = useFadeInUp(500);
  const statsStyle = useFadeInUp(700);
  const voucherStyle = useFadeInUp(900);
  const buttonsStyle = useFadeInUp(1000);

  return (
    <View style={[styles.container, { paddingTop: insets.top }]}>
      <LinearGradient
        colors={['rgba(255,122,24,0.15)', 'rgba(255,61,110,0.05)', COLORS.bg]}
        style={StyleSheet.absoluteFill}
        start={{ x: 0.5, y: 0 }}
        end={{ x: 0.5, y: 0.6 }}
      />

      <View style={styles.content}>
        <Animated.Text style={[styles.flame, flameStyle]}>🔥</Animated.Text>

        <Animated.View style={[styles.streakBox, numberStyle]}>
          <Text style={styles.streakNumber}>{streakDays}</Text>
          <Text style={styles.streakLabel}>day streak</Text>
        </Animated.View>

        <Animated.View style={shopInfoStyle}>
          <Text style={styles.shopName}>{shop?.emoji} {shop?.name}</Text>
          <Text style={styles.message}>
            {streakDays === 1
              ? 'Streak started! Come back to keep it going.'
              : `You're on fire! ${streakDays} days in a row.`}
          </Text>
        </Animated.View>

        <Animated.View style={[styles.statsRow, statsStyle]}>
          <View style={styles.statCard}>
            <Text style={styles.statNumber}>{totalVisits}</Text>
            <Text style={styles.statLabel}>total visits</Text>
          </View>
          <View style={styles.statCard}>
            <Text style={styles.statNumber}>{streakDays}</Text>
            <Text style={styles.statLabel}>current streak</Text>
          </View>
        </Animated.View>

        {newVouchers > 0 && (
          <Animated.View style={[styles.voucherBanner, voucherStyle]}>
            <Text style={styles.voucherEmoji}>🎉</Text>
            <Text style={styles.voucherText}>
              You earned {newVouchers} new voucher{newVouchers > 1 ? 's' : ''}!
            </Text>
          </Animated.View>
        )}
      </View>

      <Animated.View style={[styles.buttons, buttonsStyle]}>
        <GradientButton
          title="View Shop"
          onPress={() => router.replace(`/(customer)/shop/${params.shopId}`)}
        />
        <GradientButton
          title="Back to Home"
          onPress={() => router.replace('/(customer)/home')}
          variant="outline"
        />
      </Animated.View>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: COLORS.bg,
  },
  content: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
    paddingHorizontal: SPACING.xl,
    gap: SPACING.lg,
  },
  flame: {
    fontSize: 80,
  },
  streakBox: {
    alignItems: 'center',
  },
  streakNumber: {
    fontSize: 72,
    fontFamily: FONTS.headingBold,
    color: COLORS.ember2,
  },
  streakLabel: {
    fontSize: 18,
    fontFamily: FONTS.body,
    color: COLORS.muted,
    marginTop: -8,
  },
  shopName: {
    fontSize: 20,
    fontFamily: FONTS.headingSemiBold,
    color: COLORS.ink,
    textAlign: 'center',
  },
  message: {
    fontSize: 15,
    fontFamily: FONTS.body,
    color: COLORS.muted,
    textAlign: 'center',
    marginTop: SPACING.xs,
  },
  statsRow: {
    flexDirection: 'row',
    gap: SPACING.md,
  },
  statCard: {
    backgroundColor: COLORS.card,
    borderRadius: RADIUS.lg,
    paddingHorizontal: SPACING.lg,
    paddingVertical: SPACING.md,
    alignItems: 'center',
    borderWidth: 1,
    borderColor: COLORS.line,
    minWidth: 120,
  },
  statNumber: {
    fontSize: 28,
    fontFamily: FONTS.headingBold,
    color: COLORS.ink,
  },
  statLabel: {
    fontSize: 12,
    fontFamily: FONTS.body,
    color: COLORS.muted,
  },
  voucherBanner: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: COLORS.success + '15',
    borderRadius: RADIUS.md,
    paddingHorizontal: SPACING.md,
    paddingVertical: 12,
    gap: SPACING.sm,
    borderWidth: 1,
    borderColor: COLORS.success + '30',
  },
  voucherEmoji: {
    fontSize: 24,
  },
  voucherText: {
    fontSize: 15,
    fontFamily: FONTS.headingSemiBold,
    color: COLORS.success,
  },
  buttons: {
    paddingHorizontal: SPACING.xl,
    paddingBottom: SPACING.xxl,
    gap: SPACING.sm,
  },
});
