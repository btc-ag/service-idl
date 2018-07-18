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
package com.btc.serviceidl.generator.dotnet

import com.btc.serviceidl.generator.common.ArtifactNature
import com.btc.serviceidl.generator.common.GeneratorUtil
import com.btc.serviceidl.generator.common.ParameterBundle
import com.btc.serviceidl.generator.common.TransformType

import static extension com.btc.serviceidl.generator.common.Extensions.*
import static extension com.btc.serviceidl.generator.common.FileTypeExtensions.*
import static extension com.btc.serviceidl.generator.common.GeneratorUtil.*
import static extension com.btc.serviceidl.generator.dotnet.Util.*

class CSProjGenerator {
  static def String generateCSProj(String projectName, VSSolution vsSolution, ParameterBundle paramBundle,
        Iterable<String> referencedAssemblies, Iterable<NuGetPackage> nugetPackages,
        Iterable<ParameterBundle> projectReferences, Iterable<String> csFiles, Iterable<String> protobufFiles)
  {
      // Please do NOT edit line indents in the code below (even though they
      // may look misplaced) unless you are fully aware of what you are doing!!!
      // Those indents (2 whitespaces) follow the Visual Studio 2012 standard formatting!!!
      
      val projectGuid = vsSolution.getCsprojGUID(paramBundle)
      val isExe = isExecutable(paramBundle.projectType)
      val prins = false
      '''
      <?xml version="1.0" encoding="utf-8"?>
      <Project ToolsVersion="4.0" DefaultTargets="Build" xmlns="http://schemas.microsoft.com/developer/msbuild/2003">
        «IF isExe && prins»<Import Project="$(SolutionDir)Net.ProjectSettings" />«ENDIF»
        <PropertyGroup>
          <ProjectGuid>{«projectGuid»}</ProjectGuid>
          <OutputType>«IF isExe»Exe«ELSE»Library«ENDIF»</OutputType>
          <RootNamespace>«projectName»</RootNamespace>
          <AssemblyName>«projectName»</AssemblyName>
          <TargetFrameworkVersion>v«DotNetGenerator.DOTNET_FRAMEWORK_VERSION.toString»</TargetFrameworkVersion>
          <TargetFrameworkProfile />
        </PropertyGroup>
        «IF !isExe || !prins»
        <PropertyGroup Condition=" '$(Configuration)|$(Platform)' == 'Debug|AnyCPU' ">
          <DebugSymbols>true</DebugSymbols>
          <DebugType>full</DebugType>
          <Optimize>false</Optimize>
          <OutputPath>$(SolutionDir)\dst\$(Platform)\$(Configuration)\</OutputPath>
          <DefineConstants>DEBUG;TRACE</DefineConstants>
          <ErrorReport>prompt</ErrorReport>
          <WarningLevel>4</WarningLevel>
          <TreatWarningsAsErrors>true</TreatWarningsAsErrors>
        </PropertyGroup>
        <PropertyGroup Condition=" '$(Configuration)|$(Platform)' == 'Release|AnyCPU' ">
          <DebugType>pdbonly</DebugType>
          <Optimize>true</Optimize>
          <OutputPath>$(SolutionDir)\dst\$(Platform)\$(Configuration)\</OutputPath>
          <DefineConstants>TRACE</DefineConstants>
          <ErrorReport>prompt</ErrorReport>
          <WarningLevel>4</WarningLevel>
          <TreatWarningsAsErrors>true</TreatWarningsAsErrors>
        </PropertyGroup>
        <PropertyGroup Condition=" '$(Configuration)|$(Platform)' == 'Debug|Win32' ">
          <DebugSymbols>true</DebugSymbols>
          <DebugType>full</DebugType>
          <Optimize>false</Optimize>
          <OutputPath>$(SolutionDir)\dst\$(Platform)\$(Configuration)\</OutputPath>
          <DefineConstants>DEBUG;TRACE</DefineConstants>
          <ErrorReport>prompt</ErrorReport>
          <WarningLevel>4</WarningLevel>
          <TreatWarningsAsErrors>true</TreatWarningsAsErrors>
        </PropertyGroup>
        <PropertyGroup Condition=" '$(Configuration)|$(Platform)' == 'Release|Win32' ">
          <DebugType>pdbonly</DebugType>
          <Optimize>true</Optimize>
          <OutputPath>$(SolutionDir)\dst\$(Platform)\$(Configuration)\</OutputPath>
          <DefineConstants>TRACE</DefineConstants>
          <ErrorReport>prompt</ErrorReport>
          <WarningLevel>4</WarningLevel>
          <TreatWarningsAsErrors>true</TreatWarningsAsErrors>
        </PropertyGroup>
        <PropertyGroup Condition=" '$(Configuration)|$(Platform)' == 'Debug|x64' ">
          <DebugSymbols>true</DebugSymbols>
          <DebugType>full</DebugType>
          <Optimize>false</Optimize>
          <OutputPath>$(SolutionDir)\dst\$(Platform)\$(Configuration)\</OutputPath>
          <DefineConstants>DEBUG;TRACE</DefineConstants>
          <ErrorReport>prompt</ErrorReport>
          <WarningLevel>4</WarningLevel>
          <TreatWarningsAsErrors>true</TreatWarningsAsErrors>
        </PropertyGroup>
        <PropertyGroup Condition=" '$(Configuration)|$(Platform)' == 'Release|x64' ">
          <DebugType>pdbonly</DebugType>
          <Optimize>true</Optimize>
          <OutputPath>$(SolutionDir)\dst\$(Platform)\$(Configuration)\</OutputPath>
          <DefineConstants>TRACE</DefineConstants>
          <ErrorReport>prompt</ErrorReport>
          <WarningLevel>4</WarningLevel>
          <TreatWarningsAsErrors>true</TreatWarningsAsErrors>
        </PropertyGroup>
        «ENDIF»
        «IF isExe»
           <ItemGroup>
             <None Include="App.config">
               <SubType>Designer</SubType>
             </None>
             <None Include="«paramBundle.log4NetConfigFile»">
               <CopyToOutputDirectory>Always</CopyToOutputDirectory>
             </None>
             <None Include="packages.config">
               <SubType>Designer</SubType>
             </None>
           </ItemGroup>
        «ENDIF»
        <ItemGroup>
          «FOR assembly : referencedAssemblies»
            <Reference Include="«assembly»">
              <SpecificVersion>False</SpecificVersion>
              <HintPath>$(SolutionDir)..\lib\AnyCPU\Release\«assembly».«getReferenceExtension(assembly)»</HintPath>
            </Reference>
          «ENDFOR»
          «FOR nugetPackage : nugetPackages»
            <Reference Include="«nugetPackage.assemblyName»">
              <HintPath>$(SolutionDir)packages\«nugetPackage.assemblyPath»</HintPath>
            </Reference>
          «ENDFOR»
        </ItemGroup>
        <ItemGroup>
        «FOR protobufFile : protobufFiles»
          <Compile Include="«protobufFile».cs" />
        «ENDFOR»
        «FOR csFile : csFiles»
          <Compile Include="«csFile».cs" />
        «ENDFOR»
          <Compile Include="Properties\AssemblyInfo.cs" />
        </ItemGroup>
          «FOR projectReference : projectReferences.filter[it != paramBundle] BEFORE "  <ItemGroup>" AFTER "  </ItemGroup>"»
             <ProjectReference Include="$(SolutionDir)«projectReference.asPath(ArtifactNature.DOTNET).append(projectReference.getTransformedModuleName(ArtifactNature.DOTNET, TransformType.PACKAGE).csproj).toWindowsString»">
               <Project>{«vsSolution.getCsprojGUID(projectReference)»}</Project>
               <Name>«projectReference.getTransformedModuleName(ArtifactNature.DOTNET, TransformType.PACKAGE)»</Name>
             </ProjectReference>
          «ENDFOR»

        <Import Project="$(MSBuildToolsPath)\Microsoft.CSharp.targets" />
        «/** TODO protobufBaseDir was "$(SolutionDir)..", this must be generalized */»
        «val protobufBaseDir = "$(SolutionDir)"»
        «IF !protobufFiles.empty»
          <PropertyGroup>
            <PreBuildEvent>
            «FOR protobufFileBasename : protobufFiles»
                «val protobufFile = makeProtobufFilePath(paramBundle, protobufFileBasename)»
                «val protobinFile = '''$(ProjectDir)gen\«protobufFileBasename».protobin'''»
                «protobufBaseDir»\\packages\\Google.ProtocolBuffers\\tools\\protoc.exe --include_imports --proto_path=«protobufBaseDir» --descriptor_set_out=«protobinFile» «protobufFile»
                «protobufBaseDir»\\packages\\Google.ProtocolBuffers\\tools\\Protogen.exe -output_directory=$(ProjectDir) «protobinFile»
            «ENDFOR»
            </PreBuildEvent>
          </PropertyGroup>
        «ENDIF»
        <!-- To modify your build process, add your task inside one of the targets below and uncomment it. 
             Other similar extension points exist, see Microsoft.Common.targets.
        <Target Name="BeforeBuild">
        </Target>
        <Target Name="AfterBuild">
        </Target>
        -->
      </Project>
      '''
      
  }
    
    static def makeProtobufFilePath(ParameterBundle parameterBundle, String protobufFileBasename)
    {
        '''$(SolutionDir)/«GeneratorUtil.asPath(parameterBundle, ArtifactNature.DOTNET)»/gen/«protobufFileBasename».proto'''
    }

   /**
    * On rare occasions (like ServerRunner) the reference is not a DLL, but a
    * EXE, therefore here we have the chance to do some special handling to
    * retrieve the correct file extension of the reference.
    */
   private static def String getReferenceExtension(String assembly)
   {
      switch (assembly)
      {
         case "BTC.CAB.ServiceComm.NET.ServerRunner":
            "exe"
         default:
            "dll"
      }
   }
   
}
