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

######################################################################
# aligning
##########

def write_aln_in fname, intein, query, clipping_region
  clipping_start_idx = clipping_region.start - 1
  clipping_stop_idx = clipping_region.stop - 1

  clipped_seq = query.seq[clipping_start_idx .. clipping_stop_idx]

  clipped_seq_id = "clipped___#{query.id}"

  File.open(fname, "w") do |f|
    f.printf ">%s\n%s\n", intein.id, intein.seq
    f.printf ">%s\n%s\n", clipped_seq_id, clipped_seq
    f.printf ">%s\n%s\n", query.id, query.seq
  end
end

def align! aln_in, aln_out
  cmd = sprintf MAFFT, aln_in, aln_out

  Utils.run_it! cmd
end


def parse_intein_aln rec
  first_non_gap_idx = -1
  last_non_gap_idx = -1

  seq_len = rec.seq.length

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

  [first_non_gap_idx, last_non_gap_idx]
end

def parse_query_aln rec,
                    blast_record,
                    first_non_gap_idx,
                    last_non_gap_idx,
                    query2regions

  # TODO check if the alignment actually got into the region
  # that the blast hit said it should be in

  intein_n_term = NO
  end_good = NO
  extein_good = NO
  correct_region = NO

  true_pos_to_gapped_pos = PasvLib.pos_to_gapped_pos(rec.seq)
  gapped_pos_to_true_pos = true_pos_to_gapped_pos.invert

  # TODO if the non_gap_idx is not present in the
  # gapped_pos_to_true_pos hash table, then this query
  # probably has a gap at that location?
  unless gapped_pos_to_true_pos.has_key?(first_non_gap_idx + 1)
    AbortIf.logger.debug do
      "Skipping query target pair (#{blast_record.query}, " \
      "#{blast_record.subject}) as we couldn't determine " \
      "the region start."
    end

    return nil
  end

  unless gapped_pos_to_true_pos.has_key?(last_non_gap_idx + 1)
    AbortIf.logger.debug do
      "Skipping query target pair (#{blast_record.query}, " \
      "#{blast_record.subject}) as we couldn't determine " \
      "the region end."
    end

    return nil
  end

  this_region_start =
    gapped_pos_to_true_pos[first_non_gap_idx+1]
  this_region_end =
    gapped_pos_to_true_pos[last_non_gap_idx+1]

  region = [this_region_start, this_region_end].join "-"

  putative_regions = query2regions[blast_record.query]

  region_good = NO

  putative_regions.each_with_index do |(rid, info), idx|
    if this_region_start >= info[:qstart] &&
       this_region_end <= info[:qend]

      region_good = L1

      # It can never be within two separate regions as the
      # regions don't overlap (I think...TODO)
      break
    end
  end


  start_residue = rec.seq[first_non_gap_idx]
  start_good = residue_test start_residue,
                           N_TERM_LEVEL_1,
                           N_TERM_LEVEL_2

  # Take last two residues
  end_oligo = rec.seq[last_non_gap_idx-1 .. last_non_gap_idx]
  end_good = residue_test end_oligo,
                         C_TERM_LEVEL_1,
                         C_TERM_LEVEL_2

  # need to get one past the last thing in the intein
  extein_start_residue = rec.seq.upcase[last_non_gap_idx + 1]

  if C_EXTEIN_START.include? extein_start_residue
    extein_good = L1
  end

  all_good = [
    region_good,
    start_good,
    end_good,
    extein_good,
  ].all? { |test| test != NO }


  h = {
    region: region,
    all_good: all_good,
    region_good: region_good,
    start_good: start_good,
    end_good: end_good,
    extein_good: extein_good,
    start_residue: start_residue,
    end_oligo: end_oligo,
    extein_start_residue: extein_start_residue
  }

  return h
end

def parse_aln_out aln_out,
                  blast_record,
                  clipping_region,
                  query2regions

  num = 0
  out_line = nil
  result = nil
  all_good = nil
  first_non_gap_idx = nil
  last_non_gap_idx = nil
  ParseFasta::SeqFile.open(aln_out).each_record do |rec|
    num += 1

    if num == 1
      # Intein
      first_non_gap_idx, last_non_gap_idx = parse_intein_aln rec
    elsif num == 3
      # This query

      result = parse_query_aln rec,
                               blast_record,
                               first_non_gap_idx,
                               last_non_gap_idx,
                               query2regions

      if result
        out_line = [
          blast_record.query,
          blast_record.subject,
          blast_record.evalue,
          clipping_region.id,
          result[:region],
          result[:region_good],
          result[:start_good],
          result[:end_good],
          result[:extein_good],
          result[:start_residue],
          result[:end_oligo],
          result[:extein_start_residue]
        ]

        all_good = result[:all_good]
      end
    end
  end

  [all_good, out_line]
end

##########
# aligning
######################################################################





######################################################################
# random stuff
##############

def try_rm files
  files.each do |fname|
    if fname && File.exist?(fname)
      FileUtils.rm fname
    end
  end
end

def new_region regions, qstart, qend
  regions[regions.count] = { qstart: qstart, qend: qend }
end


# name can be either a name or a path to the program.
def check_program name
  abort_unless File.exists?(name) || Utils.command?(name),
               "Either #{name} doesn't exist or it is not a command."
end

def residue_test aa, level_1, level_2
  test_aa = aa.upcase

  if level_1.include? test_aa
    L1
  elsif level_2.include? test_aa
    L2
  else
    NO
  end
end

def residue_test_pass? result, strictness
  result == L1 || (result == L2 && strictness >= 2)
end



def check_file fname
  abort_if fname && !File.exist?(fname),
           "#{fname} doesn't exist!  Try #{__FILE__} --help for help."
end

def check_arg opts, arg
  abort_unless opts.send(:fetch, arg),
               "You must specify --#{arg.to_s.tr('_', '-')}.  Try #{__FILE__} --help for help."
end

##############
# random stuff
######################################################################



######################################################################
# search
########

def mmseqs_search! infile, outfile
  cmd = sprintf MMSEQS_SEARCH, infile, outfile

  Utils.run_and_time_it! "Running mmseqs", cmd
end

def rpsblast_search! infile, outfile

  cmd = sprintf RPSBLAST_SEARCH, infile, outfile

  Utils.run_and_time_it! "Running rpsblast", cmd
end

def rpsblast_search_parallel! infile, outfile
  cmd = sprintf RPSBLAST_SEARCH_PARALLEL, infile, outfile

  Utils.run_and_time_it! "Running rpsblast", cmd
end

########
# search
######################################################################
