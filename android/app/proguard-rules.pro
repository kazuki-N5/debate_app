# ------------------------------------------------------------------
# R8 / ProGuard keep rules for this app
#
# WorkManager (androidx.work, pulled in by flutter_local_notifications
# and firebase_messaging) uses Room internally. Room instantiates the
# generated database implementation class (androidx.work.impl.WorkDatabase_Impl)
# REFLECTIVELY at app startup (via androidx.startup.InitializationProvider).
# R8 (enabled for release builds by AGP 9) cannot see that reflection and
# strips the generated class constructor, which crashes the app at launch:
#
#   java.lang.RuntimeException: Unable to get provider
#       androidx.startup.InitializationProvider
#   Caused by: java.lang.RuntimeException: Failed to create an instance of
#       androidx.work.impl.WorkDatabase
#
# Debug builds work because R8 does not run there.
# ------------------------------------------------------------------

# Keep the generated Room database implementation for WorkManager,
# including its no-arg constructor and DAO implementations.
-keep class androidx.work.impl.WorkDatabase_Impl { *; }

# Generic rule: keep any Room generated *Database_Impl class and its
# constructor (covers future Room databases added to the app).
-keep class * extends androidx.room.RoomDatabase { <init>(); }
