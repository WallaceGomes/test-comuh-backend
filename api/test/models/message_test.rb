require "test_helper"

class MessageTest < ActiveSupport::TestCase
  should belong_to(:user)
  should belong_to(:community)
  should belong_to(:parent_message).optional

  should have_many(:replies).dependent(:nullify)
  should have_many(:reactions).dependent(:destroy)

  should validate_presence_of(:content)
  should validate_presence_of(:user_ip)

  describe "validations" do
    it "is invalid without content" do
      message = build(:message, content: nil)

      assert_not message.valid?
      assert_includes message.errors[:content], "can't be blank"
    end

    it "is invalid without user_ip" do
      message = build(:message, user_ip: nil)

      assert_not message.valid?
      assert_includes message.errors[:user_ip], "can't be blank"
    end
  end
end
