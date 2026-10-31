# The ads SDK pulls in WorkManager, which opens a Room database by reflection.
# R8 can't see that use and strips the generated database classes, so the
# release build crashed at startup in androidx.startup.InitializationProvider.
-keep class * extends androidx.room.RoomDatabase { <init>(); }
