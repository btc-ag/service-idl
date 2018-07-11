/*********************************************************************
 * \author see AUTHORS file
 * \copyright 2015-2018 BTC Business Technology Consulting AG and others
 * 
 * This program and the accompanying materials are made
 * available under the terms of the Eclipse Public License 2.0
 * which is available at https://www.eclipse.org/legal/epl-2.0/
 * 
 * SPDX-License-Identifier: EPL-2.0
 **********************************************************************/
package com.btc.serviceidl.generator.cpp

import com.btc.serviceidl.generator.common.ArtifactNature
import com.btc.serviceidl.generator.common.GeneratorUtil
import com.btc.serviceidl.generator.common.Names
import com.btc.serviceidl.generator.common.ParameterBundle
import com.btc.serviceidl.generator.common.ProjectType
import com.btc.serviceidl.generator.common.ResolvedName
import com.btc.serviceidl.generator.common.TransformType
import com.btc.serviceidl.generator.common.TypeWrapper
import com.btc.serviceidl.generator.cpp.HeaderResolver.GroupedHeader
import com.btc.serviceidl.generator.cpp.prins.PrinsHeaderResolver
import com.btc.serviceidl.idl.AbstractType
import com.btc.serviceidl.idl.AbstractTypeReference
import com.btc.serviceidl.idl.PrimitiveType
import java.util.Collection
import java.util.HashMap
import java.util.HashSet
import java.util.LinkedHashSet
import java.util.Map
import java.util.Set
import org.eclipse.core.runtime.IPath
import org.eclipse.emf.ecore.EObject
import org.eclipse.xtend.lib.annotations.Accessors
import org.eclipse.xtend.lib.annotations.Data
import org.eclipse.xtext.naming.IQualifiedNameProvider

import static extension com.btc.serviceidl.generator.common.Extensions.*
import static extension com.btc.serviceidl.generator.cpp.CppExtensions.*
import static extension com.btc.serviceidl.util.Util.*

@Accessors(NONE)
class TypeResolver
{
    @Accessors(PACKAGE_GETTER) val IQualifiedNameProvider qualified_name_provider
    @Accessors(PACKAGE_GETTER) val IProjectSet projectSet
    @Accessors(PACKAGE_GETTER) val IModuleStructureStrategy moduleStructureStrategy

    val Collection<IProjectReference> project_references
    val Collection<ExternalDependency> cab_libs
    val Map<EObject, Collection<EObject>> smart_pointer_map

    @Accessors(NONE) val Map<IncludeGroup, Set<IPath>> includes = new HashMap<IncludeGroup, Set<IPath>>

    def getIncludes()
    {
        includes.entrySet.map[new Pair(it.key, it.value.immutableCopy)].toMap([it.key], [value])
    }

    def Iterable<IProjectReference> getProject_references()
    {
        project_references.unmodifiableView
    }

    def Iterable<ExternalDependency> getCab_libs()
    {
        cab_libs.unmodifiableView
    }

    @Deprecated
    def void addLibraryDependency(ExternalDependency libFile)
    {
        cab_libs.add(libFile)
    }

    def addTargetInclude(IPath path)
    { addToGroup(TARGET_INCLUDE_GROUP, path) }

    @Deprecated
    def addCabInclude(IPath path)
    {
        addToGroup(CAB_INCLUDE_GROUP, path)
        path
    }

    private def void addToGroup(IncludeGroup includeGroup, IPath path)
    {
        includes.computeIfAbsent(includeGroup, [new HashSet<IPath>]).add(path)
    }

    @Data
    static class IncludeGroup
    {
        val String name;
    }

    public static val TARGET_INCLUDE_GROUP = new IncludeGroup("target")
    public static val STL_INCLUDE_GROUP = new IncludeGroup("STL")
    public static val BOOST_INCLUDE_GROUP = new IncludeGroup("boost")
    public static val CAB_INCLUDE_GROUP = new IncludeGroup("BTC.CAB")

    @Accessors(PACKAGE_GETTER) val HeaderResolver headerResolver

    new(
        IQualifiedNameProvider qualified_name_provider,
        IProjectSet projectSet,
        IModuleStructureStrategy moduleStructureStrategy,
        Collection<IProjectReference> project_references,
        Collection<ExternalDependency> cab_libs,
        Map<EObject, Collection<EObject>> smart_pointer_map
    )
    {
        this.qualified_name_provider = qualified_name_provider
        this.projectSet = projectSet
        this.moduleStructureStrategy = moduleStructureStrategy
        this.project_references = project_references
        this.cab_libs = cab_libs
        this.smart_pointer_map = smart_pointer_map
        this.headerResolver = moduleStructureStrategy.createHeaderResolver
    }

    def String resolveSymbol(String symbolName)
    {
        headerResolver.getHeader(symbolName).resolveHeader
        return symbolName
    }

    def void resolveHeader(GroupedHeader header)
    {
        addToGroup(header.includeGroup, header.path)
        resolveLibrary(header)
    }

    def boolean tryResolveSymbol(String symbolName)
    {
        val header = headerResolver.tryGetHeader(symbolName)
        header?.resolveHeader
        return header !== null
    }

    private def void resolveLibrary(HeaderResolver.GroupedHeader header)
    {
        // TODO resolve and add to libs generically
        switch (header.includeGroup)
        {
            case CAB_INCLUDE_GROUP:
                cab_libs.addAll(LibResolver.getCABLibs(header.path))
            case STL_INCLUDE_GROUP:
            // do nothing
            {
            }
            case PrinsHeaderResolver.ODB_INCLUDE_GROUP:
            // TODO remove this here, make a subclass in prins.* or so
            // do nothing
            {
            }
            default:
                throw new IllegalArgumentException("Cannot resolve a library for this header: " + header.toString)
        }
    }

    def String resolveSymbolWithImplementation(String symbolName)
    {
        val header = headerResolver.getImplementationHeader(symbolName)
        addToGroup(header.includeGroup, header.path)
        resolveLibrary(header)
        return symbolName
    }

    def ResolvedName resolve(AbstractTypeReference object)
    {
        return resolve(object, object.mainProjectType)
    }

    def ResolvedName resolve(AbstractTypeReference object, ProjectType project_type)
    {
        if (project_type == ProjectType.PROTOBUF)
            throw new IllegalArgumentException("Use ProtobufUtil.resolveProtobuf instead!")

        if (object instanceof PrimitiveType)
            return new ResolvedName(getPrimitiveTypeName(object), TransformType.NAMESPACE)
        else if (object instanceof AbstractType && (object as AbstractType).primitiveType !== null)
            return resolve((object as AbstractType).primitiveType, project_type)

        val qualified_name = qualified_name_provider.getFullyQualifiedName(object)
        if (qualified_name === null)
            return new ResolvedName(Names.plain(object), TransformType.NAMESPACE)

        if (tryResolveSymbol(GeneratorUtil.switchPackageSeperator(qualified_name.toString, TransformType.NAMESPACE)))
        {
            return new ResolvedName(qualified_name, TransformType.NAMESPACE)
        }
        else
        {
            val result = GeneratorUtil.getFullyQualifiedClassName(object, qualified_name, project_type,
                ArtifactNature.CPP, TransformType.NAMESPACE)
            addToGroup(TARGET_INCLUDE_GROUP, object.getIncludeFilePath(project_type, moduleStructureStrategy))
            object.resolveProjectFilePath(project_type)
            return new ResolvedName(result, TransformType.NAMESPACE)
        }
    }

    def void resolveProjectFilePath(EObject referenced_object, ProjectType project_type)
    {
        project_references.add(projectSet.resolve(
            new ParameterBundle.Builder().with(referenced_object.moduleStack).with(project_type).build))
    }

    def getPrimitiveTypeName(PrimitiveType item)
    {
        if (item.integerType !== null)
        {
            switch item.integerType
            {
                case "int64":
                    return resolveSymbol("int64_t")
                case "int32":
                    return resolveSymbol("int32_t")
                case "int16":
                    return resolveSymbol("int16_t")
                case "byte":
                    return resolveSymbol("int8_t")
                default:
                    return item.integerType
            }
        }
        else if (item.stringType !== null)
            return resolveSymbol("std::string")
        else if (item.floatingPointType !== null)
            return item.floatingPointType
        else if (item.uuidType !== null)
            return resolveSymbol("BTC::Commons::CoreExtras::UUID")
        else if (item.booleanType !== null)
            return "bool"
        else if (item.charType !== null)
            return "char"

        throw new IllegalArgumentException("Unknown PrimitiveType: " + item.class.toString)
    }

    /**
     * For a given element, check if another type (as member of this element)
     * must be represented as smart pointer + forward declaration, or as-is.
     */
    def boolean useSmartPointer(EObject element, AbstractTypeReference other_type)
    {
        // sequences use forward-declared types as template parameters
        // and do not need the smart pointer wrapping
        if (other_type.isSequenceType)
            return false

        val dependencies = smart_pointer_map.get(element)
        return dependencies !== null && dependencies.contains(other_type.ultimateType)
    }

    def Iterable<EObject> resolveForwardDeclarations(Iterable<TypeWrapper> types)
    {
        // TODO does this really need to iterate twice through types? 
        for (wrapper : types)
        {
            smart_pointer_map.computeIfAbsent(wrapper.type, [new LinkedHashSet<EObject>]).addAll(
                wrapper.forwardDeclarations)
        }

        return types.stream.filter[!it.forwardDeclarations.empty].flatMap[forwardDeclarations.stream].distinct.iterator.
            toIterable
    }

}
