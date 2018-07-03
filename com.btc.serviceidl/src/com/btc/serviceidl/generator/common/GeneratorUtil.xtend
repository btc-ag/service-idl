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

import com.btc.serviceidl.idl.AbstractType
import com.btc.serviceidl.idl.AliasDeclaration
import com.btc.serviceidl.idl.EnumDeclaration
import com.btc.serviceidl.idl.ExceptionDeclaration
import com.btc.serviceidl.idl.IDLSpecification
import com.btc.serviceidl.idl.InterfaceDeclaration
import com.btc.serviceidl.idl.ModuleDeclaration
import com.btc.serviceidl.idl.ParameterElement
import com.btc.serviceidl.idl.PrimitiveType
import com.btc.serviceidl.idl.SequenceDeclaration
import com.btc.serviceidl.idl.StructDeclaration
import com.btc.serviceidl.util.Constants
import com.btc.serviceidl.util.Util
import com.google.common.base.CaseFormat
import java.util.ArrayList
import java.util.HashSet
import java.util.regex.Pattern
import org.eclipse.core.runtime.Path
import org.eclipse.emf.ecore.EObject
import org.eclipse.xtext.naming.IQualifiedNameProvider
import org.eclipse.xtext.naming.QualifiedName

import static extension com.btc.serviceidl.util.Extensions.*
import static extension com.btc.serviceidl.util.Util.*

class GeneratorUtil
{
    def static String getTransformedModuleName(ParameterBundle parameterBundle, ArtifactNature artifactNature,
        TransformType transformType)
    {
        val parts = parameterBundle.getModuleStack.map [ module |
            if (!module.virtual || transformType.useVirtual || artifactNature == ArtifactNature.JAVA)
                getEffectiveModuleName(module, artifactNature)
            else
                #[]
        ].flatten + if (parameterBundle.projectType !== null)
            #[parameterBundle.projectType.getName]
        else
            #[]
        val result = parts.join(transformType.separator)

        if (artifactNature == ArtifactNature.JAVA)
            result.toLowerCase
        else
            result
    }

    private static def Iterable<String> getEffectiveModuleName(ModuleDeclaration module, ArtifactNature artifactNature)
    {
        if (artifactNature == ArtifactNature.DOTNET && module.main)
        {
            // TODO shouldn't this return two parts instead of a single one containg "."?
            #[if (module.main) module.name + ".NET" else module.name]
        }
        else if (artifactNature == ArtifactNature.JAVA)
        {
            // TODO this must be changed... prefixing "com" is not appropriate in general
            if (module.eContainer === null || (module.eContainer instanceof IDLSpecification))
                #["com", module.name]
            else
                #[module.name]
        }
        else
            #[module.name]
    }

    def static String switchPackageSeperator(String name, TransformType targetTransformType)
    {
        return name.replaceAll(Pattern.quote(Constants.SEPARATOR_PACKAGE), targetTransformType.getSeparator)
    }

    static def String switchSeparator(String name, TransformType sourceTransformType, TransformType targetTransformType)
    {
        name.replaceAll(Pattern.quote(sourceTransformType.separator), targetTransformType.separator)
    }

    static def Iterable<EObject> getFailableTypes(EObject container)
    {
        var objects = new ArrayList<Iterable<EObject>>

        // interfaces: special handling due to inheritance
        if (container instanceof InterfaceDeclaration)
        {
            objects.add(container.functions.map[parameters].flatten.filter[isFailable(paramType)].filter(EObject))
            objects.add(container.functions.map[returnedType].filter[isFailable].filter(EObject))
        }

        val contents = container.eAllContents.toList

        // typedefs
        objects.add(
            contents.filter(AliasDeclaration).filter[isFailable(type)].map[type]
        )

        // structs
        objects.add(
            contents.filter(StructDeclaration).map[members].flatten.filter[isFailable(type)].map[type]
        )

        // filter out duplicates (especially primitive types) before delivering the result!
        return objects.flatten.toSet.map[getUltimateType].map[UniqueWrapper.from(it)].toSet.map[type].sortBy[e|Names.plain(e)]
    }

    static val FAILABLE_SEPARATOR = "_"

    static def String asFailable(EObject element, EObject container, IQualifiedNameProvider qualifiedNameProvider)
    {
        #[#["Failable"], qualifiedNameProvider.getFullyQualifiedName(container).segments, getTypeName(
            Util.getUltimateType(element), qualifiedNameProvider).map[toFirstUpper]].flatten.join(FAILABLE_SEPARATOR)
    }

    private static def Iterable<String> getTypeName(EObject type, IQualifiedNameProvider qualifiedNameProvider)
    {
        if (type.isPrimitive)
            #[Names.plain(type)]
        else
            qualifiedNameProvider.getFullyQualifiedName(type).segments
    }

    static def Iterable<EObject> getEncodableTypes(EObject owner)
    {
        val nestedTypes = new HashSet<EObject>
        nestedTypes.addAll(owner.eContents.filter(StructDeclaration))
        nestedTypes.addAll(owner.eContents.filter(ExceptionDeclaration))
        nestedTypes.addAll(owner.eContents.filter(EnumDeclaration))
        return nestedTypes.sortBy[e|Names.plain(e)]
    }

    static def String getClassName(ArtifactNature artifactNature, ProjectType projectType, String basicName)
    {
        projectType.getClassName(artifactNature, basicName)
    }

    static def boolean useCodec(EObject element, ArtifactNature artifactNature)
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

    static def String getCodecName(EObject object)
    {
        '''«getPbFileName(object)»«Constants.FILE_NAME_CODEC»'''
    }

    static def String getPbFileName(EObject object)
    {
        if (object instanceof ModuleDeclaration)
            Constants.FILE_NAME_TYPES
        else if (object instanceof InterfaceDeclaration)
            Names.plain(object)
        else
            getPbFileName(Util.getScopeDeterminant(object))
    }

    static def asPath(ParameterBundle bundle, ArtifactNature nature)
    {
        new Path(getTransformedModuleName(bundle, nature, TransformType.FILE_SYSTEM))
    }

    static def String asProtobufName(String name, CaseFormat targetFormat)
    {
        // TODO instead of applying a heuristic, this should be configured explicitly, see 
        // https://github.com/btc-ag/service-idl/issues/90
        val caseFormat = if (name.contains('_'))
                CaseFormat.LOWER_UNDERSCORE
            else (if (Character.isUpperCase(name.charAt(0)))
                CaseFormat.UPPER_CAMEL
            else
                CaseFormat.LOWER_CAMEL)

        caseFormat.to(targetFormat, name.fixAbbreviation)
    }

    private def static String fixAbbreviation(String intermediate)
    {
        val res = new StringBuilder
        var StringBuilder currentAbbrev = null
        for (c : intermediate.toCharArray)
        {
            if (Character.isUpperCase(c))
            {
                if (currentAbbrev !== null)
                    currentAbbrev.append(Character.toLowerCase(c))
                else
                {
                    currentAbbrev = new StringBuilder
                    currentAbbrev.append(c)
                }
            }
            else
            {
                if (currentAbbrev !== null)
                {
                    val tmp = currentAbbrev.toString
                    res.append(tmp.substring(0, tmp.length - 1))
                    res.append(Character.toUpperCase(tmp.charAt(tmp.length - 1)))
                    currentAbbrev = null
                }
                res.append(c)
            }
        }
        if (currentAbbrev !== null) res.append(currentAbbrev)

        res.toString
    }

    static def getFullyQualifiedClassName(EObject object, QualifiedName qualifiedName, ProjectType projectType,
        ArtifactNature artifactNature, TransformType transformType)
    {
        String.join(transformType.separator, #[getTransformedModuleName(ParameterBundle.createBuilder(
            object.scopeDeterminant.moduleStack
        ).with(projectType).build, artifactNature, transformType), if (object instanceof InterfaceDeclaration)
            projectType.getClassName(artifactNature, qualifiedName.lastSegment)
        else
            qualifiedName.lastSegment])
    }
}
