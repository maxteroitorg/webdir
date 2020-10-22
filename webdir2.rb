#!/usr/bin/ruby

require 'optparse'
require 'httparty'

Options = Struct.new(:list_web, :list_dir, :ssl, :status_code, :thread_num)

class Parser
  PROG_NAME = 'webdir'
  VERSION   = 'V2.0.0 22Oct2020'
  AUTHOR    = 'Leo Feradero Nugraha'

  def self.parse(options)
    args = Options.new(nil, nil, false, ["404"], 1)

    opt_parser = OptionParser.new do |opts|
      opts.banner = "Usage: #{PROG_NAME} -u <url_list> -d <dir_list>"
      opts.version = "#{PROG_NAME} #{VERSION} by #{AUTHOR}"
      
      opts.on('-u', '--url [FILENAME]', 'List urls.') do |url|
        args.list_web = url
      end
      
      opts.on('-d', '--dir [FILENAME]', 'List directory.') do |dir|
        args.list_dir = dir
      end
      
      opts.on('-s', '--ssl', 'Verify ssl (off by defaut).') do |flag|
        args.ssl = flag
      end

      opts.on('--ignore code1,code2,code3', Array, 'Ignore the status code(s) (default: [404]).') do |code|
        args.status_code.push(code).flatten!.uniq!
      end

      opts.on('-t', '--thread [N]', 'Number of thread(s) (default: 1).') do |num|
        args.thread_num = num.to_i
      end
      
      opts.on('-v', '--version', 'Print current version.') do
        puts "#{PROG_NAME} #{VERSION} by #{AUTHOR}"
        exit
      end
    end

    begin
      opt_parser.parse!(options)
    rescue OptionParser::MissingArgument => e
      puts "Error: #{e}"
      self.parse(%w[--help])
    rescue OptionParser::InvalidOption
      # discard invalid arg(s)
    end

    args
  end
end


$RED = "\033[0;31m"
$GREEN = "\033[0;32m"
$ORANGE = "\033[0;33m"
$L_PURPLE = "\033[1;35m"
$L_GRAY = "\033[0;37m"

$NORMAL = "\033[0m"
$UNDERLINE = "\033[4m"

$NC = "\033[0m"

response_code = {'200' => "#{$GREEN}OK#{$NC}",
                 '404' => "#{$RED}Not Found#{$NC}",
                 '403' => "#{$ORANGE}Forbidden#{$NC}",
                 '406' => "#{$RED}Not Acceptable#{$NC}"}


def get(url, ssl, ignore_list, response_code)
  begin
    resp = HTTParty.get(url, :verify => ssl)
    if !ignore_list.include?(resp.code.to_s)
      clock = Time.now # avoid calling Time.now many times
      # for realtime checking
      timestamp = "#{clock.hour.to_s.rjust(2, '0')}:"
      timestamp += "#{clock.min.to_s.rjust(2, '0')}:"
      timestamp += "#{clock.sec.to_s.rjust(2, '0')}"
      #
      print "[#{$L_PURPLE}#{timestamp}#{$NC}] #{$ORANGE}Path#{$NC} : "
      puts "#{$UNDERLINE}#{url}#{$NORMAL}"
      print "[#{$L_PURPLE}#{timestamp}#{$NC}]"
      puts " --> #{resp.code}[#{response_code[resp.code.to_s]}]"
    end
  rescue OpenSSL::SSL::SSLError
    puts "#{$RED}SSL Error!#{$NC}"
  rescue Errno::ECONNREFUSED
    puts "#{$RED}#Connection to #{url} Refused!#{$NC}"
  end
end

def scan(lweb, ldir, ssl, ignore_list, response_code, thread_num)
  puts \
  "#{$ORANGE}Automated Web and Directory listing.#{$NC}\n"\
  "Reading url(s) from      : #{lweb}\n"\
  "Reading dir(s) from      : #{ldir}\n"\
  "Ignoring status code(s)  : #{ignore_list.inspect}\n"\
  "Number of thread(s)      : #{thread_num}\n\n"

  begin
    _urls = File.open(lweb, 'r').read.split("\n").map{|s| s.gsub(/[\r\n]+/m, "")} 
    _dirs = File.open(ldir, 'r').read.split("\n").map{|s| s.gsub(/[\r\n]+/m, "")} 
  rescue Errno::ENOENT => e
    puts e
  end

  _urls.each do |url|
    puts "#{$ORANGE}Scanning : #{$L_GRAY}#{url}#{$NC}"
    links = _dirs.map do |dir|
      if dir[0] == '/'
        "#{url}#{dir}"
      elsif dir[0] == '#'
        nil #skipping comment section
      else
        "#{url}/#{dir}"
      end
    end
    while links.empty? == false do 
      begin
        threads = []
        thread_num.times {
          threads << Thread.new {
            req = links.shift
            get(req, ssl, ignore_list, response_code) if req.nil? == false
          }
        }
        # waiting for all threads to finish its job
        threads.each(&:join)
      rescue Interrupt
        puts "Leaving the program..."
        exit
      end
    end
    puts
  end
end

opts = Parser.parse(ARGV)
#pp opts

if (!opts.list_web.nil?) && (!opts.list_dir.nil?)
  scan(opts.list_web, opts.list_dir, opts.ssl, opts.status_code, response_code, opts.thread_num)
else
  Parser.parse(%w[--help])
end
