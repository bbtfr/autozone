require 'test_helper'

class BuilderTest < ActionView::TestCase
  # WRAPPER
  test "index_for allows wrapper to be configured globally" do
    swap IndexFor, :wrapper_tag => "li", :wrapper_class => "my_wrapper" do
      with_attribute_for @user, :name
      assert_select "div.index_for li.user_name.my_wrapper"
      assert_select "div.index_for li.my_wrapper strong.label"
      assert_select "div.index_for li.my_wrapper"
    end
  end

  test "index_for attribute wraps each attribute with a label and content" do
    with_attribute_for @user, :name
    assert_select "div.index_for p.user_name.wrapper"
    assert_select "div.index_for p.wrapper strong.label"
    assert_select "div.index_for p.wrapper"
  end

  test "index_for properly deals with namespaced models" do
    @user = Namespaced::User.new(:id => 1, :name => "IndexFor")

    with_attribute_for @user, :name
    assert_select "div.index_for p.namespaced_user_name.wrapper"
    assert_select "div.index_for p.wrapper strong.label"
    assert_select "div.index_for p.wrapper"
  end

  test "index_for allows wrapper tag to be changed by attribute" do
    with_attribute_for @user, :name, :wrapper_tag => :span
    assert_select "div.index_for span.user_name.wrapper"
  end

  test "index_for allows wrapper html to be configured by attribute" do
    with_attribute_for @user, :name, :wrapper_html => { :id => "thewrapper", :class => "special" }
    assert_select "div.index_for p#thewrapper.user_name.wrapper.special"
  end

  # SEPARATOR
  test "index_for uses a separator if requested" do
    with_attribute_for @user, :name
    assert_select "div.index_for p.wrapper br"
  end

  test "index_for does not blow if a separator is not set" do
    swap IndexFor, :separator => nil do
      with_attribute_for @user, :name
      assert_select "div.index_for p.wrapper"
    end
  end
end
