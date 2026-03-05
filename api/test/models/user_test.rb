require "test_helper"

class UserTest < ActiveSupport::TestCase
  should have_many(:messages).dependent(:nullify)
  should have_many(:reactions).dependent(:nullify)

  should validate_presence_of(:username)
  should validate_uniqueness_of(:username)

  describe "username" do
    it "is invalid when blank" do
      user = build(:user, username: nil)

      assert_not user.valid?
      assert_includes user.errors[:username], "can't be blank"
    end
  end
end
