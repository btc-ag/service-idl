package com.btc.serviceidl.generator.cpp

import org.eclipse.xtend.lib.annotations.Accessors

@Accessors
class OdbGenerator
{
    private val extension TypeResolver typeResolver

    def generateODBTraitsBody()
    {
        '''
            namespace odb
            {
               // ***** MSSQL *****
               namespace mssql
               {
                  template<>
                  struct default_type_traits<«resolveModules("BTC::PRINS::Commons::GUID")»>
                  {
                     static const database_type_id db_type_id = «resolveODB("id_uniqueidentifier")»;
                  };
            
                  template<>
                  class value_traits<BTC::PRINS::Commons::GUID, id_uniqueidentifier>
                  {
                  public:
                     typedef BTC::PRINS::Commons::GUID   value_type;
                     typedef BTC::PRINS::Commons::GUID   query_type;
                     typedef uniqueidentifier            image_type;
            
                     static void set_value(value_type& val, const image_type& img, bool is_null)
                     {
                        if (!is_null)
                        {
                           «resolveCAB("BTC::Commons::CoreExtras::UUID")» uuid;
                           «resolveSTL("std::array")»<char, 16> db_data;
                           «resolveSTL("std::memcpy")»(db_data.data(), &img, 16);
                           «resolveModules("BTC::PRINS::Commons::Utilities::GUIDHelper")»::guidEncode(db_data.data(), uuid);
                           val = BTC::PRINS::Commons::GUID::FromStringSafe("{" + uuid.ToString() + "}");
                        }
                        else
                           val = BTC::PRINS::Commons::GUID::nullGuid;
                     }
            
                     static void set_image(image_type& img, bool& is_null, const value_type& val)
                     {
                        is_null = false;
                        auto uuid = BTC::Commons::CoreExtras::UUID::ParseString(val.ToString());
                        std::array<char, 16> db_data;
                        BTC::PRINS::Commons::Utilities::GUIDHelper::guidDecode(uuid, db_data.data());
                        std::memcpy(&img, db_data.data(), 16);
                     }
                  };
               }
               
               // ***** ORACLE *****
               namespace oracle
               {
                  template<>
                  struct default_type_traits<«resolveModules("BTC::PRINS::Commons::GUID")»>
                  {
                     static const database_type_id db_type_id = «resolveODB("id_raw")»;
                  };
            
                  template<>
                  class value_traits<BTC::PRINS::Commons::GUID, id_raw>
                  {
                  public:
                     typedef BTC::PRINS::Commons::GUID   value_type;
                     typedef BTC::PRINS::Commons::GUID   query_type;
                     typedef char                        image_type[16];
            
                     static void set_value(value_type& val, const image_type img, std::size_t n, bool is_null)
                     {
                        «resolveCAB("BTC::Commons::CoreExtras::UUID")» uuid;
                        «resolveSTL("std::vector")»<char> db_data;
                        db_data.reserve(n);
                        «resolveSTL("std::memcpy")»(db_data.data(), img, n);
                        «resolveModules("BTC::PRINS::Commons::Utilities::GUIDHelper")»::guidEncode(db_data.data(), uuid);
                        val = BTC::PRINS::Commons::GUID::FromStringSafe("{" + uuid.ToString() + "}");
                     }
            
                     static void set_image(image_type img, std::size_t c, std::size_t& n, bool& is_null, const value_type& val)
                     {
                        is_null = false;
                        auto uuid = BTC::Commons::CoreExtras::UUID::ParseString(val.ToString());
                        std::vector<char> db_data;
                        db_data.resize(16);
                        BTC::PRINS::Commons::Utilities::GUIDHelper::guidDecode(uuid, db_data.data());
                        n = db_data.size();
                        std::memcpy (img, db_data.data(), n);
                     }
                  };
               }
            }
        '''

    }

}
