import React, { useRef, useState } from 'react';
import {
  View,
  Text,
  StyleSheet,
  Dimensions,
  FlatList,
  TextInput,
  KeyboardAvoidingView,
  Platform,
} from 'react-native';
import { useRouter } from 'expo-router';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { LinearGradient } from 'expo-linear-gradient';
import Animated, { FadeInUp, FadeInDown } from 'react-native-reanimated';
import * as Haptics from 'expo-haptics';
import { COLORS, FONTS, RADIUS, SPACING } from '../src/constants/theme';
import { setOnboarded } from '../src/store/storage';
import { useStore } from '../src/store/StoreProvider';
import GradientButton from '../src/components/GradientButton';
import RoleSwitcher from '../src/components/RoleSwitcher';
import { UserRole } from '../src/types';

const { width } = Dimensions.get('window');

const PAGES = [
  {
    emoji: '📱',
    title: 'Scan & Check In',
    subtitle: 'Scan a QR code at any partner restaurant to log your visit. It takes 2 seconds.',
  },
  {
    emoji: '🔥',
    title: 'Build Streaks',
    subtitle: 'Visit regularly to build consecutive-day streaks. The longer your streak, the bigger your rewards.',
  },
  {
    emoji: '🎁',
    title: 'Earn Rewards',
    subtitle: 'Unlock vouchers and discounts as you hit milestones. Both visit counts and streak days earn rewards.',
  },
];

export default function OnboardingScreen() {
  const router = useRouter();
  const insets = useSafeAreaInsets();
  const { state, switchRole, updateUser } = useStore();
  const flatListRef = useRef<FlatList>(null);
  const [currentPage, setCurrentPage] = useState(0);
  const [name, setName] = useState('');
  const [role, setRole] = useState<UserRole>('customer');

  const isLastPage = currentPage === PAGES.length;

  const goNext = () => {
    if (currentPage < PAGES.length) {
      flatListRef.current?.scrollToIndex({ index: currentPage + 1, animated: true });
      setCurrentPage(currentPage + 1);
      Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
    }
  };

  const handleFinish = async () => {
    Haptics.notificationAsync(Haptics.NotificationFeedbackType.Success);
    await setOnboarded();

    if (name.trim() && state.currentUser) {
      await updateUser({ ...state.currentUser, name: name.trim() });
    }
    await switchRole(role);

    if (role === 'owner') {
      router.replace('/(owner)/dashboard');
    } else {
      router.replace('/(customer)/home');
    }
  };

  const renderPage = ({ item, index }: { item: typeof PAGES[0] | null; index: number }) => {
    if (index === PAGES.length) {
      return (
        <KeyboardAvoidingView
          style={styles.page}
          behavior={Platform.OS === 'ios' ? 'padding' : undefined}
        >
          <Animated.View entering={FadeInUp.springify()} style={styles.setupContent}>
            <Text style={styles.setupEmoji}>👋</Text>
            <Text style={styles.setupTitle}>Let's get started</Text>

            <View style={styles.inputGroup}>
              <Text style={styles.inputLabel}>Your name</Text>
              <TextInput
                style={styles.nameInput}
                placeholder="What should we call you?"
                placeholderTextColor={COLORS.muted2}
                value={name}
                onChangeText={setName}
                autoCapitalize="words"
              />
            </View>

            <View style={styles.inputGroup}>
              <Text style={styles.inputLabel}>I am a...</Text>
              <RoleSwitcher currentRole={role} onSwitch={setRole} />
            </View>

            <GradientButton
              title="Let's Go!"
              onPress={handleFinish}
              size="lg"
              style={styles.finishBtn}
            />
          </Animated.View>
        </KeyboardAvoidingView>
      );
    }

    return (
      <View style={styles.page}>
        <Animated.View entering={FadeInUp.springify()} style={styles.pageContent}>
          <Text style={styles.pageEmoji}>{item!.emoji}</Text>
          <Text style={styles.pageTitle}>{item!.title}</Text>
          <Text style={styles.pageSubtitle}>{item!.subtitle}</Text>
        </Animated.View>
      </View>
    );
  };

  return (
    <View style={[styles.container, { paddingTop: insets.top, paddingBottom: insets.bottom }]}>
      <LinearGradient
        colors={['rgba(255,122,24,0.08)', 'transparent']}
        style={StyleSheet.absoluteFill}
        start={{ x: 0.5, y: 0 }}
        end={{ x: 0.5, y: 0.4 }}
      />

      <FlatList
        ref={flatListRef}
        data={[...PAGES, null]}
        renderItem={renderPage as any}
        horizontal
        pagingEnabled
        showsHorizontalScrollIndicator={false}
        scrollEventThrottle={16}
        scrollEnabled={false}
        keyExtractor={(_, i) => i.toString()}
        getItemLayout={(_, index) => ({ length: width, offset: width * index, index })}
      />

      <Animated.View entering={FadeInDown.delay(300).springify()} style={styles.footer}>
        <View style={styles.dots}>
          {[...PAGES, null].map((_, i) => (
            <View
              key={i}
              style={[
                styles.dot,
                i === currentPage && styles.activeDot,
              ]}
            />
          ))}
        </View>

        {!isLastPage && (
          <GradientButton title="Next" onPress={goNext} size="md" style={styles.nextBtn} />
        )}
      </Animated.View>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: COLORS.bg,
  },
  page: {
    width,
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    paddingHorizontal: SPACING.xl,
  },
  pageContent: {
    alignItems: 'center',
    gap: SPACING.md,
  },
  pageEmoji: {
    fontSize: 80,
    marginBottom: SPACING.md,
  },
  pageTitle: {
    fontSize: 28,
    fontFamily: FONTS.headingBold,
    color: COLORS.ink,
    textAlign: 'center',
  },
  pageSubtitle: {
    fontSize: 16,
    fontFamily: FONTS.body,
    color: COLORS.muted,
    textAlign: 'center',
    lineHeight: 24,
    paddingHorizontal: SPACING.md,
  },
  setupContent: {
    width: '100%',
    alignItems: 'center',
    gap: SPACING.lg,
  },
  setupEmoji: {
    fontSize: 64,
  },
  setupTitle: {
    fontSize: 24,
    fontFamily: FONTS.headingBold,
    color: COLORS.ink,
  },
  inputGroup: {
    width: '100%',
    gap: SPACING.sm,
  },
  inputLabel: {
    fontSize: 15,
    fontFamily: FONTS.headingSemiBold,
    color: COLORS.ink,
  },
  nameInput: {
    backgroundColor: COLORS.card,
    borderRadius: RADIUS.md,
    paddingHorizontal: SPACING.md,
    paddingVertical: 14,
    fontSize: 16,
    fontFamily: FONTS.body,
    color: COLORS.ink,
    borderWidth: 1,
    borderColor: COLORS.line,
  },
  finishBtn: {
    width: '100%',
    marginTop: SPACING.md,
  },
  footer: {
    paddingHorizontal: SPACING.xl,
    paddingBottom: SPACING.lg,
    gap: SPACING.md,
    alignItems: 'center',
  },
  dots: {
    flexDirection: 'row',
    gap: SPACING.sm,
  },
  dot: {
    width: 8,
    height: 8,
    borderRadius: 4,
    backgroundColor: COLORS.muted2,
  },
  activeDot: {
    width: 24,
    backgroundColor: COLORS.ember2,
  },
  nextBtn: {
    width: '100%',
  },
});
