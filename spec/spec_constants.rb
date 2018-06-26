TEST_FILE_DIR = File.join __dir__, "test_files"

TEST_FILE_INPUT_DIR = File.join TEST_FILE_DIR, "input"
TEST_FILE_OUTPUT_DIR = File.join TEST_FILE_DIR, "output"

ROOT_DIR = File.absolute_path(File.join __dir__, "..")
BIN_DIR = File.join ROOT_DIR, "bin"

module SpecHelper
  def self.try_rm *files
    files.each do |fname|
      FileUtils.rm fname if File.exist? fname
    end
  end
end
