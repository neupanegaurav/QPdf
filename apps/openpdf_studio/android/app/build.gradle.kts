import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    FileInputStream(keystorePropertiesFile).use(keystoreProperties::load)
}

android {
    namespace = "studio.gaurav.qpdf"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "studio.gaurav.qpdf"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        // The in-process portable AI runtime uses Android APIs introduced in
        // API 28. Do not override its manifest: that would install on devices
        // where native inference can fail at runtime.
        minSdk = 28
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (keystorePropertiesFile.exists()) {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            // Without key.properties Gradle emits an unsigned release artifact.
            // CI/store builds inject the protected release keystore values.
            signingConfigs.findByName("release")?.let { signingConfig = it }
        }
    }

    packaging {
        jniLibs {
            // onnxruntime-android also carries the JNI bridge for its Java API,
            // which QPdf never calls: the Dart plugin binds libonnxruntime.so
            // through FFI. That bridge is still built for 4 KB pages, so
            // shipping it would fail Google Play's 16 KB page-size check.
            excludes += "**/libonnxruntime4j_jni.so"
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
