# -*- encoding : utf-8 -*-

# A Page is a blogabble semi-static content-item.
#
# If <code>show_in_menu</code> is set the page will have a link in the
# application menu.
#
# Pages can be addressed by <code>/pages/OBJECT_ID</code> or
# <code>/p/TITLE_OF_THE_PAGE</code>. It can have comments and a 'cover-picture'
require File.expand_path("../../../lib/translator/translator", __FILE__)
class Page
  include ContentItem
  acts_as_content_item
  has_cover_picture
  include Translator
  translate_fields [:title, :body]

  field :show_in_menu, :type => Boolean, :default => true
  field :menu_order, :type => Integer, :default => 99999
  field :body, :type => String, :required => true
  validates_presence_of :body

  field :interpreter,                             :default => :markdown
  field :allow_comments,        :type => Boolean, :default => true
  field :allow_public_comments, :type => Boolean, :default => true
  field :is_template,           :type => Boolean, :default => false
  field :template_id,           :type => BSON::ObjectId, :default => nil
  
  # Flags
  field :allow_removing_component, :type => Boolean, :default => true
  
  # If this page is derived from a Page(Template) this method returns the
  # template-page 
  def template
    if self.template_id
      Page.templates.find(self.template_id)
    else
      nil
    end
  end
  
  # Set the template id
  # @param [Page] new_template is the page to be used as template for this page
  def template=(new_template)
    if new_template
      self.template_id = new_template.id
    else
      self.template_id = nil
    end
  end
  
  # @return [Boolean] true if this page is derived from another page and the original page still exists!
  def derived?
    return self.template != nil
  end
  
  default_scope lambda { where( is_template: false) }
  scope :templates, lambda { where(is_template: true ) }
  scope :top_pages, lambda { where(show_in_menu: true).asc(:menu_order) }

  references_many            :comments, :inverse_of => :commentable
  validates_associated       :comments

  # TODO.txt: Move this definitions to a library-module
  # TODO.txt: and replace this lines with just 'has_attchments'
  embeds_many :attachments
  validates_associated :attachments
  accepts_nested_attributes_for :attachments, :allow_destroy => true

  embeds_many :page_components
  accepts_nested_attributes_for :page_components, :allow_destroy => true

  field :page_template_id, :type => BSON::ObjectId

  # Return the CSS PageTemplate of this page
  def page_template
    PageTemplate.where(:_id => self.page_template_id.to_s).first if self.page_template_id
  end
  
  # Assign a CSS Template to this Page
  def page_template=(new_template)
    self.page_template_id = new_template.id if new_template
  end

  has_and_belongs_to_many :blogs

  # Render the body with RedCloth or Discount
  def render_body(view_context=nil)
    @view_context = view_context unless view_context.nil?
    unless (@view_context && self.page_template)
      parts = [self.title_and_flags, self.t(I18n.locale,:body),"\nPLUSONE"]
      self.page_components.each do |component|
        parts << ( [ (component.t(I18n.locale,:title)||''),
                             ("-"*component.t(I18n.locale,:title).length),
                             "\n"+(component.t(I18n.locale,:body) || '')
                           ].join("\n")
                         )
      end
      rc=render_for_html( parts.join("\n") )
    else
      rc=render_with_template
    end
    rc
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
    render_for_html((t(I18n.locale,:body)||self.body).paragraphs[0])
  end

  # TODO.txt: Remove duplication!
  # TODO.txt:   This code occurs in Page and PageComponent. Move it to a single
  # TODO.txt:   place.
  def render_with_template
    self.page_template.render do |template|
      template.gsub(/TITLE/, self.title_and_flags)\
              .gsub(/BODY/,  self.render_for_html(self.t(I18n.locale,:body)))\
              .gsub(/COMPONENTS/, render_components )\
              .gsub(/COVERPICTURE/, render_cover_picture)\
              .gsub(/COMMENTS/, render_comments)\
              .gsub(/BUTTONS/, render_buttons)\
              .gsub(/PLUSONE/, ("<p><g:plusone size=\"small\"></g:plusone></p>".html_safe))\
              .gsub(/ATTACHMENTS/, render_attachments)\
              .gsub(/ATTACHMENT\[(\d)+\]/) { |attachment_number|
                attachment_number.gsub! /\D/,''
                if c= self.attachments[attachment_number.to_i-1]
                  if c.file_content_type =~ /image/
                    @view_context.image_tag c.file.url(:medium)
                  elsif
                    @view_context.link_to( c.file_file_name, c.file.url )
                  end
                else
                  "ATTACHMENT #{attachment_number} NOT FOUND"
                end
              }\
              .gsub(/COMPONENT\[(\d)\]/) do |component_number|
                component_number.gsub! /\D/,''
                 c = self.components.where(:position => component_number.to_i-1).first
                 if c
                   c.render_body
                 else
                   "COMPONENT #{component_number} NOT FOUND"
                 end
              end
    end
  end

  def render_components
    self.page_components.asc(:title).map do |component|
      if @view_context
        component.render_body(@view_context)
      else
        component.body || ''
      end
    end.join("\n")
  end

  def render_comments
    if @view_context
      @view_context.render( :partial => 'pages/comments', :locals => {:page => self} )
    else
      ""
    end
  end

  def render_attachments
    if @view_context
      @view_context.render( :partial => 'pages/attachments', :locals => {:page => self })
    else
      ""
    end
  end

  def render_cover_picture
    if self.cover_picture_exists? && self.cover_picture.url(:medium)
      @view_context.image_tag self.cover_picture.url(:medium)
    else
      ""
    end
  end

  def render_buttons
    @view_context.render :partial => "pages/buttons", :locals => { :page => self }
  end

end
