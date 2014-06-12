require 'open-uri'

AddressEntry=Struct.new(:name,:ip,:mac,:connect)

class RouterScraper
  def get_address_table
    doc=open("http://#{$ROUTER_ADDRESS}/Status_Lan.asp",{:http_basic_authentication => $ROUTER_ID_PASSWD}).read

    str=doc.scan(/setARPTable\( (\S*)\);/)[0][0]
    addresses=str.delete("'").split(",")

    result=[]
    addresses.each_slice(4){|i|
      result<<AddressEntry.new(*i)
    }

    result
  end
end

class RouterScraperDummy
  def get_address_table
    #[]
    [AddressEntry.new('','0.0.0.0','9c:eb:e8:03:04:7b',0)] #sample
  end
end

