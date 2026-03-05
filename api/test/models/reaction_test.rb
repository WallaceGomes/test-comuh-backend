require "test_helper"

class ReactionTest < ActiveSupport::TestCase
  should belong_to(:message)
  should belong_to(:user)

  should validate_presence_of(:reaction_type)
  should validate_inclusion_of(:reaction_type).in_array(Reaction::ALLOWED_TYPES)
  should validate_uniqueness_of(:reaction_type).scoped_to(:message_id, :user_id)

  describe "reaction_type" do
    it "is invalid when not allowed" do
      reaction = build(:reaction, reaction_type: "wow")

      assert_not reaction.valid?
      assert_includes reaction.errors[:reaction_type], "is not included in the list"
    end
  end
end
