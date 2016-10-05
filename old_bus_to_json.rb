require 'rubygems'
require 'nokogiri'
require 'open-uri'
require 'json'
require 'pry'
require 'byebug'

file = File.read('./output.json')
all_buses = file ? JSON.parse(file) : {}

blacklist = ['395-79', '394-27']
empty = []

[3, 21, 22, 23].each do |zone|
  sleep 4
  select_page = Nokogiri::HTML(open("http://www.eptc.com.br/EPTC_Itinerarios/Linha.asp?cdEmp=#{zone}"))

  select_page.css('option').each do |o|

    option_text = o.text.strip
    id = o.attributes["value"].value.to_s.strip
    bus_code = option_text.match(/^\w+/).to_s.to_sym
    bus_name = option_text.match(/(?!^\w+)(?!\s{1,}\-)\s.+(\n|)/m).to_s.strip
    # bus_name = option_text.match(/-\s.+/).to_s.gsub(/^-\s/, '')

    if all_buses[bus_code.to_s] || blacklist.include?(id)
      # puts all_buses[bus_code.to_s]["nome"] if all_buses[bus_code.to_s]
      next
    end

    bus = {bus_code => {id: id, nome: bus_name, code: bus_code, horarios: {}}}

    sleep 5
    begin
      url = "http://www.eptc.com.br/EPTC_Itinerarios/Cadastro.asp?" +
            "Linha=#{id}&Tipo=TH&Veiculo=1&Sentido=0&Logradouro=0" +
            "&Action=Tabela"
      page = Nokogiri::HTML(open(url))
    rescue
      puts all_buses.to_json
      abort
    end

    if page && page.text.match(/Nenhum registro encontrado/)
      sleep 5
      empty << id
      next
    end

    direction = :none
    bus_info = {}
    day_type = :dias_uteis
    row = ''
    page.css('b').each do |b|
      row = b.text.strip
      case row
        when "BAIRRO/CENTRO"
          direction = :ida
          sentido = "bairro_centro"
          bus_info.merge!(ida: {sentido: sentido})
          next
        when "CENTRO/BAIRRO"
          direction = :volta
          sentido = "centro_bairro"
          bus_info.merge!(volta: {sentido: sentido})
          next
        when "BAIR/CENT/BAIR", "CENT/BAIR/CENT", "TERMINAL/BAIRRO/TERMINAL"
          direction = :circular
          sentido = "circular"
          bus_info.merge!(circular: {sentido: sentido})
          next
        when "BAIRRO/TERMINAL"
          direction = :ida
          sentido = "bairro_terminal"
          bus_info.merge!(ida: {sentido: sentido})
          next
        when "TERMINAL/BAIRRO"
          direction = :volta
          sentido = "terminal_bairro"
          bus_info.merge!(volta: {sentido: sentido})
          next
        when "NORTE/SUL"
          direction = :ida
          sentido = "norte_sul"
          bus_info.merge!(ida: {sentido: sentido})
          next
        when "SUL/NORTE"
          direction = :volta
          sentido = "sul_norte"
          bus_info.merge!(volta: {sentido: sentido})
          next
        when "NORTE/LESTE"
          direction = :ida
          sentido = "norte_leste"
          bus_info.merge!(ida: {sentido: sentido})
          next
        when "LESTE/NORTE"
          direction = :volta
          sentido = "leste_norte"
          bus_info.merge!(volta: {sentido: sentido})
          next
        when "LESTE/SUL"
          direction = :ida
          sentido = "leste_sul"
          bus_info.merge!(ida: {sentido: sentido})
          next
        when "SUL/LESTE"
          direction = :volta
          sentido = "sul_leste"
          bus_info.merge!(volta: {sentido: sentido})
          next
        when "BAIRRO/TERMINAL"
          direction = :ida
          sentido = "bairro_terminal"
          bus_info.merge!(ida: {sentido: sentido})
          next
        when "TERMINAL/BAIRRO"
          direction = :volta
          sentido = "terminal_bairro"
          bus_info.merge!(volta: {sentido: sentido})
          next
      end

      case row
        when "Dias Úteis"
          day_type = :dias_uteis
          bus_info[direction].merge!(dias_uteis: [])
          next
        when "Sábados"
          day_type = :sabado
          bus_info[direction].merge!(sabado: [])
          next
        when "Domingos"
          day_type = :domingo
          bus_info[direction].merge!(domingo: [])
          next
      end
      time = row.match(/(\d{2})[:](\d{2})/)
      is_disabled_people = b.to_s.match(/APD\.gif/) ? true : false
      unless time.nil?
        time_array = [time[1].to_i, time[2].to_i]
        bus_info[direction][day_type] << [time_array, cadeirante: is_disabled_people]
      end
    end
    bus[bus_code][:horarios].merge!(bus_info)
    all_buses.merge!(bus)
  end
end
puts all_buses.to_json
