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

import com.btc.serviceidl.generator.common.GeneratorUtil
import com.btc.serviceidl.generator.common.ParameterBundle
import com.btc.serviceidl.generator.common.TransformType
import java.util.Map

import static extension com.btc.serviceidl.generator.dotnet.Util.*
import com.btc.serviceidl.generator.common.ArtifactNature

class CSProjGenerator {
  def static generateCSProj(String project_name, VSSolution vsSolution, ParameterBundle param_bundle, Iterable<String> referenced_assemblies, Iterable<NuGetPackage> nuget_packages, Map<String, String> project_references, Iterable<String> cs_files, Iterable<String> protobuf_files)
  {
      // Please do NOT edit line indents in the code below (even though they
      // may look misplaced) unless you are fully aware of what you are doing!!!
      // Those indents (2 whitespaces) follow the Visual Studio 2012 standard formatting!!!
      
      val project_guid = vsSolution.getCsprojGUID(project_name)
      val is_exe = isExecutable(param_bundle.projectType)
      val prins = false
      '''
      <?xml version="1.0" encoding="utf-8"?>
      <Project ToolsVersion="4.0" DefaultTargets="Build" xmlns="http://schemas.microsoft.com/developer/msbuild/2003">
        «IF is_exe && prins»<Import Project="$(SolutionDir)Net.ProjectSettings" />«ENDIF»
        <PropertyGroup>
          <ProjectGuid>{«project_guid»}</ProjectGuid>
          <OutputType>«IF is_exe»Exe«ELSE»Library«ENDIF»</OutputType>
          <RootNamespace>«project_name»</RootNamespace>
          <AssemblyName>«project_name»</AssemblyName>
          <TargetFrameworkVersion>v4.0</TargetFrameworkVersion>
          <TargetFrameworkProfile />
        </PropertyGroup>
        «IF !is_exe || !prins»
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
        «IF is_exe»
           <ItemGroup>
             <None Include="App.config">
               <SubType>Designer</SubType>
             </None>
             <None Include="«param_bundle.log4NetConfigFile»">
               <CopyToOutputDirectory>Always</CopyToOutputDirectory>
             </None>
             <None Include="packages.config">
               <SubType>Designer</SubType>
             </None>
           </ItemGroup>
        «ENDIF»
        <ItemGroup>
          «FOR assembly : referenced_assemblies»
            <Reference Include="«assembly»">
              <SpecificVersion>False</SpecificVersion>
              <HintPath>$(SolutionDir)..\lib\AnyCPU\Release\«assembly».«getReferenceExtension(assembly)»</HintPath>
            </Reference>
          «ENDFOR»
          «FOR nuget_package : nuget_packages»
            <Reference Include="«nuget_package.assemblyName»">
              <HintPath>$(SolutionDir)packages\«nuget_package.assemblyPath»</HintPath>
            </Reference>
          «ENDFOR»
        </ItemGroup>
        <ItemGroup>
        «IF protobuf_files !== null»
          «FOR protobuf_file : protobuf_files»
            <Compile Include="«protobuf_file».cs" />
          «ENDFOR»
        «ENDIF»
          «FOR cs_file : cs_files»
            <Compile Include="«cs_file».cs" />
          «ENDFOR»
          <Compile Include="Properties\AssemblyInfo.cs" />
        </ItemGroup>
          «FOR name : project_references.keySet.filter[it != project_name] BEFORE "  <ItemGroup>" AFTER "  </ItemGroup>"»
             <ProjectReference Include="«project_references.get(name)».csproj">
               <Project>{«vsSolution.getCsprojGUID(name)»}</Project>
               <Name>«name»</Name>
             </ProjectReference>
          «ENDFOR»

        <Import Project="$(MSBuildToolsPath)\Microsoft.CSharp.targets" />
        «IF protobuf_files !== null»
          <PropertyGroup>
            <PreBuildEvent>
            «FOR protobuf_file : protobuf_files»
            «/** TODO here was "$(SolutionDir)..", this must be generalized */»
                protoc.exe --include_imports --proto_path=$(SolutionDir) --descriptor_set_out=$(ProjectDir)gen/«protobuf_file».protobin $(SolutionDir)/«GeneratorUtil.getTransformedModuleName(param_bundle, ArtifactNature.DOTNET, TransformType.FILE_SYSTEM)»/gen/«protobuf_file».proto
                Protogen.exe -output_directory=$(ProjectDir) $(ProjectDir)gen\«protobuf_file».protobin
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

   /**
    * On rare occasions (like ServerRunner) the reference is not a DLL, but a
    * EXE, therefore here we have the chance to do some special handling to
    * retrieve the correct file extension of the reference.
    */
   def private static String getReferenceExtension(String assembly)
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