plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "dev.taildeck.taildeck"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "dev.taildeck.app"
        // Tailscale itself requires Android 8.0, so there is no point
        // supporting lower: the VPN this app depends on could not run there.
        minSdk = 26
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO(m5): replace with a real keystore before distributing.
            // Signing with the debug keys for now, so `flutter build apk
            // --release` works out of the box.
            signingConfig = signingConfigs.getByName("debug")

            // TODO(m5): enable R8 once the release build can be exercised on a
            // device. `proguard-rules.pro` is already in place, but shrinking a
            // WebView host is exactly the kind of change that fails at runtime
            // rather than at build time, so it stays off until it can be
            // verified by hand.
            isMinifyEnabled = false
            isShrinkResources = false
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
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
