#!/usr/bin/env ruby
Signal.trap("PIPE", "EXIT")

actual = ARGV[0]

require "set"

puts %w[seq good.target good.start good.stop good.trimmable].join "\t"
File.open(actual, "rt").each_line.with_index do |line, idx|
  unless idx.zero?
    seq, region, start, stop, len, trimmable, target, evalue = line.chomp.split "\t"

    exp_target = seq.match(/---(.*_seq_.*)---/)[1]
    exp_start = seq.match(/---([0-9]+)~to~/)[1]
    exp_stop = seq.match(/~to~([0-9]+)$/)[1]

    test1 = exp_target == target
    test2 = exp_start == start
    test3 = exp_stop == stop
    test4 = trimmable == "Yes"

    if [test1, test2, test3, test4].any? { |test| test == false }
      puts [seq, exp_target == target, exp_start == start, exp_stop == stop, trimmable == "Yes"].join "\t"
      STDERR.puts line
    end
  end
end
