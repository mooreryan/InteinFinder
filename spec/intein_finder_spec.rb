require "fileutils"

require_relative "lib_helper"
require_relative "spec_constants"

RSpec.describe InteinFinder do
  let(:klass) { Class.new.extend InteinFinder }

  # describe "#query_good?" do
  #   it "gives TOO_SHORT flag if the query is too short" do
  #     query = "ACTG"
  #     min_len = 5
  #     max_len = 100

  #     expect(klass.query_good? query, min_len, max_len).to be false
  #   end

  #   it "gives TOO_LONG flag if the query is too long" do
  #     query = "ACTG"
  #     min_len = 0
  #     max_len = 3

  #     expect(klass.query_good? query, min_len, max_len).to be false
  #   end

  #   it "is false if the query has gap chars" do
  #     query = "AC-TG"
  #     min_len = 0
  #     max_len = 10

  #     expect(klass.query_good? query, min_len, max_len).to be false
  #   end
  # end

  # The runners won't be tested too in-depth.  Mainly just to see that
  # they actually produce an output file and don't have any errors.
  describe InteinFinder::Runners do
    let(:runners) { Class.new.extend InteinFinder::Runners }

    describe "makeprofiledb" do
      let(:makeprofiledb_exe) do
        "makeprofiledb"
      end
      let(:makeprofiledb_smp_paths) do
        [File.join(TEST_FILE_INPUT_DIR, "cd00081.smp")]
      end
      let(:makeprofiledb_output_base) do
        File.join TEST_FILE_OUTPUT_DIR,
                  "makeprofiledb_output"
      end

      before :each do
        SpecHelper::try_rm(*Dir.glob("#{makeprofiledb_output_base}.*"))
      end

      after :each do
        SpecHelper::try_rm(*Dir.glob("#{makeprofiledb_output_base}.*"))
      end

      it "produces the expected files" do
        ret_val = nil

        expect {
          ret_val = runners.makeprofiledb! makeprofiledb_exe,
                                           makeprofiledb_smp_paths,
                                           makeprofiledb_output_base
        }.not_to raise_error

        expect(Dir.glob "#{makeprofiledb_output_base}.*").not_to be_empty
      end

      it "raises error if one of the smp files doesn't exist" do
        bad_path = File.join TEST_FILE_INPUT_DIR, "arstoien"
        paths = makeprofiledb_smp_paths.push bad_path

        expect {
          runners.makeprofiledb! makeprofiledb_exe,
                                 paths,
                                 makeprofiledb_output_base
        }.to raise_error AbortIf::Exit, /does not exist/
      end
    end

    describe "mmseqs!" do
      let(:mmseqs_exe) do
        "mmseqs"
      end
      let(:mmseqs_queries) do
        File.join TEST_FILE_INPUT_DIR,
                  "mmseqs_queries.fa"
      end
      let(:mmseqs_targets) do
        File.join TEST_FILE_INPUT_DIR,
                  "mmseqs_targets.fa"
      end
      let(:mmseqs_output) do
        File.join TEST_FILE_OUTPUT_DIR,
                  "mmseqs_output.txt"
      end
      let(:mmseqs_tmp) do
        File.join TEST_FILE_OUTPUT_DIR,
                  "mmseqs_tmpdir"
      end
      let(:mmseqs_log) do
        File.join TEST_FILE_OUTPUT_DIR,
                  "mmseqs_log.txt"
      end


      before :each do
        SpecHelper::try_rm mmseqs_output, mmseqs_log
        FileUtils.rm_r(mmseqs_tmp) if File.exist?(mmseqs_tmp)
      end

      after :each do
        SpecHelper::try_rm mmseqs_output
        FileUtils.rm_r(mmseqs_tmp) if File.exist?(mmseqs_tmp)
      end

      # Do everything in a single test as it is a slow one.
      it "produces the expected files" do
        ret_val = nil

        expect {
          ret_val = runners.mmseqs! exe: mmseqs_exe,
                                    queries: mmseqs_queries,
                                    targets: mmseqs_targets,
                                    output: mmseqs_output,
                                    tmpdir: mmseqs_tmp,
                                    log: mmseqs_log,
                                    sensitivity: 1,
                                    num_iterations: 1,
                                    threads: 4

        }.not_to raise_error

        expect(File).to exist mmseqs_output
        expect(File).to exist mmseqs_tmp

        expect(ret_val[:output]).to eq mmseqs_output
      end

      it "raises nice error if output already exists" do
          File.open(mmseqs_output, "w") { |f| f.puts "hi" }

          expect {
            runners.mmseqs! exe: mmseqs_exe,
                            queries: mmseqs_queries,
                            targets: mmseqs_targets,
                            output: mmseqs_output,
                            tmpdir: mmseqs_tmp,
                            log: mmseqs_log,
                            sensitivity: 1,
                            num_iterations: 1,
                            threads: 4
          }.to raise_error AbortIf::Exit, /output file.*already exists/
      end
    end

    describe "parallel_rpsblast!" do
      let(:parallel_rpsblast_exe) do
        "rpsblast"
      end
      let(:parallel_rpsblast_query_files) do
        Dir.glob(File.join(TEST_FILE_INPUT_DIR,
                           "parallel_rpsblast_input.fa.split_?"))
      end
      let(:parallel_rpsblast_target_db) do
        File.join TEST_FILE_INPUT_DIR,
                  "parallel_rpsblast_target_db"
      end
      let(:parallel_rpsblast_output) do
        File.join TEST_FILE_OUTPUT_DIR,
                  "parallel_rpsblast_output.txt"
      end

      it "raises nice error if one of the query files does not exist" do
        expect {
          runners.parallel_rpsblast! exe: parallel_rpsblast_exe,
                                     query_files: ["arstoien"],
                                     target_db: parallel_rpsblast_target_db,
                                     output: parallel_rpsblast_output,
                                     threads: 4
        }.to raise_error AbortIf::Exit, /does not exist/
      end

      it "produces the expected file" do
        ret_val = nil

        expect {
          ret_val = runners.parallel_rpsblast! exe: parallel_rpsblast_exe,
                                               query_files: parallel_rpsblast_query_files,
                                               target_db: parallel_rpsblast_target_db,
                                               output: parallel_rpsblast_output,
                                               threads: 4
        }.not_to raise_error

        expect(File).to exist ret_val[:output]
      end
    end

    describe "process_input_seqs!" do
      let(:annotation) { "snazzy_lala" }
      let(:num_mmseqs_splits) { 2 }
      let(:num_rpsblast_splits) { 3 }
      let(:min_len) { 8 }
      let(:process_input_seqs_exe) do
        File.join BIN_DIR, "process_input_seqs"
      end
      let(:input) do
        File.join TEST_FILE_INPUT_DIR,
                  "process_input_seqs_input.fa"
      end
      let(:outdir) do
        File.join TEST_FILE_OUTPUT_DIR,
                  "PROCESS_INPUT_FILES_TMP"
      end

      # These are the expected files.
      let(:expected_output_name_map) do
        File.join TEST_FILE_OUTPUT_DIR,
                  "process_input_seqs_output",
                  "process_input_seqs_input.fa.intein_finder.name_map"
      end
      let(:expected_output_stats) do
        File.join TEST_FILE_OUTPUT_DIR,
                  "process_input_seqs_output",
                  "process_input_seqs_input.fa.intein_finder.stats"
      end
      let(:expected_output_single_file) do
        File.join TEST_FILE_OUTPUT_DIR,
                  "process_input_seqs_output",
                  "process_input_seqs_input.fa.intein_finder"
      end
      let(:expected_output_mmseqs_splits_dir) do
        File.join TEST_FILE_OUTPUT_DIR,
                  "process_input_seqs_output",
                  "mmseqs_splits"
      end
      let(:expected_output_mmseqs_split_0) do
        File.join TEST_FILE_OUTPUT_DIR,
                  "process_input_seqs_output",
                  "mmseqs_splits",
                  "process_input_seqs_input.fa.intein_finder.split_0"
      end
      let(:expected_output_mmseqs_split_1) do
        File.join TEST_FILE_OUTPUT_DIR,
                  "process_input_seqs_output",
                  "mmseqs_splits",
                  "process_input_seqs_input.fa.intein_finder.split_1"
      end


      # START HERE: make the test files for these.
      let(:expected_output_rpsblast_splits_dir) do
        File.join TEST_FILE_OUTPUT_DIR,
                  "process_input_seqs_output",
                  "rpsblast_splits"
      end
      let(:expected_output_rpsblast_split_0) do
        File.join TEST_FILE_OUTPUT_DIR,
                  "process_input_seqs_output",
                  "rpsblast_splits",
                  "process_input_seqs_input.fa.intein_finder.split_0"
      end
      let(:expected_output_rpsblast_split_1) do
        File.join TEST_FILE_OUTPUT_DIR,
                  "process_input_seqs_output",
                  "rpsblast_splits",
                  "process_input_seqs_input.fa.intein_finder.split_1"
      end
      let(:expected_output_rpsblast_split_2) do
        File.join TEST_FILE_OUTPUT_DIR,
                  "process_input_seqs_output",
                  "rpsblast_splits",
                  "process_input_seqs_input.fa.intein_finder.split_2"
      end

      before :each do
        SpecHelper::try_rm outdir

      end

      after :each do
        SpecHelper::try_rm outdir
      end

      # shared_examples_for "writes the file" do |file_sym, filename|
      #   it "writes the #{file_sym} file" do
      #     output = nil
      #     expect {
      #       output = runners.process_input_seqs! process_input_seqs_exe,
      #                                            input,
      #                                            outdir,
      #                                            annotation,
      #                                            num_mmseqs_splits,
      #                                            min_len
      #     }.not_to raise_error

      #     actual =
      #       File.read output[file_sym]
      #     expected =
      #       File.read filename

      #     expect(actual).to eq expected

      #   end
      # end

      it "outputs the files in a hash" do
        SpecHelper::try_rm outdir
        output = nil
        expect {
          output = runners.process_input_seqs! process_input_seqs_exe,
                                               input,
                                               outdir,
                                               annotation,
                                               num_mmseqs_splits,
                                               num_rpsblast_splits,
                                               min_len
        }.not_to raise_error

        expected = {
          name_map: File.join(outdir, File.basename(expected_output_name_map)),
          stats: File.join(outdir, File.basename(expected_output_stats)),
          single_file: File.join(outdir, File.basename(expected_output_single_file)),
          mmseqs_splits_dir: File.join(outdir, File.basename(expected_output_mmseqs_splits_dir)),
          mmseqs_splits: File.join(outdir, "mmseqs_splits", "process_input_seqs_input.fa.intein_finder.split_*"),
          rpsblast_splits_dir: File.join(outdir, File.basename(expected_output_rpsblast_splits_dir)),
          rpsblast_splits: File.join(outdir, "rpsblast_splits", "process_input_seqs_input.fa.intein_finder.split_*"),
        }
        expect(output).to eq expected
      end

      it "writes the name map" do
        output = nil
        expect {
          output = runners.process_input_seqs! process_input_seqs_exe,
                                               input,
                                               outdir,
                                               annotation,
                                               num_mmseqs_splits,
                                               num_rpsblast_splits,
                                               min_len
        }.not_to raise_error

        actual =
          File.read output[:name_map]
        expected =
          File.read expected_output_name_map

        expect(actual).to eq expected
      end
      # include_examples "writes the file", :name_map, expected_output_name_map

      it "writes the stats" do
        output = nil
        expect {
          output = runners.process_input_seqs! process_input_seqs_exe,
                                               input,
                                               outdir,
                                               annotation,
                                               num_mmseqs_splits,
                                               num_rpsblast_splits,
                                               min_len
        }.not_to raise_error

        actual =
          File.read output[:stats]
        expected =
          File.read expected_output_stats

        expect(actual).to eq expected

      end

      it "writes the single file" do
        output = nil
        expect {
          output = runners.process_input_seqs! process_input_seqs_exe,
                                               input,
                                               outdir,
                                               annotation,
                                               num_mmseqs_splits,
                                               num_rpsblast_splits,
                                               min_len
        }.not_to raise_error

        actual =
          File.read output[:single_file]
        expected =
          File.read expected_output_single_file

        expect(actual).to eq expected

      end

      it "writes mmseqs split 0" do
        output = nil
        expect {
          output = runners.process_input_seqs! process_input_seqs_exe,
                                               input,
                                               outdir,
                                               annotation,
                                               num_mmseqs_splits,
                                               num_rpsblast_splits,
                                               min_len
        }.not_to raise_error

        actual =
          File.read(File.join(outdir,
                              "mmseqs_splits",
                              "process_input_seqs_input.fa.intein_finder.split_0"))
        expected =
          File.read expected_output_mmseqs_split_0

        expect(actual).to eq expected
      end

      it "writes mmseqs split 1" do
        output = nil
        expect {
          output = runners.process_input_seqs! process_input_seqs_exe,
                                               input,
                                               outdir,
                                               annotation,
                                               num_mmseqs_splits,
                                               num_rpsblast_splits,
                                               min_len
        }.not_to raise_error

        actual =
          File.read(File.join(outdir,
                              "mmseqs_splits",
                              "process_input_seqs_input.fa.intein_finder.split_1"))
        expected =
          File.read expected_output_mmseqs_split_1

        expect(actual).to eq expected
      end


      it "writes rpsblast split 0" do
        output = nil
        expect {
          output = runners.process_input_seqs! process_input_seqs_exe,
                                               input,
                                               outdir,
                                               annotation,
                                               num_mmseqs_splits,
                                               num_rpsblast_splits,
                                               min_len
        }.not_to raise_error

        actual =
          File.read(File.join(outdir,
                              "rpsblast_splits",
                              "process_input_seqs_input.fa.intein_finder.split_0"))
        expected =
          File.read expected_output_rpsblast_split_0

        expect(actual).to eq expected
      end


      it "writes rpsblast split 1" do
        output = nil
        expect {
          output = runners.process_input_seqs! process_input_seqs_exe,
                                               input,
                                               outdir,
                                               annotation,
                                               num_mmseqs_splits,
                                               num_rpsblast_splits,
                                               min_len
        }.not_to raise_error

        actual =
          File.read(File.join(outdir,
                              "rpsblast_splits",
                              "process_input_seqs_input.fa.intein_finder.split_1"))
        expected =
          File.read expected_output_rpsblast_split_1

        expect(actual).to eq expected
      end

      it "writes rpsblast split 2" do
        output = nil
        expect {
          output = runners.process_input_seqs! process_input_seqs_exe,
                                               input,
                                               outdir,
                                               annotation,
                                               num_mmseqs_splits,
                                               num_rpsblast_splits,
                                               min_len
        }.not_to raise_error

        actual =
          File.read(File.join(outdir,
                              "rpsblast_splits",
                              "process_input_seqs_input.fa.intein_finder.split_2"))
        expected =
          File.read expected_output_rpsblast_split_2

        expect(actual).to eq expected
      end

    end

    describe "simple_headers!" do

      let(:annotation) { "apple" }

      let(:simple_headers_exe) do
        File.join BIN_DIR, "simple_headers"
      end

      let(:simple_headers_input) do
        File.join TEST_FILE_INPUT_DIR,
                  "simple_headers_input.fa"
      end
      let(:simple_headers_name_map_output) do
        File.join TEST_FILE_INPUT_DIR,
                  "simple_headers_input.simple_headers.name_map.txt"
      end
      let(:simple_headers_seqs_output) do
        File.join TEST_FILE_INPUT_DIR,
                  "simple_headers_input.simple_headers.fa"
      end

      before :each do
        SpecHelper::try_rm simple_headers_name_map_output,
                           simple_headers_seqs_output
      end

      after :each do
        SpecHelper::try_rm simple_headers_name_map_output,
                           simple_headers_seqs_output
      end

      it "raises error if the input doesn't exist" do
        expect {
          runners.simple_headers! simple_headers_exe,
                                  annotation,
                                  "i_dont_exist"
        }.to raise_error AbortIf::Exit
      end

      it "produces the expected files" do

        expect {
          runners.simple_headers! simple_headers_exe,
                                  annotation,
                                  simple_headers_input
        }.not_to raise_error

        expect(File).to exist simple_headers_name_map_output
        expect(File).to exist simple_headers_seqs_output
      end

      it "returns the names of the output files in a hash" do
        # Gotta wrap it in this to avoid this test passing if it
        # exits.
        ret_val = nil
        expect {
          ret_val = runners.simple_headers! simple_headers_exe,
                                            annotation,
                                            simple_headers_input
        }.not_to raise_error

        expect(ret_val[:seqs]).to eq simple_headers_seqs_output
        expect(ret_val[:name_map]).to eq simple_headers_name_map_output
      end
    end

    describe "split_seqs!" do
      let(:num_splits) { 2 }

      let(:split_seqs_exe) do
        File.join BIN_DIR, "split_seqs"
      end

      let(:split_seqs_input) do
        File.join TEST_FILE_INPUT_DIR,
                  "split_seqs_input.fa"
      end
      let(:split_seqs_output_1) do
        File.join TEST_FILE_INPUT_DIR,
                  "split_seqs_input.fa.split_0"
      end
      let(:split_seqs_output_2) do
        File.join TEST_FILE_INPUT_DIR,
                  "split_seqs_input.fa.split_1"
      end
      let(:split_seqs_output_glob) do
        File.join TEST_FILE_INPUT_DIR,
                  "split_seqs_input.fa.split_*"
      end

      before :each do
        SpecHelper::try_rm split_seqs_output_1,
                           split_seqs_output_2
      end

      after :each do
        SpecHelper::try_rm split_seqs_output_1,
                           split_seqs_output_2

      end

      it "returns the file names" do
        ret_val = nil

        expect {
          ret_val = runners.split_seqs! split_seqs_exe,
                                        num_splits,
                                        split_seqs_input
        }.not_to raise_error

        expect(ret_val[:splits]).to eq split_seqs_output_glob
      end

      it "produces the expected files" do
        ret_val = nil

        expect {
          ret_val = runners.split_seqs! split_seqs_exe,
                                        num_splits,
                                        split_seqs_input
        }.not_to raise_error

        expect(File).to exist split_seqs_output_1
        expect(File).to exist split_seqs_output_2
      end
    end
  end
end
