import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystorePropertiesFile = rootProject.file("key.properties").takeIf { it.exists() }
    ?: rootProject.file("app/key.properties").takeIf { it.exists() }
    ?: file("key.properties")

val keystoreProperties = Properties()
if (keystorePropertiesFile.exists()) {
    keystorePropertiesFile.inputStream().use { keystoreProperties.load(it) }
}

android {
    namespace = "com.leitnerplatform.mobile_app"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.leitnerplatform.mobile_app"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            if (keystorePropertiesFile.exists()) {
                val keyStorePath = keystoreProperties.getProperty("storeFile") ?: "upload-keystore.jks"
                val resolvedStoreFile = if (file(keyStorePath).exists()) {
                    file(keyStorePath)
                } else if (file("app/$keyStorePath").exists()) {
                    file("app/$keyStorePath")
                } else if (rootProject.file("app/$keyStorePath").exists()) {
                    rootProject.file("app/$keyStorePath")
                } else {
                    file(keyStorePath)
                }
                keyAlias = keystoreProperties.getProperty("keyAlias") ?: "upload"
                keyPassword = keystoreProperties.getProperty("keyPassword") ?: "leitner123456"
                storeFile = resolvedStoreFile
                storePassword = keystoreProperties.getProperty("storePassword") ?: "leitner123456"
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (keystorePropertiesFile.exists()) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
        }
    }

    flavorDimensions.add("version")

    productFlavors {
        create("store") {
            dimension = "version"
            applicationIdSuffix = ".store"
            versionNameSuffix = "-store"
        }
        create("premium") {
            dimension = "version"
            applicationIdSuffix = ".premium"
            versionNameSuffix = "-premium"
        }
        create("direct") {
            dimension = "version"
            applicationIdSuffix = ".direct"
            versionNameSuffix = "-direct"
        }
        create("bazaar") {
            dimension = "version"
            versionNameSuffix = "-bazaar"
        }
        create("myket") {
            dimension = "version"
            versionNameSuffix = "-myket"
        }
        create("googleplay") {
            dimension = "version"
            versionNameSuffix = "-play"
        }
    }

    lint {
        abortOnError = false
        checkReleaseBuilds = false
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

flutter {
    source = "../.."
}
