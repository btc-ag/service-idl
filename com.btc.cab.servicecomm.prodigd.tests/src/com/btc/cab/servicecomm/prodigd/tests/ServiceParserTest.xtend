package com.btc.cab.servicecomm.prodigd.tests

import com.btc.cab.servicecomm.prodigd.IdlInjectorProvider
import com.btc.cab.servicecomm.prodigd.idl.IDLSpecification
import com.google.inject.Inject
import com.google.inject.Provider
import org.eclipse.emf.common.util.URI
import org.eclipse.emf.ecore.resource.ResourceSet
import org.eclipse.xtext.junit4.InjectWith
import org.eclipse.xtext.junit4.XtextRunner
import org.eclipse.xtext.junit4.util.ParseHelper
import org.eclipse.xtext.junit4.validation.ValidationTestHelper
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(typeof(XtextRunner))
@InjectWith(typeof(IdlInjectorProvider))
class ServiceParserTest {
	@Inject extension ParseHelper<IDLSpecification>
	@Inject extension ValidationTestHelper
	@Inject Provider <ResourceSet> rsp
		
	@Test
	def void testParsing() {
		val spec = '''
		virtual module BTC {
		virtual module PRINS { 
		module Infrastructure {
		module ServiceHost {
		module Demo { 
		module API {

		interface KeyValueStore[version=1.0.0] { 
		};
		};
		};
		};
		};
		};
		};
		'''.parse

		spec.assertNoErrors;
		
		/*
		val interface = ((((((spec.defintions.get(0) as module).defintions.get(0) as module).defintions.get(0) as module).defintions.get(0) as module)
		                   .defintions.get(0) as module).defintions.get(0) as module).defintions.get(0) as interface_decl;
		Assert::assertEquals("KeyValueStore", interface.name);
		*/
	}
	
	@Test
	def void testInhertiance() {
		val spec = '''
		virtual module BTC {
		virtual module PRINS { 
		module Infrastructure {
		module ServiceHost {
		module Demo { 
		module API {

		interface KeyValueStore[version=1.0.0] { 
		};
		
		interface IntfB : KeyValueStore {
		};
		};
		};
		};
		};
		};
		};
		'''.parse

		spec.assertNoErrors;
		
		/*
		val interface = ((((((spec.defintions.get(0) as module).defintions.get(0) as module).defintions.get(0) as module).defintions.get(0) as module)
		                   .defintions.get(0) as module).defintions.get(0) as module).defintions.get(0) as interface_decl;
		Assert::assertEquals("KeyValueStore", interface.name);
		*/
	}
	
	@Test
	def void testExceptionDecl() {
	   
        val rs = rsp.get()
        // TODO: Das muss noch Bestandteil der Grammatik werden
        rs.getResource(URI.createURI("src/com/btc/servicecomm/prodigd/tests/testdata/base.idl"), true) 
        
		val spec = '''
		// #include "base.idl"
		import BTC.Commons.Core.InvalidArgumentException
		
		module Test {

		interface KeyValueStore { 
			exception DuplicateKeyException :  BTC.Commons.Core.InvalidArgumentException { 
				string reason;
			};
			
			foo() returns void raises DuplicateKeyException;
		};
		};
		'''.parse(rs)
		
		spec.assertNoErrors;

/*
		val exceptionDecl = ((spec.defintions.get(0) as module).defintions.get(0) as interface_decl).contains.get(0);
		Assert::assertTrue("wrong type", exceptionDecl instanceof ExcecptionDecl);
		Assert::assertEquals("DuplicateKeyException", (exceptionDecl as except_decl).name);
		*/
	}
	
	@Test
	def void testTypeDefs() {
		val spec = '''
		
		module Test {

		interface KeyValueStore { 

			typedef string KeyType;
			
			struct IKeyValueStoreTypes {

				typedef string KeyType;
				typedef string ValueType;
				
			};

		};
		};
		'''.parse;
		
				// typedef pair<KeyType, ValueType> EntryType;
				// typedef BTC::PRINS::Commons::SafeInsertableTypes<KeyType> KeyInsertableTypes;
		
		spec.assertNoErrors;
		
		
	}

	@Test
	def void testTemplates() {
		val spec = '''
		
		module Test {

		interface KeyValueStore { 

			typedef string KeyType;
			typedef string ValueType;
			typedef tuple<KeyType, ValueType> EntryType;
			
			typedef sequence<int32> IntSeq;
		};
		};
		'''.parse;
		
		spec.assertNoErrors;
		
//		val typedef = spec.defintions.get(0).module.defintions.get(0).interfaceDecl.contains.get(0).typeDecl.aliasType;
//		Assert::assertEquals("KeyType", typedef.name);
//		Assert::assertEquals("string", typedef.containedType.baseType.primitive.charstrType.stringType.PK_STRING);
		
	}
	
	@Test
	def void testStructs() {
		val spec = '''
		
		module Test {

		interface KeyValueStore {
			
			struct IKeyValueStoreTypes {
				typedef string KeyType;
		   		typedef string ValueType;
		   	  	typedef tuple<KeyType, ValueType> EntryType;
		//   	  	      typedef BTC::PRINS::Commons::SafeInsertableTypes<KeyType> KeyInsertableTypes;
		   	};
			 
		
			struct ModificationEvent {
		      	IKeyValueStoreTypes.KeyType key;
				optional IKeyValueStoreTypes.ValueType value;

		   };

		};
		};
		'''.parse;
		
		spec.assertNoErrors;	
	}
	
	@Test
	def void testEnums() {
		val spec = '''
		
		module Test {

		interface KeyValueStore {
			
			struct IKeyValueStoreTypes {
				typedef string KeyType;
		   		typedef string ValueType;
		   	  	typedef tuple<KeyType, ValueType> EntryType;
		//   	  	      typedef BTC::PRINS::Commons::SafeInsertableTypes<KeyType> KeyInsertableTypes;
		   	};
			 
		
			struct ModificationEvent {
		      	IKeyValueStoreTypes.KeyType key;
				optional IKeyValueStoreTypes.ValueType value;
				
				enum ModificationKind {
					ModificationKind_Added,
		 			ModificationKind_Modified,
		 			ModificationKind_Removed
				} modificationKind;
		   };

		};
		};
		'''.parse;
		
		spec.assertNoErrors;	
	}
	
	@Test
	def void testOperations() {
		val spec = '''
		
		module Test {

		interface KeyValueStore {
			
			struct IKeyValueStoreTypes {
				typedef string KeyType;
		   		typedef string ValueType;
		   	  	typedef tuple<KeyType, ValueType> EntryType;
		//   	  	      typedef BTC::PRINS::Commons::SafeInsertableTypes<KeyType> KeyInsertableTypes;
		   	};
			 
		
			struct ModificationEvent {
		      	IKeyValueStoreTypes.KeyType key;
				optional IKeyValueStoreTypes.ValueType value;
				
				enum ModificationKind {
					ModificationKind_Added,
		 			ModificationKind_Modified,
		 			ModificationKind_Removed
				} modificationKind;
		   };
		   
		   AddEntries(in sequence<IKeyValueStoreTypes.EntryType> entries) returns void;

		/** Queries the keys of entries with a given prefix asynchronously. */
		   QueryKeysWithPrefix(in IKeyValueStoreTypes.KeyType prefix) returns sequence<IKeyValueStoreTypes.KeyType> ; // async keyword? nein! Default ist async. sync als spezielles Keyword
		   //Wie das Reingeben eines Inseratables machen?

		};
		};
		'''.parse;
		
		spec.assertNoErrors;
	}
	
}