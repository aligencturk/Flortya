plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

android {
    namespace = "com.rivorya.flortya"
    compileSdk = 36
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
        // Desugaring'i etkinleştir - Java 8+ özellikleri için
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    aaptOptions {
        noCompress += listOf("tflite") // TensorFlow Lite model dosyalarını sıkıştırma
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.rivorya.flortya"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 23
        targetSdk = 36 // Flutter'in targetSdkVersion değeri yerine manuel olarak ayarlıyoruz
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        
        // MultiDex desteği ekle
        multiDexEnabled = true
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            // signingConfig = signingConfigs.getByName("debug")
            
            // ProGuard kurallarını etkinleştir
            isMinifyEnabled = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }

    packaging {
        resources {
            // ML Kit ile ilgili kaynakları hariç tut
            excludes += "/META-INF/{AL2.0,LGPL2.1}"
            excludes += "**/*.proto"
        }
    }

    lint {
        disable += "InvalidPackage"
        checkReleaseBuilds = false
        abortOnError = false
    }
}

dependencies {
    // Java 8+ desugaring desteği
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
    
    // Firebase BOM
    implementation(platform("com.google.firebase:firebase-bom:32.7.1"))
    
    // Firebase ürünleri için dependency ekleyin
    implementation("com.google.firebase:firebase-analytics")
    implementation("com.google.firebase:firebase-auth")
    implementation("com.google.android.gms:play-services-auth:20.7.0")
    
    // ML Kit modülleri - sadece Latin dilleri için
    implementation("com.google.mlkit:text-recognition:16.0.0")
    
    // ML Kit için gerekli ek bağımlılıklar
    implementation("com.google.android.gms:play-services-mlkit-text-recognition:19.0.0")
    
    // MultiDex desteği
    implementation("androidx.multidex:multidex:2.0.1")
}

flutter {
    source = "../.."
}

afterEvaluate {
    tasks.named("assembleRelease") {
        doLast {
            // Android Gradle tarafından oluşturulan APK'nın yolu
            val outputApk = file("${buildDir}/outputs/apk/release/app-release-unsigned.apk")
            if (outputApk.exists()) {
                // Flutter'ın beklediği klasör yolu
                val flutterOutputDir = file("${rootProject.rootDir}/../build/app/outputs/flutter-apk")
                flutterOutputDir.mkdirs()
                
                // APK'yı Flutter'ın beklediği konuma kopyala
                copy {
                    from(outputApk)
                    into(flutterOutputDir)
                    rename { "app-release.apk" }
                }
                
                println("APK dosyası başarıyla kopyalandı: ${flutterOutputDir}/app-release.apk")
            } else {
                println("HATA: APK dosyası bulunamadı: $outputApk")
                // Mevcut APK dosyalarını göster
                file("${buildDir}/outputs").walk().filter { it.isFile && it.extension == "apk" }.forEach {
                    println("Bulunan APK: $it")
                }
            }
        }
    }
}

afterEvaluate {
    tasks.named("assembleDebug") {
        doLast {
            val outputApk = file("$buildDir/outputs/flutter-apk/app-debug.apk")
            val flutterExpectedPath = file("${rootProject.rootDir}/../build/app/outputs/flutter-apk")
            flutterExpectedPath.mkdirs()
            copy {
                from(outputApk)
                into(flutterExpectedPath)
            }
        }
    }
}
