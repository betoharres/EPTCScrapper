# frozen_string_literal: true

require 'rubygems'
require './EPTCBus'
# require 'pry'

counter = 1
[3, 21, 22, 23].each do |zone|
  select_page = Nokogiri::HTML(
    open("http://www.eptc.com.br/EPTC_Itinerarios/Linha.asp?cdEmp=#{zone}")
  )
  select_page.css('option').each do |o|
    bus_row_text = o.text.strip
    id = o.attributes['value'].value.to_s.strip
    url = 'http://www.eptc.com.br/EPTC_Itinerarios/Cadastro.asp?' \
          "Linha=#{id}&Tipo=TH&Veiculo=1&Sentido=0&Logradouro=0" \
          '&Action=Tabela'

    puts "#{bus_row_text} (#{((counter / 408.0) * 100).to_i}% - #{counter}/408)"
    current_bus = EPTCBus.new(id, bus_row_text, url)
    begin
      current_bus.build(sleep: 2)
      counter += 1
    rescue StandardError => error
      puts error
      next
    end
  end
end
