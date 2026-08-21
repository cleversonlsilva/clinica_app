import org.gradle.api.file.Directory
import org.gradle.api.tasks.Delete

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// ============================================================
// DIRETÓRIO DE BUILD
// ============================================================

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()

rootProject.layout.buildDirectory.value(
    newBuildDir
)

subprojects {
    val newSubprojectBuildDir: Directory =
        newBuildDir
            .dir(project.name)

    project.layout.buildDirectory.value(
        newSubprojectBuildDir
    )
}

// ============================================================
// DEPENDÊNCIAS ENTRE SUBPROJETOS
// ============================================================

subprojects {
    project.evaluationDependsOn(":app")
}

// ============================================================
// CLEAN
// ============================================================

tasks.register<Delete>("clean") {
    delete(
        rootProject.layout.buildDirectory
    )
}