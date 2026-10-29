import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.jianxi.reader"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    lint {
        checkReleaseBuilds = true
        abortOnError = true
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.jianxi.reader"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // 签名身份不可再生：release 包只能用正式 key 签，绝不允许回退 debug key。
    // 缺 key.properties 时保持未签名，并由下方 package*Release 守卫在打包前硬失败，
    // 这样既不会产出"能装但签名随机"的包，也不会影响 debug 构建与单元测试。
    val keystoreFile = rootProject.file("key.properties")
    val hasReleaseSigning = keystoreFile.exists()

    signingConfigs {
        if (hasReleaseSigning) {
            create("release") {
                val props = Properties()
                props.load(FileInputStream(keystoreFile))
                storeFile = rootProject.file(props.getProperty("storeFile"))
                storePassword = props.getProperty("storePassword")
                keyAlias = props.getProperty("keyAlias")
                keyPassword = props.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (hasReleaseSigning) signingConfigs.getByName("release") else null
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

// Release 打包守卫：缺 key.properties 时直接失败，而不是产出未签名/调试签名的包。
// 只挂在 package*Release 上，debug 构建与单测不受影响。
tasks
    .matching { it.name.startsWith("package") && it.name.contains("Release") }
    .configureEach {
        doFirst {
            if (!hasReleaseSigning) {
                throw GradleException(
                    "缺少 android/key.properties：release 包必须使用正式签名。" +
                        "请按 docs/release.md 配置签名后重试（不会回退到 debug 签名）。",
                )
            }
        }
    }

flutter {
    source = "../.."
}
