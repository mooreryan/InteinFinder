#!/usr/bin/env ruby
Signal.trap("PIPE", "EXIT")

require "abort_if"

include AbortIf
include AbortIf::Assert

QSTART_IDX = 6
QEND_IDX = 7
PADDING = 10

def new_region regions, qstart, qend
  regions[regions.count] = { qstart: qstart, qend: qend }
end

def clipping_region region, padding
  { qstart: region[:qstart] - padding,
    qend: region[:qend] + padding }
end

hits = []
File.open(ARGV.first, "rt").each_line do |line|
  unless line.downcase.start_with? "query"
    ary = line.chomp.split("\t")
    ary[QSTART_IDX] = ary[QSTART_IDX].to_i
    ary[QEND_IDX] = ary[QEND_IDX].to_i
    hits << ary
  end
end

# Sort by qstart, if tied, break tie with qend
hits.sort! do |a, b|
  comp = a[QSTART_IDX] <=> b[QSTART_IDX]

  comp.zero? ? (a[QEND_IDX] <=> b[QEND_IDX]) : comp
end

regions = {}

hits.each do |ary|
  qstart = ary[QSTART_IDX]
  qend   = ary[QEND_IDX]

  abort_if qstart == qend,
           "BAD STUFF (#{qstart}, #{qend})"

  if regions.empty?
    new_region regions, qstart, qend
  else
    last_region = regions.count - 1
    if qstart >= regions[last_region][:qend]
      new_region regions, qstart, qend
    elsif qend > regions[last_region][:qend]
      regions[last_region][:qend] = qend
    end
  end
end

regions.each do |id, region|
  cut_this = clipping_region region, PADDING

  puts [region[:qstart], region[:qend]].join "\t" #, cut_this[:qstart], cut_this[:qend]].join "\t"
end
