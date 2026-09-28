allprojects {
    repositories {
        google()
        mavenCentral()
    }
    // home_widget pulls an alpha Glance that demands API 37; the stable line
    // has everything the plugin uses and compiles against API 36.
    configurations.all {
        resolutionStrategy.force("androidx.glance:glance:1.1.1", "androidx.glance:glance-appwidget:1.1.1")
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
    project.evaluationDependsOn(":app")
}

// Plugins compiled for older JVM targets break against Glance's newer
// bytecode; compile every module's Kotlin for Java 17 (validation of the
// Java/Kotlin target mismatch is relaxed to a warning in gradle.properties).
subprojects {
    tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
        compilerOptions.jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
