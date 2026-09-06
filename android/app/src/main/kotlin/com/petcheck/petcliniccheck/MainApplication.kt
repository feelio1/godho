package com.petcheck.petcliniccheck

import android.app.Application
import android.util.Log
import androidx.work.Configuration
import androidx.work.WorkManager

/**
 * WorkManager's default androidx.startup-based auto-initialization is opted
 * out of in AndroidManifest.xml, because it was crashing the app at cold
 * start (java.lang.RuntimeException: Failed to create an instance of
 * androidx.work.impl.WorkDatabase, surfacing through Google Mobile Ads'
 * internal use of WorkManager for background telemetry — unrelated to the
 * banner/app-open ad serving this app actually uses).
 *
 * We initialize WorkManager here instead, after the process has fully
 * attached, and never let a failure here be fatal: if WorkDatabase creation
 * still fails on a given device, WorkManager simply stays uninitialized and
 * the app continues normally — only Google Mobile Ads' optional background
 * telemetry would be affected, not core app functionality or ad display.
 */
class MainApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        try {
            WorkManager.initialize(this, Configuration.Builder().build())
        } catch (e: Throwable) {
            Log.w("MainApplication", "WorkManager initialization failed; continuing without it", e)
        }
    }
}
