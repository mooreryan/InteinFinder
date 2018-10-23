#!/usr/bin/env ruby
Signal.trap("PIPE", "EXIT")

require "aai"
require "abort_if"
require "fileutils"
require "optimist"

include AbortIf

Time.extend Aai::CoreExtensions::Time
Process.extend Aai::CoreExtensions::Process

opts = Optimist.options do
  banner <<-EOS

  Run blast, but first split up the query seqs into multiple files.

  If the blast program you want to use is not on your path, you must
  specify the full path with the --blast-program option instead of
  just the name of the program.

  Options:
  EOS

  opt(:infile,
      "Seqs that you want to blast.",
      type: :string)
  opt(:blast_db,
      "Path to db to blast against",
      type: :string)
  opt(:outdir,
      "Output directory",
      type: :string,
      default: "blast_results")
  opt(:cpus,
      "Number of cpus",
      default: 4)
  opt(:evalue,
      "Evalue for blast program",
      default: 1e-3)

  opt(:specific_outfile,
      "If you want a specific name for your outfile (for use in a pipeline for example)",
      type: :string)

  opt(:blast_program,
      "Path to the blast exe you want to use",
      default: "blastn")
  opt(:split_program,
      "Path to the n_fold_splits program",
      default: "/home/moorer/bin/n_fold_splits.rb")
end

abort_unless_file_exists opts[:infile]
# TODO check if blast db exists.  It's got all those extensions.

FileUtils.mkdir_p opts[:outdir]

inbase = if (match = opts[:infile].match(/^(.*)\.gz$/))
           ary = File.basename(match[1]).split(".")
           ary.pop
           ary.join "."
         else
           ary = File.basename(opts[:infile]).split(".")
           ary.pop
           ary.join "."
         end

dbbase = if (match = opts[:blast_db].match(/^(.*)\.gz$/))
           ary = File.basename(match[1]).split(".")
           ary.pop
           ary.join "."
         else
           ary = File.basename(opts[:blast_db]).split(".")
           ary.pop
           ary.join "."
         end

mga_outf = File.join opts[:outdir], "#{inbase}.mga"
infile_splits_glob = File.join opts[:outdir], "#{File.basename(opts[:infile])}.split_*"

# First split up the infile with the number of cpus.
cmd = "#{opts[:split_program]} #{opts[:cpus]} #{opts[:infile]}"
Process.run_and_time_it! "Splitting infile", cmd

# Move the splits to the outdir if they aren't already there.
unless File.dirname(opts[:infile]) == opts[:outdir]
  cmd = "mv #{opts[:infile]}.split_* #{opts[:outdir]}"
  Process.run_and_time_it! "Moving splits", cmd
end

# Run blast on each of the splits
cmd = "parallel #{opts[:blast_program]} -query {} -db #{opts[:blast_db]} -num_threads 1 -outfmt 6 -out {}.tmp_btab -evalue #{opts[:evalue]} ::: #{infile_splits_glob}"
Process.run_and_time_it! "Running blast jobs", cmd

# Cat btabs
final_btab = File.join opts[:outdir], "#{inbase}.btab"
cmd = "cat #{File.join(opts[:outdir], '*.tmp_btab')} > #{final_btab}"
Process.run_and_time_it! "Catting tmp btabs", cmd

# Remove tmp btabs
cmd = "rm #{File.join(opts[:outdir], '*.tmp_btab')}"
Process.run_and_time_it! "Removing tmp btabs", cmd

# Remove the splits
cmd = "rm #{infile_splits_glob}"
Process.run_and_time_it! "Removing splits", cmd

if opts[:specific_outfile]
  AbortIf.logger.info { "Moving output to final location" }
  FileUtils.mv final_btab, opts[:specific_outfile]
end
