import React from 'react';
import { View, Text, StyleSheet, TouchableOpacity } from 'react-native';
import { LinearGradient } from 'expo-linear-gradient';
import Animated, { FadeInDown } from 'react-native-reanimated';
import { COLORS, FONTS, RADIUS, SPACING } from '../constants/theme';
import { Voucher } from '../types';
import { daysFromNow, formatDate } from '../utils/dates';

interface Props {
  voucher: Voucher;
  onRedeem?: () => void;
  onPress?: () => void;
  index?: number;
}

export default function VoucherCard({ voucher, onRedeem, onPress, index = 0 }: Props) {
  const daysLeft = daysFromNow(voucher.expiresAt);
  const isExpired = daysLeft <= 0 && !voucher.isRedeemed;

  return (
    <Animated.View entering={FadeInDown.delay(index * 80).springify()}>
      <TouchableOpacity
        onPress={onPress}
        activeOpacity={0.85}
        style={[styles.card, voucher.isRedeemed && styles.redeemed, isExpired && styles.expired]}
      >
        <View style={styles.left}>
          <View style={styles.discountRow}>
            <Text style={styles.discountNumber}>{voucher.discountPercent}</Text>
            <Text style={styles.discountPercent}>%</Text>
            <Text style={styles.discountOff}>OFF</Text>
          </View>
          <View style={styles.dashes} />
        </View>

        <View style={styles.right}>
          <View style={styles.topRow}>
            <Text style={styles.shopInfo}>{voucher.shopEmoji} {voucher.shopName}</Text>
            {voucher.isRedeemed && (
              <View style={styles.usedBadge}>
                <Text style={styles.usedText}>Used</Text>
              </View>
            )}
            {isExpired && (
              <View style={[styles.usedBadge, { backgroundColor: COLORS.error + '20' }]}>
                <Text style={[styles.usedText, { color: COLORS.error }]}>Expired</Text>
              </View>
            )}
          </View>

          <Text style={styles.tierLabel}>{voucher.tierLabel}</Text>
          <Text style={styles.code}>{voucher.code}</Text>

          <View style={styles.bottomRow}>
            <Text style={styles.dateText}>
              {voucher.isRedeemed
                ? `Used ${formatDate(voucher.redeemedAt!)}`
                : isExpired
                ? 'Expired'
                : `Expires in ${daysLeft} days`}
            </Text>
            {!voucher.isRedeemed && !isExpired && onRedeem && (
              <TouchableOpacity onPress={onRedeem} style={styles.redeemBtn}>
                <LinearGradient
                  colors={[COLORS.ember1, COLORS.ember2]}
                  start={{ x: 0, y: 0 }}
                  end={{ x: 1, y: 0 }}
                  style={styles.redeemGradient}
                >
                  <Text style={styles.redeemText}>Use</Text>
                </LinearGradient>
              </TouchableOpacity>
            )}
          </View>
        </View>
      </TouchableOpacity>
    </Animated.View>
  );
}

const styles = StyleSheet.create({
  card: {
    flexDirection: 'row',
    backgroundColor: COLORS.card,
    borderRadius: RADIUS.lg,
    borderWidth: 1,
    borderColor: COLORS.ember2 + '30',
    overflow: 'hidden',
  },
  redeemed: {
    opacity: 0.6,
    borderColor: COLORS.line,
  },
  expired: {
    opacity: 0.5,
    borderColor: COLORS.error + '30',
  },
  left: {
    width: 90,
    alignItems: 'center',
    justifyContent: 'center',
    paddingVertical: SPACING.md,
    borderRightWidth: 1,
    borderRightColor: COLORS.line,
    borderStyle: 'dashed',
  },
  discountRow: {
    flexDirection: 'row',
    alignItems: 'flex-start',
  },
  discountNumber: {
    fontSize: 36,
    fontFamily: FONTS.headingBold,
    color: COLORS.ember2,
  },
  discountPercent: {
    fontSize: 18,
    fontFamily: FONTS.headingBold,
    color: COLORS.ember2,
    marginTop: 4,
  },
  discountOff: {
    fontSize: 11,
    fontFamily: FONTS.bodySemiBold,
    color: COLORS.muted,
    position: 'absolute',
    bottom: -2,
    right: -4,
  },
  dashes: {
    width: 30,
    height: 1,
    borderBottomWidth: 1,
    borderBottomColor: COLORS.line2,
    borderStyle: 'dashed',
    marginTop: 4,
  },
  right: {
    flex: 1,
    padding: SPACING.md,
    gap: 4,
  },
  topRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
  },
  shopInfo: {
    fontSize: 14,
    fontFamily: FONTS.headingMedium,
    color: COLORS.ink,
    flex: 1,
  },
  usedBadge: {
    backgroundColor: COLORS.muted2 + '30',
    paddingHorizontal: 8,
    paddingVertical: 2,
    borderRadius: RADIUS.pill,
  },
  usedText: {
    fontSize: 11,
    fontFamily: FONTS.bodySemiBold,
    color: COLORS.muted,
  },
  tierLabel: {
    fontSize: 12,
    fontFamily: FONTS.body,
    color: COLORS.muted,
  },
  code: {
    fontSize: 16,
    fontFamily: FONTS.headingSemiBold,
    color: COLORS.ember1,
    letterSpacing: 2,
  },
  bottomRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginTop: 4,
  },
  dateText: {
    fontSize: 12,
    fontFamily: FONTS.body,
    color: COLORS.muted2,
  },
  redeemBtn: {
    borderRadius: RADIUS.sm,
    overflow: 'hidden',
  },
  redeemGradient: {
    paddingHorizontal: 16,
    paddingVertical: 6,
    borderRadius: RADIUS.sm,
  },
  redeemText: {
    fontSize: 13,
    fontFamily: FONTS.headingSemiBold,
    color: '#1a0d05',
  },
});
