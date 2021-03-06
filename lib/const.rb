PSSM_DIR =
  File.join __dir__, "..", "assets", "intein_superfamily_members"

PSSMs = [
  "cd00081.smp",
  "cd00085.smp",
  "cd09643.smp",
  "COG1372.smp",
  "COG1403.smp",
  "COG2356.smp",
  "pfam01844.smp",
  "pfam04231.smp",
  "pfam05551.smp",
  "pfam07510.smp",
  "pfam12639.smp",
  "pfam13391.smp",
  "pfam13392.smp",
  "pfam13395.smp",
  "pfam13403.smp",
  "pfam14414.smp",
  "pfam14623.smp",
  "pfam14890.smp",
  "PRK11295.smp",
  "PRK15137.smp",
  "smart00305.smp",
  "smart00306.smp",
  "smart00507.smp",
  "TIGR01443.smp",
  "TIGR01445.smp",
  "TIGR02646.smp",
  "pfam05204.smp",
  "pfam14528.smp",
  "pfam14527.smp"
]

PSSM_PATHS = PSSMs.map { |pssm| File.join PSSM_DIR, pssm }

NO = "No"
L1 = "L1"
L2 = "L2"

N_TERM_LEVEL_1 = Set.new %w[C S A Q P T]
N_TERM_LEVEL_2 = Set.new %w[V G L M N F]
C_TERM_LEVEL_1 = Set.new %w[HN SN GN GQ LD FN]
C_TERM_LEVEL_2 = Set.new [
  "KN",
  "DY",
  "SQ",
  "HQ",
  "NS",
  "AN",
  "SD",
  "TH",
  "RD",
  "PY",
  "YN",
  "VH",
  "KQ",
  "PP",
  "NT",
  "CN",
  "LH",
]

C_EXTEIN_START = Set.new %w[S T C]

# The defaults come from the InterPro page about inteins plus some
# padding.
REGION_MIN_LEN_DEFAULT = 100
REGION_MAX_LEN_DEFAULT = 700
IGNORE_QUERIES_LESS_THAN_DEFUALT = REGION_MIN_LEN_DEFAULT
IGNORE_REGIONS_LESS_THAN_DEFUALT = 100

VERSION   = "v0.8.2"
COPYRIGHT = "2018 Ryan Moore"
CONTACT   = "moorer@udel.edu"
WEBSITE   = "https://github.com/mooreryan/InteinFinder"
LICENSE   = "MIT"


VERSION_BANNER = "# Version:   #{VERSION}
# Copyright: #{COPYRIGHT}
# Contact:   #{CONTACT}
# License:   #{LICENSE}"

MAX_ALIGNMENTS_BEFORE_ALL = 5

QSTART_IDX = 6
QEND_IDX = 7

PADDING = 10

PARALLEL_MODE_CUTOFF = 250

QUERY_REJECT_LENGTH = "length"
QUERY_REJECT_GAPS = "has gap chars"

module InteinFinder
  ROOT_DIR = File.absolute_path(File.join(__dir__, ".."))

  ANNOTATION = "INTEIN_FINDER"
end
