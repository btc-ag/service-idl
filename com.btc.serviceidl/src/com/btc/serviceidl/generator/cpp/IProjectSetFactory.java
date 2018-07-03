package com.btc.serviceidl.generator.cpp;

import java.util.Map;
import java.util.Set;

import org.eclipse.core.runtime.IPath;
import org.eclipse.xtext.generator.IFileSystemAccess;
import org.eclipse.xtext.xbase.lib.Functions.Function0;

import com.btc.serviceidl.generator.common.ParameterBundle;
import com.btc.serviceidl.generator.common.ProjectType;

public interface IProjectSetFactory {
    IProjectSet create();

    void generateProjectFiles(IFileSystemAccess fileSystemAccess, ParameterBundle parameterBundle,
            IProjectSet projectSet, Map<String, Set<IProjectReference>> protobufProjectReferences,
            Iterable<IProjectReference> projectReferences, ProjectFileSet projectFileSet, ProjectType projectType,
            IPath projectPath, String projectName, Function0<TypeResolver> createTypeResolver);
}
