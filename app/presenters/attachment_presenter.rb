class AttachmentPresenter < BasePresenter
  presents :attachment
    
  def image_or_link
    if attachment.file.content_type =~ /image/
      link_to_function( h.image_tag( w3c_url(attachment.file.url(:icon)) ), "image_popup('#{attachment.file.url(:popup)}')")
    else
      link_button attachment.file.original_filename, "button download small", attachment.file.url()
    end
  end
end