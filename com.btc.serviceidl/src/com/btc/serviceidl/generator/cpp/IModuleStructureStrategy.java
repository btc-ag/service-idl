package com.btc.serviceidl.generator.cpp;

import org.eclipse.core.runtime.IPath;
import org.eclipse.xtext.xbase.lib.Pair;

import com.btc.serviceidl.generator.common.ParameterBundle;
import com.btc.serviceidl.generator.common.ProjectType;
import com.btc.serviceidl.idl.ModuleDeclaration;

/**
 * Provides an abstraction of aspects defining the module structure of the
 * generated C++ code.
 * 
 * @author SIGIESEC
 *
 */
public interface IModuleStructureStrategy {

    /**
     * Determines the include file path for a generated header file specified by the
     * given properties. Include directives for the header files are generated using
     * the HeaderResolver returned by createHeaderResolver.
     * 
     * @param moduleHierarchy
     *            the hierarchy of modules in which the header is placed
     * @param projectType
     *            the generated project within the specified module
     * @param baseName
     *            the base name of the header
     * @param headerType
     *            the type of the header, which is used to determine the appropriate
     *            file extension
     * @return the include file path for the specified header, which must be
     *         resolvable in the include path used by the generated code
     */
    IPath getIncludeFilePath(Iterable<ModuleDeclaration> moduleHierarchy, ProjectType projectType, String baseName,
            HeaderType headerType);

    /**
     * Describes which header files are used to encapsulate the code within a
     * generated header file. Include directives for these header files are
     * generated using the HeaderResolver returned by createHeaderResolver.
     * 
     * For example, if getEncapsulationHeaders returns Pair("foo/a.h", "foo/b.h"), a
     * generated include file might look like
     * 
     * <pre>
     * {@code
     * #pragma once
     * 
     * #include <foo/a.h>
     * 
     * // generated content
     * 
     * #include <foo/b.h>
     * }
     * </pre>
     * 
     * @return a Pair of paths to the encapsulation headers, which must be
     *         resolvable in the include path used by the generated code
     */
    Pair<String, String> getEncapsulationHeaders();

    /**
     * Creates a HeaderResolver configured according to the coding conventions
     * implemented by the strategy. An implementation must configure all default
     * include groups.
     * 
     * @return a HeaderResolver
     */
    HeaderResolver createHeaderResolver();

    /**
     * Returns the base directory for a project.
     * 
     * @param bundle
     *            project specification
     * @return IPath specifying the base directory.
     */
    IPath getProjectDir(ParameterBundle bundle);

}
