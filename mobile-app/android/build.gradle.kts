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

subprojects {
    val configureNamespace: (Project) -> Unit = { proj ->
        if (proj.hasProperty("android")) {
            val android = proj.extensions.findByName("android")
            if (android != null) {
                // Configure namespace
                try {
                    val getNamespace = android.javaClass.getMethod("getNamespace")
                    val currentNamespace = getNamespace.invoke(android)
                    if (currentNamespace == null || (currentNamespace as? String)?.isEmpty() == true) {
                        val setNamespace = android.javaClass.getMethod("setNamespace", String::class.java)
                        val ns = if (proj.name == "flutter_jailbreak_detection") {
                            "appmire.be.flutterjailbreakdetection"
                        } else {
                            "com.leitnerplatform.mobile_app.${proj.name.replace("-", "_")}"
                        }
                        setNamespace.invoke(android, ns)
                        println("Dynamically set namespace for subproject ${proj.name} to $ns")
                    }
                } catch (e: Exception) {
                    // Ignore reflection errors
                }

                // Configure Java compatibility
                try {
                    val compileOptions = android.javaClass.getMethod("getCompileOptions").invoke(android)
                    val targetCompat = compileOptions.javaClass.getMethod("setTargetCompatibility", org.gradle.api.JavaVersion::class.java)
                    val sourceCompat = compileOptions.javaClass.getMethod("setSourceCompatibility", org.gradle.api.JavaVersion::class.java)
                    targetCompat.invoke(compileOptions, org.gradle.api.JavaVersion.VERSION_17)
                    sourceCompat.invoke(compileOptions, org.gradle.api.JavaVersion.VERSION_17)
                    println("Dynamically set Java compatibility to 17 for subproject ${proj.name}")
                } catch (e: Exception) {
                    // Ignore reflection errors
                }
            }
        }
    }

    if (project.state.executed) {
        configureNamespace(project)
    } else {
        project.afterEvaluate {
            configureNamespace(project)
        }
    }

    // Configure Kotlin compatibility
    tasks.configureEach {
        if (name.startsWith("compile") && name.endsWith("Kotlin")) {
            try {
                val compilerOptions = this.javaClass.getMethod("getCompilerOptions").invoke(this)
                val jvmTargetProp = compilerOptions.javaClass.getMethod("getJvmTarget")
                val jvmTargetVal = jvmTargetProp.invoke(compilerOptions)
                val setMethod = jvmTargetVal.javaClass.getMethod("set", Object::class.java)
                val jvmTargetEnumClass = Class.forName("org.jetbrains.kotlin.gradle.dsl.JvmTarget")
                val jvmTarget17 = jvmTargetEnumClass.getField("JVM_17").get(null)
                setMethod.invoke(jvmTargetVal, jvmTarget17)
                println("Dynamically set Kotlin JVM target to 17 for task $name in subproject ${project.name}")
            } catch (e: Exception) {
                // Ignore if not a Kotlin JVM task
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
