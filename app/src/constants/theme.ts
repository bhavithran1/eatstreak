export const COLORS = {
  bg: '#0a0807',
  bg2: '#0f0c0a',
  ink: '#fbf6f0',
  muted: '#a89c92',
  muted2: '#7a6f66',
  line: 'rgba(255,255,255,0.08)',
  line2: 'rgba(255,255,255,0.14)',
  card: '#1a1614',
  card2: '#231f1c',
  ember1: '#ffd166',
  ember2: '#ff7a18',
  ember3: '#ff3d6e',
  success: '#5fd897',
  error: '#ff4d4d',
  warning: '#ffb84d',
} as const;

export const GRADIENT = {
  colors: ['#ffd166', '#ff7a18', '#ff3d6e'] as const,
  start: { x: 0, y: 0 },
  end: { x: 1, y: 1 },
};

export const FONTS = {
  heading: 'SpaceGrotesk_400Regular',
  headingMedium: 'SpaceGrotesk_500Medium',
  headingSemiBold: 'SpaceGrotesk_600SemiBold',
  headingBold: 'SpaceGrotesk_700Bold',
  body: 'Inter_400Regular',
  bodyMedium: 'Inter_500Medium',
  bodySemiBold: 'Inter_600SemiBold',
  bodyBold: 'Inter_700Bold',
} as const;

export const SPACING = {
  xs: 4,
  sm: 8,
  md: 16,
  lg: 24,
  xl: 32,
  xxl: 48,
} as const;

export const RADIUS = {
  sm: 8,
  md: 13,
  lg: 20,
  xl: 24,
  pill: 100,
} as const;
