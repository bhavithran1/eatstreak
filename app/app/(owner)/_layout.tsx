import { Tabs } from 'expo-router';
import { Platform } from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import { COLORS, FONTS } from '../../src/constants/theme';

function TabIcon({ name, focused }: { name: keyof typeof Ionicons.glyphMap; focused: boolean }) {
  return <Ionicons name={name} size={24} color={focused ? COLORS.ember2 : COLORS.muted2} />;
}

export default function OwnerLayout() {
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
        name="dashboard"
        options={{
          title: 'Dashboard',
          tabBarIcon: ({ focused }) => <TabIcon name={focused ? 'bar-chart' : 'bar-chart-outline'} focused={focused} />,
        }}
      />
      <Tabs.Screen
        name="qrcode"
        options={{
          title: 'QR Code',
          tabBarIcon: ({ focused }) => <TabIcon name={focused ? 'qr-code' : 'qr-code-outline'} focused={focused} />,
        }}
      />
      <Tabs.Screen
        name="rewards"
        options={{
          title: 'Rewards',
          tabBarIcon: ({ focused }) => <TabIcon name={focused ? 'gift' : 'gift-outline'} focused={focused} />,
        }}
      />
      <Tabs.Screen
        name="customers"
        options={{
          title: 'Customers',
          tabBarIcon: ({ focused }) => <TabIcon name={focused ? 'people' : 'people-outline'} focused={focused} />,
        }}
      />
      <Tabs.Screen
        name="profile"
        options={{
          title: 'Profile',
          tabBarIcon: ({ focused }) => <TabIcon name={focused ? 'person' : 'person-outline'} focused={focused} />,
        }}
      />
    </Tabs>
  );
}
