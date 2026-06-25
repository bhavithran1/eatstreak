import React, { useState, useEffect, useRef } from 'react';
import { View, Text, StyleSheet, TouchableOpacity, Dimensions, Platform } from 'react-native';
import { CameraView, useCameraPermissions } from 'expo-camera';
import { useRouter } from 'expo-router';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { LinearGradient } from 'expo-linear-gradient';
import Animated, {
  useSharedValue,
  useAnimatedStyle,
  withRepeat,
  withTiming,
  Easing,
} from 'react-native-reanimated';
import * as Haptics from 'expo-haptics';
import { useStore } from '../../src/store/StoreProvider';
import { useToast } from '../../src/components/Toast';
import { decodeQR } from '../../src/utils/qr';
import { COLORS, FONTS, RADIUS, SPACING } from '../../src/constants/theme';
import GradientButton from '../../src/components/GradientButton';

const { width } = Dimensions.get('window');
const SCAN_SIZE = width * 0.7;

export default function ScannerScreen() {
  const router = useRouter();
  const insets = useSafeAreaInsets();
  const { state, scanQR } = useStore();
  const { showToast } = useToast();
  const [permission, requestPermission] = useCameraPermissions();
  const [scanned, setScanned] = useState(false);
  const [showDevPicker, setShowDevPicker] = useState(false);
  const scanLineY = useSharedValue(0);

  useEffect(() => {
    scanLineY.value = withRepeat(
      withTiming(SCAN_SIZE - 4, { duration: 2000, easing: Easing.inOut(Easing.ease) }),
      -1,
      true
    );
  }, []);

  const scanLineStyle = useAnimatedStyle(() => ({
    transform: [{ translateY: scanLineY.value }],
  }));

  const handleBarCodeScanned = async ({ data }: { data: string }) => {
    if (scanned) return;
    setScanned(true);
    Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Medium);

    const payload = decodeQR(data);
    if (!payload) {
      showToast({ message: 'Invalid QR code', type: 'error' });
      setTimeout(() => setScanned(false), 2000);
      return;
    }

    const result = await scanQR(payload.s);
    if (result.status === 'already_visited_today') {
      showToast({ message: 'Already checked in today! Come back tomorrow.', type: 'info' });
      setTimeout(() => setScanned(false), 2000);
      return;
    }
    if (result.status === 'shop_not_found') {
      showToast({ message: 'Shop not found', type: 'error' });
      setTimeout(() => setScanned(false), 2000);
      return;
    }

    Haptics.notificationAsync(Haptics.NotificationFeedbackType.Success);
    router.push({
      pathname: '/(customer)/scan-success',
      params: {
        shopId: payload.s,
        streakDays: result.streak?.currentStreakDays.toString(),
        totalVisits: result.streak?.totalVisits.toString(),
        newVoucherCount: (result.newVouchers?.length || 0).toString(),
      },
    });
    setTimeout(() => setScanned(false), 3000);
  };

  const handleDevScan = async (shopId: string) => {
    setShowDevPicker(false);
    const result = await scanQR(shopId);
    if (result.status === 'already_visited_today') {
      showToast({ message: 'Already checked in today!', type: 'info' });
      return;
    }
    if (result.status === 'success') {
      Haptics.notificationAsync(Haptics.NotificationFeedbackType.Success);
      router.push({
        pathname: '/(customer)/scan-success',
        params: {
          shopId,
          streakDays: result.streak?.currentStreakDays.toString(),
          totalVisits: result.streak?.totalVisits.toString(),
          newVoucherCount: (result.newVouchers?.length || 0).toString(),
        },
      });
    }
  };

  if (!permission?.granted) {
    return (
      <View style={[styles.permissionContainer, { paddingTop: insets.top }]}>
        <Text style={styles.permissionEmoji}>📸</Text>
        <Text style={styles.permissionTitle}>Camera Access Needed</Text>
        <Text style={styles.permissionText}>
          EatStreak needs your camera to scan QR codes at restaurants and track your eating streaks.
        </Text>
        <GradientButton title="Allow Camera" onPress={requestPermission} />

        <View style={styles.devSection}>
          <Text style={styles.devTitle}>Dev Mode: Pick a Shop</Text>
          {state.shops.map(shop => (
            <TouchableOpacity
              key={shop.id}
              style={styles.devShopBtn}
              onPress={() => handleDevScan(shop.id)}
            >
              <Text style={styles.devShopText}>{shop.emoji} {shop.name}</Text>
            </TouchableOpacity>
          ))}
        </View>
      </View>
    );
  }

  return (
    <View style={styles.container}>
      <CameraView
        style={StyleSheet.absoluteFill}
        barcodeScannerSettings={{ barcodeTypes: ['qr'] }}
        onBarcodeScanned={scanned ? undefined : handleBarCodeScanned}
      />

      <View style={styles.overlay}>
        <View style={[styles.overlayTop, { height: (Dimensions.get('window').height - SCAN_SIZE) / 2 - 40 }]} />
        <View style={styles.scanRow}>
          <View style={styles.overlaySide} />
          <View style={styles.scanFrame}>
            <View style={[styles.corner, styles.cornerTL]} />
            <View style={[styles.corner, styles.cornerTR]} />
            <View style={[styles.corner, styles.cornerBL]} />
            <View style={[styles.corner, styles.cornerBR]} />
            <Animated.View style={[styles.scanLine, scanLineStyle]}>
              <LinearGradient
                colors={['transparent', COLORS.ember2 + '80', 'transparent']}
                start={{ x: 0, y: 0 }}
                end={{ x: 1, y: 0 }}
                style={styles.scanLineGradient}
              />
            </Animated.View>
          </View>
          <View style={styles.overlaySide} />
        </View>
        <View style={styles.overlayBottom}>
          <Text style={styles.instructions}>Point at a restaurant QR code</Text>

          <TouchableOpacity
            style={styles.devBtn}
            onPress={() => setShowDevPicker(!showDevPicker)}
          >
            <Text style={styles.devBtnText}>Dev: Simulate Scan</Text>
          </TouchableOpacity>

          {showDevPicker && (
            <View style={styles.devPickerContainer}>
              {state.shops.map(shop => (
                <TouchableOpacity
                  key={shop.id}
                  style={styles.devShopBtn}
                  onPress={() => handleDevScan(shop.id)}
                >
                  <Text style={styles.devShopText}>{shop.emoji} {shop.name}</Text>
                </TouchableOpacity>
              ))}
            </View>
          )}
        </View>
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#000',
  },
  overlay: {
    position: 'absolute', top: 0, left: 0, right: 0, bottom: 0,
  },
  overlayTop: {
    backgroundColor: 'rgba(0,0,0,0.7)',
  },
  scanRow: {
    flexDirection: 'row',
    height: SCAN_SIZE,
  },
  overlaySide: {
    flex: 1,
    backgroundColor: 'rgba(0,0,0,0.7)',
  },
  scanFrame: {
    width: SCAN_SIZE,
    height: SCAN_SIZE,
    overflow: 'hidden',
  },
  corner: {
    position: 'absolute',
    width: 30,
    height: 30,
    borderColor: COLORS.ember2,
  },
  cornerTL: {
    top: 0,
    left: 0,
    borderTopWidth: 3,
    borderLeftWidth: 3,
    borderTopLeftRadius: 8,
  },
  cornerTR: {
    top: 0,
    right: 0,
    borderTopWidth: 3,
    borderRightWidth: 3,
    borderTopRightRadius: 8,
  },
  cornerBL: {
    bottom: 0,
    left: 0,
    borderBottomWidth: 3,
    borderLeftWidth: 3,
    borderBottomLeftRadius: 8,
  },
  cornerBR: {
    bottom: 0,
    right: 0,
    borderBottomWidth: 3,
    borderRightWidth: 3,
    borderBottomRightRadius: 8,
  },
  scanLine: {
    position: 'absolute',
    left: 0,
    right: 0,
    height: 2,
  },
  scanLineGradient: {
    flex: 1,
  },
  overlayBottom: {
    flex: 1,
    backgroundColor: 'rgba(0,0,0,0.7)',
    alignItems: 'center',
    paddingTop: SPACING.xl,
    gap: SPACING.md,
  },
  instructions: {
    fontSize: 16,
    fontFamily: FONTS.bodyMedium,
    color: COLORS.ink,
  },
  permissionContainer: {
    flex: 1,
    backgroundColor: COLORS.bg,
    alignItems: 'center',
    justifyContent: 'center',
    paddingHorizontal: SPACING.xl,
    gap: SPACING.md,
  },
  permissionEmoji: {
    fontSize: 64,
  },
  permissionTitle: {
    fontSize: 22,
    fontFamily: FONTS.headingBold,
    color: COLORS.ink,
    textAlign: 'center',
  },
  permissionText: {
    fontSize: 15,
    fontFamily: FONTS.body,
    color: COLORS.muted,
    textAlign: 'center',
    lineHeight: 22,
    marginBottom: SPACING.md,
  },
  devSection: {
    marginTop: SPACING.xxl,
    width: '100%',
    gap: SPACING.sm,
  },
  devTitle: {
    fontSize: 14,
    fontFamily: FONTS.headingSemiBold,
    color: COLORS.muted2,
    textAlign: 'center',
    marginBottom: SPACING.sm,
  },
  devBtn: {
    paddingHorizontal: 16,
    paddingVertical: 8,
    borderRadius: RADIUS.sm,
    borderWidth: 1,
    borderColor: COLORS.muted2,
  },
  devBtnText: {
    fontSize: 13,
    fontFamily: FONTS.bodyMedium,
    color: COLORS.muted,
  },
  devPickerContainer: {
    width: '80%',
    gap: SPACING.sm,
  },
  devShopBtn: {
    backgroundColor: COLORS.card2,
    paddingHorizontal: SPACING.md,
    paddingVertical: 12,
    borderRadius: RADIUS.md,
    borderWidth: 1,
    borderColor: COLORS.line,
  },
  devShopText: {
    fontSize: 15,
    fontFamily: FONTS.headingMedium,
    color: COLORS.ink,
    textAlign: 'center',
  },
});
