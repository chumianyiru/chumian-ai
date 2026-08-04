plugins {
    id("com.android.application")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.chumian.ai"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.chumian.ai"
        minSdk = 24
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            val keystorePath = System.getenv("KEYSTORE_PATH")
            val keystorePasswordEnv = System.getenv("KEYSTORE_PASSWORD")
            val keyPasswordEnv = System.getenv("KEY_PASSWORD")
            val keyAliasEnv = System.getenv("KEY_ALIAS")

            if (keystorePath != null &&
                keystorePasswordEnv != null &&
                keyPasswordEnv != null &&
                keyAliasEnv != null
            ) {
                storeFile = file(keystorePath)
                storePassword = keystorePasswordEnv
                keyPassword = keyPasswordEnv
                keyAlias = keyAliasEnv
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (signingConfigs.getByName("release").storeFile?.exists() == true) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
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
