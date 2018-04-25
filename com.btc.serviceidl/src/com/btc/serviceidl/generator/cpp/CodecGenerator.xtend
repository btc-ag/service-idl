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
import com.btc.serviceidl.generator.common.TransformType
import com.btc.serviceidl.idl.AbstractType
import com.btc.serviceidl.idl.EnumDeclaration
import com.btc.serviceidl.idl.ExceptionDeclaration
import com.btc.serviceidl.idl.StructDeclaration
import com.btc.serviceidl.util.Constants
import com.btc.serviceidl.util.MemberElementWrapper
import org.eclipse.emf.ecore.EObject
import org.eclipse.xtend.lib.annotations.Accessors

import static extension com.btc.serviceidl.generator.common.FileTypeExtensions.*
import static extension com.btc.serviceidl.generator.cpp.ProtobufUtil.*
import static extension com.btc.serviceidl.generator.cpp.TypeResolverExtensions.*
import static extension com.btc.serviceidl.generator.cpp.Util.*
import static extension com.btc.serviceidl.util.Extensions.*

@Accessors
class CodecGenerator extends BasicCppGenerator
{
    def private generateHCodecInline(EObject owner, Iterable<EObject> nested_types)
    {
        val cab_uuid = resolveCAB("BTC::Commons::CoreExtras::UUID")
        val forward_const_iterator = resolveCAB("BTC::Commons::Core::ForwardConstIterator")
        val std_vector = resolveSTL("std::vector")
        val std_string = resolveSTL("std::string")
        val std_for_each = resolveSTL("std::for_each")
        val create_default_async_insertable = resolveCAB("BTC::Commons::FutureUtil::CreateDefaultAsyncInsertable")
        val insertable_traits = resolveCAB("BTC::Commons::CoreExtras::InsertableTraits")
        val failable_handle = resolveCAB("BTC::Commons::CoreExtras::FailableHandle")
        val cab_exception = resolveCAB("BTC::Commons::Core::Exception")
        val cab_vector = resolveCAB("BTC::Commons::Core::Vector")
        val cab_del_exception = resolveCAB("BTC::Commons::Core::DelException")
        val cab_string = resolveCAB("BTC::Commons::Core::String")
        val cab_create_unique = resolveCAB("BTC::Commons::Core::CreateUnique")
        val std_find_if = resolveSTL("std::find_if")

        val failable_types = GeneratorUtil.getFailableTypes(owner)

        '''
            template<typename PROTOBUF_TYPE, typename API_TYPE>
            inline «forward_const_iterator»< API_TYPE > Decode(google::protobuf::RepeatedPtrField< PROTOBUF_TYPE > const& protobuf_input)
            {
               typedef «insertable_traits»< API_TYPE > APITypeTraits;
               APITypeTraits::AutoPtrType entries( «create_default_async_insertable»< API_TYPE >() );
               APITypeTraits::FutureType future( entries->GetFuture() );
               
               «std_for_each»( protobuf_input.begin(), protobuf_input.end(), [ &entries ]( PROTOBUF_TYPE const& protobuf_entry )
               {  entries->OnNext( Decode(protobuf_entry) ); } );
               
               entries->OnCompleted();
               return future.Get();
            }
            
            template<typename PROTOBUF_TYPE, typename API_TYPE>
            inline «forward_const_iterator»< API_TYPE > Decode(google::protobuf::RepeatedField< PROTOBUF_TYPE > const& protobuf_input)
            {
               typedef «insertable_traits»< API_TYPE > APITypeTraits;
               APITypeTraits::AutoPtrType entries( «create_default_async_insertable»< API_TYPE >() );
               APITypeTraits::FutureType future( entries->GetFuture() );
               
               «std_for_each»( protobuf_input.begin(), protobuf_input.end(), [ &entries ]( PROTOBUF_TYPE const& protobuf_entry )
               {  entries->OnNext( Decode(protobuf_entry) ); } );
               
               entries->OnCompleted();
               return future.Get();
            }
            
            template<typename PROTOBUF_TYPE, typename API_TYPE>
            inline «std_vector»< API_TYPE > DecodeToVector(google::protobuf::RepeatedPtrField< PROTOBUF_TYPE > const& protobuf_input)
            {
               «std_vector»< API_TYPE > entries;
               
               «std_for_each»( protobuf_input.begin(), protobuf_input.end(), [ &entries ]( PROTOBUF_TYPE const& protobuf_entry )
               {  entries.push_back( Decode(protobuf_entry) ); } );
               return entries;
            }
            
            template<typename PROTOBUF_TYPE, typename API_TYPE>
            inline «std_vector»< API_TYPE > DecodeToVector(google::protobuf::RepeatedField< PROTOBUF_TYPE > const& protobuf_input)
            {
               «std_vector»< API_TYPE > entries;
               
               «std_for_each»( protobuf_input.begin(), protobuf_input.end(), [ &entries ]( PROTOBUF_TYPE const& protobuf_entry )
               {  entries.push_back( Decode(protobuf_entry) ); } );
               return entries;
            }
            
            inline void EnsureFailableHandlers()
            {
               «resolveSTL("std::call_once")»(register_fault_handlers, [&]()
               {
                  «FOR exception : com.btc.serviceidl.util.Util.getFailableExceptions(owner)»
                      «val exception_type = resolve(exception)»
                      «val exception_name = com.btc.serviceidl.util.Util.getCommonExceptionName(exception, qualified_name_provider)»
                      fault_handlers["«exception_name»"] = [](«cab_string» const& msg) { return «cab_create_unique»<«exception_type»>(msg); };
                  «ENDFOR»
                  
                  // most commonly used exception types
                  «val default_exceptions = typeResolver.defaultExceptionRegistration»
                  «FOR exception : default_exceptions.keySet.sort»
                      fault_handlers["«exception»"] = [](«cab_string» const& msg) { return «cab_create_unique»<«default_exceptions.get(exception)»>(msg); };
                  «ENDFOR»
               });
            }
            
            template<typename PROTOBUF_TYPE>
            inline «resolveCAB("BTC::Commons::Core::AutoPtr")»<«cab_exception»> MakeException
            (
               PROTOBUF_TYPE const& protobuf_entry
            )
            {
               EnsureFailableHandlers();
               
               const «cab_string» message( protobuf_entry.message().c_str() );
               const auto handler = fault_handlers.find( protobuf_entry.exception() );
               
               auto exception = ( handler != fault_handlers.end() ) ? handler->second( message ) : «cab_create_unique»<«cab_exception»>( message );
               exception->SetStackTrace( protobuf_entry.stacktrace().c_str() );
               
               return exception;
            }
            
            template<typename PROTOBUF_TYPE>
            inline void SerializeException
            (
               const «cab_exception» &exception,
               PROTOBUF_TYPE & protobuf_item
            )
            {
               EnsureFailableHandlers();
            
               auto match = «std_find_if»(fault_handlers.begin(), fault_handlers.end(), [&](const «resolveSTL("std::pair")»<const «std_string», «resolveSTL("std::function")»<«resolveCAB("BTC::Commons::Core::AutoPtr")»<«cab_exception»>(«cab_string» const&)>> &item) -> bool
               {
               auto sample_exception = item.second(""); // fetch sample exception to use it for type comparison!
               return ( typeid(*sample_exception) == typeid(exception) );
               });
               if (match != fault_handlers.end())
               {
                  protobuf_item->set_exception( match->first );
               }
               else
               {
                  protobuf_item->set_exception( «resolveCAB("CABTYPENAME")»(exception).GetChar() );
               }
               
               protobuf_item->set_message( exception.GetMessageWithType().GetChar() );
               protobuf_item->set_stacktrace( exception.GetStackTrace().GetChar() );
            }
            
            template<typename PROTOBUF_TYPE, typename API_TYPE >
            inline void DecodeFailable
            (
               google::protobuf::RepeatedPtrField< PROTOBUF_TYPE > const& protobuf_input,
               typename «insertable_traits»< «failable_handle»< API_TYPE > >::Type &api_output
            )
            {
               «std_for_each»( protobuf_input.begin(), protobuf_input.end(), [&]( PROTOBUF_TYPE const& protobuf_entry )
               {
                  if (protobuf_entry.has_exception())
                  {
                     api_output.OnError( MakeException(protobuf_entry) );
                  }
                  else
                  {
                     api_output.OnNext( DecodeFailable(protobuf_entry) );
                  }
               } );
            
               api_output.OnCompleted();
            }
            
            template<typename PROTOBUF_TYPE, typename API_TYPE>
            inline «forward_const_iterator»< «failable_handle»<API_TYPE> >
            DecodeFailable
            (
               google::protobuf::RepeatedPtrField< PROTOBUF_TYPE > const& protobuf_input
            )
            {
               typedef «failable_handle»<API_TYPE> ResultType;
            
               «resolveCAB("BTC::Commons::Core::AutoPtr")»< «cab_vector»< ResultType > > result( new «cab_vector»< ResultType >() );
               «std_for_each»( protobuf_input.begin(), protobuf_input.end(), [ &result ]( PROTOBUF_TYPE const& protobuf_entry )
               {
               if (protobuf_entry.has_exception())
               {
                  result->Add( ResultType( MakeException(protobuf_entry)) );
               }
               else
               {
                  result->Add( ResultType( DecodeFailable(protobuf_entry) ) );
               }
               } );
               return «resolveCAB("BTC::Commons::CoreExtras::MakeOwningForwardConstIterator")»< ResultType >( result.Move() );
            }
            
            template<typename API_TYPE, typename PROTOBUF_TYPE>
            inline void EncodeFailable
            (
               «forward_const_iterator»< «failable_handle»<API_TYPE> > api_input,
               google::protobuf::RepeatedPtrField< PROTOBUF_TYPE >* const protobuf_output
            )
            {
               for ( ; api_input; ++api_input )
               {
                  «failable_handle»< API_TYPE > const& failable_item( *api_input );
                  PROTOBUF_TYPE* const protobuf_item( protobuf_output->Add() );
            
                  if (failable_item.HasException())
                  {
               try
               {
                  «failable_handle»< API_TYPE > item(failable_item);
                  item.Get();
               }
               catch («resolveCAB("BTC::Commons::Core::Exception")» const * e)
               {
                  «cab_del_exception» _(e);
                  SerializeException(*e, protobuf_item);
               }
                  }
                  else
                  {
                     EncodeFailable(*failable_item, protobuf_item);
                  }
               }
            }
            
            template<typename PROTOBUF_TYPE, typename API_TYPE>
            inline «std_vector»< «failable_handle»< API_TYPE > > DecodeFailableToVector(google::protobuf::RepeatedPtrField< PROTOBUF_TYPE > const& protobuf_input)
            {
               «std_vector»< «failable_handle»< API_TYPE > > entries;
               
               «std_for_each»( protobuf_input.begin(), protobuf_input.end(), [ &entries ]( PROTOBUF_TYPE const& protobuf_entry )
               {
                  if (protobuf_entry.has_exception())
                  {
                     entries.emplace_back( MakeException(protobuf_entry) );
                  }
                  else
                  {
                     entries.emplace_back( DecodeFailable(protobuf_entry) );
                  }
               } );
               return entries;
            }
            
            template<typename API_TYPE, typename PROTOBUF_TYPE>
            inline void EncodeFailable(«std_vector»< «failable_handle»< API_TYPE > > const& api_input, google::protobuf::RepeatedPtrField< PROTOBUF_TYPE >* const protobuf_output)
            {
               for ( auto const& failable_item : api_input )
               {
                  PROTOBUF_TYPE* const protobuf_item( protobuf_output->Add() );
                  if (failable_item.HasException())
                  {
                     try
                     {
                        «failable_handle»< API_TYPE > item(failable_item);
                        item.Get();
                     }
                     catch («cab_exception» const * e)
                     {
                        «cab_del_exception» _(e);
                        SerializeException(*e, protobuf_item);
                     }
                  }
                  else
                  {
                     EncodeFailable(*failable_item, protobuf_item);
                  }
               }
            }
            
            template<typename API_TYPE, typename PROTOBUF_TYPE>
            inline void Encode(«forward_const_iterator»< API_TYPE > api_input, google::protobuf::RepeatedPtrField< PROTOBUF_TYPE >* const protobuf_output)
            {
               for ( ; api_input; ++api_input )
               {
                  API_TYPE const& api_item( *api_input );
                  PROTOBUF_TYPE* const protobuf_item( protobuf_output->Add() );
                  
                  Encode(api_item, protobuf_item);
               }
            }
            
            template<typename API_TYPE, typename PROTOBUF_TYPE>
            inline void Encode(«forward_const_iterator»< API_TYPE > api_input, google::protobuf::RepeatedField< PROTOBUF_TYPE >* const protobuf_output)
            {
               for ( ; api_input; ++api_input )
               {
                  API_TYPE const& api_item( *api_input );
                  PROTOBUF_TYPE* const protobuf_item( protobuf_output->Add() );
                  
                  Encode(api_item, protobuf_item);
               }
            }
            
            template<typename API_TYPE, typename PROTOBUF_TYPE>
            inline void Encode(«std_vector»< API_TYPE > const& api_input, google::protobuf::RepeatedPtrField< PROTOBUF_TYPE >* const protobuf_output)
            {
               for ( auto const& api_item : api_input )
               {
                  PROTOBUF_TYPE* const protobuf_item( protobuf_output->Add() );
                  Encode(api_item, protobuf_item);
               }
            }
            
            template<typename API_TYPE, typename PROTOBUF_TYPE>
            inline void Encode(«std_vector»< API_TYPE > const& api_input, google::protobuf::RepeatedField< PROTOBUF_TYPE >* protobuf_output)
            {
               for ( auto const& api_item : api_input )
               {
                  PROTOBUF_TYPE* const protobuf_item( protobuf_output->Add() );
                  Encode(api_item, protobuf_item);
               }
            }
            
            template<typename PROTOBUF_TYPE, typename API_TYPE>
            inline void Decode(google::protobuf::RepeatedPtrField< PROTOBUF_TYPE > const& protobuf_input, typename «resolveCAB("BTC::Commons::CoreExtras::InsertableTraits")»< API_TYPE >::Type &api_output)
            {
               «std_for_each»( protobuf_input.begin(), protobuf_input.end(), [&]( PROTOBUF_TYPE const& protobuf_entry )
               {  api_output.OnNext( Decode(protobuf_entry) ); } );
            
               api_output.OnCompleted();
            }
            
            template<typename PROTOBUF_TYPE, typename API_TYPE>
            inline void Decode(google::protobuf::RepeatedField< PROTOBUF_TYPE > const& protobuf_input, typename «resolveCAB("BTC::Commons::CoreExtras::InsertableTraits")»< API_TYPE >::Type &api_output)
            {
               «std_for_each»( protobuf_input.begin(), protobuf_input.end(), [&]( PROTOBUF_TYPE const& protobuf_entry )
               {  api_output.OnNext( Decode(protobuf_entry) ); } );
            
               api_output.OnCompleted();
            }
            
            template<typename PROTOBUF_ENUM_TYPE, typename API_ENUM_TYPE>
            inline «forward_const_iterator»< API_ENUM_TYPE > Decode(google::protobuf::RepeatedField< google::protobuf::int32 > const& protobuf_input)
            {
               typedef «insertable_traits»< API_ENUM_TYPE > APITypeTraits;
               APITypeTraits::AutoPtrType entries( «create_default_async_insertable»< API_ENUM_TYPE >() );
               APITypeTraits::FutureType future( entries->GetFuture() );
               
               «std_for_each»( protobuf_input.begin(), protobuf_input.end(), [ &entries ]( google::protobuf::int32 const& protobuf_entry )
               {  entries->OnNext( Decode(static_cast<PROTOBUF_ENUM_TYPE>(protobuf_entry)) ); } );
               
               entries->OnCompleted();
               return future.Get();      
            }
            
            template<typename IDENTICAL_TYPE>
            inline IDENTICAL_TYPE Decode(IDENTICAL_TYPE const& protobuf_input)
            {
               return protobuf_input;
            }
            
            template<typename IDENTICAL_TYPE>
            inline void Encode(IDENTICAL_TYPE const& api_input, IDENTICAL_TYPE * const protobuf_output)
            {
               *protobuf_output = api_input;
            }
            
            template<typename PROTOBUF_TYPE, typename API_TYPE>
            inline void Encode(API_TYPE const& api_input, PROTOBUF_TYPE * const protobuf_output)
            {
               *protobuf_output = static_cast<PROTOBUF_TYPE>( api_input );
            }
            
            inline «std_vector»< «cab_uuid» > DecodeUUIDToVector(google::protobuf::RepeatedPtrField< «std_string» > const& protobuf_input)
            {
               «std_vector»< «cab_uuid» > entries;
               «std_for_each»( protobuf_input.begin(), protobuf_input.end(), [ &entries ]( «std_string» const& protobuf_entry )
               {  entries.push_back( DecodeUUID(protobuf_entry) ); } );
               return entries;
            }
            
            inline «forward_const_iterator»< «cab_uuid» > DecodeUUID(google::protobuf::RepeatedPtrField< «std_string» > const& protobuf_input)
            {
               typedef «insertable_traits»< «cab_uuid» > APITypeTraits;
               APITypeTraits::AutoPtrType entries( «create_default_async_insertable»< «cab_uuid» >() );
               APITypeTraits::FutureType future( entries->GetFuture() );
            
               «std_for_each»( protobuf_input.begin(), protobuf_input.end(), [ &entries ]( «std_string» const& protobuf_entry )
               {  entries->OnNext(DecodeUUID(protobuf_entry)); });
            
               entries->OnCompleted();
               return future.Get();
            }
            
            inline void DecodeUUID(google::protobuf::RepeatedPtrField< «std_string» > const& protobuf_input, «insertable_traits»< «cab_uuid» >::Type &api_output)
            {
               «std_for_each»( protobuf_input.begin(), protobuf_input.end(), [&]( «std_string» const& protobuf_entry )
               {  api_output.OnNext( DecodeUUID(protobuf_entry) ); } );
            
               api_output.OnCompleted();
            }
            
            inline void Encode(«cab_uuid» const& api_input, «std_string» * const protobuf_output)
            {
               «resolveCAB("BTC::Commons::Core::UInt32")» param1 = 0;
               «resolveCAB("BTC::Commons::Core::UInt16")» param2 = 0;
               BTC::Commons::Core::UInt16 param3 = 0;
               «resolveSTL("std::array")»<«resolveCAB("BTC::Commons::Core::UInt8")», 8> param4 = {0};
            
               api_input.ExtractComponents(&param1, &param2, &param3, param4.data());
            
               protobuf_output->resize(16); // UUID is exactly 16 bytes long
            
               «resolveSTL("std::copy")»(static_cast<const char*>(static_cast<const void*>(&param1)),
               static_cast<const char*>(static_cast<const void*>(&param1)) + 4,
               protobuf_output->begin());
            
               std::copy(static_cast<const char*>(static_cast<const void*>(&param2)),
                  static_cast<const char*>(static_cast<const void*>(&param2)) + 2,
                  protobuf_output->begin() + 4);
            
               std::copy(static_cast<const char*>(static_cast<const void*>(&param3)),
                  static_cast<const char*>(static_cast<const void*>(&param3)) + 2,
                  protobuf_output->begin() + 6);
            
               std::copy( param4.begin(), param4.end(), protobuf_output->begin() + 8);
            }
            
            inline «cab_uuid» DecodeUUID(«std_string» const& protobuf_input)
            {
               «resolveSTL("assert")»( protobuf_input.size() == 16 ); // lower half + upper half = 16 bytes!
               
               «resolveSTL("std::array")»<unsigned char, 16> raw_bytes = {0};
               «resolveSTL("std::copy")»( protobuf_input.begin(), protobuf_input.end(), raw_bytes.begin() );
            
               «resolveCAB("BTC::Commons::Core::UInt32")» param1 = (raw_bytes[0] << 0 | raw_bytes[1] << 8 | raw_bytes[2] << 16 | raw_bytes[3] << 24);
               «resolveCAB("BTC::Commons::Core::UInt16")» param2 = (raw_bytes[4] << 0 | raw_bytes[5] << 8);
               BTC::Commons::Core::UInt16 param3 = (raw_bytes[6] << 0 | raw_bytes[7] << 8);
            
               std::array<«resolveCAB("BTC::Commons::Core::UInt8")», 8> param4 = {0};
               std::copy(raw_bytes.begin() + 8, raw_bytes.end(), param4.begin());
            
               return «cab_uuid»::MakeFromComponents(param1, param2, param3, param4.data());
            }
            
            «FOR type : nested_types»
                «val api_type_name = resolve(type)»
                «val proto_type_name = resolve(type, ProjectType.PROTOBUF)»
                inline «api_type_name» Decode(«proto_type_name» const& protobuf_input)
                {
                   «makeDecode(type, owner)»
                }
                
                «IF type instanceof EnumDeclaration»
                    inline «proto_type_name» Encode(«api_type_name» const& api_input)
                «ELSE»
                    inline void Encode(«api_type_name» const& api_input, «proto_type_name» * const protobuf_output)
                «ENDIF»
                {
                   «makeEncode(type)»
                }
            «ENDFOR»
            
            «FOR type : failable_types»
                «val api_type_name = resolve(type)»
                «val proto_failable_type_name = typeResolver.resolveFailableProtobufType(type, owner)»
                «val proto_type_name = resolve(type, ProjectType.PROTOBUF)»
                inline «api_type_name» DecodeFailable(«proto_failable_type_name» const& protobuf_entry)
                {
                   return «typeResolver.resolveDecode(type, owner)»(protobuf_entry.value());
                }
                
                inline void EncodeFailable(«api_type_name» const& api_input, «proto_failable_type_name» * const protobuf_output)
                {
                   «val is_mutable = isMutableField(type)»
                   «IF is_mutable»
                       «resolveEncode(type)»(api_input, protobuf_output->mutable_value());
                   «ELSE»
                       «proto_type_name» value;
                       «resolveEncode(type)»(api_input, &value);
                       protobuf_output->set_value(value);
                   «ENDIF»
                }
            «ENDFOR»
        '''
    }

    def private dispatch String makeDecode(StructDeclaration element, EObject container)
    {
        '''
            «resolve(element)» api_output;
            «FOR member : element.allMembers»
                «makeDecodeMember(member, container)»
            «ENDFOR»
            return api_output;
        '''
    }

    def private dispatch String makeDecode(ExceptionDeclaration element, EObject container)
    {
        '''
            «resolve(element)» api_output;
            «FOR member : element.allMembers»
                «makeDecodeMember(member, container)»
            «ENDFOR»
            return api_output;
        '''
    }

    def private dispatch String makeDecode(EnumDeclaration element, EObject container)
    {
        '''
            «FOR enum_value : element.containedIdentifiers»
                «IF enum_value != element.containedIdentifiers.head»else «ENDIF»if (protobuf_input == «typeResolver.resolveProtobuf(element, ProtobufType.REQUEST)»::«enum_value»)
                   return «resolve(element)»::«enum_value»;
            «ENDFOR»
            
            «resolveCAB("CABTHROW_V2")»(«resolveCAB("BTC::Commons::Core::InvalidArgumentException")»("Unknown enum value!"));
        '''
    }

    def private String makeDecodeMember(MemberElementWrapper element, EObject container)
    {
        val use_codec = GeneratorUtil.useCodec(element.type, ArtifactNature.CPP)
        val is_pointer = useSmartPointer(element.container, element.type)
        val is_optional = element.optional
        val is_sequence = com.btc.serviceidl.util.Util.isSequenceType(element.type)
        val protobuf_name = element.name.toLowerCase
        val is_failable = com.btc.serviceidl.util.Util.isFailable(element.type)
        val codec_name = if (use_codec) typeResolver.resolveDecode(element.type, container, !is_failable)

        '''
            «IF is_optional && !is_sequence»if (protobuf_input.has_«protobuf_name»())«ENDIF»
            «IF is_optional && !is_sequence»   «ENDIF»api_output.«element.name.asMember» = «IF is_pointer»«resolveSTL("std::make_shared")»< «toText(element.type, null)» >( «ENDIF»«IF use_codec»«codec_name»( «ENDIF»protobuf_input.«protobuf_name»()«IF use_codec» )«ENDIF»«IF is_pointer» )«ENDIF»;
        '''
    }

    def private dispatch String makeDecode(AbstractType element, EObject container)
    {
        if (element.referenceType !== null)
            return makeDecode(element.referenceType, container)
    }

    def private dispatch String makeEncode(StructDeclaration element)
    {
        '''
            «FOR member : element.allMembers»
                «makeEncodeMember(member)»
            «ENDFOR»
        '''
    }

    def private dispatch String makeEncode(ExceptionDeclaration element)
    {
        '''
            «FOR member : element.allMembers»
                «makeEncodeMember(member)»
            «ENDFOR»
        '''
    }

    def private dispatch String makeEncode(EnumDeclaration element)
    {
        '''
            «FOR enum_value : element.containedIdentifiers»
                «IF enum_value != element.containedIdentifiers.head»else «ENDIF»if (api_input == «resolve(element)»::«enum_value»)
                   return «typeResolver.resolveProtobuf(element, ProtobufType.RESPONSE)»::«enum_value»;
            «ENDFOR»
            
            «resolveCAB("CABTHROW_V2")»(«resolveCAB("BTC::Commons::Core::InvalidArgumentException")»("Unknown enum value!"));
        '''
    }

    def private String makeEncodeMember(MemberElementWrapper element)
    {
        val use_codec = GeneratorUtil.useCodec(element.type, ArtifactNature.CPP)
        val optional = element.optional
        val is_enum = com.btc.serviceidl.util.Util.isEnumType(element.type)
        val is_pointer = useSmartPointer(element.container, element.type)
        '''
            «IF optional»if (api_input.«element.name.asMember»«IF is_pointer» !== nullptr«ELSE».GetIsPresent()«ENDIF»)«ENDIF»
            «IF use_codec && !(com.btc.serviceidl.util.Util.isByte(element.type) || com.btc.serviceidl.util.Util.isInt16(element.type) || com.btc.serviceidl.util.Util.isChar(element.type) || is_enum)»
                «IF optional»   «ENDIF»«resolveEncode(element.type)»( «IF optional»*( «ENDIF»api_input.«element.name.asMember»«IF optional && !is_pointer».GetValue()«ENDIF»«IF optional» )«ENDIF», protobuf_output->mutable_«element.name.toLowerCase»() );
            «ELSE»
                «IF optional»   «ENDIF»protobuf_output->set_«element.name.toLowerCase»(«IF is_enum»«resolveEncode(element.type)»( «ENDIF»«IF optional»*«ENDIF»api_input.«element.name.asMember»«IF optional && !is_pointer».GetValue()«ENDIF» «IF is_enum»)«ENDIF»);
            «ENDIF»
        '''
    }

    def private dispatch String makeEncode(AbstractType element)
    {
        if (element.referenceType !== null)
            return makeEncode(element.referenceType)
    }

    def private String resolveEncode(EObject element)
    {
        val is_failable = com.btc.serviceidl.util.Util.isFailable(element)
        if (is_failable)
            return '''EncodeFailable'''

        if (com.btc.serviceidl.util.Util.isUUIDType(element))
            return '''Encode'''

        return '''«typeResolver.resolveCodecNS(element)»::Encode'''
    }

    def private static boolean isMutableField(EObject type)
    {
        val ultimate_type = com.btc.serviceidl.util.Util.getUltimateType(type)
        val use_codec = GeneratorUtil.useCodec(ultimate_type, ArtifactNature.CPP)
        val is_enum = com.btc.serviceidl.util.Util.isEnumType(ultimate_type)

        return ( use_codec &&
            !(com.btc.serviceidl.util.Util.isByte(ultimate_type) ||
                com.btc.serviceidl.util.Util.isInt16(ultimate_type) ||
                com.btc.serviceidl.util.Util.isChar(ultimate_type) || is_enum) )
    }

    def generateHeaderFileBody(EObject owner)
    {
        // collect all contained distinct types which need conversion
        val nested_types = GeneratorUtil.getEncodableTypes(owner)

        val cab_uuid = resolveCAB("BTC::Commons::CoreExtras::UUID")
        val forward_const_iterator = resolveCAB("BTC::Commons::Core::ForwardConstIterator")
        val std_vector = resolveSTL("std::vector")
        val insertable_traits = resolveCAB("BTC::Commons::CoreExtras::InsertableTraits")
        val std_string = resolveSTL("std::string")
        val std_function = resolveSTL("std::function")
        val failable_handle = resolveCAB("BTC::Commons::CoreExtras::FailableHandle")
        val cab_exception = resolveCAB("BTC::Commons::Core::Exception")
        val cab_auto_ptr = resolveCAB("BTC::Commons::Core::AutoPtr")
        val cab_string = resolveCAB("BTC::Commons::Core::String")

        val failable_types = GeneratorUtil.getFailableTypes(owner)
        
        // always include corresponding *.pb.h file due to local failable types definitions
        val include_path = "modules" + Constants.SEPARATOR_FILE +
            GeneratorUtil.getTransformedModuleName(paramBundle, ArtifactNature.CPP, TransformType.FILE_SYSTEM) + Constants.SEPARATOR_FILE +
            "gen" + Constants.SEPARATOR_FILE + GeneratorUtil.getPbFileName(owner).pb.h
        addTargetInclude(include_path)        

        '''
            namespace «GeneratorUtil.getCodecName(owner)»
            {
               static «resolveSTL("std::once_flag")» register_fault_handlers;
               static «resolveSTL("std::map")»<«std_string», «std_function»< «cab_auto_ptr»<«cab_exception»>(«cab_string» const&)> > fault_handlers;
               
               // forward declarations
               template<typename PROTOBUF_TYPE, typename API_TYPE>
               «forward_const_iterator»< API_TYPE > Decode(google::protobuf::RepeatedPtrField< PROTOBUF_TYPE > const& protobuf_input);
               
               template<typename PROTOBUF_TYPE, typename API_TYPE>
               «forward_const_iterator»< API_TYPE > Decode(google::protobuf::RepeatedField< PROTOBUF_TYPE > const& protobuf_input);
               
               template<typename PROTOBUF_TYPE, typename API_TYPE>
               «std_vector»< API_TYPE > DecodeToVector(google::protobuf::RepeatedPtrField< PROTOBUF_TYPE > const& protobuf_input);
            
               template<typename PROTOBUF_TYPE, typename API_TYPE>
               «std_vector»< API_TYPE > DecodeToVector(google::protobuf::RepeatedField< PROTOBUF_TYPE > const& protobuf_input);
               
               void EnsureFailableHandlers();
               
               template<typename PROTOBUF_TYPE>
               «resolveCAB("BTC::Commons::Core::AutoPtr")»<«cab_exception»> MakeException
               (
               PROTOBUF_TYPE const& protobuf_entry
               );
               
               template<typename PROTOBUF_TYPE>
               void SerializeException
               (
                  const «cab_exception» &exception,
                  PROTOBUF_TYPE & protobuf_item
               );
               
               template<typename PROTOBUF_TYPE, typename API_TYPE >
               void DecodeFailable
               (
                  google::protobuf::RepeatedPtrField< PROTOBUF_TYPE > const& protobuf_input,
                  typename «insertable_traits»< «failable_handle»< API_TYPE > >::Type &api_output
               );
               
               template<typename PROTOBUF_TYPE, typename API_TYPE>
               «forward_const_iterator»< «failable_handle»<API_TYPE> >
               DecodeFailable
               (
                  google::protobuf::RepeatedPtrField< PROTOBUF_TYPE > const& protobuf_input
               );
               
               template<typename API_TYPE, typename PROTOBUF_TYPE>
               void EncodeFailable
               (
                  «forward_const_iterator»< «failable_handle»<API_TYPE> > api_input,
                  google::protobuf::RepeatedPtrField< PROTOBUF_TYPE >* const protobuf_output
               );
               
               template<typename PROTOBUF_TYPE, typename API_TYPE>
               «std_vector»< «failable_handle»< API_TYPE > > DecodeFailableToVector(google::protobuf::RepeatedPtrField< PROTOBUF_TYPE > const& protobuf_input);
               
               template<typename API_TYPE, typename PROTOBUF_TYPE>
               void EncodeFailable(«std_vector»< «failable_handle»< API_TYPE > > const& api_input, google::protobuf::RepeatedPtrField< PROTOBUF_TYPE >* const protobuf_output);
               
               template<typename API_TYPE, typename PROTOBUF_TYPE>
               void Encode(«forward_const_iterator»< API_TYPE > api_input, google::protobuf::RepeatedPtrField< PROTOBUF_TYPE >* const protobuf_output);
               
               template<typename API_TYPE, typename PROTOBUF_TYPE>
               void Encode(«forward_const_iterator»< API_TYPE > api_input, google::protobuf::RepeatedField< PROTOBUF_TYPE >* const protobuf_output);
               
               template<typename API_TYPE, typename PROTOBUF_TYPE>
               void Encode(«std_vector»< API_TYPE > const& api_input, google::protobuf::RepeatedPtrField< PROTOBUF_TYPE >* const protobuf_output);
               
               template<typename API_TYPE, typename PROTOBUF_TYPE>
               void Encode(«std_vector»< API_TYPE > const& api_input, google::protobuf::RepeatedField< PROTOBUF_TYPE >* protobuf_output);
               
               template<typename IDENTICAL_TYPE>
               IDENTICAL_TYPE Decode(IDENTICAL_TYPE const& protobuf_input);
               
               template<typename PROTOBUF_TYPE, typename API_TYPE>
               void Encode(API_TYPE const& api_input, PROTOBUF_TYPE * const protobuf_output);
               
               template<typename PROTOBUF_TYPE, typename API_TYPE>
               void Decode(google::protobuf::RepeatedPtrField< PROTOBUF_TYPE > const& protobuf_input, typename «insertable_traits»< API_TYPE >::Type &api_output);
               
               template<typename PROTOBUF_TYPE, typename API_TYPE>
               void Decode(google::protobuf::RepeatedField< PROTOBUF_TYPE > const& protobuf_input, typename «insertable_traits»< API_TYPE >::Type &api_output);
               
               template<typename PROTOBUF_ENUM_TYPE, typename API_ENUM_TYPE>
               «forward_const_iterator»< API_ENUM_TYPE > Decode(google::protobuf::RepeatedField< google::protobuf::int32 > const& protobuf_input);
               
               template<typename IDENTICAL_TYPE>
               void Encode(IDENTICAL_TYPE const& api_input, IDENTICAL_TYPE * const protobuf_output);
               
               «std_vector»< «cab_uuid» > DecodeUUIDToVector(google::protobuf::RepeatedPtrField< «std_string» > const& protobuf_input);
               
               «forward_const_iterator»< «cab_uuid» > DecodeUUID(google::protobuf::RepeatedPtrField< «std_string» > const& protobuf_input);
            
               void DecodeUUID(google::protobuf::RepeatedPtrField< «std_string» > const& protobuf_input, «insertable_traits»< «cab_uuid» >::Type &api_output);
               
               «cab_uuid» DecodeUUID(«std_string» const& protobuf_input);
               
               void Encode(«cab_uuid» const& api_input, «std_string» * const protobuf_output);
               
               «FOR type : nested_types»
                «val api_type_name = resolve(type)»
                «val proto_type_name = resolve(type, ProjectType.PROTOBUF)»
                «api_type_name» Decode(«proto_type_name» const& protobuf_input);
                
                «IF type instanceof EnumDeclaration»
                    «proto_type_name» Encode(«api_type_name» const& api_input);
                «ELSE»
                    void Encode(«api_type_name» const& api_input, «proto_type_name» * const protobuf_output);
                «ENDIF»
               «ENDFOR»
               
               «FOR type : failable_types»
                «val api_type_name = resolve(type)»
                «val proto_type_name = typeResolver.resolveFailableProtobufType(type, owner)»
                «api_type_name» DecodeFailable(«proto_type_name» const& protobuf_input);
                
                void EncodeFailable(«api_type_name» const& api_input, «proto_type_name» * const protobuf_output);
               «ENDFOR»
               
               // inline implementations
               «generateHCodecInline(owner, nested_types)»
            }
        '''
    }

}
