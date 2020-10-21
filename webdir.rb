#!/usr/bin/ruby
require 'httparty'
require 'optparse'


$RED="\033[0;31m"
$GREEN="\033[0;32m"
$ORANGE="\033[0;33m"
$L_PURPLE="\033[1;35m"

$NORMAL = "\033[0m"
$UNDERLINE = "\033[4m"

$NC="\033[0m"

def scan(lweb, ldir, ssl, response_code)
  begin
    _urls = File.open(lweb, 'r').read.split("\n")
    _dirs = File.open(ldir, 'r').read.split("\n")
  rescue Errno::ENOENT => e
    puts e
  end

  _urls.each do |url|
    _dirs.each do |dir|
      begin
        req = "#{url}#{dir}"
        clock = Time.now # avoid calling Time.now many times
        timestamp = "#{clock.hour}:#{clock.min}:#{clock.sec}"
        print "[#{$L_PURPLE}#{timestamp}#{$NC}] Requesting: "
        puts "#{$UNDERLINE}#{req}#{$NORMAL}"
        resp = HTTParty.get(req, :verify => ssl)
        print "[#{$L_PURPLE}#{timestamp}#{$NC}]"
        puts " --> #{resp.code}[#{response_code[resp.code.to_s]}]"
      rescue Interrupt
        puts "Leaving the program..."
        exit
      rescue OpenSSL::SSL::SSLError
        puts "SSL Error"
      end
    end
  end
end

response_code = {"200"=>"#{$GREEN}OK#{$NC}",
                 "404"=>"#{$RED}Not Found#{$NC}",
                 "403"=>"#{$ORANGE}Forbidden#{$NC}",
                 "406"=>"#{$RED}Not Acceptable#{$NC}"}

list_web = ''
list_dir = ''
verif_ssl = false

def help
  "Usage: #{__FILE__} -u 'list_web' -d 'list_dir' [--ssl-check if needed]"
end

OptionParser.new do |parser|
  parser.banner = help
  parser.version = "1.0.0"
  parser.on('-u', '--url FILENAME', 'List urls.') { |url| list_web = url}
  parser.on('-d', '--dir FILENAME', 'List directory.') { |dir| list_dir = dir}
  parser.on('-s', '--ssl-check', 'Verify ssl (off by defaut)') {|v| verif_ssl = v}
end.parse!


if (list_web != '') && (list_dir != '')
  scan(list_web, list_dir, verif_ssl, response_code)
else
  puts help
end
