#!/usr/bin/env ruby
Signal.trap("PIPE", "EXIT")

require "abort_if"

include AbortIf
include AbortIf::Assert




link_match = /<a href="(intein.*name=.*)">/

"intein8a5d.html?name=APMV+Pol"

list = "http://www.biocenter.helsinki.fi/bi/iwai/InBase/tools.neb.com/inbase/list.html"
list_html = `\\curl --silent '#{list}'`.chomp

details_base = "http://www.biocenter.helsinki.fi/bi/iwai/InBase/tools.neb.com/inbase/"




seq_match = /<FONT FACE="Courier">&gt;(.*)<\/FONT><\/TD><\/TR><TR><TH ALIGN=RIGHT VALIGN=TOP>Block A/
seq_match_with_carrot = /<FONT FACE="Courier">>;(.*)<\/FONT><\/TD><\/TR><TR><TH ALIGN=RIGHT VALIGN=TOP>Block A/

link_end_things = list_html.scan(link_match).flatten

num = link_end_things.count

link_end_things.each_with_index do |link_end, idx|
  STDERR.printf("WORKING -- %d of %d\r", idx, num)
  sleep rand

  link = "#{details_base}#{link_end}"

  intein_data = `\\curl --silent #{link}`.gsub(/\n/, "")

  if intein_data.empty?
    STDERR.puts "WARN -- couldn't curl #{link}"
    next
  end

  match = intein_data.match seq_match

  if !match
    match = intein_data.match seq_match_with_carrot

    if !match
      STDERR.puts "WARN -- no match data for #{link}"
      next
    end
  end

  tokens = match[1].split(/<br *\/*>/)

  if tokens.count < 2
    STDERR.puts "WARN -- no header and seq info for #{link}"
    next
  end

  header = ">#{tokens.shift}"
  seq = tokens.join

  puts header
  puts seq
end

