require "test_helper"

class CommunityTest < ActiveSupport::TestCase
  should have_many(:messages).dependent(:destroy)
  should validate_presence_of(:name)
  should validate_uniqueness_of(:name)

  describe "name" do
    it "is invalid when blank" do
      community = build(:community, name: nil)

      assert_not community.valid?
      assert_includes community.errors[:name], "can't be blank"
    end
  end
end
