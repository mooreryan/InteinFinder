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

PSSM_DIR = File.join __dir__, "assets", "intein_superfamily_members"
PSSMs = ["cd00081.smp", "cd00085.smp", "cd09643.smp", "COG1372.smp", "COG1403.smp", "COG2356.smp", "pfam01844.smp", "pfam04231.smp", "pfam05551.smp", "pfam07510.smp", "pfam12639.smp", "pfam13391.smp", "pfam13392.smp", "pfam13395.smp", "pfam13403.smp", "pfam14414.smp", "pfam14623.smp", "pfam14890.smp", "PRK11295.smp", "PRK15137.smp", "smart00305.smp", "smart00306.smp", "smart00507.smp", "TIGR01443.smp", "TIGR01445.smp", "TIGR02646.smp", "pfam05204.smp", "pfam14528.smp"]
PSSM_PATHS = PSSMs.map { |pssm| File.join PSSM_DIR, pssm }

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

def check_file fname
  abort_if fname && !File.exist?(fname),
           "#{fname} doesn't exist!  Try #{__FILE__} --help for help."
end

def check_arg opts, arg
  abort_unless opts.send(:fetch, arg),
               "You must specify --#{arg.to_s.tr('_', '-')}.  Try #{__FILE__} --help for help."
end

VERSION = "0.1.0"
COPYRIGHT = "2018 Ryan Moore"
CONTACT   = "moorer@udel.edu"
#WEBSITE   = "https://github.com/mooreryan/ZetaHunter"
LICENSE   = "MIT"


VERSION_BANNER = "  # Version:   #{VERSION}
# Copyright: #{COPYRIGHT}
# Contact:   #{CONTACT}
# License:   #{LICENSE}"


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
      default: File.join(__dir__, "assets", "intein_sequences", "inbase.faa"))
  opt(:pssm_list,
      "Input file that contains a list of smp files (delimited by space, tab or newline).  Don't pass this argument to use the default.",
      type: :string)

  opt(:evalue_rpsblast,
      "Report hits less than this evalue in the rpsblast",
      default: 1e-5)
  opt(:evalue_mmseqs,
      "Report hits less than this evalue in the mmseqs search",
      default: 1e-5)

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

  # opt(:look_for_key_residues,
  #     "DO THE FANCY THING!",
  #     default: false)


  opt(:keep_alignment_files,
      "Keep the alignment files",
      default: false)

  opt(:cpus, "Number of cpus to use", default: 1)
  opt(:split_queries, "Split queries for rpsblast if there are enough sequences", default: false)
  opt(:mmseqs_sensitivity, "-s for mmseqs", default: 5.7)
  opt(:mmseqs_iterations, "--num-iterations for mmseqs", default: 2)

  opt(:outdir, "Output directory", type: :string, default: ".")
end

AbortIf.logger.info { "Checking arguments" }
# TODO make sure that you have a version of MMseqs2 that has the
# easy-search pipeline
search = "#{opts[:mmseqs]} easy-search"

# TODO this only works for the defaults.  If you pass in a full path, it will break.
Utils.check_command opts[:makeprofiledb]
Utils.check_command opts[:rpsblast]
Utils.check_command opts[:mmseqs]
Utils.check_command opts[:mafft]

check_file opts[:n_fold_splits]
check_file opts[:parallel_blast]

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

details_dir = File.join opts[:outdir], "details"
aln_dir = File.join details_dir, "alignments"

rpsblast_out = File.join details_dir, "search_results_superfamily_cds.txt"
mmseqs_out = File.join details_dir, "search_results_inteins.txt"
mmseqs_log = File.join details_dir, "mmseqs_log.txt"

all_blast_out = File.join details_dir, "all_search_results.txt"


query_basename = File.basename(opts[:queries], File.extname(opts[:queries]))

# Outfiles
queries_simple_name_out = File.join opts[:outdir], "queries_with_simple_names.faa"

intein_info_out = File.join opts[:outdir], "#{query_basename}.search_info.txt"
containing_regions_out = File.join opts[:outdir], "#{query_basename}.intein_containing_regions.txt"
criteria_check_full_out = File.join opts[:outdir], "#{query_basename}.intein_criteria_check_full.txt"
criteria_check_condensed_out = File.join opts[:outdir], "#{query_basename}.intein_criteria_check_condensed.txt"


abort_if Dir.exist?(opts[:outdir]),
         "The outdir #{opts[:outdir]} already exists!  Specify a different outdir!"

AbortIf.logger.info { "Making directories" }

FileUtils.mkdir_p opts[:outdir]
FileUtils.mkdir_p profile_db_dir
FileUtils.mkdir_p tmp_dir
FileUtils.mkdir_p details_dir
FileUtils.mkdir_p aln_dir


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
    new_name = "user_query___seq_#{n}"
    old_rec_id = rec.id
    n += 1
    query_name_map[new_name] = old_rec_id

    rec.header = new_name
    rec.id = new_name

    query_records[old_rec_id] = rec

    f.puts rec

    unless queries.has_key? old_rec_id
      queries[old_rec_id] = { mmseqs_hits: 0, mmseqs_best_evalue: 1,
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
cmd = "#{search} #{queries_simple_name_out} #{opts[:inteins]} #{mmseqs_out} #{tmp_dir} --format-mode 2 -s #{opts[:mmseqs_sensitivity]} --num-iterations #{opts[:mmseqs_iterations]} -e #{opts[:evalue_mmseqs]} --threads #{opts[:cpus]} > #{mmseqs_log}"
Utils.run_and_time_it! "Running mmseqs", cmd

#################
# homology search
######################################################################









######################################################################
# change the IDs in the search files back
##########################################

AbortIf.logger.info { "Swapping IDs in search files" }

# We do this so the user can actually read the search details.
tmpfile = File.join opts[:outdir], "tmptmp"
File.open(tmpfile, "w") do |f|
  File.open(rpsblast_out, "rt").each_line do |line|
    query, *rest = line.chomp.split "\t"

    f.puts [query_name_map[query], rest].join "\t"
  end
end
Utils.run_and_time_it! "Changing IDs in rpsblast", "mv #{tmpfile} #{rpsblast_out}"

tmpfile = File.join opts[:outdir], "tmptmp"
File.open(tmpfile, "w") do |f|
  File.open(mmseqs_out, "rt").each_line do |line|
    query, *rest = line.chomp.split "\t"

    f.puts [query_name_map[query], rest].join "\t"
  end
end
Utils.run_and_time_it! "Changing IDs in rpsblast", "mv #{tmpfile} #{mmseqs_out}"

# From here out, the sequence IDs should be back to normal.

##########################################
# change the IDs in the search files back
######################################################################







######################################################################
# get regions
#############

AbortIf.logger.info { "Getting putative intein regions" }

QSTART_IDX = 6
QEND_IDX = 7
PADDING = 10

def new_region regions, qstart, qend
  regions[regions.count] = { qstart: qstart, qend: qend }
end

def clipping_region region, padding
  { qstart: region[:qstart] - padding,
    qend: region[:qend] + padding }
end

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
  f.puts %w[seq region.id start end].join "\t"

  all_query_ids.each do |query|
    regions = query2regions[query]
    if regions
      regions.each do |id, info|
        f.puts [query, id, info[:qstart], info[:qend]].join "\t"
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

# Read the mmseqs blast as that is the one with the inteins
mmseqs_lines = []
File.open(mmseqs_out, "rt").each_line do |line|
  mmseqs_lines << line.chomp
end

conserved_f_lines = nil

conserved_f_lines = Parallel.map(mmseqs_lines, in_processes: opts[:cpus], progress: "Checking for key residues") do |line|
  out_line = nil
  query, target, *rest = line.chomp.split "\t"

  tmp_aln_in = File.join aln_dir, "tmp_aln_in_#{query}_#{target}.faa"
  tmp_aln_out = File.join aln_dir, "tmp_aln_out_#{query}_#{target}.faa"

  aln_len = rest[1].to_i
  qstart = rest[4].to_i # 1-based
  qend = rest[5].to_i # 1-based
  sstart = rest[6].to_i
  send = rest[7].to_i
  evalue = rest[8].to_f
  target_len = rest[11].to_i

  clipping_start_idx = -100
  clipping_end_idx = -100
  first_non_gap_idx = nil
  last_non_gap_idx = nil
  region_idx = -1

  slen_in_aln = send - sstart + 1

  # TODO if you want to use aln len, need to compare region to the
  # full putatitive regions calculated above
  # if slen_in_aln >= target_len
  if true # aln_len >= target_len
    # TODO check for missing seqs
    this_query = query_records[query]
    this_intein = intein_records[target]

    # Need to get the clipping region.  We want to select the 'overall
    # region' that the qstart-qend falls into.  If it doesn't (it
    # should) just fall back to this clipping region.

    if true
      query_middle = (qend + qstart + 1) / 2.0
      putative_regions = query2regions[query]
      putative_regions.each do |rid, info|
        if query_middle >= info[:qstart] && query_middle <= info[:qend]
          clipping_start_idx = info[:qstart]-1-PADDING
          clipping_end_idx = info[:qend]-1-PADDING
          region_idx = rid
          break
        end
      end

      assert clipping_start_idx != -100, "#{line}"
      assert clipping_end_idx != -100
    else
      # TODO Is there any reason we should use the homology region
      # rather than the region we calculated above?  Using the region calculated above def is able to pull more of the wonky seqs.  See intein region 2 (of 0,1,2) of seq_4.
      clipping_start_idx = qstart-1-PADDING
      clipping_end_idx = qend-1+PADDING
    end

    clipping_start_idx = clipping_start_idx < 0 ? 0 : clipping_start_idx
    # Note that if the clipping_end_idx is passed the length of the string, Ruby will just give us all the way up to the end of the string.

    this_clipping_region =
      this_query.seq[clipping_start_idx .. clipping_end_idx]

    clipping_rec = ParseFasta::Record.new header: "clipped___#{this_query.id}",
                                          seq: this_clipping_region
    # end

    # if true
    # Write the aln infile
    File.open(tmp_aln_in, "w") do |f|
      f.puts ">" + this_intein.id
      f.puts this_intein.seq

      f.puts ">" + clipping_rec.id
      f.puts clipping_rec.seq

      f.puts ">" + this_query.id
      f.puts this_query.seq
    end

    cmd = "#{opts[:mafft]} --quiet --auto --thread 1 '#{tmp_aln_in}' > '#{tmp_aln_out}'"
    Utils.run_it! cmd

    num = 0
    ParseFasta::SeqFile.open(tmp_aln_out).each_record do |rec|
      num += 1

      if num == 1 # Intein
        first_non_gap_idx = -1
        seq_len = rec.seq.length
        last_non_gap_idx = -1

        rec.seq.each_char.with_index do |char, idx|
          # TODO account for other gap characters
          if char != "-"
            first_non_gap_idx = idx

            break
          end
        end

        rec.seq.reverse.each_char.with_index do |char, idx|
          forward_index = seq_len - 1 - idx

          if char != "-"
            last_non_gap_idx = forward_index
            break
          end
        end
      elsif num == 3 # This query
        # TODO account for gaps in the start and end regions of the query seq.

        # TODO check if the alignment actually got into the region that the blast hit said it should be in

        has_start = "N"
        has_end = "N"
        has_extein_start = "N"
        correct_region = "N"

        true_pos_to_gapped_pos = PasvLib.pos_to_gapped_pos(rec.seq)
        gapped_pos_to_true_pos = true_pos_to_gapped_pos.invert

        # if the non_gap_idx is not present in the gapped_pos_to_true_pos hash table, then this query probably has a gap at that location?

        unless gapped_pos_to_true_pos.has_key?(first_non_gap_idx + 1)
          AbortIf.logger.warn { "Skipping query target pair (#{query}, #{target}) as we couldn't determine the region start." }
          break
        end

        unless gapped_pos_to_true_pos.has_key?(last_non_gap_idx + 1)
          AbortIf.logger.warn { "Skipping query target pair (#{query}, #{target}) as we couldn't determine the region end." }
          break
        end

        this_region_start = gapped_pos_to_true_pos[first_non_gap_idx+1]
        this_region_end = gapped_pos_to_true_pos[last_non_gap_idx+1]
        region = [this_region_start, this_region_end].join "-"

        putative_regions = query2regions[query]

        putative_region_good = "N"

        putative_regions.each_with_index do |(rid, info), idx|
          if this_region_start >= info[:qstart] && this_region_end <= info[:qend]
            putative_region_good = "Y"
            break # it can never be within two separate regions as the regions don't overlap (I think...TODO)
          end
        end

        # TODO if we go through the exteins by hand to make sure if the index includes part of the extein or not this could be simplified.

        start_oligo =
          Set.new(rec.seq.downcase[first_non_gap_idx .. first_non_gap_idx+1].chars)

        if !start_oligo.intersection(Set.new(%w[s t c])).empty?
          has_start = "Y"
        end

        end_oligo = rec.seq.downcase[last_non_gap_idx-2 .. last_non_gap_idx]

        first_pair = end_oligo[0..1]
        second_pair = end_oligo[1..2]
        if first_pair == "hn" || first_pair == "hq" ||
           second_pair == "hn" || second_pair == "hq"
          has_end = "Y"
        end

        extein_start_oligo =
          Set.new(rec.seq.downcase[last_non_gap_idx .. last_non_gap_idx+1].chars)
        if !extein_start_oligo.intersection(Set.new(%w[s t c])).empty?
          has_extein_start = "Y"
        end

        out_line = [query, target, evalue, region_idx, region, putative_region_good, has_start, has_end, has_extein_start]
      end
    end

    FileUtils.rm tmp_aln_in
    FileUtils.rm tmp_aln_out unless opts[:keep_alignment_files]
  end

  out_line
end

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
  conserved_f.puts %w[query target which.region aln.region region.good has.start has.end has.extein.start].join "\t"

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

    all_good = region_good == "Y" && start_good == "Y" &&
               end_good == "Y" && extein_good == "Y"

    unless query_good.has_key?(query)
      query_good[query] = {}
    end

    unless query_good[query].has_key?(region_idx)
      query_good[query][region_idx] = {
        region_good: "N",
        start_good: "N",
        end_good: "N",
        extein_good: "N",
        single_target_all_good: "N"
      }
    end


    # Because this input file is sorted by query then by region then
    # by evalue, the targets with the best evalues for that query will
    # be first.  So if we only keep the first target for that region,
    # it will be the one with the best evalue.
    if all_good && query_good[query][region_idx][:single_target_all_good] == "N"
      query_good[query][region_idx][:single_target_all_good] = target
    end

    if region_good == "Y"
      query_good[query][region_idx][:region_good] = "Y"
    end

    if start_good == "Y"
      query_good[query][region_idx][:start_good] = "Y"
    end

    if end_good == "Y"
      query_good[query][region_idx][:end_good] = "Y"
    end

    if extein_good == "Y"
      query_good[query][region_idx][:extein_good] = "Y"
    end

  end
end

AbortIf.logger.info { "Writing condensed criteria check" }

File.open(criteria_check_condensed_out, "w") do |f|
  f.puts %w[seq region.id single.target.all multi.target.all region start end extein].join "\t"

  query_good.each do |query, regions|
    regions.each do |region, info|
      all = info[:region_good] == "Y" && info[:start_good] == "Y" && info[:end_good] == "Y" && info[:extein_good] == "Y" ? "Y" : "N"

      # This time the query is the original query name as it is read
      # from an outfile.
      f.puts [query, region, info[:single_target_all_good], all, info[:region_good], info[:start_good], info[:end_good], info[:extein_good]].join "\t"
    end
  end
end


##########################
# condensed criteria check
######################################################################













AbortIf.logger.info { "Writing intein info" }

File.open(intein_info_out, "w") do |f|
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

FileUtils.rm queries_simple_name_out

unless opts[:pssm_list]
  # This is the temporary one we made.
  FileUtils.rm pssm_list
end

AbortIf.logger.info { "Done!" }
