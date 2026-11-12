import java.io.FileInputStream
import java.net.URI
import java.net.URISyntaxException
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

// Same rules as tool/check_release_config.py and AppConfig.parse; the shared cases are in
// config/release_url_cases.json (run `gradlew :app:verifyReleaseConfigRules`).
val releaseHostPattern = Regex("^[a-z0-9]([a-z0-9-]*[a-z0-9])?(\\.[a-z0-9]([a-z0-9-]*[a-z0-9])?)*\\.[a-z]{2,}$")

/** Why [url] is not a usable release API_BASE_URL, or null. Never echoes the URL (it may hold credentials). */
fun releaseApiUrlProblem(url: String): String? {
    if (url.isBlank()) return "API_BASE_URL is missing or empty"
    val uri = try {
        URI(url.trim())
    } catch (e: URISyntaxException) {
        return "API_BASE_URL is not a valid URL"
    }
    if (uri.scheme?.lowercase() != "https") return "API_BASE_URL must use https"
    if (uri.rawUserInfo != null) return "API_BASE_URL must not contain credentials"
    if (uri.rawQuery != null || uri.rawFragment != null) return "API_BASE_URL must not contain a query or a fragment"
    val host = uri.host?.lowercase()?.trim('[', ']')
        ?: return "API_BASE_URL must have a valid host name"
    if (host.contains(':') || Regex("^[0-9.]+$").matches(host)) return "API_BASE_URL must use a host name, not an IP address"
    if (host == "localhost" || host.endsWith(".localhost")) return "API_BASE_URL must not point at localhost"
    if (!releaseHostPattern.matches(host)) return "API_BASE_URL host is not a public host name"
    return null
}

tasks.configureEach {
    val isReleaseTask = Regex("^pre(Staging|Prod)ReleaseBuild$").matches(name)
    if (isReleaseTask) {
        doFirst {
            val problem = releaseApiUrlProblem(dartDefines()["API_BASE_URL"].orEmpty())
            if (problem != null) {
                throw GradleException(
                    "Release build $name: $problem. Pass --dart-define-from-file=config/<flavor>.json " +
                        "and check it with tool/check_release_config.py."
                )
            }
        }
    }
}

tasks.register("verifyReleaseConfigRules") {
    description = "Checks the Gradle release URL rules against config/release_url_cases.json."
    val casesFile = rootProject.file("../config/release_url_cases.json")
    inputs.file(casesFile)
    doLast {
        @Suppress("UNCHECKED_CAST")
        val cases = (groovy.json.JsonSlurper().parse(casesFile) as Map<String, Any>)["cases"] as List<Map<String, Any>>
        val wrong = cases.filter { (releaseApiUrlProblem(it["url"] as String) == null) != (it["valid"] as Boolean) }
        if (wrong.isNotEmpty()) {
            throw GradleException("Release URL rules disagree with ${wrong.size} shared case(s): " +
                wrong.joinToString { "#" + cases.indexOf(it) })
        }
        println("verifyReleaseConfigRules: ${cases.size} shared cases OK")
    }
}

flutter {
    source = "../.."
}
