# A Page is a blogabble semi-static content-item.
# If <code>show_in_menu</code> the page will have a link in the
# application menu.
# Pages can be addressed by <code>/pages/OBJECT_ID</code> or
# <code>/p/TITLE_OF_THE_PAGE</code>. It can have comments and a 'cover-picture'
class Page 
  include ContentItem
  acts_as_content_item
  has_cover_picture
    
  field :show_in_menu, :type => Boolean, :default => true
  field :menu_order, :type => Integer, :default => 99999
  field :body, :type => String, :required => true
  validates_presence_of :body

  scope :top_pages, :where => { :show_in_menu => true }, :asc => :menu_order
        
  embeds_many :comments
  validates_associated :comments
    
  # Render the body with RedCloth
  def render_body
    RedCloth.new(body).to_html
  end
  
  # Same as short_title but will append a $-sign instead of '...'
  # ... smells in URLs and one can not see the difference if ... is just
  # part of the title or comes from truncation.
  def short_title_for_url
    title.truncate(CONSTANTS['title_max_length'].to_i, :omission => '$' )
  end
  
  private
  # Render the intro (which is the first paragraph of the body)
  def content_for_intro
    RedCloth.new(body.paragraphs[0]).to_html
  end
  

end
