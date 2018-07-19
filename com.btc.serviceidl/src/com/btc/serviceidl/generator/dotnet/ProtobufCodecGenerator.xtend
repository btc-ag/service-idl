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

import com.btc.serviceidl.generator.common.ArtifactNature
import com.btc.serviceidl.generator.common.GeneratorUtil
import com.btc.serviceidl.generator.common.ProjectType
import com.btc.serviceidl.idl.AbstractContainerDeclaration
import com.btc.serviceidl.idl.AbstractTypeDeclaration
import com.btc.serviceidl.idl.AbstractTypeReference
import com.btc.serviceidl.idl.EnumDeclaration
import com.btc.serviceidl.idl.ExceptionDeclaration
import com.btc.serviceidl.idl.StructDeclaration
import com.btc.serviceidl.util.Constants
import com.btc.serviceidl.util.MemberElementWrapper
import java.util.Arrays
import org.eclipse.xtend.lib.annotations.Accessors

import static extension com.btc.serviceidl.generator.dotnet.ProtobufUtil.*
import static extension com.btc.serviceidl.generator.dotnet.Util.*
import static extension com.btc.serviceidl.util.Extensions.*
import static extension com.btc.serviceidl.util.Util.*

@Accessors(NONE)
class ProtobufCodecGenerator extends ProxyDispatcherGeneratorBase
{
    def generate(AbstractContainerDeclaration owner, String className)
    {
        val enumerable = resolve("System.Collections.Generic.IEnumerable")
        resolve("System.Linq.Enumerable")
        val task = resolve("System.Threading.Tasks.Task")
        val string = resolve("System.string")
        val object = resolve("System.object")
        val type = resolve("System.Type")
        val guid = resolve("System.Guid")
        val byteString = resolve("Google.ProtocolBuffers.ByteString")
        val bindingFlags = resolve("System.Reflection.BindingFlags")

        // reference main project for common fault handling
        val serviceFaultHandling = Util.resolveServiceFaultHandling(typeResolver, owner).fullyQualifiedName

        // collect all data types which are relevant for encoding
        val dataTypes = GeneratorUtil.getEncodableTypes(owner)

        '''
            public static class «className»
            {
               public static IEnumerable<TOut> encodeEnumerable<TOut, TIn>(IEnumerable<TIn> plainData)
               {
                  return plainData.Select(item => (TOut) encode(item)).ToList();
               }
               
               public static «enumerable»<TOut> encodeFailable<TOut, TIn>(«enumerable»<«task»<TIn>> plainData)
               {
                  return plainData.Select(item => encodeFailable<TOut, TIn>(item)).ToList();
               }
               
               private static TOut encodeFailable<TOut, TIn>(«task»<TIn> plainData)
               {
                  var builder = typeof(TOut).GetMethod("CreateBuilder", new «type»[0]).Invoke(null, null);
                  var builderType = builder.GetType();
                  if (plainData.IsFaulted)
                  {
                     // encode error from exception
                     var exception = plainData.Exception.Flatten().InnerException;
                     builderType.GetMethod("SetException").Invoke(builder, new «object»[] { «serviceFaultHandling».resolveError(exception) });
                     builderType.GetMethod("SetMessage").Invoke(builder, new «object»[] { exception.Message ?? «string».Empty });
                     builderType.GetMethod("SetStacktrace").Invoke(builder, new «object»[] { exception.StackTrace ?? «string».Empty });
                  }
                  else
                  {
                     // encode value
                     TIn value = plainData.Result;
                     «object» encodedValue = default(TOut);
                     if (typeof(TIn) == typeof(«guid»))
                        encodedValue = encodeUUID((«guid»)(«object») value);
                     else
                        encodedValue = encode(value);
                     builderType.GetProperty("Value", «bindingFlags».Public | «bindingFlags».Instance).SetValue(builder, encodedValue);
                  }
                  return (TOut) builderType.GetMethod("Build").Invoke(builder, null);
               }
            
               public static int encodeByte(byte plainData)
               {
               return plainData;
               }
            
               public static int encodeShort(short plainData)
               {
               return plainData;
               }
               
               public static int encodeChar(char plainData)
               {
                  return plainData;
               }
            
               public static «resolve(TypeResolver.PROTOBUF_UUID_TYPE)» encodeUUID(«resolve("System.Guid")» plainData)
               {
               return Google.ProtocolBuffers.ByteString.CopyFrom(plainData.ToByteArray());
               }
            
               // TOut and TIn are necessary here to be able to generate the same calling code as for the generic method above.
               public static IEnumerable<int> encodeEnumerable<TOut, TIn>(IEnumerable<byte> plainData)
               {
               return plainData.Select(item => (int)item).ToList();
               }
            
               // TOut and TIn are necessary here to be able to generate the same calling code as for the generic method above.
               public static IEnumerable<int> encodeEnumerable<TOut, TIn>(IEnumerable<short> plainData)
               {
                return plainData.Select(item => (int)item).ToList();
               }
               
               // TOut and TIn are necessary here to be able to generate the same calling code as for the generic method above.
               public static IEnumerable<int> encodeEnumerable<TOut, TIn>(IEnumerable<char> plainData)
               {
                   return plainData.Select(item => (int)item).ToList();
               }
               
               // TOut and TIn are necessary here to be able to generate the same calling code as for the generic method above.
               public static IEnumerable<«resolve(TypeResolver.PROTOBUF_UUID_TYPE)»> encodeEnumerable<TOut, TIn>(IEnumerable<«resolve("System.Guid")»> plainData)
               {
                   return plainData.Select(item => encodeUUID(item)).ToList();
               }
               
               public static «resolve("System.object")» encode(object plainData)
               {
                  if (plainData == null)
                     throw new «resolve("System.ArgumentNullException")»();
            
                  «FOR dataType : dataTypes»
                      if (plainData.GetType() == typeof(«resolve(dataType)»))
                      {
                         «makeEncode(dataType, owner)»
                      }
                  «ENDFOR»
                  
                  return plainData;
               }
               
               public static IEnumerable<TOut> decodeEnumerable<TOut, TIn>(IEnumerable<TIn> encodedData)
               {
                  return encodedData.Select(item => (TOut) decode(item)).ToList();
               }
               
               public static «enumerable»<«task»<TOut>> decodeFailable<TOut, TIn>(«enumerable»<TIn> encodedData)
               {
                  return encodedData.Select(item => decodeFailable<TOut, TIn>(item)).ToList();
               }
               
               private static «task»<TOut> decodeFailable<TOut, TIn>(TIn encodedData)
               {
                  var encodedType = encodedData.GetType();
                  bool hasValue = (bool) encodedType.GetProperty("HasValue").GetValue(encodedData);
                  if (hasValue)
                  {
                     // get encoded value and decode it
                     var value = encodedType.GetProperty("Value").GetValue(encodedData);
                     «object» decodedValue = default(TOut);
                     if (typeof(TOut) == typeof(«guid») && value.GetType() == typeof(«byteString»))
                        decodedValue = decodeUUID((«byteString»)(«object») value);
                     else
                        decodedValue = decode(value);
                     return «task».FromResult<TOut>((TOut) decodedValue);
                  }
                  else
                  {
                     // get error and map it to proper exception
                     var exception = («string») encodedType.GetProperty("Exception").GetValue(encodedData);
                     var message = («string») encodedType.GetProperty("Message").GetValue(encodedData);
                     var stacktrace = («string») encodedType.GetProperty("Stacktrace").GetValue(encodedData);
                     return «task».FromException<TOut>(«serviceFaultHandling».resolveError(exception, message, stacktrace));
                  }
               }
               
               public static IEnumerable<byte> decodeEnumerableByte(IEnumerable<int> encodedData)
               {
                  return encodedData.Select(item => (byte) item).ToList();
               }
               
               public static IEnumerable<short> decodeEnumerableShort (IEnumerable<int> encodedData)
               {
                  return encodedData.Select(item => (short)item).ToList();
               }
               
               public static IEnumerable<char> decodeEnumerableChar (IEnumerable<int> encodedData)
               {
                  return encodedData.Select(item => (char)item).ToList();
               }
               
               public static IEnumerable<«resolve("System.Guid")»> decodeEnumerableUUID (IEnumerable<«resolve(TypeResolver.PROTOBUF_UUID_TYPE)»> encodedData)
               {
                  return encodedData.Select(item => decodeUUID(item)).ToList();
               }
               
               public static byte decodeByte(int encodedData)
               {
                  return (byte) encodedData;
               }
               
               public static short decodeShort(int encodedData)
               {
                  return (short) encodedData;
               }
               
               public static char decodeChar(int encodedData)
               {
                  return (char) encodedData;
               }
               
               public static «resolve("System.Guid")» decodeUUID(«resolve(TypeResolver.PROTOBUF_UUID_TYPE)» encodedData)
               {
                  return new System.Guid(encodedData.ToByteArray());
               }
               
               public static object decode(object encodedData)
               {
                  if (encodedData == null)
                     throw new «resolve("System.ArgumentNullException")»();
            
                  «FOR dataType : dataTypes»
                      if (encodedData.GetType() == typeof(«resolve(dataType, ProjectType.PROTOBUF)»))
                      {
                         «makeDecode(dataType, owner)»
                      }
                  «ENDFOR»
            
               return encodedData;
                  }
               }
        '''
    }

    private def dispatch String makeEncode(EnumDeclaration element, AbstractContainerDeclaration owner)
    {
        val apiTypeName = resolve(element)
        val protobufTypeName = resolve(element, ProjectType.PROTOBUF)

        '''
            «apiTypeName» typedData = («apiTypeName») plainData;
            «FOR item : element.containedIdentifiers»
                «IF item != element.containedIdentifiers.head»else «ENDIF»if (typedData == «apiTypeName».«item»)
                   return «protobufTypeName».«item»;
            «ENDFOR»
            else
               throw new «resolve("System.ArgumentOutOfRangeException")»("Unknown value " + typedData.ToString() + " for enumeration «element.name»");
        '''
    }

    private def dispatch String makeEncode(StructDeclaration element, AbstractContainerDeclaration owner)
    {
        makeEncodeStructOrException(element, element.allMembers, element.typeDecls)
    }

    private def dispatch String makeEncode(ExceptionDeclaration element, AbstractContainerDeclaration owner)
    {
        makeEncodeStructOrException(element, element.allMembers, Arrays.asList)
    }

    private def dispatch String makeEncode(AbstractTypeReference element, AbstractContainerDeclaration owner)
    {
        throw new IllegalArgumentException
    }

    private def String makeEncodeStructOrException(AbstractTypeDeclaration element,
        Iterable<MemberElementWrapper> members, Iterable<AbstractTypeDeclaration> typeDeclarations)
    {
        val apiTypeName = resolve(element)
        val protobufTypeName = resolve(element, ProjectType.PROTOBUF)
        val container = element.scopeDeterminant

        '''
            «apiTypeName» typedData = («apiTypeName») plainData;
            var builder = «protobufTypeName».CreateBuilder();
            «FOR member : members»
                «makeEncodeMember(member, container)»
            «ENDFOR»
            «FOR structDecl : typeDeclarations.filter(StructDeclaration).filter[declarator !== null]»
                «val codec = resolveCodec(typeResolver, parameterBundle, structDecl)»
                builder.Set«new MemberElementWrapper(structDecl).protobufName»((«protobufTypeName».Types.«structDecl.name») «codec».encode(typedData.«structDecl.declarator.asProperty»));
            «ENDFOR»
            «FOR enumDecl : typeDeclarations.filter(EnumDeclaration).filter[declarator !== null]»
                «val codec = resolveCodec(typeResolver, parameterBundle, enumDecl)»
                builder.Set«new MemberElementWrapper(enumDecl).protobufName»((«protobufTypeName».Types.«enumDecl.name») «codec».encode(typedData.«enumDecl.declarator»));
            «ENDFOR»
            return builder.BuildPartial();
        '''
    }
    
    def makeEncodeMember(MemberElementWrapper member, AbstractContainerDeclaration container)
    {
        val codec = resolveCodec(typeResolver, parameterBundle, member.type)
        val isFailable = member.type.isFailable
        val useCodec = isFailable || GeneratorUtil.useCodec(member.type, ArtifactNature.DOTNET)
        val useCast = useCodec && !isFailable
        val encodeMethod = getEncodeMethod(member.type, container)
        val methodName = (if (member.type.isSequenceType) "AddRange" else "Set") + member.name.asDotNetProtobufName
        if (member.type.isAbstractCrossReferenceType && !member.type.isEnumType && !member.type.isPrimitive)
        {
            '''if (typedData.«member.name.asProperty» != null)
               {
                   builder.«methodName»(«IF useCodec»«IF useCast»(«resolveEncode(member.type)») «ENDIF»«codec».«encodeMethod»(«ENDIF»typedData.«member.name.asProperty»«IF useCodec»)«ENDIF»);
               }
            '''
        }
        else
        {
            val isNullable = (member.optional && member.type.valueType)
            val isOptionalReference = (member.optional && !member.type.valueType)
            if (member.type.isByte || member.type.isInt16 || member.type.isChar)
                '''«IF isNullable»if (typedData.«member.name.asProperty».HasValue) «ENDIF»
                   builder.«methodName»(typedData.«member.name.asProperty»
                   «IF isNullable».Value«ENDIF»
                   );
                '''
            else
                '''«IF isNullable»if (typedData.«member.name.asProperty».HasValue) «ENDIF»
                   «IF isOptionalReference»if (typedData.«member.name.asProperty» != null) «ENDIF»
                   builder.«methodName»(«IF useCodec»«IF useCast»(«resolveEncode(member.type)») «ENDIF»«codec».«encodeMethod»(«ENDIF»typedData.«member.name.asProperty»
                   «IF isNullable».Value«ENDIF»«IF useCodec»)«ENDIF»
                   );
                '''
        }
    }

    private def dispatch String makeDecode(EnumDeclaration element, AbstractContainerDeclaration owner)
    {
        val apiTypeName = resolve(element)
        val protobufTypeName = resolve(element, ProjectType.PROTOBUF)

        '''
            «protobufTypeName» typedData = («protobufTypeName») encodedData;
            «FOR item : element.containedIdentifiers»
                «IF item != element.containedIdentifiers.head»else «ENDIF»if (typedData == «protobufTypeName».«item»)
                   return «apiTypeName».«item»;
            «ENDFOR»
            else
               throw new «resolve("System.ArgumentOutOfRangeException")»("Unknown value " + typedData.ToString() + " for enumeration «element.name»");
        '''
    }

    private def dispatch String makeDecode(StructDeclaration element, AbstractContainerDeclaration owner)
    {
        makeDecodeStructOrException(element, element.allMembers, element.typeDecls)
    }

    private def dispatch String makeDecode(ExceptionDeclaration element, AbstractContainerDeclaration owner)
    {
        makeDecodeStructOrException(element, element.allMembers, Arrays.asList)
    }

    private def String makeDecodeStructOrException(AbstractTypeDeclaration element,
        Iterable<MemberElementWrapper> members, Iterable<AbstractTypeDeclaration> typeDeclarations)
    {
        val apiTypeName = resolve(element)
        val protobufTypeName = resolve(element, ProjectType.PROTOBUF)
        val container = element.scopeDeterminant

        '''
            «protobufTypeName» typedData = («protobufTypeName») encodedData;
            return new «apiTypeName» (
               «FOR member : members SEPARATOR ","»
                   «makeDecodeMember(member, container)»
               «ENDFOR»
               «FOR structDecl : typeDeclarations.filter(StructDeclaration).filter[declarator !== null] SEPARATOR ","»
                   «val codec = resolveCodec(typeResolver, parameterBundle, structDecl)»
                   «structDecl.declarator.asParameter»: («resolve(structDecl)») «codec».decode(typedData.«new MemberElementWrapper(structDecl).protobufName»)
               «ENDFOR»
               «FOR enumDecl : typeDeclarations.filter(EnumDeclaration).filter[declarator !== null] SEPARATOR ","»
                   «val codec = resolveCodec(typeResolver, parameterBundle, enumDecl)»
                   «enumDecl.declarator.asParameter»: («apiTypeName + Constants.SEPARATOR_PACKAGE + enumDecl.name») «codec».decode(typedData.«new MemberElementWrapper(enumDecl).protobufName»)
               «ENDFOR»
               );
        '''
    }

    def makeDecodeMember(MemberElementWrapper member, AbstractContainerDeclaration container)
    {
        val memberType = member.type
        val isSequence = memberType.isSequenceType
        val isOptional = member.optional && !isSequence
        if (memberType.isByte || memberType.isInt16 || memberType.isChar)
        {
            '''«member.name.asParameter»: 
               «IF isOptional»(typedData.«hasField(member)») ? «ENDIF»
               («resolve(member.type)») typedData.«member.protobufName»
               «IF isOptional» : («toText(member.type, null)»?) null«ENDIF»'''

        }
        else
        {
            val decodeMethod = getDecodeMethod(member.type, container)
            val isFailable = memberType.isFailable
            val useCodec = isFailable || GeneratorUtil.useCodec(member.type, ArtifactNature.DOTNET)
            val codec = if (useCodec) resolveCodec(typeResolver, parameterBundle, memberType)
            val useCast = useCodec && !isFailable

            '''«member.name.asParameter»: 
               «IF isOptional»(typedData.«hasField(member)») ? «ENDIF»
               «IF useCodec»«IF useCast»(«resolveDecode(member.type)») «ENDIF»«codec».«decodeMethod»(«ENDIF»
               typedData.«member.protobufName»«IF isSequence»List«ENDIF»«IF useCodec»)«ENDIF»
               «IF isOptional» : «IF member.type.isNullable»(«toText(member.type, null)»?) «ENDIF»null«ENDIF»'''
        }
    }

    private def dispatch String makeDecode(AbstractTypeReference element, AbstractContainerDeclaration owner)
    {
        throw new IllegalArgumentException
    }

}
