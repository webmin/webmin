#!/usr/local/bin/perl
# edit_dir.cgi
# Display information about a protected directory

require './htaccess-lib.pl';
&foreign_require($apachemod, "apache-lib.pl");
&ReadParse();
$can_create || &error($text{'dir_ecannotcreate'});
if ($in{'new'}) {
	&ui_print_header(undef, $text{'dir_title1'}, "");
	}
else {
	&ui_print_header(undef, $text{'dir_title2'}, "");
	@dirs = &list_directories();
	($dir) = grep { $_->[0] eq $in{'dir'} } @dirs;
	&can_access_dir($dir->[0]) || &error($text{'dir_ecannot'});
	}

print &ui_form_start("save_dir.cgi");
print &ui_hidden("new", $in{'new'});
print &ui_hidden_table_start($text{'dir_header'}, "width=100%", 2, "main", 1, [ "width=30%" ]);

# Directory to protect
if ($in{'new'}) {
	print &ui_table_row($text{'dir_dir'},
		&ui_textbox("dir", $dir->[0], 50)." ".
		&file_chooser_button("dir", 1));
	}
else {
	print &ui_table_row($text{'dir_dir'},
		"<tt>".&html_escape($dir->[0])."</tt>");
	print &ui_hidden("dir", $in{'dir'});
	}

# File containing users
if ($can_htpasswd) {
	# Allow choice of users file
	if ($in{'new'}) {
		$ufile = &ui_radio("auto", 1, [ [ 1, $text{'dir_auto'}."<br>" ],
						[ 0, $text{'dir_sel'} ] ]);
		}
	$ufile .= &ui_textbox("file", $dir->[1], 50)." ".
		  &file_chooser_button("file", 0);
	}
else {
	# Always automatic
	if ($in{'new'}) {
		$ufile = $text{'dir_auto'};
		}
	else {
		$ufile = "<tt>".&html_escape($dir->[1])."</tt>";
		}
	}
print &ui_table_row($text{'dir_file'}, $ufile);

# File containing groups
if ($can_htgroups) {
	@opts = ( [ 2, "$text{'dir_none'}<br>" ] );
	if ($in{'new'}) {
		push(@opts, [ 1, "$text{'dir_auto'}<br>" ]);
		}
	push(@opts, [ 0, $text{'dir_sel'}." ".
		         &ui_textbox("gfile", $dir->[4], 50)." ".
			 &file_chooser_button("gfile", 0) ]);
	print &ui_table_row($text{'dir_gfile'},
		&ui_radio("gauto", $dir->[4] ? 0 : 2, \@opts));
	}

# If MD5 encryption is available, show option for it
@crypts = ( 0 );
push(@crypts, 1) if ($config{'md5'});
push(@crypts, 2) if ($config{'sha1'});
push(@crypts, 3) if ($config{'digest'});
if (@crypts > 1) {
	print &ui_table_row($text{'dir_crypt'},
		&ui_radio("crypt", int($dir->[2]),
		  [ map { [ $_, $text{'dir_crypt'.$_} ] } @crypts ]));
	}
else {
	print &ui_hidden("crypt", $crypts[0]);
	}

# Authentication realm
if (!$in{'new'}) {
	&switch_user();
	$conf = &foreign_call($apachemod, "get_htaccess_config",
			      "$dir->[0]/$config{'htaccess'}");
	&switch_back();
	$realm = &foreign_call($apachemod, "find_directive",
			       "AuthName", $conf, 1);
	}
print &ui_table_row($text{'dir_realm'},
	&ui_textbox("realm", $realm, 50));

# Users and groups to allow
if (!$in{'new'}) {
	$require = &foreign_call($apachemod, "find_directive_struct",
				 "require", $conf);
	($rmode, @rwho) = @{$require->{'words'}} if ($require);
	}
else {
	$rmode = "valid-user";
	}
print &ui_table_row($text{'dir_require'},
   &ui_radio("require_mode", $rmode,
	[ [ "valid-user", $text{'dir_requirev'}."<br>" ],
	  [ "user", $text{'dir_requireu'}." ".
	    &ui_textbox("require_user",
		$rmode eq "user" ? join(" ", @rwho) : "", 40)."<br>" ],
	  [ "group", $text{'dir_requireg'}." ".
	    &ui_textbox("require_group",
		$rmode eq "group" ? join(" ", @rwho) : "", 40)."<br>" ] ]));

print &ui_hidden_table_end();

# Webmin synchronization mode
if ($can_sync) {
	print &ui_hidden_table_start($text{'dir_header2'}, "width=100%", 2, "sync", 0, [ "width=30%" ]);

	%sync = map { $_, 1 } split(/,/, $dir->[3]);
	foreach $s ('create', 'update', 'delete') {
		print &ui_table_row($text{'dir_sync_'.$s},
			&ui_yesno_radio("sync_$s", $sync{$s} ? 1 : 0));
		}

	print &ui_hidden_table_end();
	}

if ($in{'new'}) {
	print &ui_form_end([ [ undef, $text{'create'} ] ]);
	}
else {
	if (&foreign_available("apache")) {
		%aaccess = &get_module_acl(undef, "apache");
		if ($aaccess{'global'}) {
			@abutton = ( undef, [ 'apache', $text{'dir_apache'} ] );
			}
		}
	print &ui_form_end([ [ undef, $text{'save'} ],
			     [ 'delete', $text{'dir_delete'} ],
			     [ 'remove', $dir->[4] ? $text{'dir_delete2'}
						   : $text{'dir_delete3'} ],
			     @abutton ]);
	}

&ui_print_footer("", $text{'index_return'});

