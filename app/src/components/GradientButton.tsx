import React from 'react';
import { TouchableOpacity, Text, StyleSheet, ViewStyle, TextStyle } from 'react-native';
import { LinearGradient } from 'expo-linear-gradient';
import { COLORS, FONTS, RADIUS, SPACING } from '../constants/theme';
import Animated, { useSharedValue, useAnimatedStyle, withSpring } from 'react-native-reanimated';

const AnimatedTouchable = Animated.createAnimatedComponent(TouchableOpacity);

interface Props {
  title: string;
  onPress: () => void;
  style?: ViewStyle;
  textStyle?: TextStyle;
  size?: 'sm' | 'md' | 'lg';
  variant?: 'gradient' | 'outline';
  disabled?: boolean;
}

export default function GradientButton({ title, onPress, style, textStyle, size = 'md', variant = 'gradient', disabled }: Props) {
  const scale = useSharedValue(1);
  const animatedStyle = useAnimatedStyle(() => ({ transform: [{ scale: scale.value }] }));

  const handlePressIn = () => { scale.value = withSpring(0.97, { stiffness: 300 }); };
  const handlePressOut = () => { scale.value = withSpring(1, { stiffness: 300 }); };

  const sizeStyles = {
    sm: { paddingVertical: 10, paddingHorizontal: 20, fontSize: 14 },
    md: { paddingVertical: 14, paddingHorizontal: 28, fontSize: 16 },
    lg: { paddingVertical: 18, paddingHorizontal: 36, fontSize: 18 },
  }[size];

  if (variant === 'outline') {
    return (
      <AnimatedTouchable
        onPress={onPress}
        onPressIn={handlePressIn}
        onPressOut={handlePressOut}
        disabled={disabled}
        style={[animatedStyle, styles.outlineBtn, { paddingVertical: sizeStyles.paddingVertical, paddingHorizontal: sizeStyles.paddingHorizontal, opacity: disabled ? 0.5 : 1 }, style]}
        activeOpacity={0.8}
      >
        <Text style={[styles.outlineText, { fontSize: sizeStyles.fontSize }, textStyle]}>{title}</Text>
      </AnimatedTouchable>
    );
  }

  return (
    <AnimatedTouchable
      onPress={onPress}
      onPressIn={handlePressIn}
      onPressOut={handlePressOut}
      disabled={disabled}
      style={[animatedStyle, { opacity: disabled ? 0.5 : 1 }, style]}
      activeOpacity={0.9}
    >
      <LinearGradient
        colors={[COLORS.ember1, COLORS.ember2, COLORS.ember3]}
        start={{ x: 0, y: 0 }}
        end={{ x: 1, y: 1 }}
        style={[styles.gradient, { paddingVertical: sizeStyles.paddingVertical, paddingHorizontal: sizeStyles.paddingHorizontal }]}
      >
        <Text style={[styles.text, { fontSize: sizeStyles.fontSize }, textStyle]}>{title}</Text>
      </LinearGradient>
    </AnimatedTouchable>
  );
}

const styles = StyleSheet.create({
  gradient: {
    borderRadius: RADIUS.md,
    alignItems: 'center',
    justifyContent: 'center',
  },
  text: {
    color: '#1a0d05',
    fontFamily: FONTS.headingSemiBold,
    letterSpacing: 0.3,
  },
  outlineBtn: {
    borderRadius: RADIUS.md,
    borderWidth: 1.5,
    borderColor: COLORS.ember2,
    alignItems: 'center',
    justifyContent: 'center',
  },
  outlineText: {
    color: COLORS.ember2,
    fontFamily: FONTS.headingSemiBold,
    letterSpacing: 0.3,
  },
});
