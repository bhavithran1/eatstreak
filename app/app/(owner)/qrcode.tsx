import React from 'react';
import { View, Text, StyleSheet, ScrollView } from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { LinearGradient } from 'expo-linear-gradient';
import Animated, { FadeInDown } from 'react-native-reanimated';
import QRCode from 'react-native-qrcode-svg';
import { useStore } from '../../src/store/StoreProvider';
import { encodeQR } from '../../src/utils/qr';
import { COLORS, FONTS, RADIUS, SPACING } from '../../src/constants/theme';
import { Ionicons } from '@expo/vector-icons';

export default function QRCodeScreen() {
  const insets = useSafeAreaInsets();
  const { state } = useStore();
  const ownerShop = state.shops.find(s => s.ownerId === state.currentUser?.id);

  if (!ownerShop) return null;

  const qrData = encodeQR(ownerShop.id);

  return (
    <ScrollView
      style={styles.container}
      contentContainerStyle={[styles.content, { paddingTop: insets.top + SPACING.md }]}
      showsVerticalScrollIndicator={false}
    >
      <Text style={styles.title}>Your QR Code</Text>
      <Text style={styles.subtitle}>Customers scan this to check in</Text>

      <Animated.View entering={FadeInDown.springify()} style={styles.qrContainer}>
        <LinearGradient
          colors={[COLORS.ember1 + '30', COLORS.ember2 + '20', COLORS.ember3 + '10']}
          style={styles.qrBorder}
          start={{ x: 0, y: 0 }}
          end={{ x: 1, y: 1 }}
        >
          <View style={styles.qrInner}>
            <QRCode
              value={qrData}
              size={220}
              backgroundColor="white"
              color="#1a0d05"
            />
          </View>
        </LinearGradient>

        <Text style={styles.shopName}>{ownerShop.emoji} {ownerShop.name}</Text>
        <Text style={styles.scanText}>Scan to earn rewards</Text>
      </Animated.View>

      <Animated.View entering={FadeInDown.delay(200).springify()} style={styles.tipsCard}>
        <Text style={styles.tipsTitle}>Tips for placement</Text>
        {[
          { icon: 'restaurant-outline' as const, text: 'Place at every table and counter' },
          { icon: 'print-outline' as const, text: 'Print on table tents or stickers' },
          { icon: 'eye-outline' as const, text: 'Keep it visible and well-lit' },
          { icon: 'chatbubble-outline' as const, text: 'Train staff to encourage scanning' },
        ].map((tip) => (
          <View key={tip.text} style={styles.tipRow}>
            <Ionicons name={tip.icon} size={18} color={COLORS.ember2} />
            <Text style={styles.tipText}>{tip.text}</Text>
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
  title: {
    fontSize: 28,
    fontFamily: FONTS.headingBold,
    color: COLORS.ink,
  },
  subtitle: {
    fontSize: 15,
    fontFamily: FONTS.body,
    color: COLORS.muted,
    marginBottom: SPACING.lg,
  },
  qrContainer: {
    alignItems: 'center',
    gap: SPACING.md,
    marginBottom: SPACING.xl,
  },
  qrBorder: {
    borderRadius: RADIUS.xl,
    padding: 4,
  },
  qrInner: {
    backgroundColor: 'white',
    borderRadius: RADIUS.lg,
    padding: SPACING.lg,
    alignItems: 'center',
    justifyContent: 'center',
  },
  shopName: {
    fontSize: 20,
    fontFamily: FONTS.headingSemiBold,
    color: COLORS.ink,
  },
  scanText: {
    fontSize: 14,
    fontFamily: FONTS.body,
    color: COLORS.muted,
  },
  tipsCard: {
    backgroundColor: COLORS.card,
    borderRadius: RADIUS.lg,
    padding: SPACING.md,
    gap: SPACING.md,
    borderWidth: 1,
    borderColor: COLORS.line,
  },
  tipsTitle: {
    fontSize: 15,
    fontFamily: FONTS.headingSemiBold,
    color: COLORS.ink,
  },
  tipRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: SPACING.sm,
  },
  tipText: {
    fontSize: 14,
    fontFamily: FONTS.body,
    color: COLORS.muted,
    flex: 1,
  },
});
