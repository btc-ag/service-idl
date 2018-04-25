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
/**
 * \file       Util.xtend
 * 
 * \brief      Miscellaneous common utility methods
 */
package com.btc.serviceidl.generator.common

import com.btc.serviceidl.util.Constants
import java.util.regex.Pattern
import com.btc.serviceidl.idl.ModuleDeclaration
import com.btc.serviceidl.idl.IDLSpecification
import org.eclipse.emf.ecore.EObject
import java.util.HashSet
import com.btc.serviceidl.idl.InterfaceDeclaration
import org.eclipse.xtext.naming.IQualifiedNameProvider
import com.btc.serviceidl.util.Util
import static extension com.btc.serviceidl.util.Extensions.*
import static extension com.btc.serviceidl.util.Util.*
import com.btc.serviceidl.idl.AliasDeclaration
import com.btc.serviceidl.idl.StructDeclaration
import java.util.Collection
import com.btc.serviceidl.idl.ExceptionDeclaration
import com.btc.serviceidl.idl.EnumDeclaration
import com.btc.serviceidl.idl.SequenceDeclaration
import com.btc.serviceidl.idl.AbstractType
import com.btc.serviceidl.idl.PrimitiveType
import com.btc.serviceidl.idl.ParameterElement

class GeneratorUtil
{
    def public static String transform(ParameterBundle parameterBundle, ArtifactNature artifactNature,
        TransformType transformType)
    {
        var result = ""
        for (module : parameterBundle.getModuleStack)
        {
            if (!module.virtual)
            {
                result += getEffectiveModuleName(module, artifactNature, transformType) +
                    (if (module != parameterBundle.getModuleStack.last) transformType.getSeparator else "")
            }
            else
            {
                if (transformType.useVirtual || artifactNature == ArtifactNature.JAVA)
                    result += getEffectiveModuleName(module, artifactNature, transformType) +
                        if (module != parameterBundle.getModuleStack.last)
                            transformType.getSeparator
                        else
                            ""
            }
        }

        if (parameterBundle.projectType !== null)
            result += transformType.getSeparator + parameterBundle.projectType.getName
        if (artifactNature == ArtifactNature.JAVA)
            result = result.toLowerCase
        return result
    }

    def private static String getEffectiveModuleName(ModuleDeclaration module, ArtifactNature artifactNature,
        TransformType transformType)
    {
        if (artifactNature == ArtifactNature.DOTNET)
        {
            if (module.main) return module.name + ".NET" else module.name
        }
        else if (artifactNature == ArtifactNature.JAVA)
        {
            if (module.eContainer === null || (module.eContainer instanceof IDLSpecification))
                return "com" + transformType.separator + module.name
            else
                return module.name
        }
        return module.name
    }

    def public static String switchPackageSeperator(String name, TransformType targetTransformType)
    {
        return name.replaceAll(Pattern.quote(Constants.SEPARATOR_PACKAGE), targetTransformType.getSeparator)
    }

    def static String switchSeparator(String name, TransformType sourceTransformType, TransformType targetTransformType)
    {
        name.replaceAll(Pattern.quote(sourceTransformType.separator), targetTransformType.separator)
    }

    def static Iterable<EObject> getFailableTypes(EObject container)
    {
        var objects = new HashSet<EObject>

        // interfaces: special handling due to inheritance
        if (container instanceof InterfaceDeclaration)
        {
            // function parameters
            val parameter_types = container.functions.map[parameters].flatten.filter[isFailable(paramType)].toSet

            // function return types
            val return_types = container.functions.map[returnedType].filter[isFailable].toSet

            objects.addAll(parameter_types)
            objects.addAll(return_types)
        }

        val contents = container.eAllContents.toList

        // typedefs
        objects.addAll(
            contents.filter(AliasDeclaration).filter[isFailable(type)].map[type]
        )

        // structs
        objects.addAll(
            contents.filter(StructDeclaration).map[members].flatten.filter[isFailable(type)].map[type]
        )

        // filter out duplicates (especially primitive types) before delivering the result!
        return objects.map[getUltimateType].map[UniqueWrapper.from(it)].toSet.map[type].sortBy[e|Names.plain(e)]
    }

    def static String asFailable(EObject element, EObject container, IQualifiedNameProvider qualifiedNameProvider)
    {
        val type = Util.getUltimateType(element)
        var String type_name
        if (type.isPrimitive)
        {
            type_name = Names.plain(type)
        }
        else
        {
            type_name = qualifiedNameProvider.getFullyQualifiedName(type).segments.join("_")
        }
        val container_fqn = qualifiedNameProvider.getFullyQualifiedName(container)
        return '''Failable_«container_fqn.segments.join("_")»_«type_name.toFirstUpper»'''
    }

    def static Collection<EObject> getEncodableTypes(EObject owner)
    {
        val nestedTypes = new HashSet<EObject>
        nestedTypes.addAll(owner.eContents.filter(StructDeclaration))
        nestedTypes.addAll(owner.eContents.filter(ExceptionDeclaration))
        nestedTypes.addAll(owner.eContents.filter(EnumDeclaration))
        return nestedTypes.sortBy[e|Names.plain(e)]
    }

    def static String getClassName(ArtifactNature artifactNature, ProjectType projectType, String basicName)
    {
        return projectType.getClassName(artifactNature, basicName)
    }

    def static boolean useCodec(EObject element, ArtifactNature artifactNature)
    {
        if (element instanceof PrimitiveType)
        {
            return element.isByte || element.isInt16 || element.isChar || element.isUUID
        // all other primitive types map directly to built-in types!
        }
        else if (element instanceof ParameterElement)
        {
            return useCodec(element.paramType, artifactNature)
        }
        else if (element instanceof AliasDeclaration)
        {
            return useCodec(element.type, artifactNature)
        }
        else if (element instanceof SequenceDeclaration)
        {
            if (artifactNature == ArtifactNature.DOTNET || artifactNature == ArtifactNature.JAVA)
                return useCodec(element.type, artifactNature) // check type of containing elements
            else
                return true
        }
        else if (element instanceof AbstractType)
        {
            if (element.primitiveType !== null)
                return useCodec(element.primitiveType, artifactNature)
            else if (element.collectionType !== null)
                return useCodec(element.collectionType, artifactNature)
            else if (element.referenceType !== null)
                return useCodec(element.referenceType, artifactNature)
        }
        return true;
    }

    def static String getCodecName(EObject object)
    {
        '''«getPbFileName(object)»«Constants.FILE_NAME_CODEC»'''
    }

    def static String getPbFileName(EObject object)
    {
        if (object instanceof ModuleDeclaration)
            Constants.FILE_NAME_TYPES
        else if (object instanceof InterfaceDeclaration)
            Names.plain(object)
        else
            getPbFileName(Util.getScopeDeterminant(object))
    }

    /**
     * Given a module stack, this method will calculate relative paths up to the
     * solution root directory in form of ../../
     * 
     * \details If at least one relative parent path is there, the string ALWAYS
     * ends with the path separator!
     */
    def public static String getRelativePathsUpwards(ParameterBundle param_bundle)
    {
        var paths = ""
        for (module : param_bundle.getModuleStack)
        {
            if (!module.virtual) // = non-virtual
                paths += ".." + TransformType.FILE_SYSTEM.separator
        }
        return paths
    }
}
