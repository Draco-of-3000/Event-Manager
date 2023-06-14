require 'csv'
require 'google/apis/civicinfo_v2'
require 'erb'
require 'time'


def clean_zipcode(zipcode)
    zipcode.to_s.rjust(5, '0')[0..4]
end

def clean_number(number)
  number.gsub!(/[\s\(\)\-\.]/, '')

  if number.length < 10
    number = 'Invalid number'
  elsif number.length == 11 && number[0] == '1'
    number = number[1..-1]
  elsif number.length == 1 && number[0] != 1
    number = 'Invalid number'
  elsif number.length > 11
    number = 'Invalid number'
  else
    number
  end
end


def peak_times(registry_dates)
  hour_counts = Hash.new(0)

  registry_dates.each do |date|
    time = Time.strptime(date, "%m/%d/%y %H:%M")
    hour_counts[time.strftime("%l%P")] += 1
  end

  max_hours = hour_counts.values.max
  peak_hours = hour_counts.select { |_hour, count| count == max_hours}.keys

  peak_hours.sort_by do |hour|
    [hour[/\d+/].to_i, hour[/[ap]+m/i]]
  end

  peak_hours
end

def registration_days(registry_dates)
  day_counts = Hash.new(0)

  registry_dates.each do |date|
    time = Time.strptime(date, "%m/%d/%y %H:%M")
    day_counts[time.strftime("%A")] += 1
  end

  max_days = day_counts.values.max
  peak_days = day_counts.select { |_day, count| count == max_days}.keys

  reg_days = peak_days.uniq
end


def legislators_by_zipcode(zip)
    civic_info = Google::Apis::CivicinfoV2::CivicInfoService.new
    civic_info.key = 'AIzaSyClRzDqDh5MsXwnCWi0kOiiBivP6JsSyBw'
  
    begin
      legislators = civic_info.representative_info_by_address(
        address: zip,
        levels: 'country',
        roles: ['legislatorUpperBody', 'legislatorLowerBody']
      )
      legislators = legislators.officials
      legislator_names = legislators.map(&:name)
      legislator_names.join(", ")
    rescue
      'You can find your representatives by visiting www.commoncause.org/take-action/find-elected-officials'
    end
end

def save_thank_you_letter(id,form_letter)
  Dir.mkdir('output') unless Dir.exist?('output')

  filename = "output/thanks_#{id}.html"

  File.open(filename, 'w') do |file|
    file.puts form_letter
  end
end


puts 'Event Manager Initialized'

contents = CSV.open(
    'event_attendees.csv',
    headers: true,
    header_converters: :symbol
)

template_letter = File.read('form_letter.erb')
erb_template = ERB.new template_letter

all_peak_hours = []
all_peak_days = []

contents.each do |row|
    id = row[0]
    name = row[:first_name]
    zipcode = row[:zipcode]
    number = row[:homephone]
    registry_dates = row[:regdate].split(',') 
    
    peak_hours = peak_times(registry_dates)
    reg_days = registration_days(registry_dates)

    all_peak_hours.concat(peak_hours)
    all_peak_days.concat(reg_days)

    #puts registry_dates

    zipcode = clean_zipcode(zipcode)

    number = clean_number(number)

    legislators = legislators_by_zipcode(zipcode)

    form_letter = erb_template.result(binding)

    save_thank_you_letter(id,form_letter)
end

puts "Most Active Hours: #{all_peak_hours.uniq.sort_by { |hour| [hour.include?("am") ? 0 : 1, hour] }}"
puts "Most Active Days: #{all_peak_days.uniq}"
