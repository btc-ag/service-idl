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

package com.btc.cab.servicecomm.prodigd.generator.protobuf

import org.eclipse.emf.ecore.resource.Resource
import org.eclipse.xtext.generator.IFileSystemAccess
import org.eclipse.xtext.naming.IQualifiedNameProvider
import org.eclipse.xtext.scoping.IScopeProvider
import com.btc.cab.servicecomm.prodigd.idl.InterfaceDeclaration
import com.btc.cab.servicecomm.prodigd.generator.common.ArtifactNature
import com.btc.cab.servicecomm.prodigd.generator.common.Constants
import com.btc.cab.servicecomm.prodigd.generator.common.Util
import com.btc.cab.servicecomm.prodigd.generator.common.TransformType
import com.btc.cab.servicecomm.prodigd.generator.common.ProjectType
import com.btc.cab.servicecomm.prodigd.idl.FunctionDeclaration
import com.btc.cab.servicecomm.prodigd.idl.SequenceDeclaration
import com.btc.cab.servicecomm.prodigd.idl.StructDeclaration
import com.btc.cab.servicecomm.prodigd.idl.AbstractType
import com.btc.cab.servicecomm.prodigd.idl.PrimitiveType
import com.btc.cab.servicecomm.prodigd.idl.EnumDeclaration
import com.btc.cab.servicecomm.prodigd.idl.AliasDeclaration
import com.btc.cab.servicecomm.prodigd.idl.ParameterDirection
import org.eclipse.emf.ecore.EObject
import com.btc.cab.servicecomm.prodigd.idl.TupleDeclaration
import com.btc.cab.servicecomm.prodigd.idl.ParameterElement
import com.btc.cab.servicecomm.prodigd.generator.common.Names
import java.util.concurrent.atomic.AtomicInteger
import com.btc.cab.servicecomm.prodigd.idl.ModuleDeclaration
import com.btc.cab.servicecomm.prodigd.idl.ExceptionDeclaration
import java.util.HashSet
import java.util.HashMap
import com.btc.cab.servicecomm.prodigd.generator.common.ParameterBundle
import static extension com.btc.cab.servicecomm.prodigd.generator.common.Extensions.*
import static extension com.btc.cab.servicecomm.prodigd.generator.common.FileTypeExtensions.*
import java.util.Map
import java.util.Collection
import com.btc.cab.servicecomm.prodigd.generator.common.MemberElementWrapper
import com.btc.cab.servicecomm.prodigd.generator.java.MavenResolver
import java.util.Optional

class ProtobufGenerator
{
   // global variables
   private var Resource resource
   private var IFileSystemAccess file_system_access
   private var IQualifiedNameProvider qualified_name_provider
   private var IScopeProvider scope_provider
   
   private var param_bundle = new ParameterBundle.Builder()
   
   private val referenced_files = new HashSet<String>
   private val generated_artifacts = new HashMap<EObject, String>
   private val typedef_table = new HashMap<String, String>
   private val cpp_project_references = new HashMap<String, HashMap<String, String>>
   private val dotnet_project_references = new HashMap<String, HashMap<String, String>>
   
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
   
   def private String generateModuleContent(ArtifactNature an, ModuleDeclaration module, Iterable<EObject> module_contents)
   {
      referenced_files.clear
      param_bundle.reset(an)
      
      var file_body =
      '''
      «generateFailable(module)»
      «generateTypes(module, module.moduleComponents.filter[ e | !(e instanceof InterfaceDeclaration)].toList)»
      '''
      
      var file_header =
      '''
      «generatePackageName(an, module)»
      «generateImports(an, module)»
      '''
      
      return file_header + file_body
   }
   
   def private void generateProtobufFile(ArtifactNature an, EObject container, String artifact_name, String file_content)
   {
      param_bundle.reset(ProjectType.PROTOBUF)
      param_bundle.reset(an)
      var project_path = param_bundle.artifactNature.label + Constants.SEPARATOR_FILE;
      if (param_bundle.artifactNature == ArtifactNature.JAVA) // special directory structure according to Maven conventions
         project_path += getJavaProtoLocation(container)
      else
         project_path += Util.transform(param_bundle.with(TransformType.FILE_SYSTEM).build)
         + Constants.SEPARATOR_FILE
         + "gen"
         + Constants.SEPARATOR_FILE

      file_system_access.generateFile(project_path + artifact_name.proto, file_content)
   }
   
   def private String getJavaProtoLocation(EObject container)
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
   
   def private String generateInterface(ArtifactNature an, InterfaceDeclaration interface_declaration)
   {
      var request_part_id = 1
      var response_part_id = 1

      referenced_files.clear
      param_bundle.reset(an)

      var file_body =
      '''
      «generateFailable(interface_declaration)»
      «generateTypes(interface_declaration, interface_declaration.contains.toList)»
      
      message «Util.makeBasicMessageName(interface_declaration.name, Constants.PROTOBUF_REQUEST)»
      {
         «FOR function : interface_declaration.functions SEPARATOR System.lineSeparator»
         message «Util.makeBasicMessageName(function.name, Constants.PROTOBUF_REQUEST)»
         {
            «var field_id = new AtomicInteger»
            «FOR param : function.parameters.filter[direction == ParameterDirection.PARAM_IN]»
               «IF Util.isSequenceType(param.paramType)»
                  «makeSequence(Util.getUltimateType(param.paramType), Util.isFailable(param.paramType), param, interface_declaration, param.paramName, field_id)»
               «ELSE»
                  required «resolve(param.paramType, interface_declaration, interface_declaration)» «param.paramName.toLowerCase» = «field_id.incrementAndGet»;
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
                  «toText(sequence, param, interface_declaration, field_id)»
               «ELSE»
                  required «resolve(param.paramType, interface_declaration, interface_declaration)» «param.paramName.toLowerCase» = «field_id.incrementAndGet»;
               «ENDIF»
            «ENDFOR»
            «generateReturnType(function, interface_declaration, interface_declaration, field_id)»
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
   
   def private String generateFailable(EObject container)
   {
      val failable_types = Util.getFailableTypes(container)
      if (!failable_types.empty)
      {
         '''
         
         // local failable type wrappers
         «FOR failable_type : failable_types»
            «val failable_type_name = Util.asFailable(failable_type, container, qualified_name_provider)»
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
   
   def private String generatePackageName(ArtifactNature artifact_nature, EObject container)
   {
      '''
      syntax = "proto2";
      «IF artifact_nature == ArtifactNature.JAVA»
         package «MavenResolver.resolvePackage(container, Optional.of(ProjectType.PROTOBUF))»;
      «ELSE»
         package «Util.transform(param_bundle.with(TransformType.PACKAGE).build)»;
      «ENDIF»
      '''
   }
   
   def private String generateImports(ArtifactNature artifact_nature, EObject container)
   {
      '''
      «FOR import_file : referenced_files»
         import "«import_file»";
      «ENDFOR»
      '''
   }
   
   def private String generateReturnType(FunctionDeclaration function, EObject context, EObject container, AtomicInteger id)
   {
      val element = function.returnedType
      '''
      «IF !element.isVoid»
         «IF requiresNewMessageType(element)»
            «toText(element, function, container, id)»
         «ELSE»
            «IF Util.isSequenceType(element)»
               «toText(element, function, container, id)»
            «ELSE»
               required «resolve(element, context, container)» «function.name.toLowerCase» = «id.incrementAndGet»;
            «ENDIF»
         «ENDIF»
      «ENDIF»
      '''
   }
   
   def private dispatch String toText(StructDeclaration element, EObject context, EObject container, AtomicInteger id)
   {
      if (context instanceof ModuleDeclaration || context instanceof InterfaceDeclaration || context instanceof StructDeclaration)
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
   
   def private dispatch String toText(ExceptionDeclaration element, EObject context, EObject container, AtomicInteger id)
   {
      if (context instanceof ModuleDeclaration || context instanceof InterfaceDeclaration || context instanceof StructDeclaration)
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
   
   def private dispatch String toText(MemberElementWrapper element, EObject context, EObject container, AtomicInteger id)
   {
      '''
      «IF element.isOptional && !Util.isSequenceType(element.type)»
         optional «toText(element.type, element.type, container, new AtomicInteger)» «element.name.toLowerCase» = «id.incrementAndGet»;
      «ELSEIF Util.isSequenceType(element.type)»
         «makeSequence(Util.getUltimateType(element.type), Util.isFailable(element.type), element.type, container, element.name, id)»
      «ELSEIF requiresNewMessageType(element.type)»
         «toText(element.type, element.type, container, id)»
      «ELSE»
         required «toText(element.type, element.type, container, new AtomicInteger)» «element.name.toLowerCase» = «id.incrementAndGet»;
      «ENDIF»
      '''
   }
   
   def private String makeSequence(EObject nested_type, boolean is_failable, EObject context, EObject container, String name, AtomicInteger id)
   {
      '''
      «IF is_failable»
         «val failable_type = resolve(nested_type, context, container).alias(Util.asFailable(nested_type, container, qualified_name_provider))»
         «IF !(context instanceof InterfaceDeclaration || context instanceof AliasDeclaration)»repeated «failable_type» «name.toLowerCase» = «id.incrementAndGet»;«ENDIF»
      «ELSE»
         repeated «toText(nested_type, context, container, new AtomicInteger)» «name.toLowerCase» = «id.incrementAndGet»;
      «ENDIF»
      '''
   }
   
   def private dispatch String toText(SequenceDeclaration element, EObject context, EObject container, AtomicInteger id)
   {
      '''«makeSequence(Util.getUltimateType(element.type), element.failable, context, container, Names.plain(context), id)»'''
   }
   
   def private dispatch String toText(TupleDeclaration element, EObject context, EObject container, AtomicInteger id)
   {
      val tuple_name = ( if (context instanceof TupleDeclaration || context instanceof SequenceDeclaration) "Tuple" else Names.plain(context).toFirstUpper ) + "Wrapper"
      
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
      «IF !(context instanceof SequenceDeclaration)»required «tuple_name» «Names.plain(context).toLowerCase» = «id.incrementAndGet»;«ENDIF»
      '''
   }
   
   def private dispatch String toText(ParameterElement element, EObject context, EObject container, AtomicInteger id)
   {
      val sequence = Util.tryGetSequence(element)
      '''
      «IF sequence.present»
         «toText(sequence.get, element, container, id)»
      «ELSE»
         required «toText(element.paramType, element, container, new AtomicInteger)» «element.paramName.toLowerCase» = «id.incrementAndGet»;
      «ENDIF»
      '''
   }
   
   def private dispatch String toText(EnumDeclaration element, EObject context, EObject container, AtomicInteger id)
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
         '''«resolve(element, context, container)»'''
   }
   
   def private dispatch String toText(AliasDeclaration element, EObject context, EObject container, AtomicInteger id)
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
               type_name = "repeated " + toText(Util.getUltimateType(element.type), element, container, new AtomicInteger(0))
            else
               type_name = toText(element.type, element, container, new AtomicInteger(0))
            typedef_table.put(element.name, type_name)
         }
  
         return type_name
      }
   }
   
   def private dispatch String toText(AbstractType element, EObject context, EObject container, AtomicInteger id)
   {
      if (element.primitiveType !== null)
         return toText(element.primitiveType, context, container, id)
      else if (element.referenceType !== null)
         return toText(element.referenceType, context, container, id)
      else if (element.collectionType !== null)
         return toText(element.collectionType, context, container, id)
      
      throw new IllegalArgumentException("Unknown AbstractType: " + element.class.toString)
   }
   
   def private dispatch String toText(PrimitiveType element, EObject context, EObject container, AtomicInteger id)
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
   
   def private boolean requiresNewMessageType(EObject element)
   {
      return (element instanceof TupleDeclaration 
         || (element instanceof AbstractType && (element as AbstractType).collectionType !== null && requiresNewMessageType((element as AbstractType).collectionType))
         || (element instanceof SequenceDeclaration && (element as SequenceDeclaration).type.collectionType !== null)
      )
   }
   
   def private String resolve(EObject object, EObject context, EObject container)
   {
      if (Util.isSequenceType(object))
         return toText(object, context, container, new AtomicInteger)
      
      val actual_type = Util.getUltimateType(object)
      if (Util.isPrimitive(actual_type))
         return toText(actual_type, context, container, new AtomicInteger)

      var plain_name = Names.plain(actual_type)
      
      // first, check if we are within the same namespace
      var object_root = Util.getScopeDeterminant(actual_type)
      var context_root = Util.getScopeDeterminant(context)
      
      if (object_root == context_root)
         return plain_name
      else
      {
         val builder = ParameterBundle.createBuilder(Util.getModuleStack(object_root)).with(ProjectType.PROTOBUF).reset(param_bundle.artifactNature)

         val root_path = Util.transform(builder.with(TransformType.FILE_SYSTEM).build)
         
         var String referenced_project
         var String current_project
         
         if (param_bundle.artifactNature != ArtifactNature.JAVA)
         {
            referenced_project = Util.transform(builder.with(ProjectType.PROTOBUF).with(TransformType.PACKAGE).build)
            current_project = Util.transform(param_bundle.with(ProjectType.PROTOBUF).with(TransformType.PACKAGE).build)
         }
         else
         {
            referenced_project = MavenResolver.resolvePackage(object_root, Optional.of(ProjectType.PROTOBUF))
            current_project = MavenResolver.resolvePackage(context_root, Optional.of(ProjectType.PROTOBUF))
         }
         
         val result = referenced_project + TransformType.PACKAGE.separator + plain_name

         val import_path = makeImportPath(param_bundle.artifactNature, object_root, if (object_root instanceof InterfaceDeclaration) Names.plain(object_root) else Constants.FILE_NAME_TYPES )
         referenced_files.add(import_path)

         if (param_bundle.artifactNature != ArtifactNature.JAVA)
         {
            if (current_project != referenced_project)
            {
               val project_references = getProjectReferences(param_bundle.artifactNature)
               val project_path = "$(SolutionDir)" + ( if (param_bundle.artifactNature == ArtifactNature.DOTNET) "../" else "/" ) + root_path + "/" + referenced_project
               val HashMap<String, String> references = project_references.get(current_project) ?: new HashMap<String, String>
               references.put(referenced_project, project_path)
               project_references.put(current_project, references)
            }
         }
         
         return result
      }
   }
   
   def private String generateTypes(EObject container, Collection<? extends EObject> contents)
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
   
   def private String makeImportPath(ArtifactNature artifact_nature, EObject container, String file_name)
   {
      val builder = ParameterBundle.createBuilder(Util.getModuleStack(container)).with(ProjectType.PROTOBUF).reset(param_bundle.artifactNature)
      val root_path = Util.transform(builder.with(TransformType.FILE_SYSTEM).build)
      var String import_path
      if (artifact_nature == ArtifactNature.JAVA)
         import_path = getJavaProtoLocation(container) + file_name.proto
      else
         import_path = (if (artifact_nature == ArtifactNature.CPP) "modules/" else "") + root_path + "/gen/" + file_name.proto
      return import_path
   }
}
