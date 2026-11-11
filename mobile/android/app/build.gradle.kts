import java.io.FileInputStream
import java.util.Base64
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.teia.aiassistant"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.teia.aiassistant"
        minSdk = 26
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    flavorDimensions += "environment"
    productFlavors {
        create("dev") {
            dimension = "environment"
            applicationIdSuffix = ".dev"
            resValue("string", "app_name", "TEIA AI Dev")
        }
        create("staging") {
            dimension = "environment"
            applicationIdSuffix = ".staging"
            resValue("string", "app_name", "TEIA AI Staging")
        }
        create("prod") {
            dimension = "environment"
            resValue("string", "app_name", "TEIA AI")
        }
    }

    // Release signing comes only from a key.properties file outside git (path in TEIA_KEY_PROPERTIES,
    // default android/key.properties, which is git-ignored). Without it, release outputs are unsigned;
    // they are never signed with the debug key.
    val keyPropertiesFile = rootProject.file(System.getenv("TEIA_KEY_PROPERTIES") ?: "key.properties")
    val releaseSigning = keyPropertiesFile.takeIf { it.exists() }?.let { file ->
        val props = Properties().apply { FileInputStream(file).use { load(it) } }
        signingConfigs.create("release") {
            storeFile = file(props.getProperty("storeFile"))
            storePassword = props.getProperty("storePassword")
            keyAlias = props.getProperty("keyAlias")
            keyPassword = props.getProperty("keyPassword")
        }
    }

    buildTypes {
        release {
            signingConfig = releaseSigning
        }
    }

    // App Links for staging/prod are added only when the owner's verified host is given
    // (-PappLinkHost=<host>); there is no default domain.
    val appLinkHost = (project.findProperty("appLinkHost") as String?)?.trim().orEmpty()
    if (appLinkHost.isNotEmpty()) {
        require(Regex("^[a-z0-9.-]+\\.[a-z]{2,}$").matches(appLinkHost)) { "appLinkHost must be a plain host name" }
        defaultConfig.manifestPlaceholders["appLinkHost"] = appLinkHost
        sourceSets.getByName("staging").manifest.srcFile("src/applinks/AndroidManifest.xml")
        sourceSets.getByName("prod").manifest.srcFile("src/applinks/AndroidManifest.xml")
    }
}

// Staging and prod release builds must carry a valid https API_BASE_URL (from
// --dart-define-from-file=config/<flavor>.json); otherwise the build fails here instead of
// producing an app that only shows a configuration error.
fun dartDefines(): Map<String, String> {
    val raw = (project.findProperty("dart-defines") as String?) ?: return emptyMap()
    return raw.split(",").filter { it.isNotBlank() }.associate {
        val decoded = String(Base64.getDecoder().decode(it))
        decoded.substringBefore("=") to decoded.substringAfter("=", "")
    }
}

tasks.configureEach {
    val isReleaseTask = Regex("^pre(Staging|Prod)ReleaseBuild$").matches(name)
    if (isReleaseTask) {
        doFirst {
            val defines = dartDefines()
            val api = defines["API_BASE_URL"].orEmpty()
            val host = Regex("^https://([^/:?#@]+)").find(api)?.groupValues?.get(1).orEmpty()
            val isIp = Regex("^[0-9.]+$|:").containsMatchIn(host)
            if (host.isEmpty() || isIp || host == "localhost" || host.endsWith(".localhost")) {
                throw GradleException(
                    "Release build $name needs API_BASE_URL as an https URL with a public host name " +
                        "(pass --dart-define-from-file=config/<flavor>.json). Got: '${if (api.isEmpty()) "<missing>" else api}'."
                )
            }
        }
    }
}

flutter {
    source = "../.."
}
