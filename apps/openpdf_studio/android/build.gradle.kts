import org.jetbrains.kotlin.gradle.dsl.JvmTarget
import org.jetbrains.kotlin.gradle.tasks.KotlinJvmCompile

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    // file_picker 11 assumes AGP 9's built-in Kotlin support, while Flutter's
    // current compatibility template keeps built-in Kotlin disabled. Apply
    // KGP explicitly until all transitive plugins complete that migration.
    if (name == "file_picker") {
        pluginManager.apply("org.jetbrains.kotlin.android")
        tasks.withType<KotlinJvmCompile>().configureEach {
            compilerOptions.jvmTarget.set(JvmTarget.JVM_17)
        }
    }
    // Google Play requires 16 KB page-size support for apps targeting Android
    // 15 and above. The onnxruntime plugin ships a prebuilt libonnxruntime.so
    // whose LOAD segments are 4 KB aligned, so an upload containing it is
    // rejected. Drop that copy and take the officially published
    // onnxruntime-android AAR, which is 16 KB aligned for every ABI. The C API
    // stays backward compatible, and the plugin asks for OrtApi version 14.
    if (name == "onnxruntime") {
        pluginManager.withPlugin("com.android.library") {
            extensions.configure<com.android.build.gradle.LibraryExtension> {
                sourceSets.getByName("main").jniLibs.setSrcDirs(emptyList<String>())
            }
            dependencies.add(
                "implementation",
                "com.microsoft.onnxruntime:onnxruntime-android:1.20.0",
            )
        }
    }
    afterEvaluate {
        if (plugins.hasPlugin("com.android.library")) {
            extensions.configure<com.android.build.gradle.LibraryExtension> {
                // Some native plugins still declare API 33 internally even
                // though their AndroidX dependencies require API 34+.
                compileSdk = 36
            }
        }
    }
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
