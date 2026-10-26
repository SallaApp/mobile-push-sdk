// The app id placeholder in a Flutter app's android/app/build.gradle.kts. scripts/verify.sh consumer builds it in a
// fresh app.
android {
    defaultConfig {
        // snippet:app-id
        manifestPlaceholders["sallaPushAppId"] = "00000000-0000-4000-8000-000000000002"
        // end-snippet
    }
}
