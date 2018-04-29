module InteinFinder
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
      [@query, @subject, @pident, @alen, @mismatch, @gapopen, @qstart, @qend, @sstart, @send, @evalue, @bitscore, @qlen, @slem].join "\t"
    end
  end

  # Also has 1-based start and end to match BlastRecord.
  ClippingRegion = Struct.new :id, :start, :end
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
end
