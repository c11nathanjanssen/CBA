require 'test_helper'

class PageTest < ActiveSupport::TestCase

  def setup
    Page.delete_all
    @long_text = "Lorem ipsum dolor sit amet, consectetur adipisicing elit, \
      sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim \
      veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo \
      consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum \
      dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident"
  end

  test "sould not save without a title and a body" do
    p = Page.new
    assert !p.valid?, "A page without a title and body should not be valid"
    p.title = 'Testtitle'
    assert !p.valid?, "A page with a title but no body should not be valid"
    p.body = 'lorem ipsum'
    assert p.valid?, "A page with a title and a body should be valid"
  end

  test "Title should be unique" do
    p1 = Page.new(:title => "My Title", :body => 'Lorem')
    p2 = Page.new(:title => "My Title", :body => 'Lorem')

    assert p1.save, "Should save if title is unique"
    assert !p2.save, "Should not save with the same title again."
  end

  test "A comment should have a body" do
    p1 = Page.new(:title => "My Title", :body => 'Lorem')
    p1.comments.build( :email => 'test@server.to', :comment => '')
    assert !p1.save
  end

  test "Long titles should be truncated for permalinks" do
    p1 = Page.new(:title => @long_text, :body => "Parag One\n\nParag Two")
    assert p1.short_title_for_url =~ /^Lorem ipsum/, "Start of text should be returned"
    assert p1.short_title_for_url =~ /\$$/, "Truncated url should end with $-sign"
    assert p1.short_title_for_url != @long_text, "Title should be truncated"
  end

  test "Body should be rendered with textile and markdown" do
    markdown = Page.new(:title => "Render Body Test with md", :body => "Parag *One*\n\nParag Two", :interpreter => :markdown)
    textile = Page.new(:title => "Render Body Test with txtl", :body => "Parag *One*\n\nParag Two", :interpreter => :textile)
    assert markdown.render_body =~ /\<em\>One\<\/em\>/, "* should translate to italic with markdown"
    assert textile.render_body =~ /\<strong\>One\<\/strong\>/, "* should translate to strong with textile"
  end

end
