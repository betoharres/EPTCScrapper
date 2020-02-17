require 'rubygems'
require 'nokogiri'
require 'open-uri'

require './models'

class EPTCBus
  def initialize(id, name, url)
    @id = id.to_s.strip
    @url = url.to_s.strip
    @code = name.match(/^\w+/).to_s.to_sym
    @name = name.match(/(?!^\w+)(?!\s{1,}\-)\s.+(\n|)/m).to_s.strip
    @day_type = nil
    @direction = nil
    @direction_types = {
      unknown: 0         , circular: 1        ,
      bairro_centro: 2   , centro_bairro: 3   ,
      bairro_terminal: 2 , terminal_bairro: 5 ,
      norte_sul: 6       , sul_norte: 7       ,
      norte_leste: 8     , leste_norte: 9     ,
      leste_sul: 10      , sul_leste: 11      ,
    }
    @day_types = { unknown: 0, mon_fri: 1, saturday: 2, sunday: 3 }
    @bus = nil
    @schedule = nil
    @bus_stop = nil
  end

  # blacklist
  def valid?(all_buses = {})
    if ['395-79', '394-27'].include?(@id) || all_buses[@code.to_s]
      return false
    end
  end

  def create_bus
    Bus.find_or_create_by!(
      identifier: @id,
      code: @code,
      name: @name,
      url: @url
    )
  end

  def create_schedule(schedule_data, is_handicap)
    unless @direction
      @direction = @direction_types[:unknown]
    end
    unless @day_type
      @day_type = @day_type[:unknown]
    end
    hour = schedule_data[0]
    minute = schedule_data[1]
    time = DateTime.new(2020, 1, 1, hour, minute, 0, 0, 0)
    Schedule.create!(
      direction: @direction,
      day_type: @day_type,
      stop_datetime: time,
      time: schedule_data[2],
      is_handicap: is_handicap
    )
  end

  def build(options = {sleep: 1})
    sleep options[:sleep]
    page = Nokogiri::HTML(open(@url))
    if page.text.match(/Nenhum registro encontrado/)
      raise StandardError, "Nenhum horario encontrado em #{@name}"
    end
    page.xpath('//b').each do |row|
      # Collect schedule info here
      text = row.text.to_s.strip
      if direction = which_direction(text)
        @direction = direction
        next
      elsif day_type = which_day_type(text)
        @day_type = day_type
        next
      elsif schedule_data = schedule_info(row)
        # INSERT new schedule here
        is_handicap = handicap?(row)
        @bus = create_bus
        @schedule = create_schedule(schedule_data, is_handicap)
        @bus_stop = BusStop.create!(bus_id: @bus.id, schedule_id: @schedule.id)
        next
      end
    end
  end

  def which_direction(text)
    case text
      when "BAIRRO/CENTRO"
        return @direction_types[:bairro_centro]
      when "CENTRO/BAIRRO"
        return @direction_types[:centro_bairro]
      when "BAIR/CENT/BAIR", "CENT/BAIR/CENT", "TERMINAL/BAIRRO/TERMINAL"
        return @direction_types[:circular]
      when "BAIRRO/TERMINAL"
        return @direction_types[:bairro_terminal]
      when "TERMINAL/BAIRRO"
        return @direction_types[:terminal_bairro]
      when "NORTE/SUL"
        return @direction_types[:norte_sul]
      when "SUL/NORTE"
        return @direction_types[:sul_norte]
      when "NORTE/LESTE"
        return @direction_types[:norte_leste]
      when "LESTE/NORTE"
        return @direction_types[:leste_norte]
      when "LESTE/SUL"
        return @direction_types[:leste_sul]
      when "SUL/LESTE"
        return @direction_types[:sul_leste]
      when "BAIRRO/TERMINAL"
        return @direction_types[:bairro_terminal]
      when "TERMINAL/BAIRRO"
        return @direction_types[:terminal_bairro]
      else
        return
    end
  end

  def which_day_type(text)
    case text
      when "Dias Úteis"
        return @day_types[:mon_fri]
      when "Sábados"
        return @day_types[:saturday]
      when "Domingos"
        return @day_types[:sunday]
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
    return false if schedule_time.nil?
    return [schedule_time[1].to_i, schedule_time[2].to_i, schedule_time[0]]
  end
end
