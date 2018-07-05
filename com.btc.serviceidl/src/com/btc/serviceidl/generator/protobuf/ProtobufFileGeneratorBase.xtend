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
import com.btc.serviceidl.idl.AbstractType
import com.btc.serviceidl.idl.AliasDeclaration
import com.btc.serviceidl.idl.EnumDeclaration
import com.btc.serviceidl.idl.ExceptionDeclaration
import com.btc.serviceidl.idl.InterfaceDeclaration
import com.btc.serviceidl.idl.ModuleDeclaration
import com.btc.serviceidl.idl.ParameterElement
import com.btc.serviceidl.idl.PrimitiveType
import com.btc.serviceidl.idl.SequenceDeclaration
import com.btc.serviceidl.idl.StructDeclaration
import com.btc.serviceidl.idl.TupleDeclaration
import com.btc.serviceidl.util.Constants
import com.btc.serviceidl.util.MemberElementWrapper
import com.btc.serviceidl.util.Util
import java.util.Collection
import java.util.HashSet
import java.util.Map
import java.util.Set
import java.util.concurrent.atomic.AtomicInteger
import org.eclipse.emf.ecore.EObject
import org.eclipse.xtend.lib.annotations.Accessors
import org.eclipse.xtext.naming.IQualifiedNameProvider

import static extension com.btc.serviceidl.generator.protobuf.ProtobufGeneratorUtil.*
import static extension com.btc.serviceidl.util.Extensions.*
import static extension com.btc.serviceidl.util.Util.*

@Accessors(NONE)
class ProtobufFileGeneratorBase
{
    val IQualifiedNameProvider qualified_name_provider
    val IModuleStructureStrategy moduleStructureStrategy
    val Map<ParameterBundle, Set<ParameterBundle>> projectReferences
    val Map<String, String> typedef_table // TODO is it correct to share this across files?
    val ArtifactNature artifactNature
    val referenced_files = new HashSet<String>

    protected def String generateFailable(EObject container)
    {
        val failable_types = GeneratorUtil.getFailableTypes(container)
        if (!failable_types.empty)
        {
            '''
                
                // local failable type wrappers
                «FOR failable_type : failable_types»
                    «val failable_type_name = GeneratorUtil.asFailable(failable_type, container, qualified_name_provider)»
                    «val basic_type_name = resolve(failable_type, container, container)»
                    message «failable_type_name»
                    {
                       // NOK: exception is set
                       optional string exception  = 1;
                       optional string message    = 2;
                       optional string stacktrace = 3;
                       
                       // OK: value is set
                       optional «basic_type_name» value = 4;
                    }
                «ENDFOR»
            '''
        }
    }

    protected def String generateTypes(EObject container, Collection<? extends EObject> contents)
    {
        '''
            «FOR typedef : contents.filter(AliasDeclaration).filter[requiresNewMessageType(type)] SEPARATOR System.lineSeparator»
                «toText(typedef.type, typedef, container, new AtomicInteger)»
            «ENDFOR»
            
            «FOR enum_declaration : contents.filter(typeof(EnumDeclaration)) SEPARATOR System.lineSeparator»
                «toText(enum_declaration, container, container, new AtomicInteger)»
            «ENDFOR»
            
            «FOR struct : contents.filter(StructDeclaration) SEPARATOR System.lineSeparator»
                «toText(struct, container, container, new AtomicInteger)»
            «ENDFOR»
            
            «FOR exception_declaration : contents.filter(ExceptionDeclaration) SEPARATOR System.lineSeparator»
                «toText(exception_declaration, container, container, new AtomicInteger)»
            «ENDFOR»
        '''
    }

    protected def String generatePackageName(EObject container)
    {
        '''
            syntax = "proto2";
            package «container.getModuleName(artifactNature)»;
        '''
    }

    protected def String generateImports(EObject container)
    {
        '''
            «FOR import_file : referenced_files»
                import "«import_file»";
            «ENDFOR»
        '''
    }

    protected def dispatch String toText(StructDeclaration element, EObject context, EObject container,
        AtomicInteger id)
    {
        if (context instanceof ModuleDeclaration || context instanceof InterfaceDeclaration ||
            context instanceof StructDeclaration)
            '''
                message «element.name»
                {
                   «var field_id = new AtomicInteger»
                   «FOR type_declaration : element.typeDecls SEPARATOR System.lineSeparator»
                       «toText(type_declaration, element, container, field_id)»
                   «ENDFOR»
                   
                   «FOR member : element.allMembers SEPARATOR System.lineSeparator»
                       «toText(member, element, container, field_id)»
                   «ENDFOR»
                }
            '''
        else
        {
            id.incrementAndGet
            '''«resolve(element, context, container)»'''
        }
    }

    protected def dispatch String toText(ExceptionDeclaration element, EObject context, EObject container,
        AtomicInteger id)
    {
        if (context instanceof ModuleDeclaration || context instanceof InterfaceDeclaration ||
            context instanceof StructDeclaration)
            '''
                message «element.name»
                {
                   «var field_id = new AtomicInteger»
                   «FOR member : element.allMembers SEPARATOR System.lineSeparator»
                       «toText(member, container, element, field_id)»
                   «ENDFOR»
                }
            '''
        else
            '''«resolve(element, context, container)»'''
    }

    protected def dispatch String toText(MemberElementWrapper element, EObject context, EObject container,
        AtomicInteger id)
    {
        '''
            «IF element.isOptional && !Util.isSequenceType(element.type)»
                optional «toText(element.type, element.type, container, new AtomicInteger)» «element.protoFileAttributeName» = «id.incrementAndGet»;
            «ELSEIF Util.isSequenceType(element.type)»
                «makeSequence(Util.getUltimateType(element.type), Util.isFailable(element.type), element.type, container, element.protoFileAttributeName, id)»
            «ELSEIF requiresNewMessageType(element.type)»
                «toText(element.type, element.type, container, id)»
            «ELSE»
                required «toText(element.type, element.type, container, new AtomicInteger)» «element.protoFileAttributeName» = «id.incrementAndGet»;
            «ENDIF»
        '''
    }

    protected def dispatch String toText(SequenceDeclaration element, EObject context, EObject container,
        AtomicInteger id)
    {
        '''«makeSequence(Util.getUltimateType(element.type), element.failable, context, container, Names.plain(context).asProtoFileAttributeName, id)»'''
    }

    protected def dispatch String toText(TupleDeclaration element, EObject context, EObject container, AtomicInteger id)
    {
        val tuple_name = ( if (context instanceof TupleDeclaration ||
            context instanceof SequenceDeclaration) "Tuple" else Names.plain(context).toFirstUpper ) + "Wrapper"

        '''
            message «tuple_name»
            {
               «var element_id = new AtomicInteger»
               «FOR tuple_element : element.types»
                   «IF requiresNewMessageType(tuple_element)»
                       «toText(tuple_element, element, container, new AtomicInteger)»
                   «ELSE»
                       required «toText(tuple_element, element, container, element_id)» element«element_id» = «element_id»;
                   «ENDIF»
               «ENDFOR»
            }
            «IF !(context instanceof SequenceDeclaration)»required «tuple_name» «Names.plain(context).asProtoFileAttributeName» = «id.incrementAndGet»;«ENDIF»
        '''
    }

    protected def dispatch String toText(ParameterElement element, EObject context, EObject container, AtomicInteger id)
    {
        val sequence = Util.tryGetSequence(element)
        '''
            «IF sequence.present»
                «toText(sequence.get, element, container, id)»
            «ELSE»
                required «toText(element.paramType, element, container, new AtomicInteger)» «element.protoFileAttributeName» = «id.incrementAndGet»;
            «ENDIF»
        '''
    }

    protected def dispatch String toText(EnumDeclaration element, EObject context, EObject container, AtomicInteger id)
    {
        if (context instanceof ModuleDeclaration || context instanceof InterfaceDeclaration ||
            context instanceof StructDeclaration)
        {
            var field_id = new AtomicInteger
            '''
                enum «element.name»
                {
                   «FOR identifier : element.containedIdentifiers»
                       «identifier» = «field_id.incrementAndGet»;
                   «ENDFOR»
                }
            '''
        }
        else
            '''«resolve(element, context, container)»'''
    }

    protected def dispatch String toText(AliasDeclaration element, EObject context, EObject container, AtomicInteger id)
    {
        if (requiresNewMessageType(element.type))
        {
            Names.plain(element).toFirstUpper + "Wrapper"
        }
        else
        {
            var type_name = typedef_table.get(element.name)

            // alias not yet resolve - do it now!
            if (type_name === null)
            {
                if (Util.isSequenceType(element.type))
                    type_name = "repeated " + toText(Util.getUltimateType(element.type), element, container,
                        new AtomicInteger(0))
                else
                    type_name = toText(element.type, element, container, new AtomicInteger(0))
                typedef_table.put(element.name, type_name)
            }

            type_name
        }
    }

    protected def dispatch String toText(AbstractType element, EObject context, EObject container, AtomicInteger id)
    {
        if (element.primitiveType !== null)
            toText(element.primitiveType, context, container, id)
        else if (element.referenceType !== null)
            toText(element.referenceType, context, container, id)
        else if (element.collectionType !== null)
            toText(element.collectionType, context, container, id)
        else
            throw new IllegalArgumentException("Unknown AbstractType: " + element.class.toString)
    }

    protected def dispatch String toText(PrimitiveType element, EObject context, EObject container, AtomicInteger id)
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

    protected static def boolean requiresNewMessageType(EObject element)
    {
        element instanceof TupleDeclaration ||
            (element instanceof AbstractType && (element as AbstractType).collectionType !== null &&
                requiresNewMessageType((element as AbstractType).collectionType)) ||
            (element instanceof SequenceDeclaration && (element as SequenceDeclaration).type.collectionType !== null)
    }

    protected def String makeSequence(EObject nested_type, boolean is_failable, EObject context, EObject container,
        String protobufName, AtomicInteger id)
    {
        '''
            «IF is_failable»
                «val failable_type = resolve(nested_type, context, container).alias(GeneratorUtil.asFailable(nested_type, container, qualified_name_provider))»
                «IF !(context instanceof InterfaceDeclaration || context instanceof AliasDeclaration)»repeated «failable_type» «protobufName» = «id.incrementAndGet»;«ENDIF»
            «ELSE»
                repeated «toText(nested_type, context, container, new AtomicInteger)» «protobufName» = «id.incrementAndGet»;
            «ENDIF»
        '''
    }

    protected def String resolve(EObject object, EObject context, EObject container)
    {
        if (object.isSequenceType)
            toText(object, context, container, new AtomicInteger)
        else
        {
            val actual_type = object.ultimateType
            if (actual_type.isPrimitive)
                toText(actual_type, context, container, new AtomicInteger)
            else
                resolveNonPrimitiveType(actual_type, context)
        }
    }

    private def resolveNonPrimitiveType(EObject actual_type, EObject context)
    {
        var plain_name = Names.plain(actual_type)

        // first, check if we are within the same namespace
        var object_root = actual_type.scopeDeterminant

        if (object_root == context.scopeDeterminant)
            plain_name
        else
            resolveNonPrimitiveImportedType(object_root, plain_name,
                new ParameterBundle.Builder().with(context.moduleStack).with(ProjectType.PROTOBUF).build,
                artifactNature)
    }

    private def resolveNonPrimitiveImportedType(EObject referencedObjectContainer,
        String referencedObjectContainerPlainName, ParameterBundle referencingModuleParameterBundle,
        ArtifactNature artifactNature)
    {
        referenced_files.add(referencedObjectContainer.importPath.toPortableString)

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

    def importPath(EObject object)
    {
        makeProtobufPath(object, if (object instanceof InterfaceDeclaration)
            Names.plain(object)
        else
            Constants.FILE_NAME_TYPES, artifactNature, moduleStructureStrategy)
    }

}
