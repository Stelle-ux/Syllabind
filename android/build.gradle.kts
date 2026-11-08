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
    project.evaluationDependsOn(":app")
}

// ── Paksa semua modul plugin memakai compileSdk 36 ──
// Paket `file_picker` membawa modul Gradle-nya sendiri yang masih mematok
// compileSdk android-34. Menyetel compileSdk di android/app/build.gradle.kts
// HANYA memengaruhi modul :app — modul plugin tetap 34, sehingga Gradle
// menggagalkan build:
//   "Execution failed for task ':file_picker:checkReleaseAarMetadata'"
// Blok ini menimpa compileSdk setiap modul Android setelah dievaluasi,
// sehingga :app dan seluruh plugin berada di versi API yang sama.
// compileSdk hanya menentukan API yang boleh dipakai saat kompilasi —
// tidak mengubah minSdk, jadi tidak memengaruhi HP yang bisa memasang.
subprojects {
    // afterEvaluate harus dipasang SEBELUM subproyek dievaluasi. Kalau sudah
    // dievaluasi (mis. karena evaluationDependsOn di atas mengevaluasinya
    // lebih dulu), memanggil afterEvaluate melempar:
    //   "Cannot run Project.afterEvaluate(Action) when the project is
    //    already evaluated."
    // Karena itu perbaikannya dijalankan langsung bila statusnya sudah selesai.
    val paksaCompileSdk: () -> Unit = {
        val ext = project.extensions.findByName("android")
        if (ext != null) {
            try {
                ext.javaClass
                    .getMethod("setCompileSdkVersion", Int::class.javaPrimitiveType)
                    .invoke(ext, 36)
            } catch (_: Exception) {
                // Modul tanpa setCompileSdkVersion (mis. modul non-Android)
                // diabaikan dengan aman.
            }
        }
    }

    if (state.executed) {
        paksaCompileSdk()
    } else {
        afterEvaluate { paksaCompileSdk() }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
