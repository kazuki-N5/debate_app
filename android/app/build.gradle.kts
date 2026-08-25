import java.util.Properties
import java.io.FileInputStream


plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}


val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties") 

if (keystorePropertiesFile.exists()) {
    FileInputStream(keystorePropertiesFile).use { fis -> 
        keystoreProperties.load(fis)
    }
}




android {
    namespace = "com.kazuk.debate"
    compileSdk = 36
    ndkVersion = "28.2.13676358"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.kazuk.debate"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode.toInt()
        versionName = flutter.versionName
    }

   




       signingConfigs {
        create("release") { 
            keyAlias = keystoreProperties.getProperty("keyAlias")
            keyPassword = keystoreProperties.getProperty("keyPassword")

            val storeFileValue = keystoreProperties.getProperty("storeFile")
            if (storeFileValue != null && storeFileValue.isNotEmpty()) {
                storeFile = file(storeFileValue)
            } else {
                storeFile = null 
            }

            storePassword = keystoreProperties.getProperty("storePassword")
        }
    }

    buildTypes {
        getByName("release") { 
            signingConfig = signingConfigs.getByName("release")             
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
        }
         
    }


    

    

}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_11
    }
}

flutter {
    source = "../.."
}


dependencies {
    // NOTE: Do NOT pin com.revenuecat.purchases:purchases manually here.
    // purchases_flutter resolves its native SDK (purchases-hybrid-common ->
    // purchases-android 10.x -> Google Play Billing Library 8.3.0) automatically.
    // Pinning an older version here (e.g. 8.15.1) downgraded the Google Play
    // Billing Library to 7.1.1, which fails the Play Console requirement
    // (must be >= 8.0.0 since 2026-08-31).
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
}
