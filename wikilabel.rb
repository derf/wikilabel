require 'rubygems'
require 'media_wiki'
require 'prawn'
require 'mongrel'

host    = ARGV[0] || "0.0.0.0"
port    = ARGV[1] || 9292

class HandlerDebug < Mongrel::HttpHandler
  def process(request, response)
    title = Mongrel::HttpRequest.unescape(request.params['QUERY_STRING'])
    response.start(200) do |head, out|
      head["Content-Type"] = "text/plain"
      out.write title
    end
  end
end


class HandlerDerp < Mongrel::HttpHandler
  def process(request, response)
    title = Mongrel::HttpRequest.unescape(request.params['QUERY_STRING'])
    filename = 0
    page_url = "https://wiki.chaosdorf.de/#{title.gsub(' ','_')}"
    labeloptions = {:margin => 12, :left_margin => 20, :page_size => [255,107], :format => :landscape}
    mw = MediaWiki::Gateway.new("https://wiki.chaosdorf.de/api.php")
    site = mw.get(title)
    if site
      templates = site.gsub(/[\r\n]/,'').scan(/{{([^}}]*)}}/)
      templates.each do |template|
        fields = template[0].split("|")
        properties = fields.collect! do |field|
          property = field.split("=")
        end
        properties = Hash[properties]
        type = fields.shift.first
        case type
        when "Resource"
          filename = "tmp/"+title.downcase.gsub(/\//, '-')+".pdf"
          pdftitle = "#{properties['name']}"
          usage = 'unknown'
          ownership = 'unknown'
          case properties['ownership']
          when 'club'
            ownership = "collective property"
          when 'private'
            ownership = "private property of #{properties['contactnick']}"
          when 'lent'
            ownership = "lent by #{properties['contactnick']}"
          end
          case properties['use']
          when 'free'
            usage = 'freely'
          when 'ask'
            usage = 'with permission'
          when 'rtfm'
            usage = 'after reading manual'
          when 'no'
            usage = 'not at all'
          when 'careful'
            usage = 'carefully'
          when 'payment'
            usage = 'after donation'
          end
          pdftext = "#{properties['description']}\nIs #{ownership}. " +
            "Use #{usage}. Put into #{properties['location']}. "
          if properties['broken']
            pdftext << "If broken #{properties['broken']}. "
          end
          if properties['annoying']
            pdftext << "If annoying #{properties['annoying']}."
          end
          pdftext << "\nDate: #{Date.today}"
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
          filename = "tmp/"+title.downcase.gsub("book:", "").gsub(/\//, '-')+".pdf"
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
      file = File.new(filename, "r")
      response.start(200) do |head, out|
        head["Content-Type"] = "application/pdf"
        out.write open(filename, "rb") {|io| io.read }
      end
    else
      response.start(500) do |head, out|
        head["Content-Type"] = "text/plain"
        out.write "No such wiki page"
      end
    end
  end
end

config = Mongrel::Configurator.new :host => host, :port => port do
  listener do
#    uri "/debug",         :handler => HandlerDebug.new, :in_front => true
    uri "/",              :handler => HandlerDerp.new
  end
  trap("INT") { stop }
  trap("TERM") { stop }
  run
end

config.join
