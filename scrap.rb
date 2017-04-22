require 'rubygems'
require 'pry'
require './EPTCBus'

all_buses = {}

[3, 21, 22, 23].each do |zone|
  select_page = Nokogiri::HTML(open("http://www.eptc.com.br/EPTC_Itinerarios/Linha.asp?cdEmp=#{zone}"))
  select_page.css('option').each do |o|
    option_text = o.text.strip
    id = o.attributes["value"].value.to_s.strip
    url = "http://www.eptc.com.br/EPTC_Itinerarios/Cadastro.asp?" +
          "Linha=#{id}&Tipo=TH&Veiculo=1&Sentido=0&Logradouro=0" +
          "&Action=Tabela"

    puts option_text
    current_bus = EPTCBus.new(id, option_text, url)
    begin
      all_buses.merge!(current_bus.build(sleep: 5))
    rescue StandardError
      next
    end
  end
end

File.write("#{Time.now.strftime('%Y%m%d%H%M%S')}.json", all_buses.to_json)
