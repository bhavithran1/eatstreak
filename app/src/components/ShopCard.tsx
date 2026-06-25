import React from 'react';
import { View, Text, StyleSheet, TouchableOpacity } from 'react-native';
import Animated, { useSharedValue, useAnimatedStyle, withSpring, FadeInDown } from 'react-native-reanimated';
import { COLORS, FONTS, RADIUS, SPACING } from '../constants/theme';
import { Shop } from '../types';

const AnimatedTouchable = Animated.createAnimatedComponent(TouchableOpacity);

interface Props {
  shop: Shop;
  onPress: () => void;
  index?: number;
  subtitle?: string;
}

export default function ShopCard({ shop, onPress, index = 0, subtitle }: Props) {
  const scale = useSharedValue(1);
  const animatedStyle = useAnimatedStyle(() => ({
    transform: [{ scale: scale.value }],
  }));

  return (
    <Animated.View entering={FadeInDown.delay(index * 80).springify()}>
      <AnimatedTouchable
        onPress={onPress}
        onPressIn={() => { scale.value = withSpring(0.97); }}
        onPressOut={() => { scale.value = withSpring(1); }}
        activeOpacity={0.9}
        style={animatedStyle}
      >
        <View style={styles.card}>
          <Text style={styles.emoji}>{shop.emoji}</Text>
          <View style={styles.info}>
            <Text style={styles.name} numberOfLines={1}>{shop.name}</Text>
            <Text style={styles.category}>{shop.category}</Text>
            {subtitle && <Text style={styles.subtitle}>{subtitle}</Text>}
          </View>
          <Text style={styles.arrow}>›</Text>
        </View>
      </AnimatedTouchable>
    </Animated.View>
  );
}

const styles = StyleSheet.create({
  card: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: COLORS.card,
    borderRadius: RADIUS.lg,
    padding: SPACING.md,
    borderWidth: 1,
    borderColor: COLORS.line,
    gap: SPACING.md,
  },
  emoji: {
    fontSize: 36,
  },
  info: {
    flex: 1,
    gap: 2,
  },
  name: {
    fontSize: 16,
    fontFamily: FONTS.headingMedium,
    color: COLORS.ink,
  },
  category: {
    fontSize: 13,
    fontFamily: FONTS.body,
    color: COLORS.muted,
    textTransform: 'capitalize',
  },
  subtitle: {
    fontSize: 12,
    fontFamily: FONTS.bodySemiBold,
    color: COLORS.ember2,
    marginTop: 2,
  },
  arrow: {
    fontSize: 24,
    color: COLORS.muted2,
    fontFamily: FONTS.heading,
  },
});
