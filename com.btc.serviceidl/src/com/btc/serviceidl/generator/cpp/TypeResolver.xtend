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
import com.btc.serviceidl.generator.cpp.prins.PrinsHeaderResolver
import com.btc.serviceidl.idl.AbstractType
import com.btc.serviceidl.idl.InterfaceDeclaration
import com.btc.serviceidl.idl.PrimitiveType
import com.btc.serviceidl.util.Constants
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
    val Collection<IProjectReference> project_references
    val Collection<String> cab_libs
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

    def Iterable<String> getCab_libs()
    {
        cab_libs.unmodifiableView
    }

    @Deprecated
    def void addLibraryDependency(String libFile)
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
        if (!includes.containsKey(includeGroup)) includes.put(includeGroup, new HashSet<IPath>)
        includes.get(includeGroup).add(path)
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

    // PRINS-specific, TODO move to PRINS-package
    public static val MODULES_INCLUDE_GROUP = new IncludeGroup("BTC.PRINS.Modules")

    // TODO inject this, this is PRINS-specific
    @Accessors(PACKAGE_GETTER) val headerResolver = PrinsHeaderResolver.create

    def String resolveSymbol(String symbolName)
    {
        val header = headerResolver.getHeader(symbolName)
        addToGroup(header.includeGroup, header.path)
        resolveLibrary(header)
        return symbolName
    }

    private def void resolveLibrary(HeaderResolver.GroupedHeader header)
    {
        // TODO resolve and add to libs generically
        if (header.includeGroup == CAB_INCLUDE_GROUP)
            cab_libs.addAll(LibResolver.getCABLibs(header.path))
        if (header.includeGroup == MODULES_INCLUDE_GROUP || header.includeGroup == TARGET_INCLUDE_GROUP)
            project_references.add(projectSet.resolveHeader(header))
    }

    def String resolveSymbolWithImplementation(String symbolName)
    {
        val header = headerResolver.getImplementationHeader(symbolName)
        addToGroup(header.includeGroup, header.path)
        resolveLibrary(header)
        return symbolName
    }

    def ResolvedName resolve(EObject object)
    {
        return resolve(object, object.mainProjectType)
    }

    def ResolvedName resolve(EObject object, ProjectType project_type)
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

        val resolved_name = qualified_name.toString
        if (headerResolver.isCAB(resolved_name) || headerResolver.isBoost(resolved_name))
        {
            resolveSymbol(GeneratorUtil.switchPackageSeperator(resolved_name, TransformType.NAMESPACE))
            return new ResolvedName(qualified_name, TransformType.NAMESPACE)
        }
        else
        {
            var result = GeneratorUtil.getTransformedModuleName(ParameterBundle.createBuilder(
                object.scopeDeterminant.moduleStack
            ).with(project_type).build, ArtifactNature.CPP, TransformType.NAMESPACE)
            result += Constants.SEPARATOR_NAMESPACE + if (object instanceof InterfaceDeclaration)
                project_type.getClassName(ArtifactNature.CPP, qualified_name.lastSegment)
            else
                qualified_name.lastSegment
            addToGroup(TARGET_INCLUDE_GROUP, object.getIncludeFilePath(project_type))
            object.resolveProjectFilePath(project_type)
            return new ResolvedName(result, TransformType.NAMESPACE)
        }
    }

    def void resolveProjectFilePath(EObject referenced_object, ProjectType project_type)
    {
        val module_stack = com.btc.serviceidl.util.Util.getModuleStack(referenced_object)

        val temp_param = new ParameterBundle.Builder()
        temp_param.reset(module_stack)
        temp_param.reset(project_type)

        project_references.add(projectSet.resolve(temp_param.build))
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
    def boolean useSmartPointer(EObject element, EObject other_type)
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
            var dependencies = smart_pointer_map.get(wrapper.type)
            if (dependencies === null)
            {
                dependencies = new LinkedHashSet<EObject>
                smart_pointer_map.put(wrapper.type, dependencies)
            }
            dependencies.addAll(wrapper.forwardDeclarations)
        }

        return types.stream.filter[!it.forwardDeclarations.empty].flatMap[forwardDeclarations.stream].distinct.iterator.
            toIterable
    }

}
