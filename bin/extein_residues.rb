#!/usr/bin/env ruby
Signal.trap("PIPE", "EXIT")
require "parse_fasta"

require "abort_if"

include AbortIf
include AbortIf::Assert

def trim_first str
  str[1 .. str.length - 1]
end

def trim_last str
  str[0 .. str.length - 2]
end

def trim_first_and_last str
  str[1 .. str.length - 2]
end

def has_first seq
  first = seq[0].upcase

  # Some have A at N-terminus
  first == "S" || first == "T" || first == "C" || first == "A"
end

def has_last_two seq
  last_two = seq[seq.length - 2, 2].upcase

  last_two == "HN" || last_two == "HQ" || last_two == "HQ" || last_two == "HD"
end

def check_residues seq
  has_first(seq) && has_last_two(seq)
end

infile = ARGV.first

indir = File.dirname infile
inext = File.extname infile
inbase = File.basename infile, inext

trimmed_and_good_out = File.join indir, "#{inbase}.trimmed_and_good.faa"
not_sure_out = File.join indir, "#{inbase}.not_sure.faa"

lala = { first: Hash.new(0),
         penult: Hash.new(0),
         last: Hash.new(0),
         last_two: Hash.new(0) }


total_apples = 0
File.open(trimmed_and_good_out, "w") do |good_f|
  File.open(not_sure_out, "w") do |not_sure_f|
    ParseFasta::SeqFile.open(ARGV.first).each_record do |rec|
      head = rec.header.downcase
      trimmed_seq = nil
      good = nil
      fhandle = nil

      which = "none"

      if head.include? "including -1 and +1 extein residue"
        trimmed_seq = trim_first_and_last rec.seq

        which = "first"

        good = check_residues trimmed_seq
      elsif head.include? "including +1 extein residue"
        abort_unless head.include?("c-terminal") || head.include?("n-term"), "had +1 but not c-terminal: #{rec.header}"

        trimmed_seq = trim_last rec.seq

        which = "second"

        good = has_last_two trimmed_seq
      elsif head.include? "including -1 extein residue"
        abort_unless head.include?("n-terminal") || head.include?("n-term"), "had -1 but not n-terminal: #{rec.header}"

        trimmed_seq = trim_first rec.seq

        which = "third"

        good = has_first trimmed_seq
      end

      unless which == "none"
        total_apples += 1
      end

      if trimmed_seq
        first = trimmed_seq[0].upcase
        penult = trimmed_seq[trimmed_seq.length - 2]
        last = trimmed_seq[trimmed_seq.length - 1]
        last_two = penult + last

        if which == "first" || which == "third"
          lala[:first][first] += 1
        end

        if which == "first" || which == "second"
          lala[:penult][penult] += 1
          lala[:last][last] += 1
          lala[:last_two][last_two] += 1
        end

        # puts [rec.header, trimmed_seq[0], trimmed_seq[trimmed_seq.length - 2, 2]].join "\t"
      end

      fhandle = good ? good_f : not_sure_f

      fhandle.puts ">#{rec.header}"
      fhandle.puts trimmed_seq

      # puts [rec.header, which, good].join "\t"
    end
  end
end

puts total_apples

lala.each do |which, info|
  info.each do |aa, count|
    puts [which, aa, count].join "\t"
  end
end
