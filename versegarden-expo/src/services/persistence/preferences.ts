import AsyncStorage from "@react-native-async-storage/async-storage";

const keyPrefix = "versegarden:preferences";
const preferenceKey = (uid: string, key: string) => `${keyPrefix}:${uid}:${key}`;

export const preferences = {
  get: async <T>(uid: string, key: string): Promise<T | null> => {
    const value = await AsyncStorage.getItem(preferenceKey(uid, key));
    return value ? (JSON.parse(value) as T) : null;
  },
  set: async <T>(uid: string, key: string, value: T): Promise<void> => {
    await AsyncStorage.setItem(preferenceKey(uid, key), JSON.stringify(value));
  },
  remove: async (uid: string, key: string): Promise<void> => {
    await AsyncStorage.removeItem(preferenceKey(uid, key));
  },
};
