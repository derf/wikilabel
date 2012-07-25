require 'rubygems'
require 'media_wiki'
require 'prawn'

title = ARGV[0]
page_url = "https://wiki.chaosdorf.de/#{title.gsub(' ','_')}"
labeloptions = {:margin => 10, :left_margin => 20, :page_size => [255,107], :format => :landscape}
mw = MediaWiki::Gateway.new("https://wiki.chaosdorf.de/api.php")
templates = mw.get(title).gsub(/[\r\n]/,'').scan(/{{([^}}]*)}}/)
templates.each do |template|
  fields = template[0].split("|")
  properties = fields.collect! do |field|
    property = field.split("=")
  end
  properties = Hash[properties]
  type = fields.shift.first
  case type
  when "Resource"
    filename = title.downcase+".pdf"
    pdftitle = "#{properties['name']}"
    pdftext = "is #{properties['ownership']} by #{properties['contactnick']}.  Use #{properties['use']} for #{properties['description']}. Put into #{properties['location']}. If broken #{properties['broken']}. If annoying #{properties['annoying']}.\n Date: #{Date.today}"
    Prawn::Document.generate(filename, labeloptions) do
      font "computerfont.ttf"
      font_size 14
      text pdftitle
      font "cpmono_v07.ttf"
      font_size 8
      text "\n"
      text pdftext
      font_size 6
      move_cursor_to(7)
      text page_url
    end
  when "Book"
    filename = title.downcase.gsub("book:", "")+".pdf"
    Prawn::Document.generate(filename, labeloptions) do
      font "computerfont.ttf"
      font_size 10
      text "This book belongs into the Chaosdorf Bookshelf.\nRead it, comment it, share it!"
      font "cpmono_v07.ttf"
      font_size 8
      text "\n"
      case properties['ownership']
      when 'private'
        text "Please ask #{properties['owner']} for permission and put your name into the wiki before borrowing it. After reading, please return it immediately."
      when 'lent'
        text "Please put your name into the wiki before borrowing it. After reading, please return it immediately. The owner is #{properties['owner']}."
      when 'club'
        text "Please put your name into the wiki before borrowing it. After reading, please return it immediately. It has been donated to the club."
      end
      font_size 5
      move_cursor_to(7)
      text page_url
    end
  else
    puts "Warning: #{type} is an unknown object type. Currently, only resources and books are supported."
  end
end
