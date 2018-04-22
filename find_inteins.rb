#!/usr/bin/env ruby
Signal.trap("PIPE", "EXIT")

require "aai"
require "abort_if"
require "fileutils"
require "parse_fasta"
require "trollop"

PSSM_DIR = File.join __dir__, "assets", "intein_superfamily_members"
PSSMs = ["cd00081.smp", "cd00085.smp", "cd09643.smp", "COG1372.smp", "COG1403.smp", "COG2356.smp", "pfam01844.smp", "pfam04231.smp", "pfam05551.smp", "pfam07510.smp", "pfam12639.smp", "pfam13391.smp", "pfam13392.smp", "pfam13395.smp", "pfam13403.smp", "pfam14414.smp", "pfam14623.smp", "pfam14890.smp", "PRK11295.smp", "PRK15137.smp", "smart00305.smp", "smart00306.smp", "smart00507.smp", "TIGR01443.smp", "TIGR01445.smp", "TIGR02646.smp"]
PSSM_PATHS = PSSMs.map { |pssm| File.join PSSM_DIR, pssm }

module Utils
  extend Aai::CoreExtensions::Time
  extend Aai::CoreExtensions::Process
  extend Aai::Utils
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

opts = Trollop.options do
  banner <<-EOS

  Look for possible Inteins.

  Screens sequences against the 585 sequences from inteins.com as well
  has members of the following superfamilies cl22434 (Hint), cl25944
  (Intein_splicing) and cl00083 (HNHc).

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

  opt(:cpus, "Number of cpus to use", default: 1)
  opt(:split_queries, "Split queries for rpsblast if there are enough sequences", default: false)

  opt(:outdir, "Output directory", type: :string, default: ".")
end

search = "#{opts[:mmseqs]} easy-search"

Utils.check_command opts[:makeprofiledb]
Utils.check_command opts[:rpsblast]
Utils.check_command opts[:mmseqs]


# Utils.check_command opts[:n_fold_splits]
# Utils.check_command opts[:parallel_blast]

# TODO better checking for these programs
check_file opts[:n_fold_splits]
check_file opts[:parallel_blast]

check_file opts[:pssm_list]

check_arg opts, :queries
check_file opts[:queries]

check_arg opts, :inteins
check_file opts[:inteins]

abort_unless opts[:evalue_rpsblast] <= 0.1,
             "--evalue-rpsblast should definetely be <= 0.1"
abort_unless opts[:evalue_mmseqs] <= 0.1,
             "--evalue-mmseqs should definetely be <= 0.1"

abort_unless opts[:cpus] >= 1,
             "--cpus must be >= 1"

tmp_dir = File.join opts[:outdir], "tmp"

profile_db_dir = File.join opts[:outdir], "profile_db"
profile_db = File.join profile_db_dir, "intein_db"

rpsblast_out = File.join opts[:outdir], "rpsblast_results.txt"
mmseqs_out = File.join opts[:outdir], "mmseqs_results.txt"
mmseqs_log = File.join opts[:outdir], "mmseqs_log.txt"

query_basename = File.basename(opts[:queries], File.extname(opts[:queries]))
intein_info_out = File.join opts[:outdir], "#{query_basename}.intein_info.txt"

abort_if Dir.exist?(opts[:outdir]),
         "The outdir #{opts[:outdir]} already exists!  Specify a different outdir!"

FileUtils.mkdir_p opts[:outdir]
FileUtils.mkdir_p profile_db_dir
FileUtils.mkdir_p tmp_dir



if opts[:pssm_list]
  pssm_list = opts[:pssm_list]
else
  AbortIf.logger.info { "No --pssm-list arg was passed.  Using the default pssm list." }
  # Write the default list.
  pssm_list = File.join opts[:outdir], "pssm_list.txt"
  File.open(pssm_list, "w") do |f|
    PSSM_PATHS.each do |path|
      f.puts path
    end
  end
end

# Check that all the smp files actually exist.
File.open(pssm_list, "rt").each_line do |line|
  line.chomp.split.each do |smp_fname|
    abort_unless File.exist?(smp_fname),
                 "File #{smp_fname} was listed in #{pssm_list} but it does not exist!"
  end
end

# Set up the queries hash table
queries = {}
ParseFasta::SeqFile.open(opts[:queries]).each_record do |rec|
  unless queries.has_key? rec.id
    queries[rec.id] = { mmseqs_hits: 0, mmseqs_best_evalue: 1,
                        rpsblast_hits: 0, rpsblast_best_evalue: 1 }
  end
end


cmd = "#{opts[:makeprofiledb]} -in #{pssm_list} -out #{profile_db}"
Utils.run_and_time_it! "Making profile DB", cmd


num_seqs = queries.count
# there are enough seqs for parallel blast to be worth it and the user asked for splits
if opts[:split_queries] && num_seqs > opts[:cpus] * 2
  AbortIf.logger.info { "You asked for splits, and we have #{num_seqs} sequences, so we will split the queries before blasting." }
  cmd = "#{opts[:parallel_blast]} --cpus #{opts[:cpus]} --evalue #{opts[:evalue_rpsblast]} --infile #{opts[:queries]} --blast-db #{profile_db} --outdir #{opts[:outdir]} --specific-outfile #{rpsblast_out} --blast-program #{opts[:rpsblast]} --split-program #{opts[:n_fold_splits]}"
else
  AbortIf.logger.info { "Not splitting the queries before blasting.  Either too few (#{num_seqs}) or you didn't ask for splits." }
  cmd = "#{opts[:rpsblast]} -num_threads #{opts[:cpus]} -db #{profile_db} -query #{opts[:queries]} -evalue #{opts[:evalue_rpsblast]} -outfmt 6 -out #{rpsblast_out}"
end
Utils.run_and_time_it! "Running rpsblast", cmd

cmd = "#{search} #{opts[:queries]} #{opts[:inteins]} #{mmseqs_out} #{tmp_dir} -s 5.7 --num-iterations 2 -e #{opts[:evalue_mmseqs]} --threads #{opts[:cpus]} > #{mmseqs_log}"
Utils.run_and_time_it! "Running mmseqs", cmd



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

AbortIf.logger.info { "Writing intein info" }

File.open(intein_info_out, "w") do |f|
  f.puts %w[seq mmseqs.hits mmseqs.best.evalue rpsblast.hits rpsblast.best.evalue].join "\t"

  queries.each do |query, info|
    f.puts [query,
          info[:mmseqs_hits], info[:mmseqs_best_evalue],
          info[:rpsblast_hits], info[:rpsblast_best_evalue]].join "\t"
  end
end

AbortIf.logger.info { "Cleaning up outdir" }
FileUtils.rm_r profile_db_dir
FileUtils.rm_r tmp_dir

unless opts[:pssm_list]
  # This is the temporary one we made.
  FileUtils.rm pssm_list
end

AbortIf.logger.info { "Done!  Final output: #{intein_info_out}" }
