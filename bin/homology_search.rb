require "abort_if"
require "parse_fasta"
require "set"

require_relative "../lib/intein_finder"
require_relative "../lib/methods"

include AbortIf

abort_unless ARGV.count == 4,
             "usage: #{__FILE__} intein_db.fa seqs.fa outdir num_splits"

inteins_db = ARGV[0]
seqs_infile = ARGV[1]
outdir = ARGV[2]
num_splits = ARGV[3].to_i

FileUtils.mkdir_p outdir

Runners = Class.new { extend InteinFinder::Runners }

simple_headers_exe = File.join __dir__, "simple_headers"
split_seqs_exe = File.join __dir__, "split_seqs"
mmseqs_exe = "mmseqs"

check_program simple_headers_exe
check_program split_seqs_exe
check_program mmseqs_exe

search_results_dir = File.join outdir, "search_results"
tmp_dir = File.join outdir, "tmp"

FileUtils.mkdir_p search_results_dir
FileUtils.mkdir_p tmp_dir

mmseqs_outfile_glob =
  File.join search_results_dir,
            "initial_queries_search_inteins.split_*.txt"

mmseqs_final_outfile =
  File.join search_results_dir,
            "initial_queries_search_inteins.txt"






# keys: seqs, name_map
simple_headers_out = Runners.simple_headers! simple_headers_exe,
                                             "user_query",
                                             seqs_infile

# keys: splits
split_seqs_out = Runners.split_seqs! split_seqs_exe,
                                     num_splits,
                                     simple_headers_out[:seqs]

split_fnames = Dir.glob(split_seqs_out[:splits]).sort

# Count the inteins
num_inteins = 0
ParseFasta::SeqFile.open(inteins_db).each_record do |rec|
  num_inteins += 1
end

# And count the input seqs.  Just start with the first split.  To
# avoid counting the whole flie (slow), only count up to the number of
# intein seqs, since this should be lowish.
num_input_seqs = 0
ParseFasta::SeqFile.open(split_fnames[0]).each_record do |rec|
  num_input_seqs += 1

  break if num_input_seqs > num_inteins
end


split_fnames.each_with_index do |input_seq_fname, idx|
  # Set the targets to the file with more sequences.  It will be way
  # faster if there is a big difference in size.
  if num_input_seqs > num_inteins
    mmseqs_queries = inteins_db
    mmseqs_targets = input_seq_fname
  else
    mmseqs_queries = input_seq_fname
    mmseqs_targets = inteins_db
  end

  mmseqs_output =
    File.join search_results_dir,
              "initial_queries_search_inteins.split_#{idx}.txt"
  mmseqs_tmp =
    File.join tmp_dir,
              "mmseqs_tmp.split_#{idx}"
  mmseqs_log =
    File.join search_results_dir,
              "mmseqs_log.txt"

  mmseqs_out = Runners.mmseqs! exe: mmseqs_exe,
                               queries: mmseqs_queries,
                               targets: mmseqs_targets,
                               output: mmseqs_output,
                               tmpdir: mmseqs_tmp,
                               log: mmseqs_log,
                               sensitivity: 1,
                               num_iterations: 1,
                               threads: 4

  mmseqs_out[:output]
end

user_seq_col = num_input_seqs > num_inteins ? 1 : 0

seqs_with_hits = Set.new

name_map = {}
File.open(simple_headers_out[:name_map], "rt").each_line do |line|
  new_name, old_name = line.chomp.split "\t"

  name_map[new_name] = old_name.split(" ").first
end

# Cat the seqs and also figure out the ones with hits.
File.open(mmseqs_final_outfile, "w") do |outf|
  Dir.glob(mmseqs_outfile_glob).each do |fname|
    File.open(fname, "rt").each_line do |line|
      ary = line.chomp.split "\t"

      user_seq_name = ary[user_seq_col]
      orig_name = name_map[user_seq_name]

      seqs_with_hits << orig_name

      ary[user_seq_col] = orig_name

      outf.puts line
    end

    # And remove the tmp file
    FileUtils.rm fname
  end
end

# Print out seqs with hits.
# ParseFasta::SeqFile.open(seqs_infile).each_record do |rec|
#   if seqs_with_hits.include? rec.id
#     puts rec
#   end
# end
