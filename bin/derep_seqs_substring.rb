#!/usr/bin/env ruby
Signal.trap("PIPE", "EXIT")
require "parse_fasta"

seqs = {}
ParseFasta::SeqFile.open(ARGV.first).each_record do |rec|
  if seqs.has_key? rec.seq
    seqs[rec.seq] << rec.id
  else
    seqs[rec.seq] = [rec.id]
  end
end

seqs = seqs.sort_by { |seq, ids| seq.length }.reverse

count = seqs.count

count.times do |idx|
  seq1 = seqs[idx][0]
  ids1 = seqs[idx][1]

  (idx+1 .. count-1).times do |idx2|
    seq2 = seqs[idx2][0]
    ids2 = seqs[idx2][1]

seqs.each do |seq, ids|
  id = ids.sort.first

  printf ">%s\n%s\n", id, seq

  ids.sort.each do |other_id|
    STDERR.printf "%s\t%s\n", id, other_id
  end
end
