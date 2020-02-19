# frozen_string_literal: true

require 'rubygems'
require 'nokogiri'
require 'open-uri'

require './models'

# Bus class that will parse the html content and save into sqlite
class EPTCBus
  def initialize(id, name, url)
    @id = id.to_s.strip
    @url = url.to_s.strip
    @code = name.match(/^\w+/).to_s.to_sym
    @name = name.match(/(?!^\w+)(?!\s{1,}\-)\s.+(\n|)/m).to_s.strip
    @is_summer_time = false # :(
    @current_day_type = nil
    @current_direction = nil
    @direction_types = {
      unknown: 0, circular: 1,
      bairro_centro: 2, centro_bairro: 3,
      bairro_terminal: 4, terminal_bairro: 5,
      norte_sul: 6, sul_norte: 7,
      norte_leste: 8, leste_norte: 9,
      leste_sul: 10, sul_leste: 11
    }
    @day_types = { unknown: 0, mon_fri: 1, saturday: 2, sunday: 3 }
  end

  # blacklist
  def valid?(all_buses = {})
    return false if %w[395-79 394-27].include?(@id) || all_buses[@code.to_s]
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
    @current_direction ||= :unknown
    @current_day_type ||= :unknown

    # week_day values based on the date of: 03/01/2020,
    # so it's even possible to query the stop_datetime based on the week day.
    week_day = { mon_fri: 3, saturday: 4, sunday: 5 }
    day = week_day[@current_day_type]
    hour = schedule_data[0]
    minute = schedule_data[1]
    time_date_time = DateTime.new(2020, 1, day, hour, minute, 0, 0, 0)

    Schedule.find_or_create_by!(
      direction: @direction_types[@current_direction],
      dayType: @day_types[@current_day_type],
      hour: hour,
      minute: minute,
      time: schedule_data[2],
      timeDateTime: time_date_time,
      isHandicap: is_handicap,
      isSummerTime: @is_summer_time
    )
  end

  def create_bus_stop(bus, schedule)
    BusStop.create!(bus_id: bus.id, schedule_id: schedule.id)
  end

  def build(options = { sleep: 1 })
    sleep options[:sleep]
    page = Nokogiri::HTML(open(@url))
    if page.text.match(/Nenhum registro encontrado/)
      error_message = "Nenhum horario encontrado em #{@code} - #{@name}"
      raise StandardError, error_message
    end

    page.xpath('//b').each do |row|
      # Collect schedule info here
      text = row.text.to_s.strip
      @is_summer_time = summer_time?(text)
      if (direction = which_direction(text))
        @current_direction = direction
        next
      elsif (day_type = which_day_type(text))
        @current_day_type = day_type
        next
      elsif (schedule_data = schedule_info(row))
        # INSERT new schedule here
        bus = create_bus
        schedule = create_schedule(schedule_data, handicap?(row))
        create_bus_stop(bus, schedule)
        next
      end
    end
  end

  def which_direction(text)
    case text
    when 'BAIRRO/CENTRO'
      :bairro_centro
    when 'CENTRO/BAIRRO'
      :centro_bairro
    when 'BAIR/CENT/BAIR', 'CENT/BAIR/CENT', 'TERMINAL/BAIRRO/TERMINAL'
      :circular
    when 'BAIRRO/TERMINAL'
      :bairro_terminal
    when 'TERMINAL/BAIRRO'
      :terminal_bairro
    when 'NORTE/SUL'
      :norte_sul
    when 'SUL/NORTE'
      :sul_norte
    when 'NORTE/LESTE'
      :norte_leste
    when 'LESTE/NORTE'
      :leste_norte
    when 'LESTE/SUL'
      :leste_sul
    when 'SUL/LESTE'
      :sul_leste
    end
  end

  def which_day_type(text)
    case text
    when 'Dias Úteis'
      :mon_fri
    when 'Sábados'
      :saturday
    when 'Domingos'
      :sunday
    end
  end

  def handicap?(row)
    if row.children.length > 1
      time_row_text = row.children[1].attributes['src'].value.to_s
      time_row_text.match(/APD\.gif/) ? true : false
    else
      false
    end
  end

  def summer_time?(text)
    if text.match(/\sVERAO$/)
      true # :D
    elsif text.match(/\sOFICIAL$/)
      false # :(
    else
      @is_summer_time
    end
  end

  def schedule_info(row)
    schedule_time = row.text.match(/(\d{2})[:](\d{2})/)
    return false if schedule_time.nil?

    [schedule_time[1].to_i, schedule_time[2].to_i, schedule_time[0]]
  end
end
