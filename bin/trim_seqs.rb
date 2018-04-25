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

infile = ARGV.first

indir = File.dirname infile
inext = File.extname infile
inbase = File.basename infile, inext


not_sure_out = File.join indir, "#{inbase}.not_sure.not_trimmed.faa"

# TODO check and make sure that there aren't inteins in InBase with
# the endonuclease removed.
full_len_out = File.join indir, "#{inbase}.both.trimmed.faa"
start_only_out = File.join indir, "#{inbase}.n_term.trimmed.faa"
end_only_out = File.join indir, "#{inbase}.c_term.trimmed.faa"

lala = { first: Hash.new(0),
         penult: Hash.new(0),
         last: Hash.new(0),
         last_two: Hash.new(0) }


total_apples = 0
File.open(full_len_out, "w") do |both_f|
  File.open(start_only_out, "w") do |start_f|
    File.open(end_only_out, "w") do |end_f|
      File.open(not_sure_out, "w") do |not_sure_f|

        ParseFasta::SeqFile.open(ARGV.first).each_record do |rec|
          head = rec.header.downcase
          trimmed_seq = nil

          if head.include? "including -1 and +1 extein residue"
            trimmed_seq = trim_first_and_last rec.seq

            both_f.puts ">#{rec.header}"
            both_f.puts trimmed_seq
          elsif head.include? "including +1 extein residue"
            abort_unless head.include?("c-terminal") || head.include?("c-term"), "had +1 but not c-terminal: #{rec.header}"

            trimmed_seq = trim_last rec.seq

            end_f.puts ">#{rec.header}"
            end_f.puts trimmed_seq
          elsif head.include? "including -1 extein residue"
            abort_unless head.include?("n-terminal") || head.include?("n-term"), "had -1 but not n-terminal: #{rec.header}"

            trimmed_seq = trim_first rec.seq

            start_f.puts ">#{rec.header}"
            start_f.puts trimmed_seq
          else
            not_sure_f.puts rec
          end
        end
      end
    end
  end
end
