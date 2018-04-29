#!/usr/bin/env ruby
Signal.trap("PIPE", "EXIT")

require "aai"
require "abort_if"
require "fileutils"
require "parse_fasta"
require "pp"
require "set"
require "trollop"
require "pasv_lib"
require "parallel"

require "ruby-progressbar"

require_relative "lib/const"
require_relative "lib/methods"

module Utils
  extend Aai::CoreExtensions::Time
  extend Aai::CoreExtensions::Process
  extend Aai::Utils
end

module PasvLib
  extend PasvLib::Utils
end

include AbortIf
include AbortIf::Assert

opts = Trollop.options do
  version VERSION_BANNER
  banner <<-EOS

  Look for possible Inteins.

  Screens sequences against:

    - 585 sequences from inteins.com
    - Conserved domains from superfamilies cl22434 (Hint), cl25944
      (Intein_splicing) and cl00083 (HNHc).

  Also does some fancy aligning to check for these things:

    - Ser, Thr or Cys at the intein N-terminus
    - The dipeptide His-Asn or His-Gln at the intein C-terminus
    - Ser, Thr or Cys following the downstream splice site.

  Does not check for:

    - The conditions listed in the Intein polymorphisms section of
      http://www.inteins.com
    - Intein minimum size (though it does check that it spans the
      putative region)
    - Specific intein domains are present and in the correct order
    - If the only blast hits are to an endonucleaes

  If there were no blast hits for one of the categories (inteins or
  conserved domains), the row will have a '1' for best evalue.

  IMPORTANT: You should probably not move this file (#{__FILE__}) out
             of this directory (#{__dir__}) as it depends on some
             relative path to some of the assets.

  --in-pssm-list You should specify full paths to the .smp files in
                 this file.  They must be delimited by space, tab, or
                 newline.  To use the default PSSM list, don't pass
                 this argument.

  --split-queries If there are enough query sequences (> 2 * number of
                  CPUs specified with --cpus), then pass this option
                  to split up the RPS-BLAST search step to speed
                  things up.  If you have a lot of queries, pass this
                  option.

  Options:
  EOS

  opt(:queries,
      "Input fasta file with protein queries",
      type: :string)

  opt(:inteins,
      "Input fasta file with Inteins",
      default: File.join(__dir__, "assets", "intein_sequences", "all.faa"))
  opt(:pssm_list,
      "Input file that contains a list of smp files (delimited by space, tab or newline).  Don't pass this argument to use the default.",
      type: :string)

  opt(:evalue_rpsblast,
      "Report hits less than this evalue in the rpsblast",
      default: 1e-3)
  opt(:evalue_mmseqs,
      "Report hits less than this evalue in the mmseqs search",
      default: 1e-3)

  opt(:evalue_region_refinement,
      "Only use single target hits with evalue less than this for refinement of intein regions.",
      default: 1e-3)

  opt(:keep_alignment_files,
      "Keep the alignment files",
      default: false)

  opt(:cpus, "Number of cpus to use", default: 1)
  opt(:split_queries, "Split queries for rpsblast if there are enough sequences", default: false)
  opt(:mmseqs_sensitivity, "-s for mmseqs", default: 5.7)
  opt(:mmseqs_iterations, "--num-iterations for mmseqs", default: 2)

  opt(:intein_n_term_test_strictness,
      "Which level passes the intein_n_term_test?",
      default: 1)
  opt(:intein_c_term_dipeptide_test_strictness,
      "Which level passes the intein_c_term_dipeptide_test?",
      default: 1)

  opt(:refinement_strictness,
      "How strict for refining intein regions?",
      default: 1)
  opt(:use_length_in_refinement,
      "Use min and max len for refinement",
      default: false)

  opt(:outdir, "Output directory", type: :string, default: ".")

  # Binary file locations.
  opt(:makeprofiledb,
      "Path to makeprofiledb binary",
      default: "makeprofiledb")
  opt(:rpsblast,
      "Path to rpsblast binary",
      default: "rpsblast")
  opt(:mmseqs,
      "Path to mmseqs binary",
      default: "mmseqs")
  opt(:n_fold_splits,
      "Path to n_fold_splits ruby script",
      default: File.join(__dir__, "bin", "n_fold_splits.rb"))
  opt(:parallel_blast,
      "Path to parallel_blast ruby script",
      default: File.join(__dir__, "bin", "parallel_blast.rb"))
  opt(:mafft,
      "Path to mafft binary",
      default: "mafft")
end

AbortIf.logger.info { "Checking arguments" }

abort_unless Set.new([1,2]).include?(opts[:intein_n_term_test_strictness]),
             "--intein-n-term-test-strictness must be 1 or 2."
abort_unless Set.new([1,2]).include?(opts[:intein_c_term_dipeptide_test_strictness]),
             "--intein-c-term-dipeptide-test-strictness must be 1 or 2."
abort_unless Set.new([1]).include?(opts[:refinement_strictness]),
             "Currently, the only option for --refinement-strictness is 1."



# TODO make sure that you have a version of MMseqs2 that has the
# easy-search pipeline
search = "#{opts[:mmseqs]} easy-search"

check_program opts[:makeprofiledb]
check_program opts[:rpsblast]
check_program opts[:mmseqs]
check_program opts[:mafft]
check_program opts[:n_fold_splits]
check_program opts[:parallel_blast]

check_file opts[:pssm_list]

check_arg opts, :queries
check_file opts[:queries] # TODO this will pass even if the file is a directory.

check_arg opts, :inteins
check_file opts[:inteins]

abort_unless opts[:mmseqs_sensitivity] >= 1 && opts[:mmseqs_sensitivity] <= 7.5,
             "--mmseqs-sensitivity must be between 1 and 7.5"

abort_unless opts[:mmseqs_iterations] >= 1,
             "--mmseqs-iterations must be 1 or more"


abort_unless opts[:evalue_rpsblast] <= 0.1,
             "--evalue-rpsblast should definetely be <= 0.1"
abort_unless opts[:evalue_mmseqs] <= 0.1,
             "--evalue-mmseqs should definetely be <= 0.1"

abort_unless opts[:cpus] >= 1,
             "--cpus must be >= 1"

tmp_dir = File.join opts[:outdir], "tmp"

profile_db_dir = File.join opts[:outdir], "profile_db"
profile_db = File.join profile_db_dir, "intein_db"

search_results_dir = File.join opts[:outdir], "search_results"
aln_dir = File.join search_results_dir, "alignments"
details_dir = File.join opts[:outdir], "details"
results_dir = File.join opts[:outdir], "results"
seq_dir = File.join opts[:outdir], "sequences"


mmseqs_log = File.join search_results_dir, "mmseqs_log.txt"

rpsblast_out = File.join search_results_dir, "initial_queries_search_superfamilies.txt"
mmseqs_out = File.join search_results_dir, "initial_queries_search_inteins.txt"
all_blast_out = File.join search_results_dir, "initial_queries_search.txt"
search_results_summary_out = File.join search_results_dir, "initial_queries_search_summary.txt"

query_basename = File.basename(opts[:queries], File.extname(opts[:queries]))

queries_simple_name_out = File.join opts[:outdir], "queries_with_simple_names.faa"

# Outfiles
containing_regions_out = File.join details_dir, "intein_regions_putative.txt"
refined_containing_regions_out = File.join details_dir, "intein_regions_refined.txt"
refined_containing_regions_simple_out = File.join results_dir, "intein_regions_refined_condensed.txt"
criteria_check_full_out = File.join details_dir, "intein_criteria_check.txt"
criteria_check_condensed_out = File.join details_dir, "intein_criteria_check_condensed.txt"


abort_if Dir.exist?(opts[:outdir]),
         "The outdir #{opts[:outdir]} already exists!  Specify a different outdir!"

AbortIf.logger.info { "Making directories" }

FileUtils.mkdir_p opts[:outdir]
FileUtils.mkdir_p profile_db_dir
FileUtils.mkdir_p tmp_dir
FileUtils.mkdir_p search_results_dir
FileUtils.mkdir_p aln_dir
FileUtils.mkdir_p details_dir
FileUtils.mkdir_p results_dir
FileUtils.mkdir_p seq_dir



######################################################################
# search constants
##################

MAFFT = "#{opts[:mafft]} --quiet --auto --thread 1 '%s' > '%s'"

# first -- infile
# second -- outfile
MMSEQS_SEARCH = "#{search} %s #{opts[:inteins]} %s #{tmp_dir} --format-mode 2 -s #{opts[:mmseqs_sensitivity]} --num-iterations #{opts[:mmseqs_iterations]} -e #{opts[:evalue_mmseqs]} --threads #{opts[:cpus]} >> #{mmseqs_log}"

# first -- infile
# second -- outfile
RPSBLAST_SEARCH =  "#{opts[:rpsblast]} -num_threads #{opts[:cpus]} -db #{profile_db} -query %s -evalue #{opts[:evalue_rpsblast]} -outfmt 6 -out %s"

# first -- infile
# second -- outfile
RPSBLAST_SEARCH_PARALLEL = "#{opts[:parallel_blast]} --cpus #{opts[:cpus]} --evalue #{opts[:evalue_rpsblast]} --infile %s --blast-db #{profile_db} --outdir #{opts[:outdir]} --specific-outfile %s --blast-program #{opts[:rpsblast]} --split-program #{opts[:n_fold_splits]}"


##################
# search constants
######################################################################



AbortIf.logger.info { "Writing smp list file" }

if opts[:pssm_list]
  pssm_list = opts[:pssm_list]
else
  AbortIf.logger.info { "No --pssm-list arg was passed.  Using the default pssm list." }
  # Write the default list.  TODO why don't we just read this from the assets folder?
  pssm_list = File.join opts[:outdir], "pssm_list.txt"
  File.open(pssm_list, "w") do |f|
    PSSM_PATHS.each do |path|
      f.puts path
    end
  end
end

AbortIf.logger.info { "Checking smp files" }

# Check that all the smp files actually exist.
File.open(pssm_list, "rt").each_line do |line|
  line.chomp.split.each do |smp_fname|
    abort_unless File.exist?(smp_fname),
                 "File #{smp_fname} was listed in #{pssm_list} but it does not exist!"
  end
end


AbortIf.logger.info { "Setting up queries hash table" }


# Set up the queries hash table
queries = {}
query_records = {}
query_name_map = {}
n = 0
File.open(queries_simple_name_out, "w") do |f|
  ParseFasta::SeqFile.open(opts[:queries]).each_record do |rec|
    n += 1
    new_name = "user_query___seq_#{n}"
    orig_rec_id = rec.id
    query_name_map[new_name] = orig_rec_id

    query_records[orig_rec_id] = rec

    # rec.header = new_name
    # rec.id = new_name

    f.puts ">#{new_name}"
    f.puts rec.seq

    unless queries.has_key? orig_rec_id
      queries[orig_rec_id] = { mmseqs_hits: 0, mmseqs_best_evalue: 1,
                              rpsblast_hits: 0, rpsblast_best_evalue: 1 }
    end
  end
end


######################################################################
# homology search
#################

AbortIf.logger.info { "Searching for homology" }

cmd = "#{opts[:makeprofiledb]} -in #{pssm_list} -out #{profile_db}"
Utils.run_and_time_it! "Making profile DB", cmd

num_seqs = queries.count
# there are enough seqs for parallel blast to be worth it and the user asked for splits
if opts[:split_queries] && num_seqs > opts[:cpus] * 2
  AbortIf.logger.info { "You asked for splits, and we have #{num_seqs} sequences, so we will split the queries before blasting." }
  cmd = "#{opts[:parallel_blast]} --cpus #{opts[:cpus]} --evalue #{opts[:evalue_rpsblast]} --infile #{queries_simple_name_out} --blast-db #{profile_db} --outdir #{opts[:outdir]} --specific-outfile #{rpsblast_out} --blast-program #{opts[:rpsblast]} --split-program #{opts[:n_fold_splits]}"
else
  AbortIf.logger.info { "Not splitting the queries before blasting.  Either too few (#{num_seqs}) or you didn't ask for splits." }
  cmd = "#{opts[:rpsblast]} -num_threads #{opts[:cpus]} -db #{profile_db} -query #{queries_simple_name_out} -evalue #{opts[:evalue_rpsblast]} -outfmt 6 -out #{rpsblast_out}"
end
Utils.run_and_time_it! "Running rpsblast", cmd

# 5.7, 2
cmd = "#{search} #{queries_simple_name_out} #{opts[:inteins]} #{mmseqs_out} #{tmp_dir} --format-mode 2 -s #{opts[:mmseqs_sensitivity]} --num-iterations #{opts[:mmseqs_iterations]} -e #{opts[:evalue_mmseqs]} --threads #{opts[:cpus]} >> #{mmseqs_log}"
Utils.run_and_time_it! "Running mmseqs", cmd

#################
# homology search
######################################################################



######################################################################
# change the IDs in the search files back
##########################################

AbortIf.logger.info { "Swapping IDs in search files" }

# It looks like the evalue cutoff doesn't always work for mmseqs.  So
# just add an evalue filter to these steps as well.

# We do this so the user can actually read the search details.
tmpfile = File.join opts[:outdir], "tmptmp"
File.open(tmpfile, "w") do |f|
  File.open(rpsblast_out, "rt").each_line do |line|
    query, *rest = line.chomp.split "\t"

    evalue = rest[9].to_f

    if evalue <= opts[:evalue_rpsblast]
      f.puts [query_name_map[query], rest].join "\t"
    end
  end
end
Utils.run_and_time_it! "Changing IDs in rpsblast", "mv #{tmpfile} #{rpsblast_out}"

tmpfile = File.join opts[:outdir], "tmptmp"
File.open(tmpfile, "w") do |f|
  File.open(mmseqs_out, "rt").each_line do |line|
    query, *rest = line.chomp.split "\t"

    evalue = rest[9].to_f

    if evalue <= opts[:evalue_mmseqs]
      f.puts [query_name_map[query], rest].join "\t"
    end
  end
end
Utils.run_and_time_it! "Changing IDs in mmseqs search", "mv #{tmpfile} #{mmseqs_out}"

# From here out, the sequence IDs should be back to normal.

##########################################
# change the IDs in the search files back
######################################################################



######################################################################
# get regions
#############

AbortIf.logger.info { "Getting putative intein regions" }

cmd = "cat #{rpsblast_out} #{mmseqs_out} > #{all_blast_out}"
Utils.run_and_time_it! "Catting search results", cmd

query2hits = {}
File.open(all_blast_out, "rt").each_line do |line|
  ary = line.chomp.split("\t")
  query = ary[0]

  ary[QSTART_IDX] = ary[QSTART_IDX].to_i
  ary[QEND_IDX] = ary[QEND_IDX].to_i

  if query2hits.has_key? query
    query2hits[query] << ary
  else
    query2hits[query] = [ary]
  end
end


# Sort by qstart, if tied, break tie with qend
query2hits.each do |query, hits|
  hits.sort! do |a, b|
    comp = a[QSTART_IDX] <=> b[QSTART_IDX]

    comp.zero? ? (a[QEND_IDX] <=> b[QEND_IDX]) : comp
  end
end

query2regions = {}

query2hits.each do |query, hits|
  query2regions[query] = {}

  hits.each do |ary|
    qstart = ary[QSTART_IDX]
    qend   = ary[QEND_IDX]

    abort_if qstart == qend,
             "BAD STUFF (#{qstart}, #{qend})"

    if query2regions[query].empty?
      new_region query2regions[query], qstart, qend
    else
      last_region = query2regions[query].count - 1
      if qstart >= query2regions[query][last_region][:qend]
        new_region query2regions[query], qstart, qend
      elsif qend > query2regions[query][last_region][:qend]
        query2regions[query][last_region][:qend] = qend
      end
    end
  end
end

AbortIf.logger.info { "Writing intein region info" }

all_query_ids = queries.keys

File.open(containing_regions_out, "w") do |f|
  f.puts %w[seq region.id start end len].join "\t"

  all_query_ids.each do |query|
    regions = query2regions[query]
    if regions
      regions.each do |id, info|
        len = info[:qend] - info[:qstart] + 1
        f.puts [query, id, info[:qstart], info[:qend], len].join "\t"
      end
    else
      # f.puts [query, "na", "na"].join "\t"
    end
  end
end

#############
# get regions
######################################################################



######################################################################
# do the alignments to check for conserved residues
###################################################

AbortIf.logger.info { "Checking for conserved residues" }

# Read all the intein seqs into memory
intein_records = {}
ParseFasta::SeqFile.open(opts[:inteins]).each_record do |rec|
  # TODO check for duplicates
  intein_records[rec.id] = rec
end

mmseqs_hits = []
File.open(mmseqs_out, "rt").each_line do |line|
  blast_record = InteinFinder::BlastRecord.new line

  clipping_start_idx = -100
  clipping_end_idx = -100

  region_idx = -1

  query_middle = (blast_record.qend + blast_record.qstart + 1) / 2.0
  putative_regions = query2regions[blast_record.query]
  putative_regions.each do |rid, info|
    if query_middle >= info[:qstart] && query_middle <= info[:qend]
      clipping_start_idx = info[:qstart]-1-PADDING
      clipping_end_idx = info[:qend]-1-PADDING
      region_idx = rid
      break
    end
  end

  # The middle should at least be in a single region as the
  # regions were built on hits.  TODO it could be the case that a
  # region got built based only on hits to superfams and this
  # could break?
  assert clipping_start_idx != -100, "#{line}"
  assert clipping_end_idx != -100
  assert region_idx != -1

  clipping_start_idx = clipping_start_idx < 0 ? 0 : clipping_start_idx
  # Note that if the clipping_end_idx is passed the length of the string, Ruby will just give us all the way up to the end of the string.

  clipping_region = InteinFinder::ClippingRegion.new region_idx,
                                                     clipping_start_idx+1,
                                                     clipping_end_idx+1

  # hit = [query, target, rest, region_idx, clipping_start_idx, clipping_end_idx].flatten
  hit = [blast_record, clipping_region]

  mmseqs_hits << hit
end

# Sort by query, then by region, then by evalue.
# br = BlastRecord, cr = ClippingRecord
mmseqs_hits.sort! do |(br1, cr1), (br2, cr2)|
  query_comp = br1.query <=> br2.query
  if query_comp.zero?
    region_comp = cr1.id <=> cr2.id

    if region_comp.zero?
      br1.evalue <=> br2.evalue
    else
      region_comp
    end
  else
    query_comp
  end
end

num_aligned = 0
total_items = 0

mmseqs_hit_groups = mmseqs_hits.group_by { |br, cr| [br.query, cr.id] }

progbar = ProgressBar.create title: "Checking conserved residues",
                             starting_at: 0,
                             total: mmseqs_hit_groups.count,
                             format: "%t%e |%B|"

conserved_f_lines = []
mmseqs_hit_groups.each do |group, items|
  progbar.increment

  total_items += items.count

  found_good_hit = false

  subset_1 = items.take MAX_ALIGNMENTS_BEFORE_ALL
  subset_2 = items.drop MAX_ALIGNMENTS_BEFORE_ALL

  # Most seqs have a good hit in the first couple, so trying a few
  # single threaded before jumping to doing multiple alignments at a
  # time will actually give you better efficiency (sometimes up to
  # half as many alignments).
  subset_1.each do |(blast_record, clipping_region)|
    break if found_good_hit

    num_aligned += 1

    tmp_aln_in = File.join aln_dir,
                           "aln_in_#{blast_record.query}" +
                           "_#{blast_record.subject}.faa"
    tmp_aln_out = File.join aln_dir,
                            "aln_out_#{blast_record.query}" +
                            "_#{blast_record.subject}.faa"

    # TODO check for missing seqs
    this_query = query_records[blast_record.query]
    this_intein = intein_records[blast_record.subject]

    write_aln_in tmp_aln_in,
                 this_intein,
                 this_query,
                 clipping_region

    align! tmp_aln_in, tmp_aln_out


    all_good, out_line = parse_aln_out tmp_aln_out,
                                       blast_record,
                                       clipping_region,
                                       query2regions

    conserved_f_lines << out_line

    FileUtils.rm tmp_aln_in
    FileUtils.rm tmp_aln_out unless opts[:keep_alignment_files]

    if all_good
      found_good_hit = true
    end
  end


  if !found_good_hit && subset_2.count > 0
    seq_name = group[0]
    region_name =  group[1]
    AbortIf.logger.debug do
      "Haven't found a good hit for Seq: #{seq_name}, " \
      "Region: #{region_name} after #{MAX_ALIGNMENTS_BEFORE_ALL} " \
      "tries.  Aligning the remaining hits in " \
      "parallel."
    end

    subset_2.each_slice(opts[:cpus]) do |slice|
      break if found_good_hit

      num_aligned += slice.count

      results = Parallel.map(
        slice,
        in_processes: opts[:cpus]
      ) do |(blast_record, clipping_region)|

        tmp_aln_in = File.join aln_dir,
                               "aln_in_#{blast_record.query}" +
                               "_#{blast_record.subject}.faa"
        tmp_aln_out = File.join aln_dir,
                                "aln_out_#{blast_record.query}" +
                                "_#{blast_record.subject}.faa"

        # TODO check for missing seqs
        this_query = query_records[blast_record.query]
        this_intein = intein_records[blast_record.subject]

        write_aln_in tmp_aln_in,
                     this_intein,
                     this_query,
                     clipping_region

        align! tmp_aln_in, tmp_aln_out


        all_good, out_line = parse_aln_out tmp_aln_out,
                                           blast_record,
                                           clipping_region,
                                           query2regions

        FileUtils.rm tmp_aln_in
        FileUtils.rm tmp_aln_out unless opts[:keep_alignment_files]

        [all_good, out_line]
      end

      results.each do |all_good, out_line|
        conserved_f_lines << out_line

        if all_good
          found_good_hit = true

          break
        end
      end
    end
  end
end

if total_items > 0
  perc_aligned = (
    num_aligned.to_f / total_items
  ).round(2) * 100
else
  perc_aligned = 0
end

AbortIf.logger.debug { "Percent aligned: #{perc_aligned}%" }

# Sort lines by query, then by region, then by evalue.
conserved_f_lines = conserved_f_lines.compact.sort do |a, b|
  query_a = a[0]
  query_b = b[0]

  evalue_a = a[2].to_f
  evalue_b = b[2].to_f

  region_idx_a = a[3].to_i
  region_idx_b = b[3].to_i

  query_comp = query_a <=> query_b
  if query_comp.zero?
    region_comp = region_idx_a <=> region_idx_b

    if region_comp.zero?
      evalue_comp = evalue_a <=> evalue_b

      evalue_comp
    else
      region_comp
    end
  else
    query_comp
  end
end

File.open(criteria_check_full_out, "w") do |conserved_f|
  conserved_f.puts %w[query target evalue which.region aln.region region.good has.start has.end has.extein.start intein.n.term intein.c.term c.extein].join "\t"

  conserved_f_lines.compact.each_with_index do |ary, idx|
    conserved_f.puts ary.join "\t"
  end
end

###################################################
# do the alignments to check for conserved residues
######################################################################



######################################################################
# parse blast results
#####################

AbortIf.logger.info { "Parsing rpsblast results" }

# Read the rpsblast results
File.open(rpsblast_out, "rt").each_line do |line|
  query, target, *rest = line.chomp.split "\t"

  evalue = rest[8].to_f

  abort_unless queries.has_key?(query),
               "query #{query} was in the rpsblast output file but not in the queries file."

  queries[query][:rpsblast_hits] += 1

  if evalue < queries[query][:rpsblast_best_evalue]
    queries[query][:rpsblast_best_evalue] = evalue
  end
end

AbortIf.logger.info { "Parsing mmseqs search results" }

# Read the mmseqs search results
File.open(mmseqs_out, "rt").each_line do |line|
  query, target, *rest = line.chomp.split "\t"

  evalue = rest[8].to_f

  abort_unless queries.has_key?(query),
               "query #{query} was in the mmseqs output file but not in the queries file."

  queries[query][:mmseqs_hits] += 1

  if evalue < queries[query][:mmseqs_best_evalue]
    queries[query][:mmseqs_best_evalue] = evalue
  end
end

#####################
# parse blast results
######################################################################



######################################################################
# condensed criteria check
##########################

AbortIf.logger.info { "Parsing conserved residue file" }
query_good = {}
File.open(criteria_check_full_out, "rt").each_line do |line|
  unless line.downcase.start_with? "query"
    query, target, evalue, region_idx, region, region_good, start_good, end_good, extein_good = line.chomp.split "\t"

    start_test_pass = residue_test_pass? start_good, opts[:intein_n_term_test_strictness]
    end_test_pass = residue_test_pass? end_good, opts[:intein_c_term_dipeptide_test_strictness]

    all_good = region_good == "L1" && start_test_pass &&
               end_test_pass && extein_good == "L1"

    unless query_good.has_key?(query)
      query_good[query] = {}
    end

    unless query_good[query].has_key?(region_idx)
      query_good[query][region_idx] = {
        region_good: NO,
        start_good: NO,
        end_good: NO,
        extein_good: NO,
        single_target_all_good: NO
      }
    end


    # Because this input file is sorted by query then by region then
    # by evalue, the targets with the best evalues for that query will
    # be first.  So if we only keep the first target for that region,
    # it will be the one with the best evalue.
    if all_good && query_good[query][region_idx][:single_target_all_good] == NO
      query_good[query][region_idx][:single_target_all_good] = { seq: target, evalue: evalue, region: region }
    end

    if region_good == "L1"
      query_good[query][region_idx][:region_good] = "L1"
    end

    if start_test_pass
      query_good[query][region_idx][:start_good] = start_good # start good can have multiple levels
    end

    if end_test_pass
      query_good[query][region_idx][:end_good] = end_good
    end

    if extein_good == "L1"
      query_good[query][region_idx][:extein_good] = "L1"
    end
  end
end

AbortIf.logger.info { "Writing condensed criteria check" }

File.open(criteria_check_condensed_out, "w") do |f|
  f.puts %w[seq region.id single.target single.target.evalue single.target.region multi.target region start end extein].join "\t"

  query_good.each do |query, regions|
    regions.each do |region, info|
      start_test_pass = residue_test_pass? info[:start_good], opts[:intein_n_term_test_strictness]
      end_test_pass = residue_test_pass? info[:end_good], opts[:intein_c_term_dipeptide_test_strictness]

      all = info[:region_good] == "L1" && start_test_pass && end_test_pass && info[:extein_good] == "L1" ? "L1" : NO

      if info[:single_target_all_good] == NO
        single_target_all = NO
        single_target_all_evalue = NO
        single_target_all_region = NO
      else
        single_target_all = info[:single_target_all_good][:seq]
        single_target_all_evalue = info[:single_target_all_good][:evalue]
        single_target_all_region = info[:single_target_all_good][:region]
      end

      # This time the query is the original query name as it is read
      # from an outfile.
      f.puts [query,
              region,
              single_target_all,
              single_target_all_evalue,
              single_target_all_region,
              all,
              info[:region_good],
              info[:start_good],
              info[:end_good],
              info[:extein_good]].join "\t"
    end
  end
end


##########################
# condensed criteria check
######################################################################


######################################################################
# refine putative intein regions
################################

AbortIf.logger.info { "Refining putative intein regions" }

region_info = {}
File.open(containing_regions_out, "rt").each_line.with_index do |line, idx|
  unless idx.zero?
    seq, region_id, start, stop, len = line.chomp.split "\t"

    unless region_info.has_key? seq
      region_info[seq] = {}
    end

    abort_if region_info[seq].has_key?(region_id),
             "#{seq} - #{region_id} pair is duplicated in #{containing_regions_out}"

    region_info[seq][region_id] = {
      start: start.to_i,
      stop: stop.to_i,
      len: len.to_i,
      has_single_target: NO
    }
  end
end

# TODO do a size check on the regions.
# TODO try and join small split regions.

File.open(criteria_check_condensed_out, "rt").each_line.with_index do |line, idx|
  unless idx.zero?
    seq, region_id, single_target, evalue, region, multi_target, *rest = line.chomp.split "\t"

    if single_target == NO && multi_target != NO && opts[:refinement_strictness] > 1
      AbortIf.logger.debug { "NOT YET IMPLEMENTED" }
    elsif single_target != NO
      good_start, good_stop = region.split "-"
      good_len = good_stop.to_i - good_start.to_i + 1

      abort_unless region_info.has_key?(seq),
                   "Seq #{seq} is present in #{criteria_check_condensed_out} but not in #{containing_regions_out}"
      abort_unless region_info[seq].has_key?(region_id),
                   "Seq-region pair #{seq}-#{region_id} is present in #{criteria_check_condensed_out} but not in #{containing_regions_out}"

      if evalue.to_f > opts[:evalue_region_refinement]
        AbortIf.logger.debug { "Seq-region pair #{seq}-#{region_id} is present, but evalue is greater than threshold.  Not using it for refinement." }
      else
        region_info[seq][region_id][:has_single_target] = {
          target: single_target,
          evalue: evalue,
          start: good_start,
          stop: good_stop,
          len: good_len
        }
      end
    else
      AbortIf.logger.debug { "Not refining seq #{seq} region #{region_id}" }
    end
  end
end

info_for_trimming = {}

File.open(refined_containing_regions_simple_out, "w") do |simple_f|
  File.open(refined_containing_regions_out, "w") do |f|
    simple_f.puts %w[seq region.id start end len trimmable].join "\t"
    f.puts %w[seq region.id start end len trimmable refining.target refining.evalue].join "\t"

    region_info.each do |seq, ht|
      unless info_for_trimming.has_key? seq
        info_for_trimming[seq] = {}
      end

      ht.each do |region_id, info|
        abort_if info_for_trimming[seq].has_key?(region_id),
                 "#{seq}-#{region_id} pair was repeated in region_info table"

        len = info[:has_single_target] == NO ? info[:len] : info[:has_single_target][:len]

        if !opts[:use_length_in_refinement] ||
           (opts[:use_length_in_refinement] && REGION_MIN_LEN <= len && len <= REGION_MAX_LEN)

          if info[:has_single_target] == NO
            info_for_trimming[seq][region_id] = NO

            simple_f.puts [
              seq,
              region_id,
              info[:start],
              info[:stop],
              info[:len],
              NO,
            ].join "\t"

            f.puts [
              seq,
              region_id,
              info[:start],
              info[:stop],
              info[:len],
              NO,
              NO,
              NO,
            ].join "\t"
          else
            # If we get here, we are refining regions, so we should be
            # pretty confident in them.
            info_for_trimming[seq][region_id] = {
              start: info[:has_single_target][:start],
              stop: info[:has_single_target][:stop]
            }

            simple_f.puts [
              seq,
              region_id,
              info[:has_single_target][:start],
              info[:has_single_target][:stop],
              info[:has_single_target][:len],
              "Yes",
            ].join "\t"

            f.puts [
              seq,
              region_id,
              info[:has_single_target][:start],
              info[:has_single_target][:stop],
              info[:has_single_target][:len],
              "Yes",
              info[:has_single_target][:target],
              info[:has_single_target][:evalue],
            ].join "\t"
          end
        end
      end
    end
  end
end

################################
# refine putative intein regions
######################################################################

######################################################################
# trim out inteins from sequences that have them
################################################

AbortIf.logger.info { "Trimming inteins from queries" }

trimmed_queries_out = File.join seq_dir, "#{query_basename}.query_seqs_with_inteins_removed.faa"
trimmed_inteins_out = File.join seq_dir, "#{query_basename}.intein_seqs.faa"

intein_count_info = { n_term: Hash.new(0), c_term: Hash.new(0) }

intein_trim_info = {}

num_inteins_written = 0
File.open(trimmed_queries_out, "w") do |queries_f|
  File.open(trimmed_inteins_out, "w") do |inteins_f|
    query_records.each do |rec_id, rec|
      abort_if intein_trim_info.has_key?(rec.id),
               "#{rec.id} was repeated in intein_trim_info hash table"

      if info_for_trimming.has_key? rec.id
        intein_seqs = []
        total_inteins = 0

        info_for_trimming[rec.id].each do |region_id, info|
          total_inteins += 1
          unless info == NO
            # These are 1-based
            start_idx = info[:start].to_i - 1
            stop_idx  = info[:stop].to_i  - 1

            # Sanity checks
            abort_unless start_idx >= 0,
                         "bad start idx for #{rec.id}-#{region_id}"
            abort_unless start_idx < stop_idx,
                         "start idx not less than stop idx for #{rec.id}-#{region_id}"
            abort_unless stop_idx < rec.seq.length,
                         "bad stop idx for #{rec.id}-#{region_id}"

            intein_seq = rec.seq[start_idx .. stop_idx]
            intein_first = intein_seq[0]
            intein_dipep = intein_seq[intein_seq.length - 2, 2]

            intein_count_info[:n_term][intein_first] += 1
            intein_count_info[:c_term][intein_dipep] += 1

            inteins_f.puts ">#{rec.id}___intein_#{region_id} n_term___#{intein_first} c_term___#{intein_dipep}"
            inteins_f.puts intein_seq
            num_inteins_written += 1

            intein_seqs << intein_seq
          end
        end

        # Make sure the intein isn't repeated.  It will break the splicing if it is.
        intein_seqs.each do |iseq|
          abort_unless rec.seq.scan(iseq).count == 1,
                       "An intein was present more than once in #{rec.id}"
        end

        regex = Regexp.new intein_seqs.join("|")
        trimmed_query_seq = rec.seq.split(regex).join

        # TODO sometimes total_inteins is 0...when will this happen?
        intein_trim_info[rec.id] = "#{intein_seqs.count}_of_#{total_inteins}"
        queries_f.puts ">#{rec.id} inteins_removed___#{intein_seqs.count}_of_#{total_inteins}"
        queries_f.puts trimmed_query_seq

        # More sanity checks
        if intein_seqs.count > 0
          total_intein_length = intein_seqs.map(&:length).reduce(:+)
          abort_unless total_intein_length + trimmed_query_seq.length == rec.seq.length,
                       "Pre trimming length and post trimming length plus intein length  don't match up for seq #{rec.id}"
        end

      else
        # this record has no inteins we can trim out
        intein_trim_info[rec.id] = NO
        queries_f.puts ">#{rec.id}"
        queries_f.puts rec.seq
      end
    end
  end
end

################################################
# trim out inteins from sequences that have them
######################################################################

######################################################################
# check the sequences that were trimmed
#######################################

AbortIf.logger.info { "Checking the trimmed sequences against superfamilies and intein DB" }

trimmed_queries_rpsblast_out = File.join search_results_dir, "trimmed_queries_search_superfamilies.txt"
trimmed_inteins_rpsblast_out = File.join search_results_dir, "trimmed_inteins_search_superfamilies.txt"

trimmed_queries_mmseqs_out = File.join search_results_dir, "trimmed_queries_search_inteins.txt"
trimmed_inteins_mmseqs_out = File.join search_results_dir, "trimmed_inteins_search_inteins.txt"

trimmed_queries_all_search_out = File.join search_results_dir, "trimmed_queries_search.txt"
trimmed_inteins_all_search_out = File.join search_results_dir, "trimmed_inteins_search.txt"

# there are enough seqs for parallel blast to be worth it and the user asked for splits
if opts[:split_queries] && num_seqs > opts[:cpus] * 2
  rpsblast_search_parallel! trimmed_queries_out, trimmed_queries_rpsblast_out
else
  rpsblast_search! trimmed_queries_out, trimmed_queries_rpsblast_out
end

# First convert the headers. For the mmseqs, we need to change to
# simple headers as it will do weird stuff if they have headers like
# 'gi|23423|blah blab'

n = 0
new_query_name_map = {}
trimmed_queries_simple_headers_out = trimmed_queries_out + ".simple_headers"
File.open(trimmed_queries_simple_headers_out, "w") do |f|
  ParseFasta::SeqFile.open(trimmed_queries_out).each_record do |rec|
    n += 1
    new_name = "query_seq_#{n}"

    new_query_name_map[new_name] = rec.id

    f.puts ">#{new_name}"
    f.puts rec.seq
  end
end

mmseqs_search! trimmed_queries_simple_headers_out, trimmed_queries_mmseqs_out

# Now map the names back to how they were.
File.open(tmpfile, "w") do |f|
  File.open(trimmed_queries_mmseqs_out, "rt").each_line do |line|
    query, *rest = line.chomp.split "\t"

    evalue = rest[9].to_f

    if evalue <= opts[:evalue_mmseqs]
      f.puts [new_query_name_map[query], rest].join "\t"
    end
  end
end
Utils.run_and_time_it! "Changing IDs in query mmseqs search", "mv #{tmpfile} #{trimmed_queries_mmseqs_out}"

cmd = "cat #{trimmed_queries_rpsblast_out} #{trimmed_queries_mmseqs_out} > #{trimmed_queries_all_search_out}"
Utils.run_and_time_it! "Catting query search results", cmd

AbortIf.logger.info { "Summarizing 2nd query search" }

second_blast_summary_queries = {}
File.open(trimmed_queries_all_search_out, "rt").each_line do |line|
  query, target, *rest = line.chomp.split "\t"

  evalue = rest[8].to_f

  unless second_blast_summary_queries.has_key? query
    abort_unless intein_trim_info.has_key?(query),
                 "#{query} missing from intein_trim_info hash table"

    inteins_removed = intein_trim_info[query]
    second_blast_summary_queries[query] = {
      inteins_removed: inteins_removed,
      num_hits: 0,
      best_evalue: 1,
    }
  end

  second_blast_summary_queries[query][:num_hits] += 1

  if evalue < second_blast_summary_queries[query][:best_evalue]
    second_blast_summary_queries[query][:best_evalue] = evalue
  end
end

second_blast_summary_queries_out = File.join search_results_dir, "trimmed_queries_search_summary.txt"

File.open(second_blast_summary_queries_out, "w") do |f|
  f.puts %w[seq iteins.removed hits best.evalue].join "\t"

  second_blast_summary_queries.each do |rec_id, info|
    f.puts [rec_id, info[:inteins_removed], info[:num_hits], info[:best_evalue]].join "\t"
  end
end



if num_inteins_written.zero?
  AbortIf.logger.info { "We couldn't trim out any inteins, so the 2nd round searching won't happen." }
else
  # We actually have inteins to search against.

  if opts[:split_queries] && num_inteins_written > opts[:cpus] * 2
    rpsblast_search_parallel! trimmed_inteins_out, trimmed_inteins_rpsblast_out
  else
    rpsblast_search! trimmed_inteins_out, trimmed_inteins_rpsblast_out
  end

  n = 0
  new_intein_name_map = {}
  trimmed_inteins_simple_headers_out = trimmed_inteins_out + ".simple_headers"
  File.open(trimmed_inteins_simple_headers_out, "w") do |f|
    ParseFasta::SeqFile.open(trimmed_inteins_out).each_record do |rec|
      n += 1
      new_name = "intein_seq_#{n}"

      new_intein_name_map[new_name] = rec.id

      f.puts ">#{new_name}"
      f.puts rec.seq
    end
  end

  mmseqs_search! trimmed_inteins_simple_headers_out, trimmed_inteins_mmseqs_out

  File.open(tmpfile, "w") do |f|
    File.open(trimmed_inteins_mmseqs_out, "rt").each_line do |line|
      intein, *rest = line.chomp.split "\t"

      evalue = rest[9].to_f

      if evalue <= opts[:evalue_mmseqs]
        f.puts [new_intein_name_map[intein], rest].join "\t"
      end
    end
  end
  Utils.run_and_time_it! "Changing IDs in intein mmseqs search", "mv #{tmpfile} #{trimmed_inteins_mmseqs_out}"

  cmd = "cat #{trimmed_inteins_rpsblast_out} #{trimmed_inteins_mmseqs_out} > #{trimmed_inteins_all_search_out}"
  Utils.run_and_time_it! "Catting intein search results", cmd

  AbortIf.logger.info { "Summarizing 2nd intein search" }

  second_blast_summary_inteins = {}
  File.open(trimmed_inteins_all_search_out, "rt").each_line do |line|
    query, target, *rest = line.chomp.split "\t"

    evalue = rest[8].to_f

    unless second_blast_summary_inteins.has_key? query
      second_blast_summary_inteins[query] = {
        num_hits: 0,
        best_evalue: 1,
      }
    end

    second_blast_summary_inteins[query][:num_hits] += 1

    if evalue < second_blast_summary_inteins[query][:best_evalue]
      second_blast_summary_inteins[query][:best_evalue] = evalue
    end
  end

  second_blast_summary_inteins_out = File.join search_results_dir,
                                               "trimmed_inteins_search_summary.txt"

  File.open(second_blast_summary_inteins_out, "w") do |f|
    f.puts %w[seq hits best.evalue].join "\t"

    second_blast_summary_inteins.each do |rec_id, info|
      f.puts [rec_id, info[:num_hits], info[:best_evalue]].join "\t"
    end
  end
end

#######################################
# check the sequences that were trimmed
######################################################################

AbortIf.logger.info { "Writing intein info" }

c_term_residue_counts_out = File.join details_dir, "intein_c_term_residue_counts.txt"
n_term_residue_counts_out = File.join details_dir, "intein_n_term_residue_counts.txt"
File.open(c_term_residue_counts_out, "w") do |cf|
  File.open(n_term_residue_counts_out, "w") do |nf|
    cf.puts %w[location oligo count perc].join "\t"
    nf.puts %w[location oligo count perc].join "\t"

    intein_count_info.each do |location, counts|
      f = location == :n_term ? nf : cf
      total = counts.values.reduce(:+).to_f

      counts.sort_by { |aa, count| count.to_i }.reverse.each do |aa, count|
        perc = (count / total * 100).round(2)
        f.puts [location, aa, count, count / total * 100].join "\t"
      end
    end
  end
end

File.open(search_results_summary_out, "w") do |f|
  f.puts %w[seq intein.hits intein.best.evalue conserved.domain.hits conserved.domain.best.evalue].join "\t"

  queries.each do |query, info|
    f.puts [query,
            info[:mmseqs_hits], info[:mmseqs_best_evalue],
            info[:rpsblast_hits], info[:rpsblast_best_evalue]].join "\t"
  end
end

AbortIf.logger.info { "Cleaning up outdir" }
FileUtils.rm_r profile_db_dir
FileUtils.rm_r tmp_dir
FileUtils.rm_r aln_dir unless opts[:keep_alignment_files]

# Remove the first search intermediate files

remove_these = [
  rpsblast_out,
  mmseqs_out,
  trimmed_inteins_rpsblast_out,
  trimmed_inteins_mmseqs_out,
  trimmed_queries_rpsblast_out,
  trimmed_queries_mmseqs_out,
  trimmed_queries_simple_headers_out,
  trimmed_inteins_simple_headers_out,
  queries_simple_name_out,
]

try_rm remove_these

unless opts[:pssm_list]
  # This is the temporary one we made.
  FileUtils.rm pssm_list
end

AbortIf.logger.info { "Done!" }
