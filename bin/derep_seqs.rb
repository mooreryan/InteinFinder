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

seqs.each do |seq, ids|
  id = ids.sort.first

  printf ">%s\n%s\n", id, seq

  ids.sort.each do |other_id|
    STDERR.printf "%s\t%s\n", id, other_id
  end
end
