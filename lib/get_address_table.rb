require 'open-uri'

class RouterScraper
  def get_address_table
    doc=open("http://#{$ROUTER_ADDRESS}/Status_Lan.asp",{:http_basic_authentication => $ROUTER_ID_PASSWD}).read

    str=doc.scan(/setARPTable\( (\S*)\);/)[0][0]
    addresses=str.delete("'").split(",")

    result=[]
    col=[:name,:ip,:mac,:connect]
    addresses.each_slice(4){|i|
      col.zip(i).flatten
      result<<Hash[*col.zip(i).flatten]
    }

    result
  end
end

class RouterScraperDummy
  def get_address_table
    []
    #[{:mac => '9c:eb:e8:03:04:7b',:ip => '0.0.0.0'}] #sample
  end
end
