package com.btc.serviceidl.generator.dotnet

import org.eclipse.xtend.lib.annotations.Accessors
import org.eclipse.xtext.generator.IFileSystemAccess
import com.btc.serviceidl.generator.common.ArtifactNature

@Accessors(NONE)
class VSSolutionGenerator
{
    val IFileSystemAccess fileSystemAccess
    val VSSolution solution
    val String projectName

    def generateSolutionFile()
    {
        fileSystemAccess.generateFile(projectName + ".sln", ArtifactNature.DOTNET.label, generateContent)
    }

    def generateContent()
    {
        '''
            
            Microsoft Visual Studio Solution File, Format Version 12.00
            # Visual Studio 14
            VisualStudioVersion = 14.0.25420.1
            MinimumVisualStudioVersion = 10.0.40219.1
            «FOR project : solution.allProjects»
                Project("{FAE04EC0-301F-11D3-BF4B-00C04F79EFBC}") = "«project.key»", "«project.value.path.toPortableString.replace("/", "\\")»\«project.key».csproj", "{«project.value.uuid.toString.toUpperCase»}"
                EndProject
            «ENDFOR»
            Global
                GlobalSection(SolutionConfigurationPlatforms) = preSolution
                    Debug|Any CPU = Debug|Any CPU
                    Release|Any CPU = Release|Any CPU
                EndGlobalSection
                GlobalSection(ProjectConfigurationPlatforms) = postSolution
                «FOR project : solution.allProjects»
                    {«project.value.uuid.toString.toUpperCase»}.Debug|Any CPU.ActiveCfg = Debug|Any CPU
                    {«project.value.uuid.toString.toUpperCase»}.Debug|Any CPU.Build.0 = Debug|Any CPU
                    {«project.value.uuid.toString.toUpperCase»}.Release|Any CPU.ActiveCfg = Release|Any CPU
                    {«project.value.uuid.toString.toUpperCase»}.Release|Any CPU.Build.0 = Release|Any CPU
                «ENDFOR»
                EndGlobalSection
                GlobalSection(SolutionProperties) = preSolution
                    HideSolutionNode = FALSE
                EndGlobalSection
            EndGlobal
        '''
    }
}
