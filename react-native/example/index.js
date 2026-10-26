import { AppRegistry } from 'react-native';
import App from './src/App';
import { startEventLog } from './src/eventLog';
import { startSelfTest } from './src/selfTest';
import { startSallaPush } from './src/start';
import { name as appName } from './app.json';

// At app start, before the first screen: the tap that launched the app reaches the click listeners added here.
startEventLog();
startSallaPush();
startSelfTest();

AppRegistry.registerComponent(appName, () => App);
