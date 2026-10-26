import NativeRNSallaPush, {
  type LogEntrySpec,
  type SubscriptionChangedSpec,
} from '../NativeRNSallaPush';
import type {
  SallaPushEventSubscription,
  SallaPushLogEntry,
  SallaPushLogLevel,
  SallaPushSubscriptionChangedState,
} from '../types';
import { logEntry, subscriptionChange } from './mapping';
import { func, oneOf, valid } from './validate';

type Listener<Value> = (value: Value) => void;

/** A codegen event emitter of the TurboModule, such as NativeRNSallaPush.onClick. */
type Emitter<Payload> = (
  handler: (payload: Payload) => void
) => SallaPushEventSubscription;

/** The listeners of one event; each hub takes its own listener type. */
export interface Hub {
  add(listener: never): SallaPushEventSubscription;
  remove(listener: never): void;
}

/** What an emitter subscription is before the first listener, and what a dropped addEventListener call returns. */
const inert: SallaPushEventSubscription = Object.freeze({ remove() {} });

/**
 * The listeners of one event kind, behind one native registration. The first listener subscribes to the emitter and
 * only then starts the native registration, so the events native delivers at once (the taps kept from a cold start)
 * reach it. The last removal stops the native registration, then unsubscribes.
 */
export class EventHub<Payload, Value> implements Hub {
  private readonly listeners = new Set<Listener<Value>>();
  private subscription = inert;
  private readonly kind: string;
  private readonly name: string;
  private readonly subscribe: Emitter<Payload>;
  private readonly map: (payload: Payload) => Value;
  private readonly decide?: (value: Value, payload: Payload) => void;

  constructor(options: {
    /** The native registration: click, willDisplay, permission, user or loginFailure. */
    kind: string;
    /** The listeners as console lines name them. */
    name: string;
    subscribe: Emitter<Payload>;
    map: (payload: Payload) => Value;
    /**
     * Runs once the listeners got an event, for an event native waits on. Such a hub keeps its emitter subscription
     * after the last removal, so an event already on its way still gets its decision.
     */
    decide?: (value: Value, payload: Payload) => void;
  }) {
    this.kind = options.kind;
    this.name = options.name;
    this.subscribe = options.subscribe;
    this.map = options.map;
    this.decide = options.decide;
  }

  add(listener: Listener<Value>): SallaPushEventSubscription {
    if (!this.listeners.has(listener)) {
      this.listeners.add(listener);
      if (this.listeners.size === 1) {
        if (this.subscription === inert) {
          this.subscription = this.subscribe((payload) =>
            this.dispatch(payload)
          );
        }
        NativeRNSallaPush.startEvents(this.kind);
      }
    }
    return { remove: () => this.remove(listener) };
  }

  remove(listener: Listener<Value>): void {
    if (!this.listeners.delete(listener) || this.listeners.size > 0) {
      return;
    }
    NativeRNSallaPush.stopEvents(this.kind);
    if (!this.decide) {
      this.subscription.remove();
      this.subscription = inert;
    }
  }

  // A snapshot: a listener removed by another one during the dispatch still gets this event.
  private dispatch(payload: Payload): void {
    const value = this.map(payload);
    for (const listener of [...this.listeners]) {
      deliver(listener, value, this.name);
    }
    this.decide?.(value, payload);
  }
}

/**
 * The push-subscription listeners. Each one has its own native observer, so each gets native's own replay: the first
 * listener subscribes to the emitter, every listener then registers its id natively, and an event reaches only the
 * listener whose id it carries.
 */
export class SubscriptionHub implements Hub {
  private readonly ids = new Map<
    Listener<SallaPushSubscriptionChangedState>,
    number
  >();
  private readonly listeners = new Map<
    number,
    Listener<SallaPushSubscriptionChangedState>
  >();
  private subscription = inert;
  private nextId = 1;

  add(
    listener: Listener<SallaPushSubscriptionChangedState>
  ): SallaPushEventSubscription {
    if (!this.ids.has(listener)) {
      if (this.ids.size === 0) {
        this.subscription = NativeRNSallaPush.onPushSubscriptionChange(
          (payload) => this.dispatch(payload)
        );
      }
      const id = this.nextId++;
      this.ids.set(listener, id);
      this.listeners.set(id, listener);
      NativeRNSallaPush.addPushSubscriptionListener(id);
    }
    return { remove: () => this.remove(listener) };
  }

  remove(listener: Listener<SallaPushSubscriptionChangedState>): void {
    const id = this.ids.get(listener);
    if (id === undefined) {
      return;
    }
    this.ids.delete(listener);
    this.listeners.delete(id);
    NativeRNSallaPush.removePushSubscriptionListener(id);
    if (this.ids.size === 0) {
      this.subscription.remove();
      this.subscription = inert;
    }
  }

  private dispatch(payload: SubscriptionChangedSpec): void {
    const listener = this.listeners.get(payload.listenerId);
    if (listener) {
      deliver(
        listener,
        subscriptionChange(payload),
        "SallaPush.User.pushSubscription 'change' listener"
      );
    }
  }
}

/**
 * The app's one log handler. Its level reaches native before the native registration starts, so native registers at
 * it, and a later level only changes that registration. Removing the handler stops the registration, then unsubscribes.
 */
export class LogHandlerHub {
  private handler: Listener<SallaPushLogEntry> | null = null;
  private subscription = inert;

  set(
    level: SallaPushLogLevel,
    handler: Listener<SallaPushLogEntry> | null
  ): void {
    if (handler === null) {
      if (this.handler !== null) {
        this.handler = null;
        NativeRNSallaPush.stopEvents('log');
        this.subscription.remove();
        this.subscription = inert;
      }
      return;
    }
    NativeRNSallaPush.setLogHandlerLevel(level);
    if (this.handler === null) {
      this.subscription = NativeRNSallaPush.onLog((payload) =>
        this.dispatch(payload)
      );
      NativeRNSallaPush.startEvents('log');
    }
    this.handler = handler;
  }

  private dispatch(payload: LogEntrySpec): void {
    if (this.handler !== null) {
      deliver(this.handler, logEntry(payload), 'SallaPush.Debug log handler');
    }
  }
}

/**
 * Adds `listener` to the hub of `event`. A call with an unknown event or a listener that isn't a function is dropped
 * with one warning, and returns a subscription that does nothing.
 */
export function addListener(
  method: string,
  hubs: Readonly<Record<string, Hub>>,
  event: unknown,
  listener: unknown
): SallaPushEventSubscription {
  const hub = hubFor(method, hubs, event, listener);
  return hub ? hub.add(listener as never) : inert;
}

/** Removes `listener` from the hub of `event`; a call with an unknown event or a non-function listener is dropped. */
export function removeListener(
  method: string,
  hubs: Readonly<Record<string, Hub>>,
  event: unknown,
  listener: unknown
): void {
  hubFor(method, hubs, event, listener)?.remove(listener as never);
}

function hubFor(
  method: string,
  hubs: Readonly<Record<string, Hub>>,
  event: unknown,
  listener: unknown
): Hub | undefined {
  if (
    !valid(method, {
      event: [event, oneOf(Object.keys(hubs))],
      listener: [listener, func],
    })
  ) {
    return undefined;
  }
  return hubs[event as string];
}

/** Calls one listener; an exception it throws is reported, and doesn't reach the other listeners or native. */
function deliver<Value>(
  listener: Listener<Value>,
  value: Value,
  name: string
): void {
  try {
    listener(value);
  } catch (error) {
    console.error(`[SallaPush] A ${name} threw:`, error);
  }
}
