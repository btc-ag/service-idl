package com.btc.serviceidl.generator.cpp.prins

import com.btc.serviceidl.generator.ITargetVersionProvider
import com.btc.serviceidl.generator.common.ArtifactNature
import com.btc.serviceidl.generator.common.PackageInfo
import com.btc.serviceidl.generator.common.ParameterBundle
import com.btc.serviceidl.generator.common.ProjectType
import com.btc.serviceidl.generator.cpp.ExternalDependency
import com.btc.serviceidl.generator.cpp.IModuleStructureStrategy
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

    override generateProjectFiles(IFileSystemAccess fileSystemAccess, IModuleStructureStrategy moduleStructureStrategy,
        ITargetVersionProvider targetVersionProvider, ParameterBundle parameterBundle,
        Iterable<ExternalDependency> externalDependencies, Iterable<PackageInfo> importedDependencies,
        IProjectSet projectSet, Iterable<IProjectReference> projectReferences, ProjectFileSet projectFileSet,
        ProjectType projectType, IPath projectPath, String projectName)
    {
        val dependencyFileName = Constants.FILE_NAME_DEPENDENCIES.cpp
        val sourcePath = projectPath.append(moduleStructureStrategy.sourceFileDir)

        fileSystemAccess.generateFile(sourcePath.append(dependencyFileName).toString, ArtifactNature.CPP.label,
            generateDependencies(externalDependencies))
        projectFileSet.addToGroup(ProjectFileSet.DEPENDENCY_FILE_GROUP, dependencyFileName)

        new VSProjectFileGenerator(fileSystemAccess, moduleStructureStrategy, parameterBundle, projectSet,
            projectReferences, projectFileSet, projectType, projectPath, projectName).generate()
    }

    private def generateDependencies(Iterable<ExternalDependency> externalDependencies)
    {
        new DependenciesGenerator(externalDependencies).generate()
    }
}
