require "abort_if"
require "parse_fasta"
require "set"

require_relative "../lib/const"
require_relative "../lib/intein_finder"
require_relative "../lib/methods"

include AbortIf

Runners = Class.new { extend InteinFinder::Runners }

# Parse args

abort_unless ARGV.count == 4,
             "usage: #{__FILE__} intein_db.fa seqs.fa outdir num_splits"

inteins_db = ARGV[0]
seqs_infile = ARGV[1]
outdir = ARGV[2]
num_splits = ARGV[3].to_i

seqs_infile_ext = File.extname seqs_infile
seqs_infile_base = File.basename seqs_infile, seqs_infile_ext


mmseqs_sensitivity = 1
mmseqs_num_iterations = 1
mmseqs_evalue = 1e-3
mmseqs_threads = 4

rpsblast_evalue = 1e-3
rpsblast_threads = 4


# Needed executable files and external programs

simple_headers_exe = File.join __dir__, "simple_headers"
split_seqs_exe = File.join __dir__, "split_seqs"
mmseqs_exe = "mmseqs"
makeprofiledb_exe = "makeprofiledb"

check_program simple_headers_exe
check_program split_seqs_exe
check_program mmseqs_exe
check_program makeprofiledb_exe

# Needed directories


profile_db_dir = File.join outdir, "profile_db"
search_results_dir = File.join outdir, "search_results"
sequences_dir = File.join outdir, "sequences"
tmp_dir = File.join outdir, "tmp"

FileUtils.mkdir_p outdir
FileUtils.mkdir_p search_results_dir
FileUtils.mkdir_p sequences_dir
FileUtils.mkdir_p tmp_dir
FileUtils.mkdir_p profile_db_dir

# Input and output filenames

mmseqs_outfile_glob =
  File.join search_results_dir,
            "initial_queries_search_inteins.split_*.txt"

# mmseqs_out
mmseqs_final_outfile =
  File.join search_results_dir,
            "initial_queries_search_inteins.txt"

profile_db = File.join profile_db_dir,
                       "profile_db"

# rpsblast_out
rpsblast_outfile =
  File.join search_results_dir,
            "initial_queries_search_superfamilies.simple_headers.txt"

rpsblast_final_outfile =
  File.join search_results_dir,
            "initial_queries_search_superfamilies.txt"

# all_blast_out
homology_search_outfile =
  File.join search_results_dir,
            "initial_queries_search.txt"


queries_with_hits =
  File.join sequences_dir,
            "#{seqs_infile_base}.seqs_with_hits.faa"



# keys: seqs, name_map
simple_headers_out = Runners.simple_headers! simple_headers_exe,
                                             "user_query",
                                             seqs_infile

# keys: splits
split_seqs_out = Runners.split_seqs! split_seqs_exe,
                                     num_splits,
                                     simple_headers_out[:seqs]

split_fnames = Dir.glob(split_seqs_out[:splits]).sort

name_map = {}
File.open(simple_headers_out[:name_map], "rt").each_line do |line|
  new_name, old_name = line.chomp.split "\t"

  name_map[new_name] = old_name.split(" ").first
end

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

# Run mmseqs on all the splits.

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

  Runners.mmseqs! exe: mmseqs_exe,
                  queries: mmseqs_queries,
                  targets: mmseqs_targets,
                  output: mmseqs_output,
                  tmpdir: mmseqs_tmp,
                  log: mmseqs_log,
                  sensitivity: mmseqs_sensitivity,
                  num_iterations: mmseqs_num_iterations,
                  evalue: mmseqs_evalue,
                  threads: mmseqs_threads

end

query_seq_column = num_input_seqs > num_inteins ? 1 : 0

seqs_with_hits = Set.new

# Maps the names back and adds names with hits to the Set.
#
# @param [String] infname The name of the file to write to.  It will
#   be opened.
# @param [File] outf This is an open File for writing.
def map_names infname,
              outf,
              name_map,
              query_seq_column,
              seqs_with_hits

  File.open(infname, "rt").each_line do |line|
    ary = line.chomp.split "\t"

    query_seq_name = ary[query_seq_column]
    orig_name = name_map[query_seq_name]

    seqs_with_hits << orig_name

    ary[query_seq_column] = orig_name

    outf.puts ary.join "\t"
  end
end

# Cat the seqs and also figure out the ones with hits.
File.open(mmseqs_final_outfile, "w") do |outf|
  Dir.glob(mmseqs_outfile_glob).each do |fname|
    map_names fname,
              outf,
              name_map,
              query_seq_column,
              seqs_with_hits

    # And remove the tmp file
    FileUtils.rm fname
  end
end


######################################################################
# rpsblast
##########

# First we need to make the profile db to blast against.
Runners.makeprofiledb! "makeprofiledb", PSSM_PATHS, profile_db

# Then we actually run the blast.
Runners.parallel_rpsblast! exe: "rpsblast",
                           query_files: split_fnames,
                           target_db: profile_db,
                           output: rpsblast_outfile,
                           evalue: rpsblast_evalue,
                           threads: rpsblast_threads

# And map back the simple headers to the original ones.
File.open(rpsblast_final_outfile, 'w') do |outf|
  map_names rpsblast_outfile,
            outf,
            name_map,
            query_seq_column,
            seqs_with_hits

  FileUtils.rm rpsblast_outfile
end

##########
# rpsblast
######################################################################

# And finally combine the two search files into a single one.

File.open(homology_search_outfile, 'w') do |outf|
  File.open(mmseqs_final_outfile, "rt").each_line do |line|
    outf.puts line
  end
  FileUtils.rm mmseqs_final_outfile


  File.open(rpsblast_final_outfile, "rt").each_line do |line|
    outf.puts line
  end
  FileUtils.rm rpsblast_final_outfile
end

# Print out seqs with hits
File.open(queries_with_hits, 'w') do |f|
  ParseFasta::SeqFile.open(seqs_infile).each_record do |rec|
    if seqs_with_hits.include? rec.id
      f.puts rec
    end
  end
end
