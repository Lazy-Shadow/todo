import java.util.Properties // Fixes Unresolved reference: Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

// Fixed properties loading for Kotlin DSL
val keyProps = Properties()
val keyPropsFile = rootProject.file("key.properties")
if (keyPropsFile.exists()) {
    keyPropsFile.inputStream().use { keyProps.load(it) }
}

android {
    namespace = "com.ramos.todo_list"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17" // Fixed deprecation warning
    }

    defaultConfig {
        applicationId = "com.ramos.todo_list"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        multiDexEnabled = true
    }

    signingConfigs {
        create("release") {
            // Use getProperty() for cleaner Kotlin code
            keyAlias = keyProps.getProperty("keyAlias")
            keyPassword = keyProps.getProperty("keyPassword")
            storeFile = keyProps.getProperty("storeFile")?.let { file(it) }
            storePassword = keyProps.getProperty("storePassword")
        }
    }

    buildTypes {
        getByName("release") {
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
            signingConfig = if (keyProps.isEmpty) signingConfigs.getByName("debug") else signingConfigs.getByName("release")
        }
        getByName("debug") {
            isMinifyEnabled = false
        }
    }

    // Fixed the output renaming syntax
    applicationVariants.all {
        outputs.all {
            val output = this as com.android.build.gradle.internal.api.BaseVariantOutputImpl
            output.outputFileName = "todo.apk"
        }
    }
}

flutter {
    source = "../.."
}
