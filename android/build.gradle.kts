allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}

// AGP 9 turns the "dependency requires a newer compileSdk" check into an error.
// Some Flutter plugins (e.g. image_cropper) still compile against android-33,
// so align every Android library subproject with the app's compileSdk (36).
// This must be registered before the evaluationDependsOn(":app") block below
// (which forces early evaluation of :app) and directly (not inside
// plugins.withId) so the callback runs before AGP's own afterEvaluate
// finalization reads compileSdk.
subprojects {
    afterEvaluate {
        extensions.findByName("android")?.let { ext ->
            if (ext is com.android.build.api.dsl.LibraryExtension) {
                ext.compileSdk = 36
            }
        }
    }
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
