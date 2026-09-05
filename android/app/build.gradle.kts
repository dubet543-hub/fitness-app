import java.util.Properties
import java.io.FileInputStream
import org.jetbrains.kotlin.gradle.dsl.JvmTarget

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.example.fitness_app"
    // Pinned to 36 — ML Kit needs android:attr/lStar (API 31+) and several
    // plugins (camera_android, google_sign_in_android, …) require compiling
    // against SDK 36. The Flutter default was resolving lower and broke
    // release resource linking ("resource android:attr/lStar not found").
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.solidcore.ams"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            if (keystorePropertiesFile.exists()) {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            // Falls back to the debug key only when key.properties is absent
            // (e.g. a fresh checkout without the release keystore), so local
            // release builds don't hard-fail — Play Store uploads always run
            // with key.properties present and use the real release signature.
            signingConfig = if (keystorePropertiesFile.exists())
                signingConfigs.getByName("release")
            else
                signingConfigs.getByName("debug")
            // R8 code shrinking was already on (via Flutter's Gradle plugin
            // default) with no rules file telling it what Flutter's own
            // Play Store integration and the native SDKs need kept — the
            // cause of "installs fine, crashes instantly, but only from the
            // Play Store" on real devices. See proguard-rules.pro for why.
            isMinifyEnabled = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
            // Resource shrinking, however, is turned OFF. The notification
            // sound (raw/alarm_sound) and small icon (drawable/ic_stat_notify)
            // are only ever referenced dynamically by name string from
            // flutter_local_notifications, which the shrinker's static
            // analysis can't see — so it stripped them and every notification
            // failed at runtime (invalid_sound, then a NPE in setSmallIcon),
            // release builds only. It saves ~1 MB on a 110 MB app; not worth
            // the repeated production breakage.
            isShrinkResources = false
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = JvmTarget.JVM_17
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

flutter {
    source = "../.."
}
