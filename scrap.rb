require 'rubygems'
require './EPTCBus'
# require 'pry'

counter = 1
[3, 21, 22, 23].each do |zone|
  select_page = Nokogiri::HTML(open("http://www.eptc.com.br/EPTC_Itinerarios/Linha.asp?cdEmp=#{zone}"))
  select_page.css('option').each do |o|
    bus_row_text = o.text.strip
    id = o.attributes["value"].value.to_s.strip
    url = "http://www.eptc.com.br/EPTC_Itinerarios/Cadastro.asp?" +
          "Linha=#{id}&Tipo=TH&Veiculo=1&Sentido=0&Logradouro=0" +
          "&Action=Tabela"

    puts "#{bus_row_text} (#{((counter.to_f / 379.0) * 100).to_i}% - #{counter}/379)"
    current_bus = EPTCBus.new(id, bus_row_text, url)
    counter = counter + 1
    begin
      current_bus.build(sleep: 2)
    rescue StandardError
      next
    end
  end
end
