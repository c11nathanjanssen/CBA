$ -> $('#joined_groups').tokenInput '/polco_groups.json', crossDomain: false,prePopulate: $('#joined_groups').data('pre'), theme: 'facebook'
$ -> $('#followed_groups').tokenInput '/polco_groups.json', crossDomain: false,prePopulate: $('#followed_groups').data('pre'), theme: 'facebook'