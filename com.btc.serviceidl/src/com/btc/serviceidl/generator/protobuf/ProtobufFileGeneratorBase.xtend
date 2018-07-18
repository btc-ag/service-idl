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
package com.btc.serviceidl.generator.protobuf

import com.btc.serviceidl.generator.common.ArtifactNature
import com.btc.serviceidl.generator.common.GeneratorUtil
import com.btc.serviceidl.generator.common.Names
import com.btc.serviceidl.generator.common.ParameterBundle
import com.btc.serviceidl.generator.common.ProjectType
import com.btc.serviceidl.generator.common.TransformType
import com.btc.serviceidl.generator.cpp.IModuleStructureStrategy
import com.btc.serviceidl.idl.AbstractContainerDeclaration
import com.btc.serviceidl.idl.AbstractStructuralDeclaration
import com.btc.serviceidl.idl.AbstractType
import com.btc.serviceidl.idl.AbstractTypeReference
import com.btc.serviceidl.idl.AliasDeclaration
import com.btc.serviceidl.idl.EnumDeclaration
import com.btc.serviceidl.idl.ExceptionDeclaration
import com.btc.serviceidl.idl.InterfaceDeclaration
import com.btc.serviceidl.idl.ParameterElement
import com.btc.serviceidl.idl.PrimitiveType
import com.btc.serviceidl.idl.SequenceDeclaration
import com.btc.serviceidl.idl.StructDeclaration
import com.btc.serviceidl.idl.TupleDeclaration
import com.btc.serviceidl.util.Constants
import com.btc.serviceidl.util.MemberElementWrapper
import java.util.Collection
import java.util.HashSet
import java.util.Map
import java.util.Set
import org.eclipse.core.runtime.IPath
import org.eclipse.emf.ecore.EObject
import org.eclipse.xtend.lib.annotations.Accessors
import org.eclipse.xtext.naming.IQualifiedNameProvider

import static extension com.btc.serviceidl.generator.protobuf.ProtobufGeneratorUtil.*
import static extension com.btc.serviceidl.util.Extensions.*
import static extension com.btc.serviceidl.util.Util.*

@Accessors(NONE)
class ProtobufFileGeneratorBase
{
    val IQualifiedNameProvider qualifiedNameProvider
    val IModuleStructureStrategy moduleStructureStrategy
    val Map<ParameterBundle, Set<ParameterBundle>> projectReferences
    val Map<String, String> typedefTable // TODO is it correct to share this across files?
    val ArtifactNature artifactNature
    val referencedFiles = new HashSet<IPath>

    static val WRAPPER_SUFFIX = "Wrapper"

    protected def String generateFailable(AbstractContainerDeclaration container)
    {
        val failableTypes = GeneratorUtil.getFailableTypes(container)
        if (!failableTypes.empty)
        {
            '''
                
                // local failable type wrappers
                «FOR failableType : failableTypes»
                    message «GeneratorUtil.asFailable(failableType, container, qualifiedNameProvider)»
                    {
                       // NOK: exception is set
                       optional string exception  = 1;
                       optional string message    = 2;
                       optional string stacktrace = 3;
                       
                       // OK: value is set
                       optional «resolve(failableType, container, container)» value = 4;
                    }
                «ENDFOR»
            '''
        }
    }

    protected def String generateTypes(AbstractContainerDeclaration container, Collection<? extends EObject> contents)
    {
        '''
            «FOR typedef : contents.filter(AliasDeclaration).filter[requiresNewMessageType(type.actualType)] SEPARATOR System.lineSeparator»
                «toText(typedef.type, typedef, container, new Counter)»
            «ENDFOR»
            
            «FOR enumDeclaration : contents.filter(typeof(EnumDeclaration)) SEPARATOR System.lineSeparator»
                «toText(enumDeclaration, container, container, new Counter)»
            «ENDFOR»
            
            «FOR struct : contents.filter(StructDeclaration) SEPARATOR System.lineSeparator»
                «toText(struct, container, container, new Counter)»
            «ENDFOR»
            
            «FOR exceptionDeclaration : contents.filter(ExceptionDeclaration) SEPARATOR System.lineSeparator»
                «toText(exceptionDeclaration, container, container, new Counter)»
            «ENDFOR»
        '''
    }

    protected def String generatePackageName(AbstractContainerDeclaration container)
    {
        '''
            syntax = "proto2";
            package «container.getModuleName(artifactNature)»;
        '''
    }

    protected def String generateImports(AbstractContainerDeclaration container)
    {
        '''
            «FOR importFile : referencedFiles»
                import "«importFile.toPortableString»";
            «ENDFOR»
        '''
    }

    protected def dispatch String toText(StructDeclaration element, EObject context,
        AbstractContainerDeclaration container, Counter id)
    {
        if (context instanceof AbstractContainerDeclaration)
            '''
                message «element.name»
                {
                   «val fieldId = new Counter»
                   «FOR typeDeclaration : element.typeDecls SEPARATOR System.lineSeparator»
                       «toText(typeDeclaration, element, container, fieldId)»
                   «ENDFOR»
                   
                   «FOR member : element.allMembers SEPARATOR System.lineSeparator»
                       «toText(member, element, container, fieldId)»
                   «ENDFOR»
                }
            '''
        else
        {
            id.incrementAndGet
            resolve(element, context, container)
        }
    }

    protected def dispatch String toText(ExceptionDeclaration element, EObject context,
        AbstractContainerDeclaration container, Counter id)
    {
        if (context instanceof AbstractContainerDeclaration)
            '''
                message «element.name»
                {
                   «val fieldId = new Counter»
                   «FOR member : element.allMembers SEPARATOR System.lineSeparator»
                       «toText(member, element, container, fieldId)»
                   «ENDFOR»
                }
            '''
        else
            resolve(element, context, container)
    }

    protected def dispatch String toText(MemberElementWrapper element, EObject context,
        AbstractContainerDeclaration container, Counter id)
    {
        '''
            «IF element.isOptional && !element.type.isSequenceType»
                optional «toText(element.type, element.type, container, new Counter)» «element.protoFileAttributeName» = «id.incrementAndGet»;
            «ELSEIF element.type.isSequenceType»
                «makeSequence(element.type.ultimateType, element.type.isFailable, element.type, container, element.protoFileAttributeName, id)»
            «ELSEIF requiresNewMessageType(element.type)»
                «toText(element.type, element.type, container, id)»
            «ELSE»
                required «toText(element.type, element.type, container, new Counter)» «element.protoFileAttributeName» = «id.incrementAndGet»;
            «ENDIF»
        '''
    }

    protected def dispatch String toText(SequenceDeclaration element, EObject context,
        AbstractContainerDeclaration container, Counter id)
    {
        makeSequence(element.type.ultimateType, element.failable, context, container,
            Names.plain(context).asProtoFileAttributeName, id)
    }

    protected def dispatch String toText(TupleDeclaration element, EObject context,
        AbstractContainerDeclaration container, Counter id)
    {
        val tupleName = ( if (context instanceof TupleDeclaration ||
            context instanceof SequenceDeclaration) "Tuple" else Names.plain(context).toFirstUpper ) + WRAPPER_SUFFIX

        '''
            message «tupleName»
            {
               «val elementId = new Counter»
               «FOR tupleElement : element.types»
                   «IF requiresNewMessageType(tupleElement.actualType)»
                       «toText(tupleElement, element, container, new Counter)»
                   «ELSE»
                       required «toText(tupleElement, element, container, elementId)» element«elementId» = «elementId»;
                   «ENDIF»
               «ENDFOR»
            }
            «IF !(context instanceof SequenceDeclaration)»required «tupleName» «Names.plain(context).asProtoFileAttributeName» = «id.incrementAndGet»;«ENDIF»
        '''
    }

    protected def dispatch String toText(ParameterElement element, EObject context,
        AbstractContainerDeclaration container, Counter id)
    {
        val sequence = element.tryGetSequence
        '''
            «IF sequence.present»
                «toText(sequence.get, element, container, id)»
            «ELSE»
                required «toText(element.paramType, element, container, new Counter)» «element.protoFileAttributeName» = «id.incrementAndGet»;
            «ENDIF»
        '''
    }

    protected def dispatch String toText(EnumDeclaration element, EObject context,
        AbstractContainerDeclaration container, Counter id)
    {
        if (context instanceof AbstractStructuralDeclaration)
        {
            val fieldId = new Counter
            '''
                enum «element.name»
                {
                   «FOR identifier : element.containedIdentifiers»
                       «identifier» = «fieldId.incrementAndGet»;
                   «ENDFOR»
                }
            '''
        }
        else
            resolve(element, context, container)
    }

    protected def dispatch String toText(AliasDeclaration element, EObject context,
        AbstractContainerDeclaration container, Counter id)
    {
        if (requiresNewMessageType(element.type.actualType))
            Names.plain(element).toFirstUpper + WRAPPER_SUFFIX
        else
            typedefTable.computeIfAbsent(element.name, [
                if (element.type.isSequenceType)
                    "repeated " + toText(element.type.ultimateType, element, container, new Counter)
                else
                    toText(element.type, element, container, new Counter)
            ])
    }

    protected def dispatch String toText(AbstractType element, EObject context, AbstractContainerDeclaration container,
        Counter id)
    {
        toText(element.actualType, context, container, id)
    }

    protected def dispatch String toText(PrimitiveType element, EObject context, AbstractContainerDeclaration container,
        Counter id)
    {
        id.incrementAndGet

        if (element.integerType !== null)
        {
            // Protobuf does not have 16 or 8 bit integer types, so we map them as int32
            switch element.integerType
            {
                case "int16":
                    "int32"
                case "byte":
                    "int32"
                default:
                    element.integerType
            }
        }
        else if (element.stringType !== null)
            "string"
        else if (element.floatingPointType !== null)
            element.floatingPointType
        else if (element.uuidType !== null)
            "bytes"
        else if (element.booleanType !== null)
            "bool"
        else if (element.charType !== null)
            "int32"
        else
            throw new IllegalArgumentException("Unknown PrimitiveType: " + element.class.toString)
    }

    protected static def boolean requiresNewMessageType(AbstractTypeReference element)
    {
        element instanceof TupleDeclaration ||
            (element instanceof SequenceDeclaration && (element as SequenceDeclaration).type.collectionType !== null)
    }

    protected def String makeSequence(AbstractTypeReference nestedType, boolean isFailable, EObject context,
        AbstractContainerDeclaration container, String protobufName, Counter id)
    {
        '''
            «IF isFailable»
                «val failableType = resolve(nestedType, context, container).alias(GeneratorUtil.asFailable(nestedType, container, qualifiedNameProvider))»
                «IF !(context instanceof InterfaceDeclaration || context instanceof AliasDeclaration)»repeated «failableType» «protobufName» = «id.incrementAndGet»;«ENDIF»
            «ELSE»
                repeated «toText(nestedType, context, container, new Counter)» «protobufName» = «id.incrementAndGet»;
            «ENDIF»
        '''
    }

    protected def String resolve(AbstractTypeReference object, EObject context, AbstractContainerDeclaration container)
    {
        if (object.isSequenceType)
            toText(object, context, container, new Counter)
        else
        {
            val actualType = object.ultimateType
            if (actualType.isPrimitive)
                toText(actualType, context, container, new Counter)
            else
                resolveNonPrimitiveType(actualType, context)
        }
    }

    private def resolveNonPrimitiveType(AbstractTypeReference actualType, EObject context)
    {
        val plainName = Names.plain(actualType)

        // first, check if we are within the same namespace
        val objectRoot = actualType.scopeDeterminant

        if (objectRoot == context.scopeDeterminant)
            plainName
        else
            resolveNonPrimitiveImportedType(objectRoot, plainName,
                new ParameterBundle.Builder().with(context.scopeDeterminant.moduleStack).with(ProjectType.PROTOBUF).
                    build, artifactNature)
    }

    private def resolveNonPrimitiveImportedType(AbstractContainerDeclaration referencedObjectContainer,
        String referencedObjectContainerPlainName, ParameterBundle referencingModuleParameterBundle,
        ArtifactNature artifactNature)
    {
        referencedFiles.add(referencedObjectContainer.importPath)

        val referencedModuleStack = referencedObjectContainer.moduleStack
        if (referencingModuleParameterBundle.moduleStack != referencedModuleStack)
        {
            projectReferences.computeIfAbsent(referencingModuleParameterBundle, [
                new HashSet<ParameterBundle>
            ]).add(ParameterBundle.createBuilder(referencedModuleStack).with(ProjectType.PROTOBUF).build)
        }

        referencedObjectContainer.getModuleName(artifactNature) + TransformType.PACKAGE.separator +
            referencedObjectContainerPlainName
    }

    def importPath(AbstractContainerDeclaration object)
    {
        makeProtobufPath(object, if (object instanceof InterfaceDeclaration)
            Names.plain(object)
        else
            Constants.FILE_NAME_TYPES, artifactNature, moduleStructureStrategy)
    }

}

class Counter
{
    var value = 0

    def int incrementAndGet()
    {
        value++
        value
    }
}
