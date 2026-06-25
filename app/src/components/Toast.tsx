import React, { createContext, useContext, useState, useCallback, useRef } from 'react';
import { View, Text, StyleSheet, Animated, TouchableOpacity, Platform } from 'react-native';
import { COLORS, FONTS, RADIUS, SPACING } from '../constants/theme';
import { Ionicons } from '@expo/vector-icons';

type ToastType = 'success' | 'warning' | 'error' | 'info';

interface ToastConfig {
  message: string;
  type: ToastType;
  duration?: number;
}

interface ToastContextType {
  showToast: (config: ToastConfig) => void;
}

const ToastContext = createContext<ToastContextType>({ showToast: () => {} });

const TOAST_COLORS: Record<ToastType, string> = {
  success: COLORS.success,
  warning: COLORS.warning,
  error: COLORS.error,
  info: COLORS.ember2,
};

const TOAST_ICONS: Record<ToastType, keyof typeof Ionicons.glyphMap> = {
  success: 'checkmark-circle',
  warning: 'warning',
  error: 'close-circle',
  info: 'information-circle',
};

const TOP_OFFSET = Platform.OS === 'ios' ? 60 : 40;

export function ToastProvider({ children }: { children: React.ReactNode }) {
  const [toast, setToast] = useState<ToastConfig | null>(null);
  const translateY = useRef(new Animated.Value(-100)).current;
  const opacity = useRef(new Animated.Value(0)).current;
  const timeoutRef = useRef<ReturnType<typeof setTimeout>>(undefined);

  const hideToast = useCallback(() => {
    Animated.parallel([
      Animated.timing(translateY, { toValue: -100, duration: 300, useNativeDriver: true }),
      Animated.timing(opacity, { toValue: 0, duration: 300, useNativeDriver: true }),
    ]).start(() => setToast(null));
  }, [translateY, opacity]);

  const showToast = useCallback((config: ToastConfig) => {
    if (timeoutRef.current) clearTimeout(timeoutRef.current);
    setToast(config);
    translateY.setValue(-100);
    opacity.setValue(0);
    Animated.parallel([
      Animated.spring(translateY, { toValue: 0, tension: 80, friction: 10, useNativeDriver: true }),
      Animated.timing(opacity, { toValue: 1, duration: 200, useNativeDriver: true }),
    ]).start();
    timeoutRef.current = setTimeout(hideToast, config.duration || 3000);
  }, [hideToast, translateY, opacity]);

  return (
    <ToastContext.Provider value={{ showToast }}>
      {children}
      {toast && (
        <Animated.View
          style={[
            styles.container,
            { top: TOP_OFFSET, transform: [{ translateY }], opacity },
          ]}
        >
          <TouchableOpacity
            style={[styles.toast, { borderLeftColor: TOAST_COLORS[toast.type] }]}
            onPress={hideToast}
            activeOpacity={0.8}
          >
            <Ionicons name={TOAST_ICONS[toast.type]} size={20} color={TOAST_COLORS[toast.type]} />
            <Text style={styles.message}>{toast.message}</Text>
          </TouchableOpacity>
        </Animated.View>
      )}
    </ToastContext.Provider>
  );
}

export function useToast() {
  return useContext(ToastContext);
}

const styles = StyleSheet.create({
  container: {
    position: 'absolute',
    left: SPACING.md,
    right: SPACING.md,
    zIndex: 9999,
    alignItems: 'center',
  },
  toast: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: COLORS.card2,
    borderRadius: RADIUS.md,
    paddingHorizontal: SPACING.md,
    paddingVertical: 14,
    borderLeftWidth: 4,
    gap: SPACING.sm,
    width: '100%',
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 4 },
    shadowOpacity: 0.3,
    shadowRadius: 8,
    elevation: 8,
  },
  message: {
    color: COLORS.ink,
    fontFamily: FONTS.bodyMedium,
    fontSize: 14,
    flex: 1,
  },
});
