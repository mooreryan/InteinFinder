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
      it "produces the expected files and deletes tmp folder" do
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
