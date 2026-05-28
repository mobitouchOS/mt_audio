group = "com.mobitouchos.mt_audio"
version = "1.0"

buildscript {
    val agpVersion = if (rootProject.extra.has("agp_version")) {
        rootProject.extra["agp_version"] as String
    } else {
        "8.11.1"
    }

    val kotlinVersion = if (rootProject.extra.has("kotlin_version")) {
        rootProject.extra["kotlin_version"] as String
    } else {
        "2.2.20"
    }

    repositories {
        google()
        mavenCentral()
    }

    dependencies {
        classpath("com.android.tools.build:gradle:$agpVersion")
        classpath("org.jetbrains.kotlin:kotlin-gradle-plugin:$kotlinVersion")
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

plugins {
    id("com.android.library")
    id("kotlin-android")
}

android {
    namespace = "com.mobitouchos.mt_audio"
    compileSdk = 35

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        minSdk = 21
    }
}
