import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Local-only secrets (gitignored). See android/secrets.properties.example for
// the format. Never commit real keys — this file only reads them.
val secretsPropertiesFile = rootProject.file("secrets.properties")
val secretsProperties = Properties()
if (secretsPropertiesFile.exists()) {
    FileInputStream(secretsPropertiesFile).use { secretsProperties.load(it) }
}
// Google's public test AdMob App ID — safe to ship as a fallback so the app
// builds and shows test ads even with no local secrets.properties.
val admobAppId: String =
    secretsProperties.getProperty("ADMOB_APP_ID", "ca-app-pub-3940256099942544~3347511713")

android {
    namespace = "com.petcheck.petcliniccheck"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // flutter_local_notifications(zonedSchedule)가 요구함 — 없으면 릴리스
        // 빌드가 :app:checkReleaseAarMetadata에서 실패한다.
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.petcheck.petcliniccheck"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        manifestPlaceholders["admobAppId"] = admobAppId
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

dependencies {
    // Explicit, pinned WorkManager dependency (google_mobile_ads only pulls it
    // in transitively via play-services-ads). This is what MainApplication.kt
    // compiles against for its manual, safe WorkManager.initialize() call, and
    // pinning one concrete version here also settles any silent version skew
    // between whatever multiple transitive requesters would otherwise resolve
    // to — the likely root cause of the WorkDatabase creation crash this
    // works around (see AndroidManifest.xml and MainApplication.kt).
    implementation("androidx.work:work-runtime-ktx:2.9.1")

    // flutter_local_notifications requires core library desugaring to be
    // enabled (its zonedSchedule implementation uses java.time APIs) — see
    // isCoreLibraryDesugaringEnabled above. Version per the plugin's own
    // setup docs.
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
