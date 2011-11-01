class UserNotificationPresenter < BasePresenter

  presents :user_notification

  def head
    content_tag :h3, class: "#{user_notification.hidden ? 'marked-read' : 'marked-unread'}" do
      link_to (user_notification.created_at.to_s(:short)+": "+
               user_notification.message.paragraphs.first + " ..."
              ), '#'
    end
  end

  def message_with_buttons
    content_tag :div do
      ContentItem::markdown(user_notification.message) +
      buttons
    end
  end

  def message
    content_tag :div do
      ContentItem::markdown(user_notification.message)
    end
  end

  def buttons
    rc = unless user_notification.hidden
      ui_button( 'mark-read', I18n.translate(:mark_read),
        hide_notification_path(user_notification.created_at.to_i))
    else
      ui_button( 'mark-unread', I18n.translate(:mark_unread),
        show_notification_path(user_notification.created_at.to_i))
    end
    rc += ui_button('destroy', I18n.translate(:destroy),
        user_user_notification_path(current_user, user_notification.id),
        confirm: I18n.translate(:are_you_sure),
        method: :delete,
        id: 'delete-link') if can? :manage, user_notification
  end


end