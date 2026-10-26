import { useSyncExternalStore } from 'react';
import { StyleSheet, Text, View } from 'react-native';
import { eventLog } from './eventLog';
import { foreground, type ForegroundMode } from './foreground';
import { Button, Choice, colors, Note, Section } from './ui';

const MODES: readonly ForegroundMode[] = ['off', 'show', 'hold'];

const MODE_NOTES: Record<ForegroundMode, string> = {
  off: 'No listener: SallaPush shows foreground notifications itself, as sent.',
  show:
    "A listener that doesn't prevent: each one is shown once it returns. On iOS that is SallaPush's local copy, " +
    'without the image, action buttons or interruption level.',
  hold: 'A listener that prevents: each one waits below, and Display shows it within 10 minutes.',
};

export function Foreground() {
  const mode = useSyncExternalStore(foreground.subscribe, foreground.mode);
  const held = useSyncExternalStore(foreground.subscribe, foreground.held);
  return (
    <Section title="Foreground notifications">
      <Choice options={MODES} value={mode} onChange={foreground.setMode} />
      <Note>{MODE_NOTES[mode]}</Note>
      {held.map((notification, index) => (
        <View key={index} style={styles.held}>
          <Text style={styles.text}>
            {notification.title ??
              notification.notificationId ??
              'notification'}
          </Text>
          <Button
            title="Display"
            onPress={() => foreground.display(notification)}
          />
        </View>
      ))}
    </Section>
  );
}

export function EventLog() {
  const lines = useSyncExternalStore(eventLog.subscribe, eventLog.lines);
  return (
    <Section title="Event log">
      <Button title="Clear" onPress={eventLog.clear} />
      {lines.map((line) => (
        <Text key={line.id} style={styles.line}>
          <Text style={styles.time}>{line.time} </Text>
          <Text style={styles.kind}>{line.kind}</Text> {line.text}
        </Text>
      ))}
    </Section>
  );
}

const styles = StyleSheet.create({
  held: {
    alignItems: 'center',
    flexDirection: 'row',
    justifyContent: 'space-between',
  },
  text: {
    color: colors.text,
  },
  line: {
    color: colors.text,
    fontSize: 12,
  },
  time: {
    color: colors.secondary,
  },
  kind: {
    fontWeight: '600',
  },
});
