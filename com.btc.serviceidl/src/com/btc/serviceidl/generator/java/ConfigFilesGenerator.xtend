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

class ConfigFilesGenerator
{
    // TODO this is outdated since log4j is longer used at all
    def public static String generateLog4jProperties()
    {
        '''
            # Root logger option
            log4j.rootLogger=INFO, stdout
            
            # Direct log messages to stdout
            log4j.appender.stdout=org.apache.log4j.ConsoleAppender
            log4j.appender.stdout.Target=System.out
            log4j.appender.stdout.layout=org.apache.log4j.PatternLayout
            log4j.appender.stdout.layout.ConversionPattern=%d{yyyy-MM-dd HH:mm:ss} %-5p %c{1}:%L - %m%n
        '''
    }

    // TODO what is the purpose of this? probably it can be removed
    def public static String generateSpringBeans(String package_name, String program_name)
    {
        '''
            <?xml version="1.0" encoding="UTF-8"?>
            <beans xmlns="http://www.springframework.org/schema/beans"
               xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
               xsi:schemaLocation="http://www.springframework.org/schema/beans http://www.springframework.org/schema/beans/spring-beans-3.0.xsd">
            
               <bean id="ServerFactory" class="com.btc.cab.servicecomm.singlequeue.zeromq.ZeroMqServerConnectionFactory">
                  <constructor-arg ref="logger" />
               </bean>
            
               <bean id="logger" class="org.apache.log4j.Logger" factory-method="getLogger">
                  <constructor-arg type="java.lang.String" value="«package_name».«program_name»" />
               </bean>
            </beans>
        '''
    }

}
