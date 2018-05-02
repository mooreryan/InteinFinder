#!/usr/bin/env ruby
Signal.trap("PIPE", "EXIT")

require_relative "../lib/methods"

intein_regions_refined = ARGV[0]
initial_queries_search = ARGV[1]

counts = {}
cutoffs = (3..100).map do |n|
  cutoff = "1e-#{n}".to_f
  counts[cutoff] = {
    region: 0, # track the trimmable regions lost
    hits:   0, # track the total hits
  }

  cutoff
end


File.open(intein_regions_refined, "rt").each_line do |line|
  unless line.start_with? "seq"
    seq, region, start, stop, len, trimmable, target, evalue = line.chomp.split "\t"

    unless evalue == "No"
      evalue = evalue.to_f

      cutoffs.each do |cutoff|
        add_this = evalue <= cutoff ? 0 : 1

        counts[cutoff][:region] += add_this
      end
    end
  end
end

File.open(initial_queries_search, "rt").each_line do |line|
  blast_record = InteinFinder::BlastRecord.new line

  unless blast_record.subject.start_with? "CDD:" # A superfam hit
    cutoffs.each do |cutoff|
      add_this = blast_record.evalue <= cutoff ? 1 : 0

      counts[cutoff][:hits] += add_this
    end
  end
end

puts %w[cutoff trimmable.regions blast.hits].join "\t"
counts.each do |cutoff, info|
  puts [cutoff, info[:region], info[:hits]].join "\t"
end
