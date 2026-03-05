module GeneralHelper
  def parsed_body
    JSON.parse(response.body)
  end

  def assert_error_message(expected)
    assert_equal expected, parsed_body["error"]
  end
end
