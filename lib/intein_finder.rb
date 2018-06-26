require "aai"
require "abort_if"

include AbortIf

module InteinFinder
  module Utils
    extend Aai::CoreExtensions::Time
    extend Aai::CoreExtensions::Process
    extend Aai::Utils
  end

  class BlastRecord
    attr_accessor :query,
                  :subject,
                  :pident,
                  :alen, # alignment length
                  :mismatch,
                  :gapopen,
                  :qstart, # 1-based
                  :qend, # 1-based
                  :sstart, # 1-based
                  :send, # 1-based
                  :evalue,
                  :bitscore,
                  :qlen, # query length
                  :slen # subject length

    def initialize line
      ary = line.chomp.split "\t"

      @query = ary[0]
      @subject = ary[1]
      @pident = ary[2].to_f
      @alen = ary[3].to_i
      @mismatch = ary[4].to_i
      @gapopen = ary[5].to_i
      @qstart = ary[6].to_i
      @qend = ary[7].to_i
      @sstart = ary[8].to_i
      @send = ary[9].to_i
      @evalue = ary[10].to_f
      @bitscore = ary[11].to_f

      # The blast line will not always have these, so they can be nil.
      @qlen = ary[12] ? ary[12].to_i : nil
      @slen = ary[13] ? ary[13].to_i : nil
    end

    def to_s
      [
        @query,
        @subject,
        @pident,
        @alen,
        @mismatch,
        @gapopen,
        @qstart,
        @qend,
        @sstart,
        @send,
        @evalue,
        @bitscore,
        @qlen,
        @slem
      ].join "\t"
    end
  end

  # Also has 1-based start and end to match BlastRecord.
  class ClippingRegion
    attr_accessor :id, :start, :stop

    def initialize id, start, stop
      @id = id
      @start = start
      @stop = stop
    end

    def to_s
      [@id, @start, @stop].join "\t"
    end
  end

  # Used to get important parts of BioRuby entries
  TinySeq = Struct.new :first_name, :seq

  # Status bitmask
  # BITMASK = {
  #   # Query stuff
  #   query_too_short:
  #   query_too_long:
  #   query_has_gaps:
  # }


  class Bitmask
    attr_accessor :mask

    def initialize *keys
      @mask = {}

      keys.each_with_index do |key, idx|
        mask[key] = (1 << idx)
      end
    end
  end

  def query_good? query, min_len, max_len
    flag = 0

    len = query.length

    gap_chars = query.include?("-") || query.include?(".")

    flag |= BAD_QUERY_TOO_SHORT if len <= min_len
    flag |= BAD_QUERY_TOO_LONG if len >= max_len
    flag |= BAD_QUERY_TOO_SHORT if gap_chars

    flag
  end

  module Parsers

  end

  # Functions for running/calling out to other scripts and programs.
  module Runners
    # @note Removes the tmpdir before starting if it exists.
    def mmseqs!(exe:,
                queries:,
                targets:,
                output:,
                tmpdir:,
                log:,
                sensitivity: 5.7,
                num_iterations: 2,
                evalue: 1e-3,
                threads: 1)

      # Remove the tmp dir if it exists
      FileUtils.rm_r(tmpdir) if File.exist?(tmpdir)

      abort_if File.exist?(output),
               "output file #{output} already exists"

      cmd = "#{exe} " \
            "easy-search " \
            "#{queries} " \
            "#{targets} " \
            "#{output} " \
            "#{tmpdir} " \
            "--format-mode 2 " \
            "-s #{sensitivity} " \
            "--num-iterations #{num_iterations} " \
            "-e #{evalue} " \
            "--threads #{threads} " \
            ">> #{log}"

      InteinFinder::Utils.run_and_time_it! "MMseqs2 homology search",
                                           cmd

      # Output the output file name for consistency with the other
      # functions.
      {
        output: output
      }
    end

    def simple_headers! exe, annotation, seqs
      cmd = "#{File.absolute_path exe} #{annotation} #{seqs}"

      InteinFinder::Utils.run_and_time_it! "Converting headers", cmd

      ext = File.extname seqs
      base = File.basename seqs, ext
      dir = File.dirname seqs

      {
        seqs: File.join(dir, "#{base}.simple_headers#{ext}"),
        name_map: File.join(dir, "#{base}.simple_headers.name_map.txt")
      }
    end

    def split_seqs! exe, num_splits, seqs
      cmd = "#{File.absolute_path exe} #{num_splits} #{seqs}"

      InteinFinder::Utils.run_and_time_it! "Splitting sequences", cmd

      base = File.basename seqs
      dir = File.dirname seqs

      # Need to return the glob as the program will remove any
      # unusede splits if there are too few seqs.
      splits = File.join dir, "#{base}.split_*"

      { splits: splits }
    end
  end
end
