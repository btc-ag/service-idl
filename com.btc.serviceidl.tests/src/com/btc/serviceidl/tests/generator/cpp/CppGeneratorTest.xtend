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
package com.btc.serviceidl.tests.generator.cpp

import com.btc.serviceidl.generator.DefaultGenerationSettingsProvider
import com.btc.serviceidl.generator.IGenerationSettingsProvider
import com.btc.serviceidl.generator.common.ArtifactNature
import com.btc.serviceidl.generator.common.ProjectType
import com.btc.serviceidl.idl.IDLSpecification
import com.btc.serviceidl.tests.IdlInjectorProvider
import com.btc.serviceidl.tests.testdata.TestData
import com.google.inject.Inject
import java.util.Arrays
import java.util.HashSet
import org.eclipse.xtext.generator.GeneratorContext
import org.eclipse.xtext.generator.IFileSystemAccess
import org.eclipse.xtext.generator.IGenerator2
import org.eclipse.xtext.generator.InMemoryFileSystemAccess
import org.eclipse.xtext.testing.InjectWith
import org.eclipse.xtext.testing.XtextRunner
import org.eclipse.xtext.testing.util.ParseHelper
import org.junit.Test
import org.junit.runner.RunWith

import static com.btc.serviceidl.tests.TestExtensions.*
import static org.junit.Assert.*

@RunWith(XtextRunner)
@InjectWith(IdlInjectorProvider)
class CppGeneratorTest {
	@Inject extension ParseHelper<IDLSpecification>
	@Inject IGenerator2 underTest
	@Inject IGenerationSettingsProvider generationSettingsProvider

	@Test
	def void testBasicServiceApi() {
		val spec = TestData.basic.parse

		val fsa = new InMemoryFileSystemAccess
		val defaultGenerationSettingsProvider = generationSettingsProvider as DefaultGenerationSettingsProvider
		defaultGenerationSettingsProvider.projectTypes = new HashSet<ProjectType>(
			Arrays.asList(ProjectType.SERVICE_API))
		defaultGenerationSettingsProvider.languages = new HashSet<ArtifactNature>(Arrays.asList(ArtifactNature.CPP))
		underTest.doGenerate(spec.eResource, fsa, new GeneratorContext)
		println(fsa.textFiles.keySet)
		assertEquals(30, fsa.textFiles.size) // TODO 30 is too much, check this
		val directory = IFileSystemAccess::DEFAULT_OUTPUT +
			"cpp/Infrastructure/ServiceHost/Demo/API/ServiceAPI/" // TODO double / should be removed
		checkFile(fsa, directory + "include//IKeyValueStore.h", '''
			#pragma once
			#include "modules/Commons/include/BeginPrinsModulesInclude.h"
			
			#include "btc_prins_infrastructure_servicehost_demo_api_serviceapi_export.h"
			
			#include "modules/Commons/include/BeginCabInclude.h"     // CAB -->
			#include "Commons/Core/include/Object.h"
			#include "Commons/CoreExtras/include/UUID.h"
			#include "ServiceComm/API/include/IServiceFaultHandler.h"
			#include "modules/Commons/include/EndCabInclude.h"       // <-- CAB			
			
			namespace BTC {
			namespace PRINS {
			namespace Infrastructure {
			namespace ServiceHost {
			namespace Demo {
			namespace API {
			namespace ServiceAPI {			   
			   class BTC_PRINS_INFRASTRUCTURE_SERVICEHOST_DEMO_API_SERVICEAPI_EXPORT
			   IKeyValueStore : virtual public BTC::Commons::Core::Object
			   {
			   public:
			      /** \return {384E277A-C343-4F37-B910-C2CE6B37FC8E} */
			      static BTC::Commons::CoreExtras::UUID TYPE_GUID();
			      
			   };
			   void BTC_PRINS_INFRASTRUCTURE_SERVICEHOST_DEMO_API_SERVICEAPI_EXPORT
			   RegisterKeyValueStoreServiceFaults(BTC::ServiceComm::API::IServiceFaultHandlerManager& serviceFaultHandlerManager);
			}}}}}}}
			
			#include "modules/Commons/include/EndPrinsModulesInclude.h"
		''')
		checkFile(fsa, directory + "source/IKeyValueStore.cpp", '''
			#include "modules/Infrastructure/ServiceHost/Demo/API/ServiceAPI/include/IKeyValueStore.h"
			
			#include "modules/Commons/include/BeginCabInclude.h"     // CAB -->
			#include "Commons/Core/include/InvalidArgumentException.h"
			#include "Commons/Core/include/String.h"
			#include "Commons/Core/include/UnsupportedOperationException.h"
			#include "Commons/CoreExtras/include/UUID.h"
			#include "ServiceComm/API/include/IServiceFaultHandler.h"
			#include "ServiceComm/Base/include/DefaultServiceFaultHandler.h"
			#include "modules/Commons/include/EndCabInclude.h"       // <-- CAB
			
			namespace BTC {
			namespace PRINS {
			namespace Infrastructure {
			namespace ServiceHost {
			namespace Demo {
			namespace API {
			namespace ServiceAPI {			   
			   // {384E277A-C343-4F37-B910-C2CE6B37FC8E}
			   static const BTC::Commons::CoreExtras::UUID sKeyValueStoreTypeGuid = 
			      BTC::Commons::CoreExtras::UUID::ParseString("384E277A-C343-4F37-B910-C2CE6B37FC8E");
			   
			   BTC::Commons::CoreExtras::UUID IKeyValueStore::TYPE_GUID()
			   {
			      return sKeyValueStoreTypeGuid;
			   }
			   
			   
			   void RegisterKeyValueStoreServiceFaults(BTC::ServiceComm::API::IServiceFaultHandlerManager& serviceFaultHandlerManager)
			   {
			      
			      // most commonly used exception types
			      BTC::ServiceComm::Base::RegisterServiceFault<BTC::Commons::Core::InvalidArgumentException>(
			         serviceFaultHandlerManager, BTC::Commons::Core::String("BTC.Commons.Core.InvalidArgumentException"));
			      BTC::ServiceComm::Base::RegisterServiceFault<BTC::Commons::Core::UnsupportedOperationException>(
			         serviceFaultHandlerManager, BTC::Commons::Core::String("BTC.Commons.Core.UnsupportedOperationException"));
			   }
			}}}}}}}
		''')

	}

}
