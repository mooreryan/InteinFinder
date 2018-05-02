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

assert seqs.count == inteins.count

seqs.count.times do |idx|
  seq = seqs[idx]
  intein = inteins[idx]

  chars = seq.seq.chars

  first_part = chars.take(99).join
  last_part = chars.drop(99).join

  new_seq = sprintf "%s%sC%s", first_part, intein.seq, last_part

  puts ">#{seq.id}---#{intein.id}---100~to~#{intein.seq.length+99}"
  puts new_seq
end
