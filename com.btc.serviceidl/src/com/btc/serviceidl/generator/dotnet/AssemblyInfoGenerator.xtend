package com.btc.serviceidl.generator.dotnet

import com.btc.serviceidl.generator.common.ParameterBundle
import java.util.Calendar
import java.util.UUID
import org.eclipse.xtend.lib.annotations.Accessors

import static com.btc.serviceidl.generator.dotnet.Util.*

import static extension com.btc.serviceidl.util.Util.*

@Accessors
class AssemblyInfoGenerator
{
    val ParameterBundle paramBundle

    def generate(String projectName)
    {
        val isExe = isExecutable(paramBundle.projectType)
        val versionString = paramBundle.moduleStack.last.resolveVersion

        '''
            using System.Reflection;
            using System.Runtime.CompilerServices;
            using System.Runtime.InteropServices;
            
            // General Information about an assembly is controlled through the following 
            // set of attributes. Change these attribute values to modify the information
            // associated with an assembly.
            [assembly: AssemblyTitle("«projectName»")]
            [assembly: AssemblyDescription("")]
            [assembly: AssemblyConfiguration("")]
            [assembly: AssemblyProduct("«projectName»")]
            «IF !isExe»
                [assembly: AssemblyCompany("BTC Business Technology Consulting AG")]
                [assembly: AssemblyCopyright("Copyright (C) BTC Business Technology Consulting AG «Calendar.getInstance().get(Calendar.YEAR)»")]
                [assembly: AssemblyTrademark("")]
                [assembly: AssemblyCulture("")]
            «ENDIF»
            
            [assembly: AssemblyVersion("«versionString.replaceMicroVersionByZero».0")]
            [assembly: AssemblyFileVersion("«versionString».0")]
            [assembly: AssemblyInformationalVersion("«versionString».0+xx")]
            
            // Setting ComVisible to false makes the types in this assembly not visible 
            // to COM components.  If you need to access a type in this assembly from 
            // COM, set the ComVisible attribute to true on that type.
            [assembly: ComVisible(false)]
            
            // The following GUID is for the ID of the typelib if this project is exposed to COM
            [assembly: Guid("«UUID.nameUUIDFromBytes((projectName+"Assembly").bytes).toString.toLowerCase»")]
        '''
    }

}
