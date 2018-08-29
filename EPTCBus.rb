require 'rubygems'
require 'nokogiri'
require 'open-uri'
require 'json'
require 'pry'

class EPTCBus
  def initialize(id, name, url)
    @id = id.to_s.strip
    @url = url.to_s.strip
    @code = name.match(/^\w+/).to_s.to_sym
    @name = name.match(/(?!^\w+)(?!\s{1,}\-)\s.+(\n|)/m).to_s.strip
    @day_type = nil
    @direction = nil
    @info = {
      @code => {id: id, nome: @name, numero: @code, sentidos: [], horarios: {}}}
  end

  # blacklist
  def valid?(all_buses = {})
    if ['395-79', '394-27'].include?(@id) || all_buses[@code.to_s]
      return false
    end
  end

  def build(options = {sleep: 1})
    sleep options[:sleep]
    page = Nokogiri::HTML(open(@url))
    if page.text.match(/Nenhum registro encontrado/)
      raise StandardError, "Nenhum horario encontrado em #{@name}"
    end
    # TODO: find best way to do this
    # maybe page.text and then search schedules with regex
    schedule_objects = nil
    page.css('b').each do |row|
      text = row.text.to_s.strip
      if direction = which_direction(text)
        @direction = direction
        @info[@code][:sentidos] << @direction
        @info[@code][:horarios].merge!({@direction => {}})
        next
      elsif day_type = current_day(text)
        @day_type = day_type
        @info[@code][:horarios][@direction].merge!({day_type => {}})
        next
      elsif schedule = schedule_info(row)
        @info[@code][:horarios][@direction][@day_type].merge!(
          {schedule[:number] => {
            horario: schedule[:time],
            cadeirante: handicap?(row)
          }})
        next
      end
    end
    sort_schedules
    return @info
  end

  def sort_schedules
    @info[@code][:horarios][@direction].keys.each do |day_type|
      schedules = @info[@code][:horarios][@direction][day_type]
      @info[@code][:horarios][@direction][day_type] = {}
      schedules.keys.sort.each do |schedule_number|
        @info[@code][:horarios][@direction][day_type].merge!({
          schedule_number => schedules[schedule_number]
        })
      end
    end
  end

  def which_direction(text)
    case text
      when "BAIRRO/CENTRO"
        return "bairro_centro"
      when "CENTRO/BAIRRO"
        return "centro_bairro"
      when "BAIR/CENT/BAIR", "CENT/BAIR/CENT", "TERMINAL/BAIRRO/TERMINAL"
        return "circular"
      when "BAIRRO/TERMINAL"
        return "bairro_terminal"
      when "TERMINAL/BAIRRO"
        return "terminal_bairro"
      when "NORTE/SUL"
        return "norte_sul"
      when "SUL/NORTE"
        return "sul_norte"
      when "NORTE/LESTE"
        return "norte_leste"
      when "LESTE/NORTE"
        return "leste_norte"
      when "LESTE/SUL"
        return "leste_sul"
      when "SUL/LESTE"
        return "sul_leste"
      when "BAIRRO/TERMINAL"
        return "bairro_terminal"
      when "TERMINAL/BAIRRO"
        return "terminal_bairro"
      else
        return
    end
  end

  def current_day(text)
    case text
      when "Dias Úteis"
        return :dias_uteis
      when "Sábados"
        return :sabado
      when "Domingos"
        return :domingo
      else
        return
    end
  end

  def handicap?(row)
    if row.children.length > 1
      row.children[1].attributes['src'].value.to_s.match(/APD\.gif/) ? true : false
    else
      return false
    end
  end

  def schedule_info(row)
    schedule_time = row.text.match(/(\d{2})[:](\d{2})/)
    return if schedule_time.nil?
    {time: schedule_time[0], number: "#{schedule_time[1]}#{schedule_time[2]}".to_i}
  end
end
