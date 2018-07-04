package com.btc.serviceidl.generator.cpp;

import org.eclipse.core.runtime.IPath;
import org.eclipse.xtext.generator.IFileSystemAccess;

import com.btc.serviceidl.generator.common.ParameterBundle;
import com.btc.serviceidl.generator.common.ProjectType;

public interface IProjectSetFactory {
    IProjectSet create();

    void generateProjectFiles(IFileSystemAccess fileSystemAccess, ParameterBundle parameterBundle,
            Iterable<ExternalDependency> externalDependencies, IProjectSet projectSet,
            Iterable<IProjectReference> projectReferences, ProjectFileSet projectFileSet, ProjectType projectType,
            IPath projectPath, String projectName);
}
