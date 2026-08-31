import { Platform } from "react-native";

export const colors = {
  primaryGreen: "#6F8F72",
  deepGreen: "#2F4F3A",
  forestGreen: "#4F7554",
  sageGreen: "#8FAA8A",
  softBrown: "#8A6A4F",
  background: "#FAF7EF",
  cardBackground: "#FFFDF8",
  cardTint: "#F2F6EC",
  primaryText: "#1F241F",
  secondaryText: "#697266",
  subtleText: "#929A8F",
  border: "#DDE7D7",
  destructive: "#DC2626",
  destructiveSurface: "#FEE2E2",
} as const;

export const spacing = { xxs: 6, xs: 10, sm: 14, md: 18, lg: 24, screen: 20 } as const;
export const radius = { small: 12, medium: 20, large: 24, pill: 28 } as const;

export const shadows = {
  card: {
    shadowColor: colors.deepGreen,
    shadowOpacity: 0.06,
    shadowRadius: 12,
    shadowOffset: { width: 0, height: 6 },
    elevation: 2,
  },
  elevated: {
    shadowColor: colors.deepGreen,
    shadowOpacity: 0.09,
    shadowRadius: 18,
    shadowOffset: { width: 0, height: 8 },
    elevation: 3,
  },
} as const;

export const typography = {
  display: { fontSize: 32, lineHeight: 40, fontWeight: "700" as const },
  title: { fontSize: 24, lineHeight: 32, fontWeight: "700" as const },
  heading: { fontSize: 20, lineHeight: 28, fontWeight: "700" as const },
  body: { fontSize: 16, lineHeight: 24, fontWeight: "400" as const },
  bodyEmphasis: { fontSize: 16, lineHeight: 24, fontWeight: "600" as const },
  caption: { fontSize: 14, lineHeight: 20, fontWeight: "400" as const },
  label: { fontSize: 14, lineHeight: 20, fontWeight: "600" as const },
} as const;

export const fontFamily = Platform.select({ ios: "System", android: "sans-serif", default: "System" });
