$(document).ready ->
  
  msg_notice = $('#flash_notice').html()
  $('#flash_notice').html( 
     '<div class="ui-widget"><p><span class="ui-icon ui-icon-info" style="float: left; margin-top: 3px; margin-right: .3em;"></span> 
      <strong>Info</strong>: ' + msg_notice + '</p></div>'
  ).addClass('ui-state-highlight ui-corner-all')
  
  msg_alert = $('#flash_alert').html()
  $('#flash_alert').html( 
     '<div class="ui-widget"><p><span class="ui-icon ui-icon-alert" style="float: left; margin-top: 3px; margin-right: .3em;"></span> 
      <strong>Alert</strong>: ' + msg_alert + '</p></div>'
  ).addClass('ui-state-error ui-corner-all')
  
  if ($('#flash_alert').html() != '' ||  $('#flash_notice').html() != '')
    t1 = setTimeout("$('#flash_notice').hide(750);",7000)
    t2 = setTimeout("$('#flash_alert').hide(750);",7000)

