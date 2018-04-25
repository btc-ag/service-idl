package com.btc.serviceidl.generator.dotnet

import org.eclipse.xtend.lib.annotations.Accessors
import com.btc.serviceidl.generator.common.ParameterBundle
import com.btc.serviceidl.generator.common.GeneratorUtil
import com.btc.serviceidl.generator.common.TransformType
import com.btc.serviceidl.generator.common.ArtifactNature

@Accessors
class Log4NetConfigGenerator
{
    private val ParameterBundle param_bundle

    def generate()
    {
        '''
            <log4net>
               <appender name="RollingLogFileAppender" type="log4net.Appender.RollingFileAppender">
                  <file value="log_«GeneratorUtil.getTransformedModuleName(param_bundle, ArtifactNature.DOTNET, TransformType.PACKAGE).toLowerCase».txt"/>
                  <appendToFile value="true"/>
                  <datePattern value="yyyyMMdd"/>
                  <rollingStyle value="Date"/>
                  <MaxSizeRollBackups value="180" />
                  <filter type="log4net.Filter.LevelRangeFilter">
                     <acceptOnMatch value="true"/>
                     <levelMin value="INFO"/>
                     <levelMax value="FATAL"/>
                  </filter>
                  <layout type="log4net.Layout.PatternLayout">
                     <conversionPattern value="%-5p %-25d thr:%-5t %9rms %c{1},%M: %m%n"/>
                  </layout>
               </appender>
            
               <appender name="ColoredConsoleAppender" type="log4net.Appender.ColoredConsoleAppender">
                  <mapping>
                     <level value="ERROR" />
                     <foreColor value="White" />
                     <backColor value="Red, HighIntensity" />
                  </mapping>
                  <mapping>
                     <level value="INFO" />
                     <foreColor value="Cyan" />
                  </mapping>
                  <mapping>
                     <level value="DEBUG" />
                     <foreColor value="Green" />
                  </mapping>
                  <layout type="log4net.Layout.PatternLayout">
                     <conversionPattern value="%date [%thread] %-5level %logger [%property{NDC}] - %message%newline" />
                  </layout>
               </appender>
            
               <root>
                  <level value="DEBUG" />
                  <appender-ref ref="RollingLogFileAppender" />
                  <appender-ref ref="ColoredConsoleAppender" />
               </root>
            </log4net>
        '''
    }

}
