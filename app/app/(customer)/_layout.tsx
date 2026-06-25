import { Tabs } from 'expo-router';
import { View, StyleSheet, Platform } from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import { COLORS, FONTS } from '../../src/constants/theme';
import { LinearGradient } from 'expo-linear-gradient';

function TabIcon({ name, focused, isCenter }: { name: keyof typeof Ionicons.glyphMap; focused: boolean; isCenter?: boolean }) {
  if (isCenter) {
    return (
      <View style={styles.centerBtn}>
        <LinearGradient
          colors={[COLORS.ember1, COLORS.ember2, COLORS.ember3]}
          start={{ x: 0, y: 0 }}
          end={{ x: 1, y: 1 }}
          style={styles.centerGradient}
        >
          <Ionicons name={name} size={28} color="#1a0d05" />
        </LinearGradient>
      </View>
    );
  }
  return <Ionicons name={name} size={24} color={focused ? COLORS.ember2 : COLORS.muted2} />;
}

export default function CustomerLayout() {
  return (
    <Tabs
      screenOptions={{
        headerShown: false,
        tabBarStyle: {
          backgroundColor: COLORS.bg2,
          borderTopColor: COLORS.line,
          borderTopWidth: 1,
          height: Platform.OS === 'ios' ? 88 : 64,
          paddingBottom: Platform.OS === 'ios' ? 28 : 8,
          paddingTop: 8,
        },
        tabBarActiveTintColor: COLORS.ember2,
        tabBarInactiveTintColor: COLORS.muted2,
        tabBarLabelStyle: {
          fontFamily: FONTS.bodyMedium,
          fontSize: 11,
        },
      }}
    >
      <Tabs.Screen
        name="home"
        options={{
          title: 'Home',
          tabBarIcon: ({ focused }) => <TabIcon name={focused ? 'flame' : 'flame-outline'} focused={focused} />,
        }}
      />
      <Tabs.Screen
        name="scanner"
        options={{
          title: 'Scan',
          tabBarIcon: ({ focused }) => <TabIcon name="qr-code" focused={focused} isCenter />,
          tabBarLabel: () => null,
        }}
      />
      <Tabs.Screen
        name="vouchers"
        options={{
          title: 'Vouchers',
          tabBarIcon: ({ focused }) => <TabIcon name={focused ? 'ticket' : 'ticket-outline'} focused={focused} />,
        }}
      />
      <Tabs.Screen
        name="profile"
        options={{
          title: 'Profile',
          tabBarIcon: ({ focused }) => <TabIcon name={focused ? 'person' : 'person-outline'} focused={focused} />,
        }}
      />
      <Tabs.Screen
        name="shop/[id]"
        options={{
          href: null,
        }}
      />
      <Tabs.Screen
        name="scan-success"
        options={{
          href: null,
        }}
      />
    </Tabs>
  );
}

const styles = StyleSheet.create({
  centerBtn: {
    position: 'absolute',
    top: -20,
    alignItems: 'center',
    justifyContent: 'center',
  },
  centerGradient: {
    width: 56,
    height: 56,
    borderRadius: 28,
    alignItems: 'center',
    justifyContent: 'center',
    shadowColor: COLORS.ember2,
    shadowOffset: { width: 0, height: 4 },
    shadowOpacity: 0.4,
    shadowRadius: 12,
    elevation: 8,
  },
});
