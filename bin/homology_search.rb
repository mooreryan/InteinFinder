require "abort_if"
require "parse_fasta"
require "set"
require "trollop"

require_relative "../lib/const"
require_relative "../lib/intein_finder"
require_relative "../lib/methods"

include AbortIf

Runners = Class.new { extend InteinFinder::Runners }

opts = Trollop.options do
  opt(:inteins_db,
      "Inteins DB",
      type: :string)
  opt(:seqs,
      "Query sequences",
      type: :string)
  opt(:outdir,
      "Out directory",
      default: "if_hs_output")

  opt(:num_splits,
      "Number of splits for the query sequences.  " \
      "The more of these, the less memory I will use.",
      default: 1)

  opt(:mmseqs_threads,
      "Number of threads for MMseqs2 to use.",
      default: 1)
  opt(:mmseqs_sensitivity,
      "-s for mmseqs",
      default: 5.7)
  opt(:mmseqs_iterations,
      "--num-iterations for mmseqs",
      default: 2)
  opt(:mmseqs_evalue,
      "Evalue for mmseqs",
      default: 1e-3)

  opt(:rpsblast_instances,
      "Number of independent RPS-BLAST instances to run.",
      default: 1)
  opt(:rpsblast_evalue,
      "Evalue for rpsblast",
      default: 1e-3)

  opt(:makeprofiledb,
      "Path to makeprofiledb binary",
      default: "makeprofiledb")
  opt(:rpsblast,
      "Path to rpsblast binary",
      default: "rpsblast")
  opt(:mmseqs,
      "Path to mmseqs binary",
      default: "mmseqs")
  opt(:split_seqs,
      "Path to split_seqs program",
      default: File.join(InteinFinder::ROOT_DIR,
                         "bin",
                         "split_seqs"))
  opt(:simple_headers,
      "Path to simple_headers program",
      default: File.join(InteinFinder::ROOT_DIR,
                         "bin",
                         "simple_headers"))
end

inteins_db = opts[:inteins_db]
seqs_infile = opts[:seqs]
outdir = opts[:outdir]
num_splits = opts[:num_splits]

simple_headers_exe = opts[:simple_headers]
split_seqs_exe = opts[:split_seqs]
mmseqs_exe = opts[:mmseqs]
makeprofiledb_exe = opts[:makeprofiledb]
rpsblast_exe = opts[:rpsblast]

mmseqs_sensitivity = opts[:mmseqs_sensitivity]
mmseqs_num_iterations = opts[:mmseqs_iterations]
mmseqs_evalue = opts[:mmseqs_evalue]
mmseqs_threads = opts[:mmseqs_threads]

rpsblast_evalue = opts[:rpsblast_evalue]
rpsblast_threads = opts[:rpsblast_instances]


# Needed executable files and external programs


check_program simple_headers_exe
check_program split_seqs_exe
check_program mmseqs_exe
check_program makeprofiledb_exe
check_program rpsblast_exe

# Needed directories

seqs_infile_ext = File.extname seqs_infile
seqs_infile_base = File.basename seqs_infile, seqs_infile_ext


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

if num_input_seqs > num_inteins
  query_seq_column  = 1
  target_seq_column = 0
else
  query_seq_column  = 0
  target_seq_column = 1
end

seqs_with_hits = Set.new

# Maps the names back and adds names with hits to the Set.  Also
# ensures that the query seq is in the 1st column of the output file.
#
# @param [String] infname The name of the file to write to.  It will
#   be opened.
# @param [File] outf This is an open File for writing.
# def map_names infname,
#               outf,
#               name_map,
#               query_seq_column,
#               target_seq_column,
#               seqs_with_hits

#   File.open(infname, "rt").each_line do |line|
#     ary = line.chomp.split "\t"

#     target_seq_name = ary[target_seq_column]
#     query_seq_name = ary[query_seq_column]
#     orig_query_name = name_map[query_seq_name]

#     seqs_with_hits << orig_name

#     # Ensure the user seq is in 1st col, and DB seq is in 2nd col.
#     ary[0] = orig_name
#     ary[1] = target_seq_name

#     outf.puts ary.join "\t"
#   end
# end

# Cat the seqs and also figure out the ones with hits.
File.open(mmseqs_final_outfile, "w") do |outf|
  Dir.glob(mmseqs_outfile_glob).each do |fname|
    # map_names fname,
    #           outf,
    #           name_map,
    #           query_seq_column,
    #           target_seq_column,
    #           seqs_with_hits


    File.open(fname, "rt").each_line do |line|
      ary = line.chomp.split "\t"

      target_seq_name = ary[target_seq_column]
      query_seq_name = ary[query_seq_column]
      orig_query_name = name_map[query_seq_name]

      seqs_with_hits << orig_query_name

      # Ensure the user seq is in 1st col, and DB seq is in 2nd col.
      ary[0] = orig_query_name
      ary[1] = target_seq_name

      outf.puts ary.join "\t"
    end

    # And remove the tmp file
    FileUtils.rm fname
  end
end


######################################################################
# rpsblast
##########

# First we need to make the profile db to blast against.
Runners.makeprofiledb! makeprofiledb_exe, PSSM_PATHS, profile_db

# Then we actually run the blast.
Runners.parallel_rpsblast! exe: rpsblast_exe,
                           query_files: split_fnames,
                           target_db: profile_db,
                           output: rpsblast_outfile,
                           evalue: rpsblast_evalue,
                           threads: rpsblast_threads

# And map back the simple headers to the original ones.
File.open(rpsblast_final_outfile, 'w') do |outf|
  # map_names rpsblast_outfile,
  #           outf,
  #           name_map,
  #           query_seq_column,
  #           target_seq_column,
  #           seqs_with_hits

  # Unlike above, rpsblast always has the actual query in the 1st
  # column.
  File.open(rpsblast_outfile, "rt").each_line do |line|
    ary = line.chomp.split "\t"

    query_seq_name = ary[0]
    orig_query_name = name_map[query_seq_name]

    seqs_with_hits << orig_query_name

    # And map the name to the original.
    ary[0] = orig_query_name

    outf.puts ary.join "\t"
  end

  FileUtils.rm rpsblast_outfile
end

##########
# rpsblast
######################################################################

# And finally combine the two search files into a single one.

AbortIf.logger.info { "Combining search output" }
File.open(homology_search_outfile, 'w') do |outf|
  File.open(mmseqs_final_outfile, "rt").each_line do |line|
    outf.puts line
  end
  # FileUtils.rm mmseqs_final_outfile


  File.open(rpsblast_final_outfile, "rt").each_line do |line|
    outf.puts line
  end
  # FileUtils.rm rpsblast_final_outfile
end

AbortIf.logger.info { "Printing sequences with hits" }
# Print out seqs with hits
File.open(queries_with_hits, 'w') do |f|
  ParseFasta::SeqFile.open(seqs_infile).each_record do |rec|
    if seqs_with_hits.include? rec.id
      f.puts rec
    end
  end
end


######################################################################
# clean up temp files
#####################

AbortIf.logger.info { "Cleaning up outdir" }

# We need to keep the profile db around for later on in InteinFinder.
# FileUtils.rm_r profile_db_dir
FileUtils.rm_r tmp_dir

#####################
# clean up temp files
######################################################################
