#!/usr/bin/env ruby
Signal.trap("PIPE", "EXIT")
require "parse_fasta"

counts = { first: Hash.new(0), last: Hash.new(0) }
num_seqs = 0
ParseFasta::SeqFile.open(ARGV.first).each_record do |rec|
  num_seqs += 1

  first_char = rec.seq[0]
  last_chars = rec.seq[rec.seq.length - 2, 2]

  counts[:first][first_char] += 1
  counts[:last][last_chars] += 1
end

counts.each do |which, counts|
  counts.sort_by { |aa, count| count }.reverse.each do |aa, count|
    puts [which, aa, count, (count / num_seqs.to_f * 100).round(3)].join "\t"
  end
end
