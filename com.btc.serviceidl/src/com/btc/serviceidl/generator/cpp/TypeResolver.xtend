package com.btc.serviceidl.generator.cpp

import com.btc.serviceidl.generator.common.GeneratorUtil
import com.btc.serviceidl.generator.common.Names
import com.btc.serviceidl.generator.common.ParameterBundle
import com.btc.serviceidl.generator.common.ProjectType
import com.btc.serviceidl.generator.common.ResolvedName
import com.btc.serviceidl.generator.common.TransformType
import com.btc.serviceidl.generator.common.TypeWrapper
import com.btc.serviceidl.idl.AbstractType
import com.btc.serviceidl.idl.InterfaceDeclaration
import com.btc.serviceidl.idl.PrimitiveType
import com.btc.serviceidl.util.Constants
import java.util.Collection
import java.util.HashSet
import java.util.LinkedHashSet
import java.util.List
import java.util.Map
import java.util.stream.Collectors
import org.eclipse.emf.ecore.EObject
import org.eclipse.xtend.lib.annotations.Accessors
import org.eclipse.xtext.naming.IQualifiedNameProvider

import static extension com.btc.serviceidl.generator.common.Extensions.*
import static extension com.btc.serviceidl.generator.cpp.CppExtensions.*

@Accessors(PACKAGE_GETTER)
class TypeResolver
{
    private val IQualifiedNameProvider qualified_name_provider
    private val ParameterBundle param_bundle
    private val extension IProjectSet vsSolution
    private val Collection<IProjectReference> project_references
    private val Collection<String> cab_libs
    private val Map<EObject, Collection<EObject>> smart_pointer_map

    private val modules_includes = new HashSet<String>
    private val cab_includes = new HashSet<String>
    private val boost_includes = new HashSet<String>
    private val stl_includes = new HashSet<String>
    private val odb_includes = new HashSet<String>

    def String resolveCAB(String class_name)
    {
        val header = HeaderResolver.getCABHeader(class_name)
        cab_includes.add(header)
        cab_libs.addAll(LibResolver.getCABLibs(header))
        return class_name
    }

    def String resolveCABImpl(String class_name)
    {
        val header = HeaderResolver.getCABImpl(class_name)
        cab_includes.add(header)
        cab_libs.addAll(LibResolver.getCABLibs(header))
        return class_name
    }

    def String resolveSTL(String class_name)
    {
        stl_includes.add(HeaderResolver.getSTLHeader(class_name))
        return class_name
    }

    def String resolveBoost(String class_name)
    {
        boost_includes.add(HeaderResolver.getBoostHeader(class_name))
        return class_name
    }

    def String resolveODB(String class_name)
    {
        odb_includes.add(HeaderResolver.getODBHeader(class_name))
        return class_name
    }

    def String resolveModules(String class_name)
    {
        modules_includes.add(HeaderResolver.getModulesHeader(class_name))        
        project_references.add(vsSolution.resolveClass(class_name))
        return class_name
    }

    def ResolvedName resolve(EObject object)
    {
        return resolve(object, object.mainProjectType)
    }

    def ResolvedName resolve(EObject object, ProjectType project_type)
    {
        if (com.btc.serviceidl.util.Util.isUUIDType(object))
        {
            if (project_type == ProjectType.PROTOBUF)
                return new ResolvedName(resolveSTL("std::string"), TransformType.NAMESPACE)
            else
                return new ResolvedName("BTC::Commons::CoreExtras::UUID", TransformType.NAMESPACE)
        }
        else if (object instanceof PrimitiveType)
            return new ResolvedName(getPrimitiveTypeName(object), TransformType.NAMESPACE)
        else if (object instanceof AbstractType && (object as AbstractType).primitiveType !== null)
            return resolve((object as AbstractType).primitiveType, project_type)

        val qualified_name = qualified_name_provider.getFullyQualifiedName(object)
        if (qualified_name === null)
            return new ResolvedName(Names.plain(object), TransformType.NAMESPACE)

        val resolved_name = qualified_name.toString
        if (HeaderResolver.isCAB(resolved_name))
            resolveCAB(GeneratorUtil.switchPackageSeperator(resolved_name, TransformType.NAMESPACE))
        else if (HeaderResolver.isBoost(resolved_name))
            resolveBoost(GeneratorUtil.switchPackageSeperator(resolved_name, TransformType.NAMESPACE))
        else
        {
            var result = GeneratorUtil.transform(
                ParameterBundle.createBuilder(com.btc.serviceidl.util.Util.getModuleStack(
                    com.btc.serviceidl.util.Util.getScopeDeterminant(object))).with(project_type).build,
                TransformType.NAMESPACE)
            result += Constants.SEPARATOR_NAMESPACE + if (object instanceof InterfaceDeclaration)
                project_type.getClassName(param_bundle.artifactNature, qualified_name.lastSegment)
            else
                qualified_name.lastSegment
            modules_includes.add(object.getIncludeFilePath(project_type))
            object.resolveProjectFilePath(project_type)
            return new ResolvedName(result, TransformType.NAMESPACE)
        }

        return new ResolvedName(qualified_name, TransformType.NAMESPACE)
    }

    def void resolveProjectFilePath(EObject referenced_object, ProjectType project_type)
    {
        val module_stack = com.btc.serviceidl.util.Util.getModuleStack(referenced_object)

        val temp_param = new ParameterBundle.Builder()
        temp_param.reset(param_bundle.artifactNature)
        temp_param.reset(module_stack)
        temp_param.reset(project_type)

        project_references.add(vsSolution.resolve(temp_param.build))
    }

    def getPrimitiveTypeName(PrimitiveType item)
    {
        if (item.integerType !== null)
        {
            switch item.integerType
            {
                case "int64":
                    return resolveSTL("int64_t")
                case "int32":
                    return resolveSTL("int32_t")
                case "int16":
                    return resolveSTL("int16_t")
                case "byte":
                    return resolveSTL("int8_t")
                default:
                    return item.integerType
            }
        }
        else if (item.stringType !== null)
            return resolveSTL("std::string")
        else if (item.floatingPointType !== null)
            return item.floatingPointType
        else if (item.uuidType !== null)
            return resolveCAB("BTC::Commons::CoreExtras::UUID")
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
        if (com.btc.serviceidl.util.Util.isSequenceType(other_type))
            return false;

        val dependencies = smart_pointer_map.get(element)
        if (dependencies !== null)
            return dependencies.contains(com.btc.serviceidl.util.Util.getUltimateType(other_type))
        else
            return false
    }

    def List<EObject> resolveForwardDeclarations(Collection<TypeWrapper> sorted_types)
    {
        val forward_declarations = sorted_types.filter[!forwardDeclarations.empty].map[forwardDeclarations].flatten.
            toList.stream.distinct.collect(Collectors.toList)

        for (wrapper : sorted_types)
        {
            var dependencies = smart_pointer_map.get(wrapper.type)
            if (dependencies === null)
            {
                dependencies = new LinkedHashSet<EObject>
                smart_pointer_map.put(wrapper.type, dependencies)
            }
            dependencies.addAll(wrapper.forwardDeclarations)
        }

        return forward_declarations
    }
}
