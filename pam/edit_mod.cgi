#!/usr/local/bin/perl
# edit_mod.cgi
# Edit one PAM authentication module for some service

require './pam-lib.pl';
&ReadParse();
if ($in{'inc'}) {
	# Redirect to include form
	&redirect("edit_inc.cgi?idx=$in{'idx'}&type=$in{'type'}");
	return;
	}

@pam = &get_pam_config();
$pam = $pam[$in{'idx'}];
if ($in{'midx'} ne '') {
	$mod = $pam->{'mods'}->[$in{'midx'}];
	$module = $mod->{'module'};
	$module =~ s/^.*\///;
	$type = $mod->{'type'};
	&ui_print_header(undef, $text{'mod_edit'}, "");
	}
else {
	$module = $in{'module'};
	$type = $in{'type'};
	$mod = { 'type' => $type };
	&ui_print_header(undef, $text{'mod_create'}, "");
	}


print &ui_form_start("save_mod.cgi");
print &ui_hidden("idx", $in{'idx'});
print &ui_hidden("midx", $in{'midx'});
print &ui_hidden("_module", $in{'module'});
print &ui_hidden("_type", $in{'type'});
print &ui_table_start($text{'mod_header'}, "width=100%", 2);

# PAM service name
$t = $text{'desc_'.$pam->{'name'}};
print &ui_table_row($text{'mod_name'},
		    "<tt>".&html_escape($pam->{'name'})."</tt> ".
		    ($pam->{'desc'} ? "($pam->{'desc'})" : $t ? "($t)" : ""));

# PAM module name
$t = $text{$module};
print &ui_table_row($text{'mod_mod'},
		    "<tt>$module</tt> ".($t ? "($t)" : ""));

print &ui_table_row($text{'mod_type'},
		    $text{'mod_type_'.$type});

# Control mode
print &ui_table_row($text{'mod_control'},
	    &ui_select("control", $mod->{'control'},
		[ map { [ $_, $text{'control_'.$_}." (".
			      $text{'control_desc_'.$_}.")" ] }
		      ('required', 'requisite', 'sufficient', 'optional') ],
		1, 0, $in{'midx'} eq '' ? 0 : 1));

if (-r "./$module.pl") {
	do "./$module.pl";
	if (!$module_has_no_args) {
		print &ui_table_hr();
		foreach $a (split(/\s+/, $mod->{'args'})) {
			if ($a =~ /^([^\s=]+)=(\S*)$/) {
				$args{$1} = $2;
				}
			else {
				$args{$a} = "";
				}
			}
		&display_module_args($pam, $mod, \%args);
		}
	}
else {
	# Text-only args
	print &ui_table_hr();
	print &ui_table_row($text{'mod_args'},
			    &ui_textbox("args", $mod->{'args'}, 60), 3);
	}

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

