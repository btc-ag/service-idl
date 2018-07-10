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

import com.btc.serviceidl.generator.common.ArtifactNature
import com.btc.serviceidl.generator.common.GeneratorUtil
import com.btc.serviceidl.generator.common.ProtobufType
import com.btc.serviceidl.generator.common.TransformType
import com.btc.serviceidl.idl.AbstractContainerDeclaration
import com.btc.serviceidl.idl.AbstractType
import com.btc.serviceidl.idl.AbstractTypeDeclaration
import com.btc.serviceidl.idl.EnumDeclaration
import com.btc.serviceidl.idl.ExceptionDeclaration
import com.btc.serviceidl.idl.StructDeclaration
import com.btc.serviceidl.util.MemberElementWrapper
import java.util.ArrayList
import java.util.Collection
import java.util.Optional
import org.eclipse.emf.ecore.EObject
import org.eclipse.xtend.lib.annotations.Accessors

import static extension com.btc.serviceidl.generator.common.Extensions.*
import static extension com.btc.serviceidl.generator.java.BasicJavaSourceGenerator.*
import static extension com.btc.serviceidl.generator.java.ProtobufUtil.*
import static extension com.btc.serviceidl.util.Extensions.*
import static extension com.btc.serviceidl.util.Util.*

@Accessors(NONE)
class ProtobufCodecGenerator
{
    val BasicJavaSourceGenerator basicJavaSourceGenerator

    private def getTypeResolver()
    {
        basicJavaSourceGenerator.typeResolver
    }

    def generateProtobufCodecBody(AbstractContainerDeclaration container, String codec_name)
    {
        // collect all used data types to avoid duplicates
        val data_types = GeneratorUtil.getEncodableTypes(container)

        val java_uuid = typeResolver.resolve(JavaClassNames.UUID)
        val byte_string = typeResolver.resolve("com.google.protobuf.ByteString")
        val byte_buffer = typeResolver.resolve("java.nio.ByteBuffer")
        val i_error = typeResolver.resolve(JavaClassNames.ERROR)
        val service_fault_handler_factory = typeResolver.resolve(
            typeResolver.resolvePackage(container, container.mainProjectType) + TransformType.PACKAGE.separator +
                container.asServiceFaultHandlerFactory)
        val completable_future = typeResolver.resolve(JavaClassNames.COMPLETABLE_FUTURE)
        val method = typeResolver.resolve("java.lang.reflect.Method")
        val collection = typeResolver.resolve(JavaClassNames.COLLECTION)
        val collectors = typeResolver.resolve("java.util.stream.Collectors")

        '''
            public class «codec_name» {
               
               private static «i_error» encodeException(Exception e)
               {
                  Exception cause = (Exception) «typeResolver.resolve("org.apache.commons.lang3.exception.ExceptionUtils")».getRootCause(e);
                  return «service_fault_handler_factory».createError(cause);
               }
               
               private static Exception decodeException(String errorType, String message, String stackTrace)
               {
                  return «service_fault_handler_factory».createException(errorType, message, stackTrace);
               }
               
               @SuppressWarnings("unchecked")
               public static<TOut, TIn> «collection»<TOut> encode(Collection<TIn> plainData) {
                  return
                     plainData
                     .stream()
                     .map(item -> (TOut) encode(item))
                     .collect(«collectors».toList());
               }
               
               public static<TOut, TIn> «collection»<TOut> encodeFailable(«collection»<«completable_future»<TIn>> plainData, Class<TOut> targetType)
               {
                  return
                     plainData
                     .stream()
                     .map(item -> encodeFailableWrapper(item, targetType) )
                     .collect(«collectors».toList());
               }
               
               private static<TOut, TIn> TOut encodeFailableWrapper(«completable_future»<TIn> failableData, Class<TOut> targetType)
               {
                  try { return encodeFailable(failableData, targetType); }
                  catch (Exception e) { throw new RuntimeException(e); }
               }
               
               @SuppressWarnings("unchecked")
               public static<TOut, TIn> «collection»<TOut> decode(«collection»<TIn> encodedData) {
                  return
                     encodedData
                     .stream()
                     .map(item -> (item instanceof «byte_string») ? (TOut) decode( («byte_string») item) : (TOut) decode(item))
                     .collect(«collectors».toList());
               }
               
               public static «byte_string» encode(«java_uuid» plainData) {
                  
                  byte[] rawBytes = «byte_buffer».allocate(16)
                     .putLong(plainData.getMostSignificantBits())
                     .putLong(plainData.getLeastSignificantBits())
                     .array();
            
                  return «byte_string».copyFrom( switchByteOrder(rawBytes) );
               }
               
               @SuppressWarnings( {"boxing", "unchecked"} )
               private static<TOut, TIn> TOut encodeFailable(«completable_future»<TIn> failableData, Class<TOut> targetType) throws Exception
               {
                  if (failableData == null)
                     throw new NullPointerException();
               
                  if (failableData.isCompletedExceptionally())
                  {
                    try
                    {
                       failableData.get();
                    } catch (Exception e) // retrieve and encode underlying exception
                    {
                       «typeResolver.resolve(JavaClassNames.ERROR)» error = encodeException(e);
                       «method» newBuilderMethod = targetType.getDeclaredMethod("newBuilder");
                       Object builder = newBuilderMethod.invoke(null);
                       «method» setExceptionMethod = builder.getClass().getDeclaredMethod("setException", String.class);
                       setExceptionMethod.invoke(builder, error.getServerErrorType());
                       «method» setMessageMethod = builder.getClass().getDeclaredMethod("setMessage", String.class);
                       setMessageMethod.invoke(builder, error.getMessage());
                       «method» setStacktraceMethod = builder.getClass().getDeclaredMethod("setStacktrace", String.class);
                       setStacktraceMethod.invoke(builder, error.getServerContextInformation());
                       «method» buildMethod = builder.getClass().getDeclaredMethod("build");
                       return (TOut) buildMethod.invoke(builder);
                    }
                  }
                  else
                  {
                    TIn plainData = failableData.get();
                    «method» newBuilderMethod = targetType.getDeclaredMethod("newBuilder");
                    Object builder = newBuilderMethod.invoke(null);
                    «method» getValueMethod = builder.getClass().getDeclaredMethod("getValue");
                    Class<?> paramType = getValueMethod.getReturnType();
                    «method» setValueMethod = builder.getClass().getDeclaredMethod("setValue", paramType);
                    setValueMethod.invoke(builder, encode( plainData ));
                    «method» buildMethod = builder.getClass().getDeclaredMethod("build");
                    return (TOut) buildMethod.invoke(builder);
                  }
                  
                  throw new IllegalArgumentException("Unknown target type for encoding: " + targetType.getCanonicalName());
               }
               
               @SuppressWarnings("unchecked")
               public static<TOut, TIn> «collection»<«completable_future»<TOut>> decodeFailable(«collection»<TIn> encodedData)
               {
                  return
                     encodedData
                     .stream()
                     .map( item -> («completable_future»<TOut>) decodeFailableWrapper(item) )
                     .collect(«collectors».toList());
               }
               
               private static<TOut, TIn> «completable_future»<TOut> decodeFailableWrapper(TIn encodedData)
               {
                  try { return decodeFailable(encodedData); }
                  catch (Exception e) { throw new RuntimeException(e); }
               }
               
               @SuppressWarnings( {"boxing", "unchecked"} )
               public static<TOut, TIn> «completable_future»<TOut> decodeFailable(TIn encodedData) throws Exception
               {
                  if (encodedData == null)
                     throw new NullPointerException();
            
                  «completable_future»<TOut> result = new «completable_future»<TOut>();
                  
                  «method» hasValueMethod = encodedData.getClass().getDeclaredMethod("hasValue");
                  Boolean hasValue = (Boolean) hasValueMethod.invoke(encodedData);
                  if (hasValue)
                  {
                     «method» getValueMethod = encodedData.getClass().getDeclaredMethod("getValue");
                     Object value = getValueMethod.invoke(encodedData);
                     if (encodedData.getClass().getSimpleName().toLowerCase().endsWith("_uuid")) // it's a failable UUID: explicit handling
                        result.complete( (TOut) decode( («byte_string») value) );
                     else
                        result.complete( (TOut) decode(value) );
                     return result;
                  }
                  else
                  {
                     «method» hasExceptionMethod = encodedData.getClass().getDeclaredMethod("hasException");
                     Boolean hasException = (Boolean) hasExceptionMethod.invoke(encodedData);
                     if (hasException)
                     {
                        «method» getExceptionMethod = encodedData.getClass().getDeclaredMethod("getException");
                        String errorType = getExceptionMethod.invoke(encodedData).toString();
                        «method» getMessageMethod = encodedData.getClass().getDeclaredMethod("getMessage");
                        String message = getMessageMethod.invoke(encodedData).toString();
                        «method» getStacktraceMethod = encodedData.getClass().getDeclaredMethod("getStacktrace");
                        String stackTrace = getStacktraceMethod.invoke(encodedData).toString();
                        result.completeExceptionally( decodeException(errorType, message, stackTrace) );
                        return result;
                     }
                  }
                  
                  throw new IllegalArgumentException("Failed to decode the type: " + encodedData.getClass().getCanonicalName());
               }
               
               public static «java_uuid» decode(«byte_string» encodedData) {
                  «byte_buffer» byteBuffer = «byte_buffer».wrap(switchByteOrder(encodedData.toByteArray()));
                  return new «java_uuid»(byteBuffer.getLong(), byteBuffer.getLong());
               }
               
               /**
                * Utility function to change the endianness of the given GUID bytes.
                */
               private static byte[] switchByteOrder(byte[] rawBytes) {
                  
                  // raw GUID data have this format: AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE
                  byte[] switchedBytes = new byte[16];
            
                  // switch AAAAAAAA bytes
                  switchedBytes[0] = rawBytes[3];
                  switchedBytes[1] = rawBytes[2];
                  switchedBytes[2] = rawBytes[1];
                  switchedBytes[3] = rawBytes[0];
            
                  // switch BBBB bytes
                  switchedBytes[4] = rawBytes[5];
                  switchedBytes[5] = rawBytes[4];
            
                  // switch CCCC bytes
                  switchedBytes[6] = rawBytes[7];
                  switchedBytes[7] = rawBytes[6];
            
                  // switch EEEEEEEEEEEE bytes
                  for (int i = 8; i < 16; i++)
                     switchedBytes[i] = rawBytes[i];
            
                  return switchedBytes;
               }
               
               @SuppressWarnings("boxing")
               public static Object encode(Object plainData) {
               
                  if (plainData == null)
                     throw new NullPointerException();
               
                  if (plainData instanceof «java_uuid»)
                     return encode( («java_uuid») plainData );
            
                  «FOR data_type : data_types»
                      if (plainData instanceof «typeResolver.resolve(data_type)»)
                      {
                         «makeEncode(data_type)»
                      }
                      
                  «ENDFOR»
                  return plainData;
               }
               
               @SuppressWarnings("boxing")
               public static Object decode(Object encodedData) {
               
                  if (encodedData == null)
                     throw new NullPointerException();
               
                  «FOR data_type : data_types»
                      if (encodedData instanceof «ProtobufUtil.resolveProtobuf(typeResolver, data_type, Optional.empty)»)
                      {
                         «makeDecode(data_type)»
                      }
                  «ENDFOR»
                  
                  return encodedData;
               }
            }
        '''
    }

    private def dispatch String makeDecode(AbstractType element)
    {
        if (element.referenceType !== null)
            return makeDecode(element.referenceType)
    }

    private def dispatch String makeDecode(EnumDeclaration element)
    {
        val api_type_name = typeResolver.resolve(element)
        val protobuf_type_name = resolveProtobuf(element, Optional.empty)

        '''
            «protobuf_type_name» typedData = («protobuf_type_name») encodedData;
            «FOR item : element.containedIdentifiers»
                «IF item != element.containedIdentifiers.head»else «ENDIF»if (typedData == «protobuf_type_name».«item»)
                   return «api_type_name».«item»;
            «ENDFOR»
            else
               throw new «typeResolver.resolve("java.util.NoSuchElementException")»("Unknown value " + typedData.toString() + " for enumeration «element.name»");
        '''
    }

    private def dispatch String makeDecode(StructDeclaration element)
    {
        makeDecodeStructOrException(element, element.allMembers, Optional.of(element.typeDecls))
    }

    private def dispatch String makeDecode(ExceptionDeclaration element)
    {
        makeDecodeStructOrException(element, element.allMembers, Optional.empty)
    }

    private def String makeDecodeStructOrException(EObject element, Iterable<MemberElementWrapper> members,
        Optional<Collection<AbstractTypeDeclaration>> type_declarations)
    {
        val api_type_name = typeResolver.resolve(element)
        val protobuf_type_name = resolveProtobuf(element, Optional.empty)

        val all_types = new ArrayList<MemberElementWrapper>
        all_types.addAll(members)

        if (type_declarations.present)
            type_declarations.get.filter(StructDeclaration).filter[declarator !== null].forEach [
                all_types.add(new MemberElementWrapper(it))
            ]

        '''
            «protobuf_type_name» typedData = («protobuf_type_name») encodedData;
            «FOR member : members»
                «val codec = resolveCodec(member.type, typeResolver)»
                «val is_sequence = member.type.isSequenceType»
                «val is_failable = is_sequence && member.type.isFailable»
                «val is_byte = member.type.isByte»
                «val is_short = member.type.isInt16»
                «val is_char = member.type.isChar»
                «val use_codec = GeneratorUtil.useCodec(member.type, ArtifactNature.JAVA)»
                «val is_optional = member.optional»
                «val api_type = basicJavaSourceGenerator.toText(member.type)»
                «val parameterName = member.name.asParameter»
                «basicJavaSourceGenerator.formatMaybeOptional(is_optional, api_type)» «parameterName» = «IF is_optional»(typedData.«IF is_sequence»get«ELSE»has«ENDIF»«member.name.asJavaProtobufName»«IF is_sequence»Count«ENDIF»()«IF is_sequence» > 0«ENDIF») ? «ENDIF»«IF is_optional»Optional.of(«ENDIF»«IF use_codec»«IF !is_sequence»(«api_type») «ENDIF»«codec».decode«IF is_failable»Failable«ENDIF»(«ENDIF»«IF is_short || is_byte || is_char»(«IF is_byte»byte«ELSEIF is_char»char«ELSE»short«ENDIF») «ENDIF»typedData.get«member.name.asJavaProtobufName»«IF is_sequence»List«ENDIF»()«IF use_codec»)«ENDIF»«IF is_optional»)«ENDIF»«IF is_optional» : Optional.empty()«ENDIF»;
            «ENDFOR»
            
            return new «api_type_name» (
               «FOR member : members SEPARATOR ","»
                   «member.name.asParameter»
               «ENDFOR»
            );
        '''
    }

    private def dispatch String makeEncode(AbstractType element)
    {
        if (element.referenceType !== null)
            return makeEncode(element.referenceType)
    }

    private def dispatch String makeEncode(EnumDeclaration element)
    {
        val api_type_name = typeResolver.resolve(element)
        val protobuf_type_name = resolveProtobuf(element, Optional.empty)

        '''
            «api_type_name» typedData = («api_type_name») plainData;
            «FOR item : element.containedIdentifiers»
                «IF item != element.containedIdentifiers.head»else «ENDIF»if (typedData == «api_type_name».«item»)
                   return «protobuf_type_name».«item»;
            «ENDFOR»
            else
               throw new «typeResolver.resolve("java.util.NoSuchElementException")»("Unknown value " + typedData.toString() + " for enumeration «element.name»");
        '''
    }

    private def dispatch String makeEncode(StructDeclaration element)
    {
        makeEncodeStructOrException(element, element.allMembers, Optional.of(element.typeDecls))
    }

    private def dispatch String makeEncode(ExceptionDeclaration element)
    {
        makeEncodeStructOrException(element, element.allMembers, Optional.empty)
    }

    private def String makeEncodeStructOrException(EObject element, Iterable<MemberElementWrapper> members,
        Optional<Collection<AbstractTypeDeclaration>> type_declarations)
    {
        val protobuf_type = resolveProtobuf(element, Optional.empty)
        val plain_type = typeResolver.resolve(element)

        '''
            «IF !members.empty»«plain_type» typedData = («plain_type») plainData;«ENDIF»
            «protobuf_type».Builder builder
               = «protobuf_type».newBuilder();
            «FOR member : members»
                «val use_codec = GeneratorUtil.useCodec(member.type, ArtifactNature.JAVA)»
                «val is_sequence = member.type.isSequenceType»
                «val is_failable = is_sequence && member.type.isFailable»
                «val protobufName = member.name.asJavaProtobufName»
                «val commonName = member.commonName»
                «val method_name = '''«IF is_sequence»addAll«ELSE»set«ENDIF»«protobufName»'''»
                «IF member.optional»
                    if (typedData.get«typeResolver.resolve(JavaClassNames.OPTIONAL).alias(commonName)»().isPresent())
                    {
                        builder.«method_name»(«IF use_codec»«IF !is_sequence»(«resolveProtobuf(member.type, Optional.empty)») «ENDIF»encode«IF is_failable»Failable«ENDIF»(«ENDIF»typedData.get«protobufName»().get()«IF is_failable», «resolveFailableProtobufType(typeResolver, basicJavaSourceGenerator.qualified_name_provider, member.type, member.type.scopeDeterminant)».class«ENDIF»«IF use_codec»)«ENDIF»);
                    }
                «ELSE»
                builder.«method_name»(«IF use_codec»«IF !is_sequence»(«resolveProtobuf(member.type, Optional.empty)») «ENDIF»encode«IF is_failable»Failable«ENDIF»(«ENDIF»typedData.get«commonName»()«IF is_failable», «resolveFailableProtobufType(typeResolver, basicJavaSourceGenerator.qualified_name_provider, member.type, member.type.scopeDeterminant)».class«ENDIF»«IF use_codec»)«ENDIF»);
               «ENDIF»
            «ENDFOR»
            return builder.build();
        '''
    }

    // TODO change this to accept an IDL element rather than a bare string
    private static def getCommonName(MemberElementWrapper member)
    {
        // TODO use a proper naming convention transformation
        member.name.toFirstUpper
    }

    def resolveProtobuf(EObject object, Optional<ProtobufType> optionaProtobufTypel)
    {
        ProtobufUtil.resolveProtobuf(typeResolver, object, optionaProtobufTypel)
    }

}
