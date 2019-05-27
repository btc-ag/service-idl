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
package com.btc.serviceidl.generator.cpp

import com.btc.serviceidl.generator.common.ArtifactNature
import com.btc.serviceidl.generator.common.GeneratorUtil
import com.btc.serviceidl.generator.common.ProjectType
import com.btc.serviceidl.generator.common.ProtobufType
import com.btc.serviceidl.idl.AbstractContainerDeclaration
import com.btc.serviceidl.idl.AbstractType
import com.btc.serviceidl.idl.AbstractTypeReference
import com.btc.serviceidl.idl.EnumDeclaration
import com.btc.serviceidl.idl.ExceptionDeclaration
import com.btc.serviceidl.idl.StructDeclaration
import com.btc.serviceidl.util.MemberElementWrapper
import org.eclipse.xtend.lib.annotations.Accessors

import static extension com.btc.serviceidl.generator.cpp.ProtobufUtil.*
import static extension com.btc.serviceidl.generator.cpp.TypeResolverExtensions.*
import static extension com.btc.serviceidl.generator.cpp.Util.*
import static extension com.btc.serviceidl.util.Extensions.*
import static extension com.btc.serviceidl.util.Util.*

@Accessors
class CodecGenerator extends BasicCppGenerator
{
    private def generateHCodecInline(AbstractContainerDeclaration owner, Iterable<AbstractTypeReference> nestedTypes)
    {
        val failableTypes = GeneratorUtil.getFailableTypes(owner)

        '''
            «generateGenericCodec»
            
            «generateEnsureFailableHandlers(owner)»
            
            // TODO for exceptions, this must probably be done differently. It appears that custom exception 
            // attributes are not properly implemented right now
            «FOR type : nestedTypes.filter[!(it instanceof ExceptionDeclaration)]»
                «generateCodec(type, owner)»
            «ENDFOR»
            
            «FOR type : failableTypes»
                «generateFailableCodec(type, owner)»
            «ENDFOR»
        '''
    }
    
    def generateEnsureFailableHandlers(AbstractContainerDeclaration owner)
    {
        val cabString = resolveSymbol("BTC::Commons::Core::String")
        val cabCreateUnique = resolveSymbol("BTC::Commons::Core::CreateUnique")

        '''
            inline void EnsureFailableHandlers()
            {
               «resolveSymbol("std::call_once")»(registerFaultHandlers, [&]()
               {
                  «FOR exception : owner.failableExceptions»
                      «val exceptionType = resolve(exception)»
                      «val exceptionName = exception.getCommonExceptionName(qualifiedNameProvider)»
                      faultHandlers["«exceptionName»"] = [](«cabString» const& msg) { return «cabCreateUnique»<«exceptionType»>(msg); };
                  «ENDFOR»
                  
                  // most commonly used exception types
                  «val defaultExceptions = typeResolver.defaultExceptionRegistration»
                  «FOR exception : defaultExceptions.keySet.sort»
                      faultHandlers["«exception»"] = [](«cabString» const& msg) { return «cabCreateUnique»<«defaultExceptions.get(exception)»>(msg); };
                  «ENDFOR»
               });
            }
            
        '''
    }
    
    // TODO all the functions generated here do not depend on the contents on the IDL and could be moved to some library
    def generateGenericCodec()
    {
        val cabUuid = resolveSymbol("BTC::Commons::CoreExtras::UUID")
        val forwardConstIterator = resolveSymbol("BTC::Commons::Core::ForwardConstIterator")
        val stdVector = resolveSymbol("std::vector")
        val stdString = resolveSymbol("std::string")
        val stdForEach = resolveSymbol("std::for_each")
        val createDefaultAsyncInsertable = resolveSymbol("BTC::Commons::FutureUtil::CreateDefaultAsyncInsertable")
        val insertableTraits = resolveSymbol("BTC::Commons::CoreExtras::InsertableTraits")
        val failableHandle = resolveSymbol("BTC::Commons::CoreExtras::FailableHandle")
        val cabException = resolveSymbol("BTC::Commons::Core::Exception")
        val cabVector = resolveSymbol("BTC::Commons::CoreStd::Collection")
        val cabString = resolveSymbol("BTC::Commons::Core::String")
        val cabCreateUnique = resolveSymbol("BTC::Commons::Core::CreateUnique")
        val stdFindIf = resolveSymbol("std::find_if")

        '''
            template<typename PROTOBUF_TYPE, typename API_TYPE>
            inline «forwardConstIterator»< API_TYPE > Decode(google::protobuf::RepeatedPtrField< PROTOBUF_TYPE > const& protobufInput)
            {
               typedef «insertableTraits»< API_TYPE > APITypeTraits;
               auto entries = «createDefaultAsyncInsertable»< API_TYPE >();
               auto future = entries->GetFuture();
               
               «stdForEach»( protobufInput.begin(), protobufInput.end(), [ &entries ]( PROTOBUF_TYPE const& protobufEntry )
               {  entries->OnNext( Decode(protobufEntry) ); } );
               
               entries->OnCompleted();
               return future.Get();
            }
            
            template<typename PROTOBUF_TYPE, typename API_TYPE>
            inline «forwardConstIterator»< API_TYPE > Decode(google::protobuf::RepeatedField< PROTOBUF_TYPE > const& protobufInput)
            {
               typedef «insertableTraits»< API_TYPE > APITypeTraits;
               auto entries = «createDefaultAsyncInsertable»< API_TYPE >();
               auto future = entries->GetFuture();
               
               «stdForEach»( protobufInput.begin(), protobufInput.end(), [ &entries ]( PROTOBUF_TYPE const& protobufEntry )
               {  entries->OnNext( Decode(protobufEntry) ); } );
               
               entries->OnCompleted();
               return future.Get();
            }
            
            template<typename PROTOBUF_TYPE, typename API_TYPE>
            inline «stdVector»< API_TYPE > DecodeToVector(google::protobuf::RepeatedPtrField< PROTOBUF_TYPE > const& protobufInput)
            {
               «stdVector»< API_TYPE > entries;
               
               «stdForEach»( protobufInput.begin(), protobufInput.end(), [ &entries ]( PROTOBUF_TYPE const& protobufEntry )
               {  entries.push_back( Decode(protobufEntry) ); } );
               return entries;
            }
            
            template<typename PROTOBUF_TYPE, typename API_TYPE>
            inline «stdVector»< API_TYPE > DecodeToVector(google::protobuf::RepeatedField< PROTOBUF_TYPE > const& protobufInput)
            {
               «stdVector»< API_TYPE > entries;
               
               «stdForEach»( protobufInput.begin(), protobufInput.end(), [ &entries ]( PROTOBUF_TYPE const& protobufEntry )
               {  entries.push_back( Decode(protobufEntry) ); } );
               return entries;
            }
                        
            template<typename PROTOBUF_TYPE>
            inline «resolveSymbol("BTC::Commons::Core::AutoPtr")»<«cabException»> MakeException
            (
               PROTOBUF_TYPE const& protobufEntry
            )
            {
               EnsureFailableHandlers();
               
               const «cabString» message( protobufEntry.message().c_str() );
               const auto handler = faultHandlers.find( protobufEntry.exception() );
               
               auto exception = ( handler != faultHandlers.end() ) ? handler->second( message ) : «cabCreateUnique»<«cabException»>( message );
               exception->SetStackTrace( protobufEntry.stacktrace().c_str() );
               
               return exception;
            }
            
            template<typename PROTOBUF_TYPE>
            inline void SerializeException
            (
               const «cabException» &exception,
               PROTOBUF_TYPE & protobufItem
            )
            {
               EnsureFailableHandlers();
            
               auto match = «stdFindIf»(faultHandlers.begin(), faultHandlers.end(), [&](const «resolveSymbol("std::pair")»<const «stdString», «resolveSymbol("std::function")»<«resolveSymbol("BTC::Commons::Core::AutoPtr")»<«cabException»>(«cabString» const&)>> &item) -> bool
               {
               auto sampleException = item.second(""); // fetch sample exception to use it for type comparison!
               return ( typeid(*sampleException) == typeid(exception) );
               });
               if (match != faultHandlers.end())
               {
                  protobufItem->set_exception( match->first );
               }
               else
               {
                  protobufItem->set_exception( «resolveSymbol("CABTYPENAME")»(exception).GetChar() );
               }
               
               protobufItem->set_message( exception.GetMessageWithType().GetChar() );
               protobufItem->set_stacktrace( exception.GetStackTrace().GetChar() );
            }
            
            template<typename PROTOBUF_TYPE, typename API_TYPE >
            inline void DecodeFailable
            (
               google::protobuf::RepeatedPtrField< PROTOBUF_TYPE > const& protobufInput,
               typename «insertableTraits»< «failableHandle»< API_TYPE > >::Type &apiOutput
            )
            {
               «stdForEach»( protobufInput.begin(), protobufInput.end(), [&]( PROTOBUF_TYPE const& protobufEntry )
               {
                  if (protobufEntry.has_exception())
                  {
                     apiOutput.OnError( MakeException(protobufEntry) );
                  }
                  else
                  {
                     apiOutput.OnNext( DecodeFailable(protobufEntry) );
                  }
               } );
            
               apiOutput.OnCompleted();
            }
            
            template<typename PROTOBUF_TYPE, typename API_TYPE>
            inline «forwardConstIterator»< «failableHandle»<API_TYPE> >
            DecodeFailable
            (
               google::protobuf::RepeatedPtrField< PROTOBUF_TYPE > const& protobufInput
            )
            {
               typedef «failableHandle»<API_TYPE> ResultType;
            
               «resolveSymbol("BTC::Commons::Core::AutoPtr")»< «cabVector»< ResultType > > result( new «cabVector»< ResultType >() );
               «stdForEach»( protobufInput.begin(), protobufInput.end(), [ &result ]( PROTOBUF_TYPE const& protobufEntry )
               {
               if (protobufEntry.has_exception())
               {
                  result->Add( ResultType( MakeException(protobufEntry)) );
               }
               else
               {
                  result->Add( ResultType( DecodeFailable(protobufEntry) ) );
               }
               } );
               return «resolveSymbol("BTC::Commons::CoreExtras::MakeOwningForwardConstIterator")»< ResultType >( result.Move() );
            }
            
            template<typename API_TYPE, typename PROTOBUF_TYPE>
            inline void EncodeFailable
            (
               «forwardConstIterator»< «failableHandle»<API_TYPE> > apiInput,
               google::protobuf::RepeatedPtrField< PROTOBUF_TYPE >* const protobufOutput
            )
            {
               for ( ; apiInput; ++apiInput )
               {
                  «failableHandle»< API_TYPE > const& failableItem( *apiInput );
                  PROTOBUF_TYPE* const protobufItem( protobufOutput->Add() );
            
                  if (failableItem.HasException())
                  {
               try
               {
                  «failableHandle»< API_TYPE > item(failableItem);
                  item.Get();
               }               
               catch (const «resolveSymbol("BTC::Commons::Core::Exception")» «exceptionCatch("e")»)
               {
                  «maybeDelException("e")»
                  SerializeException(«exceptionAccess("e")», protobufItem);
               }
                  }
                  else
                  {
                     EncodeFailable(*failableItem, protobufItem);
                  }
               }
            }
            
            template<typename PROTOBUF_TYPE, typename API_TYPE>
            inline «stdVector»< «failableHandle»< API_TYPE > > DecodeFailableToVector(google::protobuf::RepeatedPtrField< PROTOBUF_TYPE > const& protobufInput)
            {
               «stdVector»< «failableHandle»< API_TYPE > > entries;
               
               «stdForEach»( protobufInput.begin(), protobufInput.end(), [ &entries ]( PROTOBUF_TYPE const& protobufEntry )
               {
                  if (protobufEntry.has_exception())
                  {
                     entries.emplace_back( MakeException(protobufEntry) );
                  }
                  else
                  {
                     entries.emplace_back( DecodeFailable(protobufEntry) );
                  }
               } );
               return entries;
            }
            
            template<typename API_TYPE, typename PROTOBUF_TYPE>
            inline void EncodeFailable(«stdVector»< «failableHandle»< API_TYPE > > const& apiInput, google::protobuf::RepeatedPtrField< PROTOBUF_TYPE >* const protobufOutput)
            {
               for ( auto const& failableItem : apiInput )
               {
                  PROTOBUF_TYPE* const protobufItem( protobufOutput->Add() );
                  if (failableItem.HasException())
                  {
                     try
                     {
                        «failableHandle»< API_TYPE > item(failableItem);
                        item.Get();
                     }
                     catch (const «cabException» «exceptionCatch("e")»)
                     {
                        «maybeDelException("e")»
                        SerializeException(«exceptionAccess("e")», protobufItem);
                     }
                  }
                  else
                  {
                     EncodeFailable(*failableItem, protobufItem);
                  }
               }
            }
            
            template<typename API_TYPE, typename PROTOBUF_TYPE>
            inline void Encode(«forwardConstIterator»< API_TYPE > apiInput, google::protobuf::RepeatedPtrField< PROTOBUF_TYPE >* const protobufOutput)
            {
               for ( ; apiInput; ++apiInput )
               {
                  API_TYPE const& apiItem( *apiInput );
                  PROTOBUF_TYPE* const protobufItem( protobufOutput->Add() );
                  
                  Encode(apiItem, protobufItem);
               }
            }
            
            template<typename API_TYPE, typename PROTOBUF_TYPE>
            inline void Encode(«forwardConstIterator»< API_TYPE > apiInput, google::protobuf::RepeatedField< PROTOBUF_TYPE >* const protobufOutput)
            {
               for ( ; apiInput; ++apiInput )
               {
                  API_TYPE const& apiItem( *apiInput );
                  PROTOBUF_TYPE* const protobufItem( protobufOutput->Add() );
                  
                  Encode(apiItem, protobufItem);
               }
            }
            
            template<typename API_TYPE, typename PROTOBUF_TYPE>
            inline void Encode(«stdVector»< API_TYPE > const& apiInput, google::protobuf::RepeatedPtrField< PROTOBUF_TYPE >* const protobufOutput)
            {
               for ( auto const& apiItem : apiInput )
               {
                  PROTOBUF_TYPE* const protobufItem( protobufOutput->Add() );
                  Encode(apiItem, protobufItem);
               }
            }
            
            template<typename API_TYPE, typename PROTOBUF_TYPE>
            inline void Encode(«stdVector»< API_TYPE > const& apiInput, google::protobuf::RepeatedField< PROTOBUF_TYPE >* protobufOutput)
            {
               for ( auto const& apiItem : apiInput )
               {
                  PROTOBUF_TYPE* const protobufItem( protobufOutput->Add() );
                  Encode(apiItem, protobufItem);
               }
            }
            
            template<typename PROTOBUF_TYPE, typename API_TYPE>
            inline void Decode(google::protobuf::RepeatedPtrField< PROTOBUF_TYPE > const& protobufInput, typename «resolveSymbol("BTC::Commons::CoreExtras::InsertableTraits")»< API_TYPE >::Type &apiOutput)
            {
               «stdForEach»( protobufInput.begin(), protobufInput.end(), [&]( PROTOBUF_TYPE const& protobufEntry )
               {  apiOutput.OnNext( Decode(protobufEntry) ); } );
            
               apiOutput.OnCompleted();
            }
            
            template<typename PROTOBUF_TYPE, typename API_TYPE>
            inline void Decode(google::protobuf::RepeatedField< PROTOBUF_TYPE > const& protobufInput, typename «resolveSymbol("BTC::Commons::CoreExtras::InsertableTraits")»< API_TYPE >::Type &apiOutput)
            {
               «stdForEach»( protobufInput.begin(), protobufInput.end(), [&]( PROTOBUF_TYPE const& protobufEntry )
               {  apiOutput.OnNext( Decode(protobufEntry) ); } );
            
               apiOutput.OnCompleted();
            }
            
            template<typename PROTOBUF_ENUM_TYPE, typename API_ENUM_TYPE>
            inline «forwardConstIterator»< API_ENUM_TYPE > Decode(google::protobuf::RepeatedField< google::protobuf::int32 > const& protobufInput)
            {
               typedef «insertableTraits»< API_ENUM_TYPE > APITypeTraits;
               auto entries = «createDefaultAsyncInsertable»< API_ENUM_TYPE >();
               auto future = entries->GetFuture();
               
               «stdForEach»( protobufInput.begin(), protobufInput.end(), [ &entries ]( google::protobuf::int32 const& protobufEntry )
               {  entries->OnNext( Decode(static_cast<PROTOBUF_ENUM_TYPE>(protobufEntry)) ); } );
               
               entries->OnCompleted();
               return future.Get();      
            }
            
            template<typename IDENTICAL_TYPE>
            inline IDENTICAL_TYPE Decode(IDENTICAL_TYPE const& protobufInput)
            {
               return protobufInput;
            }
            
            template<typename IDENTICAL_TYPE>
            inline void Encode(IDENTICAL_TYPE const& apiInput, IDENTICAL_TYPE * const protobufOutput)
            {
               *protobufOutput = apiInput;
            }
            
            template<typename PROTOBUF_TYPE, typename API_TYPE>
            inline void Encode(API_TYPE const& apiInput, PROTOBUF_TYPE * const protobufOutput)
            {
               *protobufOutput = static_cast<PROTOBUF_TYPE>( apiInput );
            }
            
            inline «stdVector»< «cabUuid» > DecodeUUIDToVector(google::protobuf::RepeatedPtrField< «stdString» > const& protobufInput)
            {
               «stdVector»< «cabUuid» > entries;
               «stdForEach»( protobufInput.begin(), protobufInput.end(), [ &entries ]( «stdString» const& protobufEntry )
               {  entries.push_back( DecodeUUID(protobufEntry) ); } );
               return entries;
            }
            
            inline «forwardConstIterator»< «cabUuid» > DecodeUUID(google::protobuf::RepeatedPtrField< «stdString» > const& protobufInput)
            {
               typedef «insertableTraits»< «cabUuid» > APITypeTraits;
               APITypeTraits::AutoPtrType entries( «createDefaultAsyncInsertable»< «cabUuid» >() );
               APITypeTraits::FutureType future( entries->GetFuture() );
            
               «stdForEach»( protobufInput.begin(), protobufInput.end(), [ &entries ]( «stdString» const& protobufEntry )
               {  entries->OnNext(DecodeUUID(protobufEntry)); });
            
               entries->OnCompleted();
               return future.Get();
            }
            
            inline void DecodeUUID(google::protobuf::RepeatedPtrField< «stdString» > const& protobufInput, «insertableTraits»< «cabUuid» >::Type &apiOutput)
            {
               «stdForEach»( protobufInput.begin(), protobufInput.end(), [&]( «stdString» const& protobufEntry )
               {  apiOutput.OnNext( DecodeUUID(protobufEntry) ); } );
            
               apiOutput.OnCompleted();
            }
            
            inline void Encode(«cabUuid» const& apiInput, «stdString» * const protobufOutput)
            {
               «resolveSymbol("BTC::Commons::Core::UInt32")» param1 = 0;
               «resolveSymbol("BTC::Commons::Core::UInt16")» param2 = 0;
               BTC::Commons::Core::UInt16 param3 = 0;
               «resolveSymbol("std::array")»<«resolveSymbol("BTC::Commons::Core::UInt8")», 8> param4 = {0};
            
               apiInput.ExtractComponents(&param1, &param2, &param3, param4.data());
            
               protobufOutput->resize(16); // UUID is exactly 16 bytes long
            
               «resolveSymbol("std::copy")»(static_cast<const char*>(static_cast<const void*>(&param1)),
               static_cast<const char*>(static_cast<const void*>(&param1)) + 4,
               protobufOutput->begin());
            
               std::copy(static_cast<const char*>(static_cast<const void*>(&param2)),
                  static_cast<const char*>(static_cast<const void*>(&param2)) + 2,
                  protobufOutput->begin() + 4);
            
               std::copy(static_cast<const char*>(static_cast<const void*>(&param3)),
                  static_cast<const char*>(static_cast<const void*>(&param3)) + 2,
                  protobufOutput->begin() + 6);
            
               std::copy( param4.begin(), param4.end(), protobufOutput->begin() + 8);
            }
            
            inline «cabUuid» DecodeUUID(«stdString» const& protobufInput)
            {
               «resolveSymbol("assert")»( protobufInput.size() == 16 ); // lower half + upper half = 16 bytes!
               
               «resolveSymbol("std::array")»<unsigned char, 16> rawBytes = {0};
               «resolveSymbol("std::copy")»( protobufInput.begin(), protobufInput.end(), rawBytes.begin() );
            
               «resolveSymbol("BTC::Commons::Core::UInt32")» param1 = (rawBytes[0] << 0 | rawBytes[1] << 8 | rawBytes[2] << 16 | rawBytes[3] << 24);
               «resolveSymbol("BTC::Commons::Core::UInt16")» param2 = (rawBytes[4] << 0 | rawBytes[5] << 8);
               BTC::Commons::Core::UInt16 param3 = (rawBytes[6] << 0 | rawBytes[7] << 8);
            
               std::array<«resolveSymbol("BTC::Commons::Core::UInt8")», 8> param4 = {0};
               std::copy(rawBytes.begin() + 8, rawBytes.end(), param4.begin());
            
               return «cabUuid»::MakeFromComponents(param1, param2, param3, param4.data());
            }
        '''

    }
    
    def generateCodec(AbstractTypeReference type, AbstractContainerDeclaration owner)
    {
        val apiTypeName = resolve(type)
        /* TODO change such that ProtobufType does not need to be passed, it is irrelevant here */
        val protoTypeName = typeResolver.resolveProtobuf(type, ProtobufType.REQUEST)

        '''
            inline «apiTypeName» Decode(«protoTypeName» const& protobufInput)
            {
               «makeDecode(type, owner)»
            }
            
            «IF type instanceof EnumDeclaration»
                inline «protoTypeName» Encode(«apiTypeName» const& apiInput)
            «ELSE»
                inline void Encode(«apiTypeName» const& apiInput, «protoTypeName» * const protobufOutput)
            «ENDIF»
            {
               «makeEncode(type)»
            }
        '''
    }
    
    def generateFailableCodec(AbstractTypeReference type, AbstractContainerDeclaration owner)
    {
        val apiTypeName = resolve(type)
        val protoFailableTypeName = typeResolver.resolveFailableProtobufType(type, owner)
        /* TODO change such that ProtobufType does not need to be passed, it is irrelevant here */
        val protoTypeName = typeResolver.resolveProtobuf(type, ProtobufType.REQUEST)
        
        '''
            inline «apiTypeName» DecodeFailable(«protoFailableTypeName» const& protobufEntry)
            {
               return «typeResolver.resolveDecode(paramBundle, type, owner)»(protobufEntry.value());
            }
            
            inline void EncodeFailable(«apiTypeName» const& apiInput, «protoFailableTypeName» * const protobufOutput)
            {
               «IF isMutableField(type)»
                   «resolveEncode(type)»(apiInput, protobufOutput->mutable_value());
               «ELSE»
                   «protoTypeName» value;
                   «resolveEncode(type)»(apiInput, &value);
                   protobufOutput->set_value(value);
               «ENDIF»
            }
        '''
    }
    
    private def dispatch String makeDecode(StructDeclaration element, AbstractContainerDeclaration container)
    {
        '''
            «resolve(element)» apiOutput;
            «FOR member : element.allMembers»
                «makeDecodeMember(member, container)»
            «ENDFOR»
            return apiOutput;
        '''
    }

    private def dispatch String makeDecode(ExceptionDeclaration element, AbstractContainerDeclaration container)
    {
        throw new UnsupportedOperationException("Decode for exception types with custom attributes is unsupported right now")

        // TODO this must be fixed, and the service fault registration must be changed to use this        
//        '''
//            «resolve(element)» apiOutput;
//            «FOR member : element.allMembers»
//                «makeDecodeMember(member, container)»
//            «ENDFOR»
//            return apiOutput;
//        '''
    }

    private def dispatch String makeDecode(EnumDeclaration element, AbstractContainerDeclaration container)
    {
        '''
            «FOR enumValue : element.containedIdentifiers»
                «IF enumValue != element.containedIdentifiers.head»else «ENDIF»if (protobufInput == «typeResolver.resolveProtobuf(element, ProtobufType.REQUEST)»::«enumValue»)
                   return «resolve(element)»::«enumValue»;
            «ENDFOR»
            
            «resolveSymbol("CABTHROW_V2")»(«resolveSymbol("BTC::Commons::Core::InvalidArgumentException")»("Unknown enum value!"));
        '''
    }

    private def String makeDecodeMember(MemberElementWrapper element, AbstractContainerDeclaration container)
    {
        val useCodec = GeneratorUtil.useCodec(element.type, ArtifactNature.CPP)
        val isPointer = useSmartPointer(element.container, element.type)
        val isOptional = element.optional
        val isSequence = element.type.isSequenceType
        val protobufName = element.name.asCppProtobufName
        val isFailable = element.type.isFailable
        val codecName = if (useCodec) typeResolver.resolveDecode(paramBundle, element.type, container, !isFailable)

        '''
            «IF isOptional && !isSequence»if (protobufInput.has_«protobufName»())«ENDIF»
            «IF isOptional && !isSequence»   «ENDIF»apiOutput.«element.name.asMember» = «IF isPointer»«resolveSymbol("std::make_shared")»< «toText(element.type, null)» >( «ENDIF»«IF useCodec»«codecName»( «ENDIF»protobufInput.«protobufName»()«IF useCodec» )«ENDIF»«IF isPointer» )«ENDIF»;
        '''
    }

    private def dispatch String makeDecode(AbstractType element, AbstractContainerDeclaration container)
    {
        if (element.referenceType !== null)
            return makeDecode(element.referenceType, container)
    }

    private def dispatch String makeEncode(StructDeclaration element)
    {
        '''
            «FOR member : element.allMembers»
                «makeEncodeMember(member)»
            «ENDFOR»
        '''
    }

    private def dispatch String makeEncode(ExceptionDeclaration element)
    {
        '''
            «FOR member : element.allMembers»
                «makeEncodeMember(member)»
            «ENDFOR»
        '''
    }

    private def dispatch String makeEncode(EnumDeclaration element)
    {
        '''
            «FOR enumValue : element.containedIdentifiers»
                «IF enumValue != element.containedIdentifiers.head»else «ENDIF»if (apiInput == «resolve(element)»::«enumValue»)
                   return «typeResolver.resolveProtobuf(element, ProtobufType.RESPONSE)»::«enumValue»;
            «ENDFOR»
            
            «resolveSymbol("CABTHROW_V2")»(«resolveSymbol("BTC::Commons::Core::InvalidArgumentException")»("Unknown enum value!"));
        '''
    }

    private def String makeEncodeMember(MemberElementWrapper element)
    {
        val useCodec = GeneratorUtil.useCodec(element.type, ArtifactNature.CPP)
        val optional = element.optional
        val isEnum = element.type.isEnumType
        val isPointer = useSmartPointer(element.container, element.type)
        '''
            «IF optional»if (apiInput.«element.name.asMember»«IF isPointer» != nullptr«ELSE».GetIsPresent()«ENDIF»)«ENDIF»
            «IF useCodec && !(element.type.isByte || element.type.isInt16 || element.type.isChar || isEnum)»
                «IF optional»   «ENDIF»«resolveEncode(element.type)»( «IF optional»*( «ENDIF»apiInput.«element.name.asMember»«IF optional && !isPointer».GetValue()«ENDIF»«IF optional» )«ENDIF», protobufOutput->mutable_«element.name.asCppProtobufName»() );
            «ELSE»
                «IF optional»   «ENDIF»protobufOutput->set_«element.name.asCppProtobufName»(«IF isEnum»«resolveEncode(element.type)»( «ENDIF»«IF optional»*«ENDIF»apiInput.«element.name.asMember»«IF optional && !isPointer».GetValue()«ENDIF» «IF isEnum»)«ENDIF»);
            «ENDIF»
        '''
    }

    private def dispatch String makeEncode(AbstractType element)
    {
        if (element.referenceType !== null)
            return makeEncode(element.referenceType)
    }

    private def String resolveEncode(AbstractTypeReference element)
    {
        if (element.isFailable)
            "EncodeFailable"
        else if (element.isUUIDType)
            "Encode"
        else
            '''«typeResolver.resolveCodecNS(paramBundle, element)»::Encode'''
    }

    private static def boolean isMutableField(AbstractTypeReference type)
    {
        val ultimateType = type.ultimateType

        return GeneratorUtil.useCodec(ultimateType, ArtifactNature.CPP) &&
            !(ultimateType.isByte || ultimateType.isInt16 || ultimateType.isChar || ultimateType.isEnumType)
    }

    def generateHeaderFileBody(AbstractContainerDeclaration owner)
    {
        // collect all contained distinct types which need conversion
        val nestedTypes = GeneratorUtil.getEncodableTypes(owner)

        val cabUuid = resolveSymbol("BTC::Commons::CoreExtras::UUID")
        val forwardConstIterator = resolveSymbol("BTC::Commons::Core::ForwardConstIterator")
        val stdVector = resolveSymbol("std::vector")
        val insertableTraits = resolveSymbol("BTC::Commons::CoreExtras::InsertableTraits")
        val stdString = resolveSymbol("std::string")
        val stdFunction = resolveSymbol("std::function")
        val failableHandle = resolveSymbol("BTC::Commons::CoreExtras::FailableHandle")
        val cabException = resolveSymbol("BTC::Commons::Core::Exception")
        val cabAutoPtr = resolveSymbol("BTC::Commons::Core::AutoPtr")
        val cabString = resolveSymbol("BTC::Commons::Core::String")

        val failableTypes = GeneratorUtil.getFailableTypes(owner)

        // always include corresponding *.pb.h file due to local failable types definitions
        addTargetInclude(moduleStructureStrategy.getIncludeFilePath(
            paramBundle.moduleStack,
            ProjectType.PROTOBUF,
            GeneratorUtil.getPbFileName(owner),
            HeaderType.PROTOBUF_HEADER
        ))

        '''
            namespace «GeneratorUtil.getCodecName(owner)»
            {
               static «resolveSymbol("std::once_flag")» registerFaultHandlers;
               static «resolveSymbol("std::map")»<«stdString», «stdFunction»< «cabAutoPtr»<«cabException»>(«cabString» const&)> > faultHandlers;
               
               // forward declarations
               template<typename PROTOBUF_TYPE, typename API_TYPE>
               «forwardConstIterator»< API_TYPE > Decode(google::protobuf::RepeatedPtrField< PROTOBUF_TYPE > const& protobufInput);
               
               template<typename PROTOBUF_TYPE, typename API_TYPE>
               «forwardConstIterator»< API_TYPE > Decode(google::protobuf::RepeatedField< PROTOBUF_TYPE > const& protobufInput);
               
               template<typename PROTOBUF_TYPE, typename API_TYPE>
               «stdVector»< API_TYPE > DecodeToVector(google::protobuf::RepeatedPtrField< PROTOBUF_TYPE > const& protobufInput);
            
               template<typename PROTOBUF_TYPE, typename API_TYPE>
               «stdVector»< API_TYPE > DecodeToVector(google::protobuf::RepeatedField< PROTOBUF_TYPE > const& protobufInput);
               
               void EnsureFailableHandlers();
               
               template<typename PROTOBUF_TYPE>
               «resolveSymbol("BTC::Commons::Core::AutoPtr")»<«cabException»> MakeException
               (
               PROTOBUF_TYPE const& protobufEntry
               );
               
               template<typename PROTOBUF_TYPE>
               void SerializeException
               (
                  const «cabException» &exception,
                  PROTOBUF_TYPE & protobufItem
               );
               
               template<typename PROTOBUF_TYPE, typename API_TYPE >
               void DecodeFailable
               (
                  google::protobuf::RepeatedPtrField< PROTOBUF_TYPE > const& protobufInput,
                  typename «insertableTraits»< «failableHandle»< API_TYPE > >::Type &apiOutput
               );
               
               template<typename PROTOBUF_TYPE, typename API_TYPE>
               «forwardConstIterator»< «failableHandle»<API_TYPE> >
               DecodeFailable
               (
                  google::protobuf::RepeatedPtrField< PROTOBUF_TYPE > const& protobufInput
               );
               
               template<typename API_TYPE, typename PROTOBUF_TYPE>
               void EncodeFailable
               (
                  «forwardConstIterator»< «failableHandle»<API_TYPE> > apiInput,
                  google::protobuf::RepeatedPtrField< PROTOBUF_TYPE >* const protobufOutput
               );
               
               template<typename PROTOBUF_TYPE, typename API_TYPE>
               «stdVector»< «failableHandle»< API_TYPE > > DecodeFailableToVector(google::protobuf::RepeatedPtrField< PROTOBUF_TYPE > const& protobufInput);
               
               template<typename API_TYPE, typename PROTOBUF_TYPE>
               void EncodeFailable(«stdVector»< «failableHandle»< API_TYPE > > const& apiInput, google::protobuf::RepeatedPtrField< PROTOBUF_TYPE >* const protobufOutput);
               
               template<typename API_TYPE, typename PROTOBUF_TYPE>
               void Encode(«forwardConstIterator»< API_TYPE > apiInput, google::protobuf::RepeatedPtrField< PROTOBUF_TYPE >* const protobufOutput);
               
               template<typename API_TYPE, typename PROTOBUF_TYPE>
               void Encode(«forwardConstIterator»< API_TYPE > apiInput, google::protobuf::RepeatedField< PROTOBUF_TYPE >* const protobufOutput);
               
               template<typename API_TYPE, typename PROTOBUF_TYPE>
               void Encode(«stdVector»< API_TYPE > const& apiInput, google::protobuf::RepeatedPtrField< PROTOBUF_TYPE >* const protobufOutput);
               
               template<typename API_TYPE, typename PROTOBUF_TYPE>
               void Encode(«stdVector»< API_TYPE > const& apiInput, google::protobuf::RepeatedField< PROTOBUF_TYPE >* protobufOutput);
               
               template<typename IDENTICAL_TYPE>
               IDENTICAL_TYPE Decode(IDENTICAL_TYPE const& protobufInput);
               
               template<typename PROTOBUF_TYPE, typename API_TYPE>
               void Encode(API_TYPE const& apiInput, PROTOBUF_TYPE * const protobufOutput);
               
               template<typename PROTOBUF_TYPE, typename API_TYPE>
               void Decode(google::protobuf::RepeatedPtrField< PROTOBUF_TYPE > const& protobufInput, typename «insertableTraits»< API_TYPE >::Type &apiOutput);
               
               template<typename PROTOBUF_TYPE, typename API_TYPE>
               void Decode(google::protobuf::RepeatedField< PROTOBUF_TYPE > const& protobufInput, typename «insertableTraits»< API_TYPE >::Type &apiOutput);
               
               template<typename PROTOBUF_ENUM_TYPE, typename API_ENUM_TYPE>
               «forwardConstIterator»< API_ENUM_TYPE > Decode(google::protobuf::RepeatedField< google::protobuf::int32 > const& protobufInput);
               
               template<typename IDENTICAL_TYPE>
               void Encode(IDENTICAL_TYPE const& apiInput, IDENTICAL_TYPE * const protobufOutput);
               
               «stdVector»< «cabUuid» > DecodeUUIDToVector(google::protobuf::RepeatedPtrField< «stdString» > const& protobufInput);
               
               «forwardConstIterator»< «cabUuid» > DecodeUUID(google::protobuf::RepeatedPtrField< «stdString» > const& protobufInput);
            
               void DecodeUUID(google::protobuf::RepeatedPtrField< «stdString» > const& protobufInput, «insertableTraits»< «cabUuid» >::Type &apiOutput);
               
               «cabUuid» DecodeUUID(«stdString» const& protobufInput);
               
               void Encode(«cabUuid» const& apiInput, «stdString» * const protobufOutput);
               
               «FOR type : nestedTypes»
                   «val apiTypeName = resolve(type)»
                   «/* TODO change such that ProtobufType does not need to be passed, it is irrelevant here */»
                   «val protoTypeName = typeResolver.resolveProtobuf(type, ProtobufType.REQUEST)»
                   «apiTypeName» Decode(«protoTypeName» const& protobufInput);
                   
                   «IF type instanceof EnumDeclaration»
                       «protoTypeName» Encode(«apiTypeName» const& apiInput);
                   «ELSE»
                       void Encode(«apiTypeName» const& apiInput, «protoTypeName» * const protobufOutput);
                   «ENDIF»
               «ENDFOR»
               
               «FOR type : failableTypes»
                   «val apiTypeName = resolve(type)»
                   «val protoTypeName = typeResolver.resolveFailableProtobufType(type, owner)»
                   «apiTypeName» DecodeFailable(«protoTypeName» const& protobufInput);
                   
                   void EncodeFailable(«apiTypeName» const& apiInput, «protoTypeName» * const protobufOutput);
               «ENDFOR»
               
               // inline implementations
               «generateHCodecInline(owner, nestedTypes)»
            }
        '''
    }

}
