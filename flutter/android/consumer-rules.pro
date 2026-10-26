# Applied to the R8 build of every app that uses this plugin.
#
# SallaPush Android brings WorkManager 2.9.1 and, with it, Room 2.5.0, whose rule keeps every Room database class but
# not the constructor Room calls by reflection. R8's strict full mode, the default from the Android Gradle plugin 9,
# then removes it, and every start of a minified app crashes in WorkManager's initializer. SallaPush Android ships the
# same rule; this copy is a safeguard.
-keep class * extends androidx.room.RoomDatabase {
    <init>();
}
