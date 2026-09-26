import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing: android/key.properties (gitignored, never committed) points at the
// upload keystore. When it is missing, release builds fall back to the debug key so
// `flutter build` / `flutter run --release` keep working for everyone else, with a loud
// warning. Pass -PrequireReleaseSigning=true (Flutter: --android-project-arg / -P) to make
// release builds FAIL instead of silently using the debug key.
val keystorePropertiesFile = rootProject.file("key.properties")
val hasReleaseKeystore = keystorePropertiesFile.exists()
val requireReleaseSigning =
    project.findProperty("requireReleaseSigning")?.toString()?.toBoolean() == true
val keystoreProperties = Properties()
if (hasReleaseKeystore) {
    keystorePropertiesFile.inputStream().use { keystoreProperties.load(it) }
}

fun keystoreProperty(name: String): String =
    keystoreProperties.getProperty(name)?.trim()?.takeIf { it.isNotEmpty() }
        ?: throw GradleException("android/key.properties: '$name' missing")

// Relative storeFile paths resolve against android/ (where key.properties lives);
// absolute paths are used as-is.
fun releaseStoreFile(): File {
    val file = rootProject.file(keystoreProperty("storeFile"))
    if (!file.isFile) {
        throw GradleException("android/key.properties: storeFile not found: ${file.path}")
    }
    return file
}

android {
    namespace = "com.leximera.leximera"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.leximera.leximera"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            if (hasReleaseKeystore) {
                storeFile = releaseStoreFile()
                storePassword = keystoreProperty("storePassword")
                keyAlias = keystoreProperty("keyAlias")
                keyPassword = keystoreProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            // Upload key when android/key.properties exists, otherwise the debug key.
            signingConfig = if (hasReleaseKeystore) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
}

flutter {
    source = "../.."
}

// Runs only when a release variant is built (hooked into preReleaseBuild, which both
// assembleRelease and bundleRelease depend on), so debug/profile builds are unaffected
// and never print the warning.
val verifyReleaseSigning by tasks.registering {
    val missing = !hasReleaseKeystore
    val required = requireReleaseSigning
    doLast {
        if (missing && required) {
            throw GradleException(
                "Release signing required (-PrequireReleaseSigning=true) but " +
                    "android/key.properties not found",
            )
        }
        if (missing) {
            // quiet level (not warn): Flutter runs Gradle with -q, which would hide warn.
            logger.quiet(
                "⚠ android/key.properties not found — release is signed with the DEBUG key " +
                    "(not uploadable to Play)",
            )
        }
    }
}
tasks.configureEach {
    if (name == "preReleaseBuild") dependsOn(verifyReleaseSigning)
}
