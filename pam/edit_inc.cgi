#!/usr/local/bin/perl
# Edit a PAM include for some service

require './pam-lib.pl';
&ReadParse();

@pam = &get_pam_config();
$pam = $pam[$in{'idx'}];
if ($in{'midx'} ne '') {
	$mod = $pam->{'mods'}->[$in{'midx'}];
	$inc = $mod->{'module'};
	$type = $mod->{'type'};
	&ui_print_header(undef, $text{'inc_edit'}, "");
	}
else {
	&ui_print_header(undef, $text{'inc_create'}, "");
	$type = $in{'type'};
	}


print &ui_form_start("save_inc.cgi");
print &ui_hidden("idx", $in{'idx'});
print &ui_hidden("midx", $in{'midx'});
print &ui_hidden("_type", $in{'type'});
print &ui_table_start($text{'inc_header'}, undef, 2, [ "width=30%" ]);

# PAM service name
$t = $text{'desc_'.$pam->{'name'}};
print &ui_table_row($text{'mod_name'},
		    "<tt>".&html_escape($pam->{'name'})."</tt> ".
		    ($pam->{'desc'} ? "($pam->{'desc'})" : $t ? "($t)" : ""));

# Authentication step
print &ui_table_row($text{'mod_type'},
		    $text{'mod_type_'.$type});

# Included service
@pam = sort { $a->{'name'} cmp $b->{'name'} } @pam;
print &ui_table_row($text{'inc_inc'},
    &ui_select("inc", $inc,
	[ map { [ $_->{'name'},
		  $_->{'name'}.($text{'desc_'.$_->{'name'}} ?
				" (".$text{'desc_'.$_->{'name'}}.")" : "") ] }
	      grep { $_->{'name'} ne $pam->{'name'} } @pam ],
	1, 0, $inc ? 1 : 0));

print &ui_table_end();

if ($in{'midx'} ne '') {
	print &ui_form_end([ [ undef, $text{'save'} ],
			     [ 'delete', $text{'delete'} ] ]);
	}
else {
	print &ui_form_end([ [ undef, $text{'create'} ] ]);
	}

&ui_print_footer("edit_pam.cgi?idx=$in{'idx'}", $text{'edit_return'},
		 "", $text{'index_return'});

