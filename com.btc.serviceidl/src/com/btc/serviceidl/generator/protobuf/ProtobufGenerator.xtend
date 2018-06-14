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
import java.util.Optional
import java.util.concurrent.atomic.AtomicInteger
import org.eclipse.emf.ecore.EObject
import org.eclipse.emf.ecore.resource.Resource
import org.eclipse.xtext.generator.IFileSystemAccess
import org.eclipse.xtext.naming.IQualifiedNameProvider
import org.eclipse.xtext.scoping.IScopeProvider

import static extension com.btc.serviceidl.generator.common.FileTypeExtensions.*
import static extension com.btc.serviceidl.generator.common.GeneratorUtil.*
import static extension com.btc.serviceidl.util.Extensions.*
import static extension com.btc.serviceidl.util.Util.*
import com.google.common.base.CaseFormat

class ProtobufGenerator
{
   // global variables
   private var Resource resource
   private var IFileSystemAccess file_system_access
   private var IQualifiedNameProvider qualified_name_provider
   private var IScopeProvider scope_provider
   
   private var param_bundle = new ParameterBundle.Builder()
   
   val referenced_files = new HashSet<String>
   val generated_artifacts = new HashMap<EObject, String>
   val typedef_table = new HashMap<String, String>
   val cpp_project_references = new HashMap<String, HashMap<String, String>>
   val dotnet_project_references = new HashMap<String, HashMap<String, String>>
   
   def HashMap<String, HashMap<String, String>> getProjectReferences(ArtifactNature artifact_nature)
   {
      if (artifact_nature == ArtifactNature.CPP)
         return cpp_project_references
      else if (artifact_nature == ArtifactNature.DOTNET)
         return dotnet_project_references
      
      throw new IllegalArgumentException("Unsupported artifact nature for project references: " + artifact_nature)
   }
   
   def public Map<EObject, String> getGeneratedArtifacts()
   {
      return generated_artifacts
   }
   
   def public void doGenerate(Resource res, IFileSystemAccess fsa, IQualifiedNameProvider qnp, IScopeProvider sp)
   {
      resource = res
      file_system_access = fsa
      qualified_name_provider = qnp
      scope_provider = sp
      
      // handle all interfaces
      for (interface_declaration : resource.allContents.filter(InterfaceDeclaration).toIterable)
      {
         param_bundle = ParameterBundle.createBuilder(Util.getModuleStack(interface_declaration))
         param_bundle.reset(ProjectType.PROTOBUF)
         val artifact_name = interface_declaration.name

         generateProtobufFile(ArtifactNature.CPP, interface_declaration, artifact_name, generateInterface(ArtifactNature.CPP, interface_declaration))
         generateProtobufFile(ArtifactNature.JAVA, interface_declaration, artifact_name, generateInterface(ArtifactNature.JAVA, interface_declaration))
         generateProtobufFile(ArtifactNature.DOTNET, interface_declaration, artifact_name, generateInterface(ArtifactNature.DOTNET, interface_declaration))
         
         generated_artifacts.put(interface_declaration, artifact_name)
      }
      
      // handle all module contents (excluding interfaces)
      for (module : resource.allContents.filter(ModuleDeclaration).filter[!isVirtual].toIterable)
      {
         var module_contents = module.eContents.filter( [e | !(e instanceof ModuleDeclaration || e instanceof InterfaceDeclaration)])
         if ( !module_contents.empty )
         {
            param_bundle = ParameterBundle.createBuilder(Util.getModuleStack(module))
            param_bundle.reset(ProjectType.PROTOBUF)
            val artifact_name = Constants.FILE_NAME_TYPES
            
            generateProtobufFile(ArtifactNature.CPP, module, artifact_name, generateModuleContent(ArtifactNature.CPP, module, module_contents))
            generateProtobufFile(ArtifactNature.JAVA, module, artifact_name, generateModuleContent(ArtifactNature.JAVA, module, module_contents))
            generateProtobufFile(ArtifactNature.DOTNET, module, artifact_name, generateModuleContent(ArtifactNature.DOTNET, module, module_contents))
            
            generated_artifacts.put(module, artifact_name)
         }
      }
   }
   
   private def String generateModuleContent(ArtifactNature an, ModuleDeclaration module, Iterable<EObject> module_contents)
   {
      referenced_files.clear
      
      var file_body =
      '''
      «generateFailable(an, module)»
      «generateTypes(an, module, module.moduleComponents.filter[ e | !(e instanceof InterfaceDeclaration)].toList)»
      '''
      
      var file_header =
      '''
      «generatePackageName(an, module)»
      «generateImports(an, module)»
      '''
      
      return file_header + file_body
   }
   
   private def void generateProtobufFile(ArtifactNature an, EObject container, String artifact_name, String file_content)
   {
      param_bundle.reset(ProjectType.PROTOBUF)
      var project_path = "";
      // TODO this depends on the PRINS directory structure
      if (an == ArtifactNature.CPP)
         project_path += "modules" + Constants.SEPARATOR_FILE
      if (an == ArtifactNature.JAVA) // special directory structure according to Maven conventions
         project_path += getJavaProtoLocation(container)
      else
         project_path += GeneratorUtil.getTransformedModuleName(param_bundle.build, an, TransformType.FILE_SYSTEM)
         + Constants.SEPARATOR_FILE
         + Constants.PROTOBUF_GENERATION_DIRECTORY_NAME
         + Constants.SEPARATOR_FILE

      file_system_access.generateFile(project_path + artifact_name.proto, an.label, file_content)
   }
   
   private def String getJavaProtoLocation(EObject container)
   {
      qualified_name_provider.getFullyQualifiedName(container).toLowerCase
         + Constants.SEPARATOR_FILE
         + "src"
         + Constants.SEPARATOR_FILE
         + "main"
         + Constants.SEPARATOR_FILE
         + "proto"
         + Constants.SEPARATOR_FILE
   }
   
   private def String generateInterface(ArtifactNature an, InterfaceDeclaration interface_declaration)
   {
      var request_part_id = 1
      var response_part_id = 1

      referenced_files.clear

      var file_body =
      '''
      «generateFailable(an, interface_declaration)»
      «generateTypes(an, interface_declaration, interface_declaration.contains.toList)»
      
      message «Util.makeBasicMessageName(interface_declaration.name, Constants.PROTOBUF_REQUEST)»
      {
         «FOR function : interface_declaration.functions SEPARATOR System.lineSeparator»
         message «Util.makeBasicMessageName(function.name, Constants.PROTOBUF_REQUEST)»
         {
            «var field_id = new AtomicInteger»
            «FOR param : function.parameters.filter[direction == ParameterDirection.PARAM_IN]»
               «IF Util.isSequenceType(param.paramType)»
                  «makeSequence(an, Util.getUltimateType(param.paramType), Util.isFailable(param.paramType), param, interface_declaration, param.paramName, field_id)»
               «ELSE»
                  required «resolve(an, param.paramType, interface_declaration, interface_declaration)» «param.paramName.toLowerCase» = «field_id.incrementAndGet»;
               «ENDIF»
            «ENDFOR»
         }
         «ENDFOR»

         «FOR function : interface_declaration.functions»
            «val message_part = Util.makeBasicMessageName(function.name, Constants.PROTOBUF_REQUEST)»
            optional «message_part» «message_part.toLowerCase» = «request_part_id++»;
         «ENDFOR»
      }
      
      message «interface_declaration.name + "_" + Constants.PROTOBUF_RESPONSE»
      {
         «FOR function : interface_declaration.functions SEPARATOR System.lineSeparator»
         message «Util.makeBasicMessageName(function.name, Constants.PROTOBUF_RESPONSE)»
         {
            «var field_id = new AtomicInteger»
            «FOR param : function.parameters.filter[direction == ParameterDirection.PARAM_OUT]»
               «IF Util.isSequenceType(param.paramType)»
                  «val sequence = Util.tryGetSequence(param.paramType).get»
                  «toText(sequence, an, param, interface_declaration, field_id)»
               «ELSE»
                  required «resolve(an, param.paramType, interface_declaration, interface_declaration)» «param.paramName.toLowerCase» = «field_id.incrementAndGet»;
               «ENDIF»
            «ENDFOR»
            «generateReturnType(an, function, interface_declaration, interface_declaration, field_id)»
         }
         «ENDFOR»

         «FOR function : interface_declaration.functions»
            «val message_part = Util.makeBasicMessageName(function.name, Constants.PROTOBUF_RESPONSE)»
            optional «message_part» «message_part.toLowerCase» = «response_part_id++»;
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
   
   private def String generateFailable(ArtifactNature artifactNature, EObject container)
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
   
   private def String generatePackageName(ArtifactNature artifact_nature, EObject container)
   {
      '''
      syntax = "proto2";
      «IF artifact_nature == ArtifactNature.JAVA»
         package «MavenResolver.resolvePackage(container, Optional.of(ProjectType.PROTOBUF))»;         
      «ELSE»
         package «GeneratorUtil.getTransformedModuleName(param_bundle.build, artifact_nature, TransformType.PACKAGE)»;
      «ENDIF»
      '''
   }
   
   private def String generateImports(ArtifactNature artifact_nature, EObject container)
   {
      '''
      «FOR import_file : referenced_files»
         import "«import_file»";
      «ENDFOR»
      '''
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
               required «resolve(artifactNature, element, context, container)» «function.name.toLowerCase» = «id.incrementAndGet»;
            «ENDIF»
         «ENDIF»
      «ENDIF»
      '''
   }
   
   private def dispatch String toText(StructDeclaration element, ArtifactNature artifactNature, EObject context, EObject container, AtomicInteger id)
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
   
   private def dispatch String toText(ExceptionDeclaration element, ArtifactNature artifactNature, EObject context, EObject container, AtomicInteger id)
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
   
   private static def protobufName(MemberElementWrapper element)
   {
       // TODO why is toLowerCase required here?
       asProtobufName(element.name, CaseFormat.LOWER_UNDERSCORE).toLowerCase
   }
   
   private def dispatch String toText(MemberElementWrapper element, ArtifactNature artifactNature, EObject context, EObject container, AtomicInteger id)
   {
      '''
      «IF element.isOptional && !Util.isSequenceType(element.type)»
         optional «toText(element.type, artifactNature, element.type, container, new AtomicInteger)» «element.protobufName» = «id.incrementAndGet»;
      «ELSEIF Util.isSequenceType(element.type)»
         «makeSequence(artifactNature, Util.getUltimateType(element.type), Util.isFailable(element.type), element.type, container, element.protobufName, id)»
      «ELSEIF requiresNewMessageType(element.type)»
         «toText(element.type, artifactNature, element.type, container, id)»
      «ELSE»
         required «toText(element.type, artifactNature, element.type, container, new AtomicInteger)» «element.protobufName» = «id.incrementAndGet»;
      «ENDIF»
      '''
   }
   
   private def String makeSequence(ArtifactNature artifactNature, EObject nested_type, boolean is_failable, EObject context, EObject container, String protobufName, AtomicInteger id)
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
   
   private def dispatch String toText(SequenceDeclaration element, ArtifactNature artifactNature, EObject context, EObject container, AtomicInteger id)
   {
      '''«makeSequence(artifactNature, Util.getUltimateType(element.type), element.failable, context, container, Names.plain(context), id)»'''
   }
   
   private def dispatch String toText(TupleDeclaration element, ArtifactNature artifactNature, EObject context, EObject container, AtomicInteger id)
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
      «IF !(context instanceof SequenceDeclaration)»required «tuple_name» «Names.plain(context).toLowerCase» = «id.incrementAndGet»;«ENDIF»
      '''
   }
   
   private def dispatch String toText(ParameterElement element, ArtifactNature artifactNature, EObject context, EObject container, AtomicInteger id)
   {
      val sequence = Util.tryGetSequence(element)
      '''
      «IF sequence.present»
         «toText(sequence.get, artifactNature, element, container, id)»
      «ELSE»
         required «toText(element.paramType, artifactNature, element, container, new AtomicInteger)» «element.paramName.toLowerCase» = «id.incrementAndGet»;
      «ENDIF»
      '''
   }
   
   private def dispatch String toText(EnumDeclaration element, ArtifactNature artifactNature, EObject context, EObject container, AtomicInteger id)
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
   
   private def dispatch String toText(AliasDeclaration element, ArtifactNature artifactNature, EObject context, EObject container, AtomicInteger id)
   {
      if (requiresNewMessageType(element.type))
      {
         return Names.plain(element).toFirstUpper + "Wrapper"
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
  
         return type_name
      }
   }
   
   private def dispatch String toText(AbstractType element, ArtifactNature artifactNature, EObject context, EObject container, AtomicInteger id)
   {
      if (element.primitiveType !== null)
         return toText(element.primitiveType, artifactNature, context, container, id)
      else if (element.referenceType !== null)
         return toText(element.referenceType, artifactNature, context, container, id)
      else if (element.collectionType !== null)
         return toText(element.collectionType, artifactNature, context, container, id)
      
      throw new IllegalArgumentException("Unknown AbstractType: " + element.class.toString)
   }
   
   private def dispatch String toText(PrimitiveType element, ArtifactNature artifactNature, EObject context, EObject container, AtomicInteger id)
   {
      id.incrementAndGet
      
      if (element.integerType !== null)
      {
         // Protobuf does not have 16 or 8 bit integer types, so we map them as int32
         switch element.integerType
         {
         case "int16":
            return "int32"
         case "byte":
            return "int32"
         default:
            return element.integerType
         }
      }
      else if (element.stringType !== null)
         return "string"
      else if (element.floatingPointType !== null)
         return element.floatingPointType
      else if (element.uuidType !== null)
         return "bytes"
      else if (element.booleanType !== null)
         return "bool"
      else if (element.charType !== null)
         return "int32"

      throw new IllegalArgumentException("Unknown PrimitiveType: " + element.class.toString)
   }
   
   private def boolean requiresNewMessageType(EObject element)
   {
      return (element instanceof TupleDeclaration 
         || (element instanceof AbstractType && (element as AbstractType).collectionType !== null && requiresNewMessageType((element as AbstractType).collectionType))
         || (element instanceof SequenceDeclaration && (element as SequenceDeclaration).type.collectionType !== null)
      )
   }
   
   private def String resolve(ArtifactNature artifactNature, EObject object, EObject context, EObject container)
   {
      if (Util.isSequenceType(object))
         return toText(object, artifactNature, context, container, new AtomicInteger)
      
      val actual_type = Util.getUltimateType(object)
      if (Util.isPrimitive(actual_type))
         return toText(actual_type, artifactNature, context, container, new AtomicInteger)

      var plain_name = Names.plain(actual_type)
      
      // first, check if we are within the same namespace
      var object_root = Util.getScopeDeterminant(actual_type)
      var context_root = Util.getScopeDeterminant(context)
      
      if (object_root == context_root)
         return plain_name
      else
      {
         val temp_bundle = ParameterBundle.createBuilder(Util.getModuleStack(object_root)).with(ProjectType.PROTOBUF).build

         val root_path = GeneratorUtil.getTransformedModuleName(temp_bundle, artifactNature, TransformType.FILE_SYSTEM)
         
         var String referenced_project
         var String current_project
         
         if (artifactNature != ArtifactNature.JAVA)
         {
            referenced_project = GeneratorUtil.getTransformedModuleName(temp_bundle, artifactNature, TransformType.PACKAGE)
            current_project = GeneratorUtil.getTransformedModuleName(param_bundle.with(ProjectType.PROTOBUF).build, artifactNature, TransformType.PACKAGE)
         }
         else
         {
            referenced_project = MavenResolver.resolvePackage(object_root, Optional.of(ProjectType.PROTOBUF))
            current_project = MavenResolver.resolvePackage(context_root, Optional.of(ProjectType.PROTOBUF))
         }
         
         val result = referenced_project + TransformType.PACKAGE.separator + plain_name

         val import_path = makeImportPath(artifactNature, object_root, if (object_root instanceof InterfaceDeclaration) Names.plain(object_root) else Constants.FILE_NAME_TYPES )
         referenced_files.add(import_path)

         if (artifactNature != ArtifactNature.JAVA)
         {
            if (current_project != referenced_project)
            {
               val project_references = getProjectReferences(artifactNature)
               val project_path = "$(SolutionDir)" + ( if (artifactNature == ArtifactNature.DOTNET) "../" else "/" ) + root_path + "/" + referenced_project
               val HashMap<String, String> references = project_references.get(current_project) ?: new HashMap<String, String>
               references.put(referenced_project, project_path)
               project_references.put(current_project, references)
            }
         }
         
         return result
      }
   }
   
   private def String generateTypes(ArtifactNature artifactNature, EObject container, Collection<? extends EObject> contents)
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
   
   private def String makeImportPath(ArtifactNature artifact_nature, EObject container, String file_name)
    {
        if (artifact_nature == ArtifactNature.JAVA)
        {
            getJavaProtoLocation(container) + file_name.proto
        }
        else
        {
            val temp_bundle = ParameterBundle.createBuilder(container.moduleStack).with(ProjectType.PROTOBUF).
                build
            val root_path = GeneratorUtil.getTransformedModuleName(temp_bundle, artifact_nature, TransformType.FILE_SYSTEM)

            // TODO this depends on the PRINS module structure!
            (if (artifact_nature == ArtifactNature.CPP) "modules/" else "") + root_path + "/gen/" + file_name.proto
        }
    }
}
