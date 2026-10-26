import { useState, useSyncExternalStore } from 'react';
import { Platform } from 'react-native';
import {
  SallaPush,
  SallaPushLogLevel,
} from '@salla.sa/mobile-push-react-native';
import { eventLog, followLogs } from './eventLog';
import { customerDidSignIn, customerDidSignOut } from './session';
import { Button, Choice, Field, Note, Row, Section, Toggle } from './ui';

const LEVELS = Object.values(SallaPushLogLevel);

/** Every SallaPush call the example can make; each one is written to the event log. */
export function Actions() {
  return (
    <>
      <Customer />
      <Tags />
      <Subscription />
      <Permission />
      <Delivered />
      <Consent />
      <Logs />
      {Platform.OS === 'android' ? <Migration /> : null}
    </>
  );
}

function Customer() {
  const [externalId, setExternalId] = useState('');
  const [identityToken, setIdentityToken] = useState('');
  return (
    <Section title="Customer">
      <Field
        label="External id"
        value={externalId}
        onChangeText={setExternalId}
      />
      <Field
        label="Identity token"
        value={identityToken}
        onChangeText={setIdentityToken}
        secure
      />
      <Row>
        <Button
          title="Log in"
          onPress={() =>
            call(`login('${externalId}', …)`, () =>
              customerDidSignIn(externalId, identityToken)
            )
          }
        />
        <Button
          title="Log out"
          onPress={() => call('logout()', () => customerDidSignOut())}
        />
      </Row>
    </Section>
  );
}

function Tags() {
  const [key, setKey] = useState('');
  const [value, setValue] = useState('');
  const [language, setLanguage] = useState('');
  return (
    <Section title="Tags and language">
      <Field label="Tag key" value={key} onChangeText={setKey} />
      <Field label="Tag value" value={value} onChangeText={setValue} />
      <Row>
        <Button
          title="Add tag"
          onPress={() =>
            call(`User.addTag('${key}', '${value}')`, () =>
              SallaPush.User.addTag(key, value)
            )
          }
        />
        <Button
          title="Remove tag"
          onPress={() =>
            call(`User.removeTag('${key}')`, () =>
              SallaPush.User.removeTag(key)
            )
          }
        />
      </Row>
      <Field
        label="Language, such as ar (empty: the device's)"
        value={language}
        onChangeText={setLanguage}
      />
      <Button
        title="Set language"
        onPress={() => {
          const code = language.trim() === '' ? null : language;
          call(
            `User.setLanguage(${code === null ? 'null' : `'${code}'`})`,
            () => SallaPush.User.setLanguage(code)
          );
        }}
      />
    </Section>
  );
}

function Subscription() {
  const subscription = SallaPush.User.pushSubscription;
  return (
    <Section title="Push subscription">
      <Row>
        <Button
          title="Opt in"
          onPress={() =>
            call('pushSubscription.optIn()', () => subscription.optIn())
          }
        />
        <Button
          title="Opt out"
          onPress={() =>
            call('pushSubscription.optOut()', () => subscription.optOut())
          }
        />
      </Row>
    </Section>
  );
}

function Permission() {
  const [fallbackToSettings, setFallbackToSettings] = useState(false);
  const notifications = SallaPush.Notifications;
  return (
    <Section title="Permission">
      <Toggle
        label="Open the settings after a denial"
        value={fallbackToSettings}
        onValueChange={setFallbackToSettings}
      />
      <Row>
        <Button
          title="Request"
          onPress={async () =>
            result(
              `requestPermission(${fallbackToSettings})`,
              await notifications.requestPermission(fallbackToSettings)
            )
          }
        />
        <Button
          title="Refresh"
          onPress={() =>
            call('Notifications.refreshPermission()', () =>
              notifications.refreshPermission()
            )
          }
        />
        {Platform.OS === 'ios' ? (
          <>
            <Button
              title="Provisional"
              onPress={async () =>
                result(
                  'registerForProvisionalAuthorization()',
                  await notifications.registerForProvisionalAuthorization()
                )
              }
            />
            <Button
              title="Register"
              onPress={() =>
                call('Notifications.registerForRemoteNotifications()', () =>
                  notifications.registerForRemoteNotifications()
                )
              }
            />
          </>
        ) : null}
      </Row>
    </Section>
  );
}

function Delivered() {
  const [androidId, setAndroidId] = useState('');
  const notifications = SallaPush.Notifications;
  return (
    <Section title="Delivered notifications">
      <Button
        title="Clear all"
        onPress={() =>
          call('Notifications.clearAll()', () => notifications.clearAll())
        }
      />
      {Platform.OS === 'android' ? (
        <>
          <Field
            label="Android notification id"
            value={androidId}
            onChangeText={setAndroidId}
            numeric
          />
          <Button
            title="Remove notification"
            onPress={() => {
              const id = Number(androidId);
              if (androidId.trim() === '' || !Number.isInteger(id)) {
                eventLog.add('result', 'removeNotification: enter a number');
                return;
              }
              call(`Notifications.removeNotification(${id})`, () =>
                notifications.removeNotification(id)
              );
            }}
          />
        </>
      ) : null}
    </Section>
  );
}

function Consent() {
  const [required, setRequired] = useState(false);
  const [given, setGiven] = useState(false);
  return (
    <Section title="Consent">
      <Toggle
        label="Consent required"
        value={required}
        onValueChange={(value) => {
          setRequired(value);
          call(`setConsentRequired(${value})`, () =>
            SallaPush.setConsentRequired(value)
          );
        }}
      />
      <Toggle
        label="Consent given"
        value={given}
        onValueChange={(value) => {
          setGiven(value);
          call(`setConsentGiven(${value})`, () =>
            SallaPush.setConsentGiven(value)
          );
        }}
      />
      <Note>
        SallaPush started at launch from the static configuration, so
        setConsentRequired(true) comes too late here: apps that need consent set
        SallaPushRequiresUserConsent or com.salla.push.REQUIRES_USER_CONSENT.
      </Note>
    </Section>
  );
}

function Logs() {
  const level = useSyncExternalStore(eventLog.subscribe, eventLog.logLevel);
  return (
    <Section title="Log level">
      <Choice
        options={LEVELS}
        value={level}
        onChange={(next) =>
          call(`Debug.setLogLevel('${next}')`, () => {
            SallaPush.Debug.setLogLevel(next);
            followLogs(next);
          })
        }
      />
      <Note>Sets SallaPush's console level and the event log's level.</Note>
    </Section>
  );
}

function Migration() {
  const [display, setDisplay] = useState(true);
  return (
    <Section title="Compat payloads">
      <Toggle
        label="Show compat-format payloads"
        value={display}
        onValueChange={(value) => {
          setDisplay(value);
          call(`Migration.setDisplayCompatPayloads(${value})`, () =>
            SallaPush.Migration.setDisplayCompatPayloads(value)
          );
        }}
      />
    </Section>
  );
}

function call(description: string, action: () => void): void {
  action();
  eventLog.add('call', description);
}

function result(description: string, value: boolean): void {
  eventLog.add('result', `${description}: ${value}`);
}
