Smoke test

  $ InteinFinder smoke_test.toml 2> err
  $ ../../scripts/redact_log_timestamp err
  INFO [DATETIME] Renaming queries
  INFO [DATETIME] Splitting queries
  INFO [DATETIME] Making profile DB
  INFO [DATETIME] Running rpsblast
  INFO [DATETIME] Running mmseqs
  INFO [DATETIME] Getting query regions
  INFO [DATETIME] Writing putative intein regions
  INFO [DATETIME] Getting queries with intein seq hits
  INFO [DATETIME] Making query_region_hits
  INFO [DATETIME] Reading intein DB into memory
  INFO [DATETIME] Processing regions
  INFO [DATETIME] Writing name map
  INFO [DATETIME] Renaming queries in btab files
  INFO [DATETIME] Summarizing intein DB search
  INFO [DATETIME] Summarizing conserved domain DB search
  INFO [DATETIME] Done!

Show output directory. 

  $ tree --nolinks if_out | ../../scripts/redact_date /dev/stdin | grep -v -E '[0-9]+ directories, [0-9]+ files'
  if_out
  |-- _done
  |-- alignments
  |   |-- 1_name_map.tsv
  |   |-- mafft_out___seq_10___green_2018___seq_11___1___4.fa
  |   |-- mafft_out___seq_10___inbase___seq_236___1___2.fa
  |   |-- mafft_out___seq_10___kelley_2016___seq_1___1___3.fa
  |   |-- mafft_out___seq_10___kelley_2016___seq_9___1___1.fa
  |   |-- mafft_out___seq_11___green_2018___seq_11___1___4.fa
  |   |-- mafft_out___seq_11___inbase___seq_236___1___2.fa
  |   |-- mafft_out___seq_11___kelley_2016___seq_1___1___3.fa
  |   |-- mafft_out___seq_11___kelley_2016___seq_9___1___1.fa
  |   |-- mafft_out___seq_2___inbase___seq_440___2___1.fa
  |   |-- mafft_out___seq_3___inbase___seq_219___1___1.fa
  |   |-- mafft_out___seq_4___inbase___seq_440___2___1.fa
  |   |-- mafft_out___seq_5___inbase___seq_524___1___1.fa
  |   |-- mafft_out___seq_8___inbase___seq_524___1___1.fa
  |   `-- mafft_out___seq_9___inbase___seq_524___1___1.fa
  |-- logs
  |   |-- 1_config.toml
  |   |-- 2_pipeline_info.txt
  |   `-- if_log.DATE.mmseqs_search.txt
  |-- results
  |   |-- 1_putative_intein_regions.tsv
  |   |-- 2_intein_hit_checks.tsv
  |   `-- 3_trimmed_inteins.faa
  `-- search
      |-- cdm_db
      |   |-- 1_cdm_db_search_out.tsv
      |   `-- 2_cdm_db_search_summary.tsv
      `-- intein_db
          |-- 1_intein_db_search_out.tsv
          |-- 2_intein_db_search_with_regions.tsv
          `-- 3_intein_db_search_summary.tsv
  

Show config

  $ diff smoke_test.toml if_out/logs/1_config.toml
  $ grep 'Program Versions' if_out/logs/2_pipeline_info.txt
  Program Versions
  $ grep 'Working Directory' if_out/logs/2_pipeline_info.txt
  Working Directory
  $ grep 'Config' if_out/logs/2_pipeline_info.txt
  Config

You should have the correct number of trimmed inteins

  $ awk 'BEGIN {FS="\t"} $16 ~ /Pass/' if_out/results/2_intein_hit_checks.tsv | wc -l | sed -E 's/^ +//'
  3
  $ grep -c '^>' if_out/results/3_trimmed_inteins.faa | sed -E 's/^ +//'
  3

Show the putative intein regions

  $ column -t -s "$(printf '\t')" if_out/results/1_putative_intein_regions.tsv
  query                                            region_index  start  end
  the_1_first_sequence                             1             176    569
  z3_start_of___kelley_2016___seq_9                1             1      133
  z4_start_of___kelley_2016___seq_9___maybe_start  1             2      133
  the_2_second_sequence                            1             155    545
  the_2_second_sequence                            2             750    1165
  the_3_third_sequence                             1             481    852
  the_4_fourth_sequence                            1             297    736
  the_4_fourth_sequence                            2             884    1295
  the_4_fourth_sequence                            3             1561   1966
  the_5_fifth_sequence                             1             382    747
  long_enough_but_short_region                     1             101    140
  z1_little_piece_of___inbase___seq_524            1             3      129
  z2_little_piece_of___inbase___seq_524            1             1      120

Show the intein hit checks.  Note this looks weird in that
'>z4_start_of___kelley_2016___seq_9___maybe_start' says Fail (At 1)
for the start region.  But that is actually correct as it's hit region
starts at 2 and not at 1.

  $ sort -t "$(printf '\t')" -k1,1 -k2,2n if_out/results/2_intein_hit_checks.tsv | column -t -s "$(printf '\t')"
  query                                            region  intein_target        intein_start_minus_one  intein_start  intein_penultimate  intein_end  intein_end_plus_one  intein_length  start_residue_check  end_residues_check  end_plus_one_residue_check  start_position_check  end_position_check  region_check  overall_check
  the_2_second_sequence                            2       inbase___seq_440     P                       C             A                   N           C                    412            Pass (T1 C)          Pass (T2 AN)        Pass (T1 C)                 Pass (At 751)         Pass (At 1162)      Pass          Pass (T2)
  the_3_third_sequence                             1       inbase___seq_219     P                       C             H                   N           C                    367            Pass (T1 C)          Pass (T1 HN)        Pass (T1 C)                 Pass (At 483)         Pass (At 849)       Pass          Pass (T1)
  the_4_fourth_sequence                            2       inbase___seq_440     P                       C             H                   N           C                    407            Pass (T1 C)          Pass (T1 HN)        Pass (T1 C)                 Pass (At 885)         Pass (At 1291)      Pass          Pass (T1)
  the_5_fifth_sequence                             1       inbase___seq_524     E                       K             H                   N           C                    670            Fail (K)             Pass (T1 HN)        Pass (T1 C)                 Fail (At 74)          Pass (At 743)       End_pass      Fail
  z1_little_piece_of___inbase___seq_524            1       inbase___seq_524     None                    -             -                   -           None                 None           Fail (-)             Fail (--)           NA                          Fail (Before)         Fail (After)        Fail          Fail
  z2_little_piece_of___inbase___seq_524            1       inbase___seq_524     None                    -             -                   -           None                 None           Fail (-)             Fail (--)           NA                          Fail (Before)         Fail (After)        Fail          Fail
  z3_start_of___kelley_2016___seq_9                1       green_2018___seq_11  None                    S             -                   -           None                 None           Pass (T1 S)          Fail (--)           NA                          Pass (At 1)           Fail (After)        Start_pass    Fail
  z3_start_of___kelley_2016___seq_9                1       inbase___seq_236     None                    S             -                   -           None                 None           Pass (T1 S)          Fail (--)           NA                          Pass (At 1)           Fail (After)        Start_pass    Fail
  z3_start_of___kelley_2016___seq_9                1       kelley_2016___seq_1  None                    S             -                   -           None                 None           Pass (T1 S)          Fail (--)           NA                          Pass (At 1)           Fail (After)        Start_pass    Fail
  z3_start_of___kelley_2016___seq_9                1       kelley_2016___seq_9  None                    S             -                   -           None                 None           Pass (T1 S)          Fail (--)           NA                          Pass (At 1)           Fail (After)        Start_pass    Fail
  z4_start_of___kelley_2016___seq_9___maybe_start  1       green_2018___seq_11  None                    G             -                   -           None                 None           Pass (T2 G)          Fail (--)           NA                          Fail (At 1)           Fail (After)        Fail          Fail
  z4_start_of___kelley_2016___seq_9___maybe_start  1       inbase___seq_236     None                    G             -                   -           None                 None           Pass (T2 G)          Fail (--)           NA                          Fail (At 1)           Fail (After)        Fail          Fail
  z4_start_of___kelley_2016___seq_9___maybe_start  1       kelley_2016___seq_1  None                    G             -                   -           None                 None           Pass (T2 G)          Fail (--)           NA                          Fail (At 1)           Fail (After)        Fail          Fail
  z4_start_of___kelley_2016___seq_9___maybe_start  1       kelley_2016___seq_9  None                    G             -                   -           None                 None           Pass (T2 G)          Fail (--)           NA                          Fail (At 1)           Fail (After)        Fail          Fail

Show the name map

  $ column -t -s "$(printf '\t')" if_out/alignments/1_name_map.tsv
  new_name  old_name
  seq_1     the_1_first_sequence
  seq_10    z3_start_of___kelley_2016___seq_9
  seq_11    z4_start_of___kelley_2016___seq_9___maybe_start
  seq_2     the_2_second_sequence
  seq_3     the_3_third_sequence
  seq_4     the_4_fourth_sequence
  seq_5     the_5_fifth_sequence
  seq_7     long_enough_but_short_region
  seq_8     z1_little_piece_of___inbase___seq_524
  seq_9     z2_little_piece_of___inbase___seq_524

Show search results.  They should be renamed.

  $ cut -f1 if_out/search/cdm_db/1_cdm_db_search_out.tsv | sort | uniq -c | sed -E 's/^ +//;s/ +/ /g'
  7 the_1_first_sequence
  15 the_2_second_sequence
  10 the_3_third_sequence
  29 the_4_fourth_sequence
  9 the_5_fifth_sequence
  2 z3_start_of___kelley_2016___seq_9
  2 z4_start_of___kelley_2016___seq_9___maybe_start

  $ sort if_out/search/cdm_db/1_cdm_db_search_out.tsv | head | column -t -s "$(printf '\t')" 
  the_1_first_sequence   CDD:197641  37.5    40   24   1   531   569   3   42   7.85e-08  39.8
  the_1_first_sequence   CDD:197642  26.214  103  66   4   176   272   2   100  8.79e-14  58.4
  the_1_first_sequence   CDD:224291  16.667  420  249  12  205   567   45  420  1.79e-15  69.3
  the_1_first_sequence   CDD:238035  26.316  114  72   5   176   282   1   109  3.19e-13  58.
  the_1_first_sequence   CDD:273629  28.     75   43   3   181   244   5   79   4.62e-13  55.8
  the_1_first_sequence   CDD:316994  30.     80   51   2   428   507   2   76   2.35e-14  59.1
  the_1_first_sequence   CDD:317315  19.144  444  234  17  191   567   10  395  8.74e-19  79.4
  the_2_second_sequence  CDD:197641  30.     40   27   1   507   545   3   42   4.88e-08  40.6
  the_2_second_sequence  CDD:197641  41.379  29   17   0   1137  1165  15  43   7.31e-08  40.2
  the_2_second_sequence  CDD:197642  24.272  103  68   4   155   251   2   100  2.68e-10  48.8

  $ column -t -s "$(printf '\t')" if_out/search/cdm_db/2_cdm_db_search_summary.tsv
  query                                            total_hits  best_pident  pident_target  best_bits  bits_target  best_alnlen  alnlen_target  best_alnperc  alnperc_target
  the_1_first_sequence                             7           37.5         CDD:197641     79.4       CDD:317315   444          CDD:317315     None          None
  the_2_second_sequence                            15          55.          CDD:213622     85.5       CDD:317315   456          CDD:224291     None          None
  the_3_third_sequence                             10          61.905       CDD:213622     91.2       CDD:224291   424          CDD:224291     None          None
  the_4_fourth_sequence                            29          66.667       CDD:213622     128.       CDD:317315   407          CDD:317315     None          None
  the_5_fifth_sequence                             9           75.          CDD:213622     115.       CDD:224291   424          CDD:224291     None          None
  z3_start_of___kelley_2016___seq_9                2           25.676       CDD:197642     39.2       CDD:197642   79           CDD:238035     None          None
  z4_start_of___kelley_2016___seq_9___maybe_start  2           25.676       CDD:197642     39.2       CDD:197642   79           CDD:238035     None          None

  $ column -t -s "$(printf '\t')" if_out/search/intein_db/1_intein_db_search_out.tsv
  the_2_second_sequence                            inbase___seq_440     0.265  275  153  11  901   1162  217  455  3.83e-18  80.   1713  455
  the_2_second_sequence                            inbase___seq_524     0.416  60   32   1   991   1050  356  412  8.64e-07  42.   1713  532
  the_3_third_sequence                             inbase___seq_219     0.514  35   17   0   815   849   344  378  1.14e-09  52.   1671  378
  the_4_fourth_sequence                            inbase___seq_440     0.422  71   39   1   1118  1188  291  359  5.69e-11  57.   2200  455
  the_4_fourth_sequence                            inbase___seq_524     0.415  65   33   2   1118  1182  353  412  9.52e-08  46.   2200  532
  the_5_fifth_sequence                             inbase___seq_524     0.37   27   17   0   575   601   358  384  2.58e-05  37.   1129  532
  long_enough_but_short_region                     inbase___seq_524     1.     40   0    0   101   140   1    40   2.51e-22  86.   240   532
  z1_little_piece_of___inbase___seq_524            inbase___seq_524     0.944  127  0    3   3     129   149  268  6.67e-77  239.  131   532
  z2_little_piece_of___inbase___seq_524            inbase___seq_524     1.     120  0    0   1     120   149  268  2.41e-82  254.  120   532
  z3_start_of___kelley_2016___seq_9                kelley_2016___seq_9  1.     133  0    0   1     133   1    133  2.23e-95  292.  133   331
  z3_start_of___kelley_2016___seq_9                inbase___seq_236     0.411  141  75   3   1     133   1    141  5.71e-33  113.  133   322
  z3_start_of___kelley_2016___seq_9                kelley_2016___seq_1  0.469  132  64   4   1     129   1    129  2.02e-32  111.  133   331
  z3_start_of___kelley_2016___seq_9                green_2018___seq_11  0.411  17   10   0   19    35    20   36   0.000251  29.   133   153
  z4_start_of___kelley_2016___seq_9___maybe_start  kelley_2016___seq_9  1.     132  0    0   2     133   2    133  5.76e-95  291.  133   331
  z4_start_of___kelley_2016___seq_9___maybe_start  inbase___seq_236     0.414  140  74   3   2     133   2    141  5.71e-33  113.  133   322
  z4_start_of___kelley_2016___seq_9___maybe_start  kelley_2016___seq_1  0.473  131  63   4   2     129   2    129  2.02e-32  111.  133   331
  z4_start_of___kelley_2016___seq_9___maybe_start  green_2018___seq_11  0.411  17   10   0   19    35    20   36   0.000186  30.   133   153

  $ column -t -s "$(printf '\t')" if_out/search/intein_db/3_intein_db_search_summary.tsv
  query                                            total_hits  best_pident  pident_target        best_bits  bits_target          best_alnlen  alnlen_target     best_alnperc          alnperc_target
  long_enough_but_short_region                     1           1.           inbase___seq_524     86.        inbase___seq_524     40           inbase___seq_524  0.075187969924812026  inbase___seq_524
  the_2_second_sequence                            2           0.416        inbase___seq_524     80.        inbase___seq_440     275          inbase___seq_440  0.60439560439560436   inbase___seq_440
  the_3_third_sequence                             1           0.514        inbase___seq_219     52.        inbase___seq_219     35           inbase___seq_219  0.092592592592592587  inbase___seq_219
  the_4_fourth_sequence                            2           0.422        inbase___seq_440     57.        inbase___seq_440     71           inbase___seq_440  0.15604395604395604   inbase___seq_440
  the_5_fifth_sequence                             1           0.37         inbase___seq_524     37.        inbase___seq_524     27           inbase___seq_524  0.050751879699248117  inbase___seq_524
  z1_little_piece_of___inbase___seq_524            1           0.944        inbase___seq_524     239.       inbase___seq_524     127          inbase___seq_524  0.2387218045112782    inbase___seq_524
  z2_little_piece_of___inbase___seq_524            1           1.           inbase___seq_524     254.       inbase___seq_524     120          inbase___seq_524  0.22556390977443608   inbase___seq_524
  z3_start_of___kelley_2016___seq_9                4           1.           kelley_2016___seq_9  292.       kelley_2016___seq_9  141          inbase___seq_236  0.43788819875776397   inbase___seq_236
  z4_start_of___kelley_2016___seq_9___maybe_start  4           1.           kelley_2016___seq_9  291.       kelley_2016___seq_9  140          inbase___seq_236  0.43478260869565216   inbase___seq_236

Show a few of the hits with regions

  $ head -n6 if_out/search/intein_db/2_intein_db_search_with_regions.tsv | column -t -s "$(printf '\t')" 
  query                                            region  region_start  region_end  target               pident  alnlen  mismatch  gapopen  qstart  qend  tstart  tend  evalue    bits  qlen  tlen
  z3_start_of___kelley_2016___seq_9                1       1             133         kelley_2016___seq_9  1.      133     0         0        1       133   1       133   2.23e-95  292.  133   331
  z3_start_of___kelley_2016___seq_9                1       1             133         inbase___seq_236     0.411   141     75        3        1       133   1       141   5.71e-33  113.  133   322
  z3_start_of___kelley_2016___seq_9                1       1             133         kelley_2016___seq_1  0.469   132     64        4        1       129   1       129   2.02e-32  111.  133   331
  z3_start_of___kelley_2016___seq_9                1       1             133         green_2018___seq_11  0.411   17      10        0        19      35    20      36    0.000251  29.   133   153
  z4_start_of___kelley_2016___seq_9___maybe_start  1       2             133         kelley_2016___seq_9  1.      132     0         0        2       133   2       133   5.76e-95  291.  133   331

The data should match what's in the search

  $ grep -v query if_out/search/intein_db/2_intein_db_search_with_regions.tsv | cut -f1,5- | sort > a
  $ sort if_out/search/intein_db/1_intein_db_search_out.tsv > b
  $ diff a b
  $ rm a b

Look at the trimmed exteins.  I trimmed them by hand to double check.

  $ RemoveInteins if_out/results/2_intein_hit_checks.tsv ../../assets/rnr_5.faa 2> err
  >the_2_second_sequence banana
  mpgvtkqnqierarqnrkrvlplkrrftkagvhpfdeiewrmhkvlvrgsngskeerelefpafwsdnaasiagskyfrgrigsperetsvrsmisrvvsvirawgrdsgyfsadteaeifadelthillhqkaafnspvwfnvgvedppqcsacqpyralvstpvgfypigkiveenliglpvydsrgitqvvavknngikkvykvalrngtyieatgdhqvravherrttpqwfrvdelktgmrlhlyphreiserldnsslfsgtnryseiggetltrtisiagvgsssleiskaalagwlqadgfvgqyhtgtnnsltiefvavteeerqwieshlnvvfpnvhrkiritktkagtpitrvrlygevlrafvdtyellarrnairvpailwrsspavieayvksvfqgegfvrinntsihvaidtisegwmhdiqlllyglgiysrirrkkeprvnrgdlyevdisagserrkfadrigfisaskqekllrsleapnqknipdlreeeiveikdlgeevvydiqtssgeylsnnvvvhncfilavddnmesildwiytegmifkrgsgagvnlsplrssmetlsrggvssgpvsfmrgadsvagmiasggstrraakmvvlnidhpdimrfirckaeeekkvhalmetgydmydlnnpawnsiqyqnannsvrvtdefmeaverdetfttkfvgtdkpaqeyrardlmhaiaeaawesgdpgmqydtiinkwhtcpntgrinasnpcseymhldnsacnlasinvikylnpdgsfnirdfihtvdililaqdilvggssyptekigenarnyrelglgyanlgallmtwgfpydsdearhtasaitalmtgeayrysaeiakkmgayagyeinkepqlrvvsmhraefdrvredrvrdsaiykaaekawddavflgkkygvrnsqvtviaptgtialmmdcattgiepefalvktknlvgggtmrfvntavpdalknlgysdaerdlivahiesqgtiegapalkdehvavfdsavrpangvrsihwqghvkmvaavqpfisgaisktfnmsadtsvdeimkayimgwklglkafavyrdgskaaqplvtasgkggvkkeqkpfrrklpatrpsethkfsiaghegyltysmyenrdlaeifitmskqgstlaglldafaisvsialqhgvplktlarkfvygrfepagftensdiqvatsitdyifrylslrflsssdlddigvkgapkevpaaveikemkavvasevmikapvvaeaigskvvfadsvcrecggmlvqtgscktcfqcgtstggc
  >the_3_third_sequence cranberry
  MKISRYFTTSGQDPYSGIPFEPRRSEIRNPDGSTVFLMENVMVPAHWSQVATDILAQKYFRKAGLPVGEIHGAEYAPSLKDVLTPKEDRETDSRQVFHRLAGCWRYWGEKNNYFDTTEDAQAFYDELVHMLARQVAAPNSPQWFNTGLHFAYGITGVPQGHYYVNPKTNELERSQNAYERPQPHACFILSVKDDLVNEGGIMDLWTREARIFKYGSGVGTNFSKLRAGNEKLSGGGKSSGLMSFLRVGDRSAGAIKSGGTTRRAAKMVCLDLDHPDIEEFINWKVKEEQKVAALVTGSKLNERHLNAVMKACYEGGKAQSAKREDSSSLTPHASHLAPGTPDFNPRTNKALRLAIAEAKLDEIPPNYIQRAIQFAQQGFTKIEFPTFDTGYESEAYITVSGQNSnnsvrvpnaffhavekgdtwnltarttgktiktvdaqdlweqiceaawnsadpglqydttinewhtcpvdgrinasnpcseymflddtacnlasinlvrfydqqtgkfdltgyqhairvwtvvleisvlmaqfpskdiaqlsydfrtlglgyanlgallmqmgyaydsqegfaitgaltailgggsyaasaemakeqqpfpryeankehmlrvirnhrraayntadeyeglsvlpvgidqkicppdmlqaahrawdralelgtangfrnaqvtvlaptgtiglimdcdttgiepdfalvkfkklagggyfkiinqsvppsltklgysdaqigeiigyalghkslkgapyinhetlrakgfgpdqlaaletalenafeigfafnkwtfgddfchnvlgftdeqlndwsfnmlaelgwtraeidaanlyccgtmtvegapglkpehlpvfdtanrcgkigtrfisaeghirqmaaaqpflsgaisktinlpgeatvkavndaywlswtlglkanalyrdgsklsqplnassddaaaaileatleeeevapassrqpelapassfssvpdqpsvinhqtslaeeaatklvyryisrrrtlpgrrkgytqkarvgghkvylrtgefedgslgeifidmhregaafrslmncfaiaislglqygvpleefveafvftrfepngsvqghdnikmstsvidyifrelalsylartdLVQVKPEDLQGDTVGRPSQVPDFEEEEVEDDHLEGQIPGRAAQPHDSKGFYATRDNAPQASLPLDDNPQAVGSPTWTLEQKQKNAPAQYEDRYVSGNGSNGKVLVESAQTNLFAPAPTPNAQRPTPSAAPTPQHRNTPTPRLPGGEIAEKVRQARLKGYEGDPCTNCGAFTMVRNGVCLKCDTCGETSGCS
  >the_4_fourth_sequence dragonfruit
  MERYFFDEHAQAIAKRQYLQPGDGDILGMFRRVAREIAKPEKPEERAYWEEKFFELMSSKRFSPGGRILAGAGTAHGNLLNCFVQGATENPPESFAGIMEVAKKLALVTKVGGGNGVNLDPYRSRGTRKRRAVQGVAYLSAGHPDVEDFIRGLMRPPINPDGPKEEIALKNFARVVYGEVSPELKALAERYGVALAQEPPGDVIRVPDDMGGIVEAAKEAADLARRGLVPHVDFSLLRPEGAPIRGSGGTSSGPVSFLFEIFDNFLEWAALGAEEAGPVATLRYVYAPVLRVVRQGGCLHPDTLVHTDRGTLRLCELVDPFRRGWQRHTLSVATDEGWRPSPEGYNNGVAPTLRVVLENGLEVQGTPNHKLKVLREDGTRAWVELQELKPGDWVIWVLDEHTGTPVQLAPLDEPFHPNATPIRTPEVLTEDLAFLLGFFFGEGFVSGDRLGFSVHEDEPMREEVKRLFRELFGLELREEKKPGDRSVTLVVRSRPLVTWLKKNGLLKGKARELEVPRAIRQSPRPVLAAFLRGLFEADGTVTAGYPMLATASKRLAQDVMVLLGGLGIPSKLLRYNPRPGRFSKAEHYRVRVVTAKGLERYLERIGVPQGSRLEALYQSRPDTRRESSWPLPHAEGLLRPLLAVAEKGGKGHVSPYTPLRKDLLRYLRGERQLTATGYTLVQEKAQGLGLEAEPFAFNEYYVRVAAVEPGGEILTLDLSVEGNHTYLANGLVSHNTRRGAGMATLSIEHPDLLDFLTAKDLDREKAEGDISTFNISVLVSDAFMRALEQDALWPVTPIEVPGKYYPYPLEGPYTGKVPELPEREDGAKAIPLYEGKVPARWLWHEIAWHAWATGEPGLIFVDRVNALSALKGLGERYQIRSTNPcgeipltvgepcdlgalnlaayvkdgefqmeafredvrtairfldnvldvnrfalkdneeaakrlrrlglgvmgladmlirldlpynseaarqkvyeilsamreeairasedlaeergpfplyeehreyfealgikprrnvavltvaptgttsmlmgvssgiepvfspfvwrriggeykpllhplfvelmeafppapgyekdgkwdwdkiveeiqkdghgsvqnlpfvpetirkvflcahdihpldhvrmqgvvqrafdaegyagnslskclakgtliptsrglipveeiapphpedtfvpveglytaegyritahyfagkkrgvrvrldngaelvgaweshrvltpegwrlmrdlkpgdlvlgklvpshgpggapipldfprrtnakalplpecmspelalflgmlaadgatvertgfvgiatkspeveaafrnvayklfgaepkatldkrtgvrnvyllsrrlaryvealigkgakekrvpsqilqgspeeklaflrgltldgyarqdqglilyegksrrlayeaaevarsfglpwvyqgrkkvrapretyfvhsvvvsgplqelvepieshkriprvdkryrvfvpeeilaatrvgvhhpgynnlksvrdrgvshvynrtadrlgwptevlafrvvavedagevemydievedvhryvvngiishntinlpheatvadveaayteayrtgckgitvyrdgsrefqvltvkkedkevkeerreapdeapqgqeakrgeggpvyerpgrlmgftdmvkllspegtkrsflvtvnllgdrpieviltsgkagdeanadsealgrvvsialqygvppeaivrtlrgingglygtyqgrlvsskadliavaletipqafkgmvgaeeplpslsggglalpgalpcpvcgekalvreegcykcqacgyskcg
