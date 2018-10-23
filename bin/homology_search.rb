require "abort_if"
require "parse_fasta"
require "set"
require "optimist"

require_relative "../lib/const"
require_relative "../lib/intein_finder"
require_relative "../lib/methods"

include AbortIf

Runners = Class.new { extend InteinFinder::Runners }

opts = Optimist.options do
  opt(:inteins_db,
      "Inteins DB",
      type: :string)
  opt(:seqs,
      "Query sequences",
      type: :string)
  opt(:outdir,
      "Out directory",
      default: "if_hs_output")

  opt(:min_length,
      "Minimum length to keep a sequence.",
      default: 100)

  opt(:mmseqs_splits,
      "Number of splits for the query sequences for MMseqs2.  " \
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
  opt(:process_input_seqs,
      "Path to process_input_seqs program",
      default: File.join(InteinFinder::ROOT_DIR,
                         "bin",
                         "process_input_seqs"))
end

min_len = opts[:min_length]

inteins_db = opts[:inteins_db]
seqs_infile = opts[:seqs]
outdir = opts[:outdir]
num_splits = opts[:num_splits]

process_input_seqs_exe = opts[:process_input_seqs]
mmseqs_exe = opts[:mmseqs]
makeprofiledb_exe = opts[:makeprofiledb]
rpsblast_exe = opts[:rpsblast]

mmseqs_splits = opts[:mmseqs_splits]
mmseqs_sensitivity = opts[:mmseqs_sensitivity]
mmseqs_num_iterations = opts[:mmseqs_iterations]
mmseqs_evalue = opts[:mmseqs_evalue]
mmseqs_threads = opts[:mmseqs_threads]

rpsblast_evalue = opts[:rpsblast_evalue]
rpsblast_threads = opts[:rpsblast_instances]


# Needed executable files and external programs


check_program process_input_seqs_exe
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

# keys: TODO
process_input_seqs_out = Runners.process_input_seqs! process_input_seqs_exe,
                                                     seqs_infile,
                                                     outdir,
                                                     InteinFinder::ANNOTATION,
                                                     mmseqs_splits,
                                                     rpsblast_threads,
                                                     min_len

# keys: seqs, name_map
# simple_headers_out = Runners.simple_headers! simple_headers_exe,
#                                              "user_query",
#                                              seqs_infile

# # keys: splits
# split_seqs_out = Runners.split_seqs! split_seqs_exe,
#                                      num_splits,
#                                      simple_headers_out[:seqs]

# Read the stats file for the query seqs.
total_seqs = 0
long_seqs = 0
short_seqs = 0
File.open(process_input_seqs_out[:stats], "rt").each_line.with_index do |line, idx|
  key, value = line.chomp.split "\t"

  case idx
  when 0
    abort_unless key == "total_seqs", "First line of stats file should have key total_seqs.  Got #{key}."

    total_seqs = value.to_i
  when 1
    abort_unless key == "long_seqs", "First line of stats file should have key total_seqs.  Got #{key}."

    long_seqs = value.to_i
  when 2
    abort_unless key == "short_seqs", "First line of stats file should have key total_seqs.  Got #{key}."

    short_seqs = value.to_i
  else
    abort_if true, "Too many lines in the #{process_input_seqs_out[:stats]} file"
  end
end

name_map = {}
File.open(process_input_seqs_out[:name_map], "rt").each_line do |line|
  new_name, old_name = line.chomp.split "\t"

  name_map[new_name] = old_name.split(" ").first
end

# Count the inteins
num_inteins = 0
ParseFasta::SeqFile.open(inteins_db).each_record do |rec|
  num_inteins += 1
end

# We only process the long seqs from here on.
num_input_seqs = long_seqs

# Run mmseqs on all the splits.
mmseqs_split_fnames = Dir.glob(process_input_seqs_out[:mmseqs_splits]).sort

# START_HERE.
mmseqs_split_fnames.each_with_index do |input_seq_fname, idx|
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

AbortIf.logger.debug { "num_input_seqs: #{num_input_seqs}" }
AbortIf.logger.debug { "num_inteins: #{num_inteins}" }



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
      br = InteinFinder::BlastRecord.new line

      if num_input_seqs > num_inteins
        # Need to swap the columns as the inputs are the DB rather
        # than the query.

        # Swap query and subject
        br.query, br.subject = br.subject, br.query

        # Swap qstart and sstart
        br.qstart, br.sstart = br.sstart, br.qstart

        # Swap qend and ssend
        br.qend, br.send = br.send, br.qend

        # Swap qlen and slen
        br.qlen, br.slen = br.slen, br.qlen
      end

      # We want the original names now and not the simple names.
      orig_query_name = name_map[br.query]
      seqs_with_hits << orig_query_name

      # Also we want to print the original name.
      br.query = orig_query_name

      # @todo Ideally we'd have some tests for this.
      outf.puts br
    end

    # And remove the tmp file
    FileUtils.rm fname
  end
end


######################################################################
# rpsblast
##########

rpsblast_split_fnames = Dir.glob(process_input_seqs_out[:rpsblast_splits]).sort

# First we need to make the profile db to blast against.
Runners.makeprofiledb! makeprofiledb_exe, PSSM_PATHS, profile_db

# Then we actually run the blast.
Runners.parallel_rpsblast! exe: rpsblast_exe,
                           query_files: rpsblast_split_fnames,
                           target_db: profile_db,
                           output: rpsblast_outfile,
                           evalue: rpsblast_evalue,
                           threads: rpsblast_threads

# And map back the simple headers to the original ones.
File.open(rpsblast_final_outfile, 'w') do |outf|
  # Unlike above, rpsblast always has the actual query in the 1st
  # column.
  File.open(rpsblast_outfile, "rt").each_line do |line|
    br = InteinFinder::BlastRecord.new line

    orig_query_name = name_map[br.query]

    seqs_with_hits << orig_query_name

    # And we want to print the original query name.
    br.query = orig_query_name

    outf.puts br
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
