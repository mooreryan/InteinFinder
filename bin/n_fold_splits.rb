#!/usr/bin/env ruby
Signal.trap("PIPE", "EXIT")

require "parse_fasta"
require "abort_if"

include AbortIf
include AbortIf::Assert

num_out = ARGV[0].to_i
fname = ARGV[1]

outfiles = num_out.times.map do |n|
  outfname = "#{fname}.fold_#{n}"
  abort_if File.exist?(outfname),
           "#{outfname} already exists"

  File.open(outfname, "w")
end

# TODO if there are more splits than seqs, you will have empty files.

rec_idx = 0
ParseFasta::SeqFile.open(fname).each_record do |rec|
  STDERR.printf("Reading: #{rec_idx}\r") if (rec_idx % 10_000).zero?

  outfiles[rec_idx % num_out].puts rec

  rec_idx += 1
end

outfiles.each do |f|
  f.close
end
