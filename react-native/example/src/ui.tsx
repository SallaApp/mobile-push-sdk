import type { ReactNode } from 'react';
import {
  Pressable,
  StyleSheet,
  Switch,
  Text,
  TextInput,
  View,
} from 'react-native';

export function Section({
  title,
  children,
}: {
  title: string;
  children: ReactNode;
}) {
  return (
    <View style={styles.section}>
      <Text accessibilityRole="header" style={styles.sectionTitle}>
        {title}
      </Text>
      {children}
    </View>
  );
}

export function Row({ children }: { children: ReactNode }) {
  return <View style={styles.row}>{children}</View>;
}

export function Button({
  title,
  onPress,
}: {
  title: string;
  onPress: () => void;
}) {
  return (
    <Pressable
      accessibilityRole="button"
      onPress={onPress}
      style={({ pressed }) => [styles.button, pressed && styles.pressed]}
    >
      <Text style={styles.buttonText}>{title}</Text>
    </Pressable>
  );
}

export function Field({
  label,
  value,
  onChangeText,
  secure = false,
  numeric = false,
}: {
  label: string;
  value: string;
  onChangeText: (text: string) => void;
  secure?: boolean;
  numeric?: boolean;
}) {
  return (
    <TextInput
      accessibilityLabel={label}
      autoCapitalize="none"
      autoCorrect={false}
      keyboardType={numeric ? 'number-pad' : 'default'}
      onChangeText={onChangeText}
      placeholder={label}
      placeholderTextColor={colors.secondary}
      secureTextEntry={secure}
      style={styles.field}
      value={value}
    />
  );
}

export function Toggle({
  label,
  value,
  onValueChange,
}: {
  label: string;
  value: boolean;
  onValueChange: (value: boolean) => void;
}) {
  return (
    <View style={styles.toggle}>
      <Text style={styles.text}>{label}</Text>
      <Switch
        accessibilityLabel={label}
        onValueChange={onValueChange}
        value={value}
      />
    </View>
  );
}

export function Choice<Option extends string>({
  options,
  value,
  onChange,
}: {
  options: readonly Option[];
  value: Option;
  onChange: (option: Option) => void;
}) {
  return (
    <View style={styles.row}>
      {options.map((option) => {
        const chosen = option === value;
        return (
          <Pressable
            accessibilityRole="button"
            accessibilityState={{ selected: chosen }}
            key={option}
            onPress={() => onChange(option)}
            style={[styles.choice, chosen && styles.chosen]}
          >
            <Text style={chosen ? styles.chosenText : styles.text}>
              {option}
            </Text>
          </Pressable>
        );
      })}
    </View>
  );
}

export function Line({ label, value }: { label: string; value: string }) {
  return (
    <Text style={styles.text}>
      <Text style={styles.label}>{label}: </Text>
      {value}
    </Text>
  );
}

export function Note({ children }: { children: ReactNode }) {
  return <Text style={styles.note}>{children}</Text>;
}

export const colors = {
  text: '#1c1c1e',
  secondary: '#6e6e73',
  accent: '#0a6c5d',
  border: '#d1d1d6',
  surface: '#f2f2f7',
  warning: '#fff4ce',
  white: '#ffffff',
};

const styles = StyleSheet.create({
  section: {
    gap: 8,
    paddingVertical: 12,
    borderBottomWidth: StyleSheet.hairlineWidth,
    borderBottomColor: colors.border,
  },
  sectionTitle: {
    color: colors.text,
    fontSize: 17,
    fontWeight: '600',
  },
  row: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: 8,
  },
  button: {
    backgroundColor: colors.accent,
    borderRadius: 8,
    paddingHorizontal: 14,
    paddingVertical: 8,
  },
  pressed: {
    opacity: 0.6,
  },
  buttonText: {
    color: colors.white,
    fontWeight: '600',
  },
  field: {
    borderColor: colors.border,
    borderRadius: 8,
    borderWidth: 1,
    color: colors.text,
    paddingHorizontal: 10,
    paddingVertical: 8,
  },
  toggle: {
    alignItems: 'center',
    flexDirection: 'row',
    justifyContent: 'space-between',
  },
  choice: {
    backgroundColor: colors.surface,
    borderRadius: 8,
    paddingHorizontal: 12,
    paddingVertical: 6,
  },
  chosen: {
    backgroundColor: colors.accent,
  },
  chosenText: {
    color: colors.white,
    fontWeight: '600',
  },
  text: {
    color: colors.text,
  },
  label: {
    color: colors.secondary,
  },
  note: {
    color: colors.secondary,
    fontSize: 13,
  },
});
