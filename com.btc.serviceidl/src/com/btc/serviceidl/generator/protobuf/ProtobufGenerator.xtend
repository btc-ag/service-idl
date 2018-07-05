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
 * \file       ProtobufGenerator.xtend
 * 
 * \brief      Xtend generator for Google Protocol Buffers artifacts from an IDL
 */

package com.btc.serviceidl.generator.protobuf

import com.btc.serviceidl.generator.common.ArtifactNature
import com.btc.serviceidl.generator.common.GeneratorUtil
import com.btc.serviceidl.generator.common.Names
import com.btc.serviceidl.generator.common.ParameterBundle
import com.btc.serviceidl.generator.common.ProjectType
import com.btc.serviceidl.generator.common.TransformType
import com.btc.serviceidl.generator.cpp.IModuleStructureStrategy
import com.btc.serviceidl.generator.java.MavenResolver
import com.btc.serviceidl.idl.AbstractType
import com.btc.serviceidl.idl.AliasDeclaration
import com.btc.serviceidl.idl.EnumDeclaration
import com.btc.serviceidl.idl.ExceptionDeclaration
import com.btc.serviceidl.idl.FunctionDeclaration
import com.btc.serviceidl.idl.InterfaceDeclaration
import com.btc.serviceidl.idl.ModuleDeclaration
import com.btc.serviceidl.idl.ParameterDirection
import com.btc.serviceidl.idl.ParameterElement
import com.btc.serviceidl.idl.PrimitiveType
import com.btc.serviceidl.idl.SequenceDeclaration
import com.btc.serviceidl.idl.StructDeclaration
import com.btc.serviceidl.idl.TupleDeclaration
import com.btc.serviceidl.util.Constants
import com.btc.serviceidl.util.MemberElementWrapper
import com.btc.serviceidl.util.Util
import java.util.Collection
import java.util.HashMap
import java.util.HashSet
import java.util.Map
import java.util.Set
import java.util.concurrent.atomic.AtomicInteger
import org.eclipse.emf.ecore.EObject
import org.eclipse.emf.ecore.resource.Resource
import org.eclipse.xtend.lib.annotations.Accessors
import org.eclipse.xtext.generator.IFileSystemAccess
import org.eclipse.xtext.naming.IQualifiedNameProvider
import org.eclipse.xtext.scoping.IScopeProvider

import static extension com.btc.serviceidl.generator.protobuf.ProtobufGeneratorUtil.*
import static extension com.btc.serviceidl.util.Extensions.*
import static extension com.btc.serviceidl.util.Util.*

class ProtobufGenerator
{
   val Resource resource
   val IFileSystemAccess file_system_access
   val IQualifiedNameProvider qualified_name_provider
   val IScopeProvider scope_provider
   val IModuleStructureStrategy moduleStructureStrategy
      
   val generated_artifacts = new HashMap<EObject, String>
   val typedef_table = new HashMap<String, String>
   val allProjectReferences = new HashMap<ArtifactNature, Map<ParameterBundle, Set<ParameterBundle>>>
   
   def Map<ParameterBundle, Set<ParameterBundle>> getProjectReferences(ArtifactNature artifactNature)
    {
        allProjectReferences.computeIfAbsent(artifactNature, [new HashMap<ParameterBundle, Set<ParameterBundle>>])
    }
   
   def Map<EObject, String> getGeneratedArtifacts()
   {
      return generated_artifacts
   }
   
   new(Resource res, IFileSystemAccess fsa, IQualifiedNameProvider qnp, IScopeProvider sp,
        IModuleStructureStrategy moduleStructureStrategy)
   {
      resource = res
      file_system_access = fsa
      qualified_name_provider = qnp
      scope_provider = sp
      this.moduleStructureStrategy = moduleStructureStrategy
    }

    def void doGenerate(Iterable<ArtifactNature> languages) 
    {  
      // handle all interfaces
      for (interface_declaration : resource.allContents.filter(InterfaceDeclaration).toIterable)
      {
         val artifact_name = interface_declaration.name

         // TODO why is the proto file generated for each language?
         for (language : languages) 
             generateProtobufFile(language, interface_declaration, artifact_name, new InterfaceProtobufFileGenerator(qualified_name_provider, moduleStructureStrategy, getProjectReferences(language), typedef_table).generateInterface(language, interface_declaration))
         
         generated_artifacts.put(interface_declaration, artifact_name)
      }
      
      // handle all module contents (excluding interfaces)
      for (module : resource.allContents.filter(ModuleDeclaration).filter[!isVirtual].toIterable)
      {
         val module_contents = module.eContents.filter( [e | !(e instanceof ModuleDeclaration || e instanceof InterfaceDeclaration)])
         if ( !module_contents.empty )
         {
            val artifact_name = Constants.FILE_NAME_TYPES
            
            for (language : languages) 
                generateProtobufFile(language, module, artifact_name, new ModuleProtobufFileGenerator(qualified_name_provider, moduleStructureStrategy, getProjectReferences(language), typedef_table).generateModuleContent(language, module, module_contents))
            
            generated_artifacts.put(module, artifact_name)
         }
      }
   }
   
   private def void generateProtobufFile(ArtifactNature an, EObject container, String artifact_name,
        String file_content)
    {
        file_system_access.generateFile(
            makeProtobufPath(container, artifact_name, an, moduleStructureStrategy).toPortableString, an.label,
            file_content)
    }
      
   
}


@Accessors(NONE)
class ProtobufFileGeneratorBase
{
   val IQualifiedNameProvider qualified_name_provider
   val IModuleStructureStrategy moduleStructureStrategy
   val Map<ParameterBundle, Set<ParameterBundle>> projectReferences
   val Map<String, String> typedef_table // TODO is it correct to share this across files?
    
   val referenced_files = new HashSet<String>
    
   protected def String generateFailable(ArtifactNature artifactNature, EObject container)
   {
      val failable_types = GeneratorUtil.getFailableTypes(container)
      if (!failable_types.empty)
      {
         '''
         
         // local failable type wrappers
         «FOR failable_type : failable_types»
            «val failable_type_name = GeneratorUtil.asFailable(failable_type, container, qualified_name_provider)»
            «val basic_type_name = resolve(artifactNature, failable_type, container, container)»
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

   protected def String generateTypes(ArtifactNature artifactNature, EObject container, Collection<? extends EObject> contents)
   {
      '''
      «FOR typedef : contents.filter(AliasDeclaration).filter[requiresNewMessageType(type)] SEPARATOR System.lineSeparator»
         «toText(typedef.type, artifactNature, typedef, container, new AtomicInteger)»
      «ENDFOR»
      
      «FOR enum_declaration : contents.filter(typeof(EnumDeclaration)) SEPARATOR System.lineSeparator»
         «toText(enum_declaration, artifactNature, container, container, new AtomicInteger)»
      «ENDFOR»
      
      «FOR struct : contents.filter(StructDeclaration) SEPARATOR System.lineSeparator»
         «toText(struct, artifactNature, container, container, new AtomicInteger)»
      «ENDFOR»
      
      «FOR exception_declaration : contents.filter(ExceptionDeclaration) SEPARATOR System.lineSeparator»
         «toText(exception_declaration, artifactNature, container, container, new AtomicInteger)»
      «ENDFOR»
      '''
   }
   
   protected def String generatePackageName(ArtifactNature artifact_nature, EObject container)
   {
      '''
      syntax = "proto2";
      package «container.getModuleName(artifact_nature)»;
      '''
   }
   
   protected def String generateImports(ArtifactNature artifact_nature, EObject container)
   {
      '''
      «FOR import_file : referenced_files»
         import "«import_file»";
      «ENDFOR»
      '''
   }
   
   protected def dispatch String toText(StructDeclaration element, ArtifactNature artifactNature, EObject context, EObject container, AtomicInteger id)
   {
      if (context instanceof ModuleDeclaration || context instanceof InterfaceDeclaration || context instanceof StructDeclaration)
         '''
         message «element.name»
         {
            «var field_id = new AtomicInteger»
            «FOR type_declaration : element.typeDecls SEPARATOR System.lineSeparator»
               «toText(type_declaration, artifactNature, element, container, field_id)»
            «ENDFOR»
            
            «FOR member : element.allMembers SEPARATOR System.lineSeparator»
               «toText(member, artifactNature, element, container, field_id)»
            «ENDFOR»
         }
         '''
      else
      {
         id.incrementAndGet
         '''«resolve(artifactNature, element, context, container)»'''
      }
   }
   
   protected def dispatch String toText(ExceptionDeclaration element, ArtifactNature artifactNature, EObject context, EObject container, AtomicInteger id)
   {
      if (context instanceof ModuleDeclaration || context instanceof InterfaceDeclaration || context instanceof StructDeclaration)
         '''
         message «element.name»
         {
            «var field_id = new AtomicInteger»
            «FOR member : element.allMembers SEPARATOR System.lineSeparator»
               «toText(member, artifactNature, container, element, field_id)»
            «ENDFOR»
         }
         '''
      else
         '''«resolve(artifactNature, element, context, container)»'''
   }
   
   protected def dispatch String toText(MemberElementWrapper element, ArtifactNature artifactNature, EObject context, EObject container, AtomicInteger id)
   {
      '''
      «IF element.isOptional && !Util.isSequenceType(element.type)»
         optional «toText(element.type, artifactNature, element.type, container, new AtomicInteger)» «element.protoFileAttributeName» = «id.incrementAndGet»;
      «ELSEIF Util.isSequenceType(element.type)»
         «makeSequence(artifactNature, Util.getUltimateType(element.type), Util.isFailable(element.type), element.type, container, element.protoFileAttributeName, id)»
      «ELSEIF requiresNewMessageType(element.type)»
         «toText(element.type, artifactNature, element.type, container, id)»
      «ELSE»
         required «toText(element.type, artifactNature, element.type, container, new AtomicInteger)» «element.protoFileAttributeName» = «id.incrementAndGet»;
      «ENDIF»
      '''
   }
   
   protected def dispatch String toText(SequenceDeclaration element, ArtifactNature artifactNature, EObject context, EObject container, AtomicInteger id)
   {
      '''«makeSequence(artifactNature, Util.getUltimateType(element.type), element.failable, context, container, Names.plain(context).asProtoFileAttributeName, id)»'''
   }
   
   protected def dispatch String toText(TupleDeclaration element, ArtifactNature artifactNature, EObject context, EObject container, AtomicInteger id)
   {
      val tuple_name = ( if (context instanceof TupleDeclaration || context instanceof SequenceDeclaration) "Tuple" else Names.plain(context).toFirstUpper ) + "Wrapper"
      
      '''
      message «tuple_name»
      {
         «var element_id = new AtomicInteger»
         «FOR tuple_element : element.types»
            «IF requiresNewMessageType(tuple_element)»
               «toText(tuple_element, artifactNature, element, container, new AtomicInteger)»
            «ELSE»
               required «toText(tuple_element, artifactNature, element, container, element_id)» element«element_id» = «element_id»;
            «ENDIF»
         «ENDFOR»
      }
      «IF !(context instanceof SequenceDeclaration)»required «tuple_name» «Names.plain(context).asProtoFileAttributeName» = «id.incrementAndGet»;«ENDIF»
      '''
   }
   
   protected def dispatch String toText(ParameterElement element, ArtifactNature artifactNature, EObject context, EObject container, AtomicInteger id)
   {
      val sequence = Util.tryGetSequence(element)
      '''
      «IF sequence.present»
         «toText(sequence.get, artifactNature, element, container, id)»
      «ELSE»
         required «toText(element.paramType, artifactNature, element, container, new AtomicInteger)» «element.paramName.asProtoFileAttributeName» = «id.incrementAndGet»;
      «ENDIF»
      '''
   }
   
   protected def dispatch String toText(EnumDeclaration element, ArtifactNature artifactNature, EObject context, EObject container, AtomicInteger id)
   {
      if (context instanceof ModuleDeclaration || context instanceof InterfaceDeclaration || context instanceof StructDeclaration)
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
         '''«resolve(artifactNature, element, context, container)»'''
   }
   
   protected def dispatch String toText(AliasDeclaration element, ArtifactNature artifactNature, EObject context, EObject container, AtomicInteger id)
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
               type_name = "repeated " + toText(Util.getUltimateType(element.type), artifactNature, element, container, new AtomicInteger(0))
            else
               type_name = toText(element.type, artifactNature, element, container, new AtomicInteger(0))
            typedef_table.put(element.name, type_name)
         }
  
         type_name
      }
   }
   
   protected def dispatch String toText(AbstractType element, ArtifactNature artifactNature, EObject context, EObject container, AtomicInteger id)
   {
      if (element.primitiveType !== null)
         toText(element.primitiveType, artifactNature, context, container, id)
      else if (element.referenceType !== null)
         toText(element.referenceType, artifactNature, context, container, id)
      else if (element.collectionType !== null)
         toText(element.collectionType, artifactNature, context, container, id)
      else
         throw new IllegalArgumentException("Unknown AbstractType: " + element.class.toString)
   }
   
   protected def dispatch String toText(PrimitiveType element, ArtifactNature artifactNature, EObject context, EObject container, AtomicInteger id)
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

   protected def String makeSequence(ArtifactNature artifactNature, EObject nested_type, boolean is_failable, EObject context, EObject container, String protobufName, AtomicInteger id)
   {
      '''
      «IF is_failable»
         «val failable_type = resolve(artifactNature, nested_type, context, container).alias(GeneratorUtil.asFailable(nested_type, container, qualified_name_provider))»
         «IF !(context instanceof InterfaceDeclaration || context instanceof AliasDeclaration)»repeated «failable_type» «protobufName» = «id.incrementAndGet»;«ENDIF»
      «ELSE»
         repeated «toText(nested_type, artifactNature, context, container, new AtomicInteger)» «protobufName» = «id.incrementAndGet»;
      «ENDIF»
      '''
   }
   
   protected def String resolve(ArtifactNature artifactNature, EObject object, EObject context, EObject container)
    {
        if (object.isSequenceType)
            toText(object, artifactNature, context, container, new AtomicInteger)
        else
        {
            val actual_type = object.ultimateType
            if (actual_type.isPrimitive)
                toText(actual_type, artifactNature, context, container, new AtomicInteger)
            else
                resolveNonPrimitiveType(actual_type, artifactNature, context)
        }
    }
    
    private def resolveNonPrimitiveType(EObject actual_type, ArtifactNature artifactNature, EObject context)
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
        referenced_files.add(referencedObjectContainer.importPath(artifactNature).toPortableString)

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

    private static def getModuleName(EObject object_root, ArtifactNature artifactNature)
    {
        if (artifactNature != ArtifactNature.JAVA)
            GeneratorUtil.getTransformedModuleName(ParameterBundle.createBuilder(object_root.moduleStack).with(
                ProjectType.PROTOBUF).build, artifactNature, TransformType.PACKAGE)
        else
            MavenResolver.makePackageId(object_root, ProjectType.PROTOBUF)
    }

    def importPath(EObject object, ArtifactNature artifactNature)
    {
        makeProtobufPath(object, if (object instanceof InterfaceDeclaration)
            Names.plain(object)
        else
            Constants.FILE_NAME_TYPES, artifactNature, moduleStructureStrategy)
    }
   
}

@Accessors(NONE)
final class ModuleProtobufFileGenerator extends ProtobufFileGeneratorBase
{
   def String generateModuleContent(ArtifactNature an, ModuleDeclaration module, Iterable<EObject> module_contents)
   {
      val file_body =
      '''
      «generateFailable(an, module)»
      «generateTypes(an, module, module.moduleComponents.filter[ e | !(e instanceof InterfaceDeclaration)].toList)»
      '''
      
      val file_header =
      '''
      «generatePackageName(an, module)»
      «generateImports(an, module)»
      '''
      
      return file_header + file_body
   }
   
    
}

@Accessors(NONE)
final class InterfaceProtobufFileGenerator extends ProtobufFileGeneratorBase
{
   def String generateInterface(ArtifactNature an, InterfaceDeclaration interface_declaration)
   {
      var request_part_id = 1
      var response_part_id = 1

      var file_body =
      '''
      «generateFailable(an, interface_declaration)»
      «generateTypes(an, interface_declaration, interface_declaration.contains.toList)»
      
      message «interface_declaration.name.asRequest»
      {
         «FOR function : interface_declaration.functions SEPARATOR System.lineSeparator»
         message «function.name.asRequest»
         {
            «var field_id = new AtomicInteger»
            «FOR param : function.parameters.filter[direction == ParameterDirection.PARAM_IN]»
               «IF Util.isSequenceType(param.paramType)»
                  «makeSequence(an, Util.getUltimateType(param.paramType), Util.isFailable(param.paramType), param, interface_declaration, param.paramName.asProtoFileAttributeName, field_id)»
               «ELSE»
                  required «resolve(an, param.paramType, interface_declaration, interface_declaration)» «param.paramName.asProtoFileAttributeName» = «field_id.incrementAndGet»;
               «ENDIF»
            «ENDFOR»
         }
         «ENDFOR»

         «FOR function : interface_declaration.functions»
            «val message_part = function.name.asRequest»
            optional «message_part» «message_part.asProtoFileAttributeName» = «request_part_id++»;
         «ENDFOR»
      }
      
      message «interface_declaration.name.asResponse»
      {
         «FOR function : interface_declaration.functions SEPARATOR System.lineSeparator»
         message «function.name.asResponse»
         {
            «var field_id = new AtomicInteger»
            «FOR param : function.parameters.filter[direction == ParameterDirection.PARAM_OUT]»
               «IF Util.isSequenceType(param.paramType)»
                  «val sequence = Util.tryGetSequence(param.paramType).get»
                  «toText(sequence, an, param, interface_declaration, field_id)»
               «ELSE»
                  required «resolve(an, param.paramType, interface_declaration, interface_declaration)» «param.paramName.asProtoFileAttributeName» = «field_id.incrementAndGet»;
               «ENDIF»
            «ENDFOR»
            «generateReturnType(an, function, interface_declaration, interface_declaration, field_id)»
         }
         «ENDFOR»

         «FOR function : interface_declaration.functions»
            «val message_part = function.name.asResponse»
            optional «message_part» «message_part.asProtoFileAttributeName» = «response_part_id++»;
         «ENDFOR»
      }
      '''
      
      var file_header =
      '''
      «generatePackageName(an, interface_declaration)»
      «generateImports(an, interface_declaration)»
      '''
      
      return file_header + file_body
   }
   
   private def String generateReturnType(ArtifactNature artifactNature, FunctionDeclaration function, EObject context, EObject container, AtomicInteger id)
   {
      val element = function.returnedType
      '''
      «IF !element.isVoid»
         «IF requiresNewMessageType(element)»
            «toText(element, artifactNature, function, container, id)»
         «ELSE»
            «IF Util.isSequenceType(element)»
               «toText(element, artifactNature, function, container, id)»
            «ELSE»
               required «resolve(artifactNature, element, context, container)» «function.name.asProtoFileAttributeName» = «id.incrementAndGet»;
            «ENDIF»
         «ENDIF»
      «ENDIF»
      '''
   }
   
}
