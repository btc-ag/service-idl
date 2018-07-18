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
        Iterable<IProjectReference> projectReferences, ProjectFileSet projectFileSet, ProjectType projectType,
        IPath projectPath, String projectName)
    {
        val dependencyFileName = Constants.FILE_NAME_DEPENDENCIES.cpp
        val sourcePath = projectPath.append("source")

        fileSystemAccess.generateFile(sourcePath.append(dependencyFileName).toString, ArtifactNature.CPP.label,
            generateDependencies(externalDependencies))
        projectFileSet.addToGroup(ProjectFileSet.DEPENDENCY_FILE_GROUP, dependencyFileName)

        new VSProjectFileGenerator(fileSystemAccess, parameterBundle, projectSet, projectReferences, projectFileSet,
            projectType, projectPath, projectName).generate()
    }

    private def generateDependencies(Iterable<ExternalDependency> externalDependencies)
    {
        new DependenciesGenerator(externalDependencies).generate()
    }
}
