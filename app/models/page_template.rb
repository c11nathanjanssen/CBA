class PageTemplate
  include Mongoid::Document
  include Mongoid::Timestamps
  cache

  field :name, :required => true, :default => 'default'
  validates_presence_of :name
  validates_uniqueness_of :name
  index :name, :unique => true
  field :html_template, :required => true, :default => '<h1>TITLE</h1>BUTTONS COVERPICTURE<br/>BODY<hr>COMPONENTS<hr>COMMENTS'
  field :css_class, :required => true, :default => 'default'

  scope :page_templates,  any_of({name: /^Page/}, {name: /default/})
  scope :component_templates,  where(name: /^Component/)

  def in_use?
    Page.each do |page|
      return true if page.page_template_id == self.id
      page.components.each do |component|
        return true if component.page_template_id == self.id
      end
    end
    false
  end

  def delete
    if self.in_use?
      self.errors.add(:base, I18n.translate(:template_in_use))
      false
    else
      super
    end
  end

  def render(&block)
    "<div class='#{self.css_class}'>" +
      yield( self.html_template )     +
    "</div>"
  end

end
