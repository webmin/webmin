#!/usr/local/bin/perl
# lists_configs.cgi
# List all usermin modules that can be configured

require './usermin-lib.pl';
$access{'configs'} || &error($text{'acl_ecannot'});
&ReadParse();
&ui_print_header(undef, $text{'configs_title'}, "");

@mods = &list_modules();
&get_usermin_miniserv_config(\%miniserv);
print "$text{'configs_desc'}<p>\n";
@grid = ( );

local $buttons, $bcss=' style="min-width: 20em; display: box; float: left; padding: 0.5em 0.2em;"';
foreach $m (@mods) {
	if ((-r "$miniserv{'root'}/$m->{'dir'}/config.info" ||
	    -r "$miniserv{'root'}/$m->{'dir'}/uconfig.info") &&
	    &can_use_module($m->{'dir'})) {
		$buttons.="<div $bcss><form action=\"edit_configs.cgi?mod=".$m->{'dir'}."\" method=\"post\">".
			&ui_submit($m->{'desc'})."</form></div>\n";
		}
	}
push(@grid, $buttons);
print &ui_grid_table(\@grid, 1, 100,
	undef,
	undef, $text{'configs_header'});

&ui_print_footer("", $text{'index_return'});

print   "<script>",
        "document.querySelectorAll('.btn.btn-default').forEach(function(button) {",
                " button.innerHTML=button.innerHTML.replace(/^/,'<i class=\"fa fa-fw fa-cog\"></i>&nbsp;');});",
	"</script>",
	"<style>i.fa.fa-fw.fa-cog { padding: 0 !important; color: lightgrey;}",
		" .btn:not(.btn-xxs):not(.btn-tiny):not(.ui_link_replaced), button.btn {min-width: 18em; text-align: left !important;}</style>";
