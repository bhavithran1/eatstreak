import { useEffect } from 'react';
import { View, StyleSheet, ActivityIndicator } from 'react-native';
import { useRouter } from 'expo-router';
import { useStore } from '../src/store/StoreProvider';
import { isOnboarded } from '../src/store/storage';
import { COLORS } from '../src/constants/theme';

export default function Index() {
  const router = useRouter();
  const { state } = useStore();

  useEffect(() => {
    if (!state.isInitialized) return;

    (async () => {
      const onboarded = await isOnboarded();
      if (!onboarded) {
        router.replace('/onboarding');
        return;
      }
      if (state.currentRole === 'owner') {
        router.replace('/(owner)/dashboard');
      } else {
        router.replace('/(customer)/home');
      }
    })();
  }, [state.isInitialized]);

  return (
    <View style={styles.container}>
      <ActivityIndicator size="large" color={COLORS.ember2} />
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    backgroundColor: COLORS.bg,
  },
});
