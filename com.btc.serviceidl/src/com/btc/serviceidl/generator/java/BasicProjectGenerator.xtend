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
package com.btc.serviceidl.generator.java

import com.btc.serviceidl.generator.IGenerationSettings
import com.btc.serviceidl.generator.common.ArtifactNature
import com.btc.serviceidl.generator.common.GeneratorUtil
import com.btc.serviceidl.generator.common.Names
import com.btc.serviceidl.generator.common.ParameterBundle
import com.btc.serviceidl.generator.common.ProjectType
import com.btc.serviceidl.generator.common.ResolvedName
import com.btc.serviceidl.idl.AbstractTypeDeclaration
import com.btc.serviceidl.idl.AliasDeclaration
import com.btc.serviceidl.idl.IDLSpecification
import com.btc.serviceidl.idl.InterfaceDeclaration
import com.btc.serviceidl.idl.ModuleDeclaration
import com.btc.serviceidl.util.Constants
import com.btc.serviceidl.util.Util
import java.util.HashMap
import java.util.HashSet
import java.util.Map
import org.eclipse.core.runtime.IPath
import org.eclipse.core.runtime.Path
import org.eclipse.emf.ecore.EObject
import org.eclipse.xtend.lib.annotations.Accessors
import org.eclipse.xtext.generator.IFileSystemAccess
import org.eclipse.xtext.naming.IQualifiedNameProvider

import static extension com.btc.serviceidl.generator.common.FileTypeExtensions.*
import static extension com.btc.serviceidl.generator.java.BasicJavaSourceGenerator.*
import static extension com.btc.serviceidl.util.Util.*

@Accessors(PROTECTED_GETTER)
abstract class BasicProjectGenerator
{
    enum PathType
    {
        ROOT,
        FULL
    }
   
    // parameters
    val IFileSystemAccess fileSystemAccess
    val IQualifiedNameProvider qualifiedNameProvider
    val IGenerationSettings generationSettings
    val Map<EObject, String> protobufArtifacts
    val IDLSpecification idl
    val MavenResolver mavenResolver

    val dependencies = new HashSet<MavenDependency>
    val typedefTable = new HashMap<String, ResolvedName>

    protected def createTypeResolver(ParameterBundle paramBundle)
    {
        new TypeResolver(qualifiedNameProvider, dependencies, mavenResolver)
    }

    protected def void generatePOM(EObject container, ProjectType projectType)
    {
        val pom_path = makeProjectRootPath(container, projectType).append("pom".xml)
        fileSystemAccess.generateFile(pom_path.toPortableString, ArtifactNature.JAVA.label,
            new POMGenerator(generationSettings, mavenResolver).generatePOMContents(container, projectType,
                dependencies, if (projectType == ProjectType.PROTOBUF) protobufArtifacts?.get(container) else null))
    }

    private def IPath makeProjectRootPath(EObject container, ProjectType projectType)
    {
        Path.fromPortableString(MavenResolver.makePackageId(container, projectType))
    }

   protected def IPath makeProjectSourcePath(EObject container, ProjectType projectType, MavenArtifactType mavenType, PathType pathType)
   {      
      var result = makeProjectRootPath(container, projectType).append(mavenType.directoryLayout)
      
      if (pathType == PathType.FULL)
      {
         result = result.append(
                GeneratorUtil.asPath(
                    new ParameterBundle.Builder().with(Util.getModuleStack(container)).build, ArtifactNature.JAVA))
         if (container instanceof InterfaceDeclaration) result = result.append(container.name.toLowerCase)
         result = result.append(projectType.getName.toLowerCase)
      }

      result
   }
   
   protected def void generateCommon(IPath projectSourceRootPath, ModuleDeclaration module)
   {
      val paramBundle = ParameterBundle.createBuilder(module.moduleStack).with(ProjectType.COMMON).build
      
      for ( element : module.moduleComponents.filter(AbstractTypeDeclaration).filter[e | !(e instanceof AliasDeclaration)] )
      {
         generateJavaFile(projectSourceRootPath.append(Names.plain(element).java), paramBundle, module, 
             [basicJavaSourceGenerator|basicJavaSourceGenerator.toDeclaration(element)]
         )
      }
      
      // common service fault handler factory
      // TODO the service fault handler factory is ServiceComm-specific and should therefore not be generated to the service API package
      // TODO the "common" service fault handler factory is also generated as part of the ServiceAPI!?      
      val serviceFaultHandlerFactoryName = module.asServiceFaultHandlerFactory
      generateJavaFile(projectSourceRootPath.append(ProjectType.COMMON.getClassName(ArtifactNature.JAVA, serviceFaultHandlerFactoryName).java), paramBundle, 
          module, [basicJavaSourceGenerator|new ServiceFaultHandlerFactoryGenerator(basicJavaSourceGenerator).generateServiceFaultHandlerFactory(serviceFaultHandlerFactoryName, module )]
      )
   }
   
   protected def void generateProtobuf(IPath projectSourceRootPath, EObject container)
   {
      val paramBundle = ParameterBundle.createBuilder(container.moduleStack).with(ProjectType.PROTOBUF).build
       
      val codecName = ProjectType.PROTOBUF.getClassName(ArtifactNature.JAVA, if (container instanceof InterfaceDeclaration) container.name else Constants.FILE_NAME_TYPES) + "Codec"
      // TODO most of the generated file is reusable, and should be moved to com.btc.cab.commons (UUID utilities) or something similar
      
      generateJavaFile(projectSourceRootPath.append(codecName.java), paramBundle, container,
          [basicJavaSourceGenerator|new ProtobufCodecGenerator(basicJavaSourceGenerator).generateProtobufCodecBody(container, codecName)]          
      )  
   }
   
   protected def getProjectTypes()
   {
       generationSettings.projectTypes
   }

   protected def <T extends EObject> void generateJavaFile(IPath fileName, ParameterBundle paramBundle, T declarator, (BasicJavaSourceGenerator)=>CharSequence generateBody)
   {
       // TODO T can be InterfaceDeclaration or ModuleDeclaration, the metamodel should be changed to introduce a common base type of these
      val basicJavaSourceGenerator = createBasicJavaSourceGenerator(paramBundle)
      fileSystemAccess.generateFile(fileName.toPortableString, ArtifactNature.JAVA.label, 
         generateSourceFile(
                declarator,
                paramBundle.projectType,
                basicJavaSourceGenerator.typeResolver,
                generateBody.apply(basicJavaSourceGenerator)
         )
      )
   }

   private def generateSourceFile(EObject container, ProjectType projectType, TypeResolver typeResolver, CharSequence mainContents)
   {
      '''
      package «mavenResolver.registerPackage(container, projectType)»;
      
      «FOR reference : typeResolver.referenced_types.sort AFTER System.lineSeparator»
         import «reference»;
      «ENDFOR»
      «mainContents»
      '''
   }
   
   // TODO make private
   protected def createBasicJavaSourceGenerator(ParameterBundle paramBundle)
   {
      new BasicJavaSourceGenerator(qualifiedNameProvider, generationSettings,
            createTypeResolver(paramBundle), idl, typedefTable, mavenResolver)
   }
}

