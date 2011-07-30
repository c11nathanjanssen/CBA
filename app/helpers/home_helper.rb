# -*- encoding : utf-8 -*-

module HomeHelper # :nodoc:
  
  # Render a twitter-box if config/twitter.html exists
  def insert_twitter_box
    if File.exist?( filename=File.expand_path("../../../config/twitter.#{Rails.env}.html", __FILE__))
       File.new(filename).read.html_safe
    end
  end
  
  # == Menu structure
  # The main menue, displayed in the #session-div on top of application's layout
  # will _yield_ on 'root-menus' if `SiteMenu.roots.any?` otherwise _yield_ on
  # a 'home-link', 'top-pages', 'blogs', 'userlist', and 'comments'
  #
  # === Note:
  # If a `SiteMenu` exists in the Database-collection only this menue will be
  # displayed and you have to define admin-links like 'blogs', 'userlist', and
  # so on too.
  #
  # === RakeTask:
  # There is a rake-task to generate the default menu in `SiteMenu`
  #
  #     rake data:generate_standard_root_menu
  #
  # @param [boolean] include_children default => true. False will only fetch root-items
  # @param [block] yield this block with every entry
  # @return [array] array of menu-items
  def main_menu(include_children=true,&block)
    menu_items = []
    
    if (root_menus=SiteMenu.roots).any?
      # load menu from database
      root_menus.each do |menu|
        menu_items << yield(menu.name, 
                              render( 'home/menu/with_children', 
                                 :menu => menu, 
                                 :recursive=>include_children,
                                 :force => true
                              )
                            ) if menu && (menu.role_needed||0) <= current_role
      end
    else
      # Use default menu
      
      # home
      menu_items = [ yield(:home, menu_link_to( t("menu.home"), root_path)) ]
      
      # Top pages
      menu_items << top_pages.map { |page|
          yield( page.id.to_s.to_sym, menu_link_to( page.short_title, "/p/#{page.link_to_title}" ))
      } if can? :read, Page
      
      # Blogs, Userlist, Comments
      menu_items << yield(:blogs, menu_link_to( t(:blogs), blogs_path )) if can? :read, Blog
      menu_items << yield(:userlist, menu_link_to( t("menu.userlist"), registrations_path)) if can? :read, Page
      menu_items << yield(:comments, menu_link_to( t("menu.comments"), comments_path)) if can? :read, Comment.new
    end
 
    menu_items
  end
  

end
