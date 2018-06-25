# require_relative "lib_helper"

# RSpec.describe InteinFinder do
#   let(:klass) { Class.new.extend InteinFinder }

#   describe "#query_good?" do
#     it "gives TOO_SHORT flag if the query is too short" do
#       query = "ACTG"
#       min_len = 5
#       max_len = 100

#       expect(klass.query_good? query, min_len, max_len).to be false
#     end

#     it "gives TOO_LONG flag if the query is too long" do
#       query = "ACTG"
#       min_len = 0
#       max_len = 3

#       expect(klass.query_good? query, min_len, max_len).to be false
#     end

#     it "is false if the query has gap chars" do
#       query = "AC-TG"
#       min_len = 0
#       max_len = 10

#       expect(klass.query_good? query, min_len, max_len).to be false
#     end
#   end
# end
