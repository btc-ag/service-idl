package com.btc.serviceidl.generator.cpp.prins

import com.btc.serviceidl.generator.common.ArtifactNature
import com.btc.serviceidl.generator.common.ParameterBundle
import com.btc.serviceidl.generator.common.ProjectType
import com.btc.serviceidl.generator.cpp.ExternalDependency
import com.btc.serviceidl.generator.cpp.IProjectReference
import com.btc.serviceidl.generator.cpp.IProjectSet
import com.btc.serviceidl.generator.cpp.IProjectSetFactory
import com.btc.serviceidl.generator.cpp.ProjectFileSet
import com.btc.serviceidl.util.Constants
import java.util.Map
import java.util.Set
import org.eclipse.core.runtime.IPath
import org.eclipse.xtext.generator.IFileSystemAccess

import static extension com.btc.serviceidl.generator.common.FileTypeExtensions.*

class VSSolutionFactory implements IProjectSetFactory
{

    override IProjectSet create()
    {
        new VSSolution
    }

    override generateProjectFiles(IFileSystemAccess fileSystemAccess, ParameterBundle parameterBundle,
        Iterable<ExternalDependency> externalDependencies, IProjectSet projectSet,
        Map<IProjectReference, Set<IProjectReference>> protobufProjectReferences,
        Iterable<IProjectReference> projectReferences, ProjectFileSet projectFileSet, ProjectType projectType,
        IPath projectPath, String projectName)
    {
        val dependency_file_name = Constants.FILE_NAME_DEPENDENCIES.cpp
        val source_path = projectPath.append("source")

        fileSystemAccess.generateFile(source_path.append(dependency_file_name).toString, ArtifactNature.CPP.label,
            generateDependencies(externalDependencies))
        projectFileSet.addToGroup(ProjectFileSet.DEPENDENCY_FILE_GROUP, dependency_file_name)

        new VSProjectFileGenerator(fileSystemAccess, parameterBundle, projectSet, protobufProjectReferences,
            projectReferences, projectFileSet, projectType, projectPath, projectName).generate()
    }

    private def generateDependencies(Iterable<ExternalDependency> externalDependencies)
    {
        new DependenciesGenerator(externalDependencies).generate()
    }
}
