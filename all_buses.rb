require 'rubygems'
require 'pry'

[3, 21, 22, 23].each do |zone|
  select_page = Nokogiri::HTML(open("http://www.eptc.com.br/EPTC_Itinerarios/Linha.asp?cdEmp=#{zone}"))
  select_page.css('option').each do |o|
    option_text = o.text.strip
    id = o.attributes["value"].value.to_s.strip
    url = "http://www.eptc.com.br/EPTC_Itinerarios/Cadastro.asp?" +
          "Linha=#{id}&Tipo=TH&Veiculo=1&Sentido=0&Logradouro=0" +
          "&Action=Tabela"
    bus = EPTCBus.new(id, option_text, option_text, url)
    binding.pry
  end
end
