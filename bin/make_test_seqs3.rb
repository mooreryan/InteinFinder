#!/usr/bin/env ruby
Signal.trap("PIPE", "EXIT")
require "parse_fasta"

seqs_f = ARGV[0]
inteins_f = ARGV[1]

seqs = []
ParseFasta::SeqFile.open(seqs_f).each_record do |rec|
  seqs << rec
end

inteins = []
ParseFasta::SeqFile.open(inteins_f).each_record do |rec|
  inteins << rec
end

require "abort_if"

include AbortIf
include AbortIf::Assert

INSERT_IDX = 49

STDERR.puts %w[seq region.id start end len trimmable refining.target].join "\t"
seqs.each_with_index do |seq, idx|
  if rand < 0.5
    intein = inteins.sample

    chars = seq.seq.chars

    first_part = chars.take(INSERT_IDX).join
    last_part = chars.drop(INSERT_IDX).join

    new_seq = sprintf "%s%sC%s", first_part, intein.seq, last_part

    seq_name = "seq_#{idx+1}---#{intein.id}---#{INSERT_IDX+1}~to~#{intein.seq.length+INSERT_IDX}"

    puts ">#{seq_name}"
    puts new_seq

    start_pos = INSERT_IDX + 1
    end_pos = intein.seq.length + INSERT_IDX
    len = end_pos - start_pos + 1

    STDERR.puts [seq_name, 0, start_pos, end_pos, len, "Yes", intein.id].join "\t"
  else
    seq_name = "seq_#{idx+1}---NO_INTEINS_ADDED"

    puts ">#{seq_name}"
    puts seq.seq
  end
end
