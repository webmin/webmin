#!/usr/local/bin/perl
# Show the web serving options form

require './webmin-lib.pl';
&ui_print_header(undef, $text{'web_title'}, "");
&get_miniserv_config(\%miniserv);

print &ui_form_start("change_web.cgi", "post");
print &ui_table_start($text{'web_header'}, undef, 2);

# Default content expiry time
print &ui_table_row($text{'web_expires'},
	&ui_opt_textbox("expires", $miniserv{'expires'}, 10,
			$text{'web_expiresdef'}, $text{'web_expiressecs'}), undef, [ "valign=middle","valign=middle" ]);

# Additional expiry times based on path
my @expires_paths;
foreach my $pe (split(/\t+/, $miniserv{'expires_paths'})) {
	my ($p, $e) = split(/=/, $pe);
	if ($p && $e ne '') {
		push(@expires_paths, [ $p, $e ]);
		}
	}
push(@expires_paths, [ undef, $miniserv{'expires'} || 86400 ]);
my $etable = &ui_columns_start([ $text{'web_expirespath'},
			         $text{'web_expirestime'} ]);
for(my $i=0; $i<@expires_paths; $i++) {
	$etable .= &ui_columns_row([
		&ui_textbox("expirespath_$i", $expires_paths[$i]->[0], 40),
		&ui_textbox("expirestime_$i", $expires_paths[$i]->[1], 10),
		]);
	}
$etable .= &ui_columns_end();
print &ui_table_row($text{'web_expirespaths'}, $etable);

# Show call stack on error
print &ui_table_row($text{'advanced_stack'},
		    &ui_yesno_radio("stack", int($gconfig{'error_stack'})), undef, [ "valign=middle","valign=middle" ]);

# Show CGI errors
print &ui_table_row($text{'advanced_showstderr'},
	    &ui_yesno_radio("showstderr", int(!$miniserv{'noshowstderr'})), undef, [ "valign=middle","valign=middle" ]);

if (!$miniserv{'session'}) {
	# Pass passwords to CGI programs
	print &ui_table_row($text{'advanced_pass'},
		    &ui_yesno_radio("pass", int($miniserv{'pass_password'})), undef, [ "valign=middle","valign=middle" ]);
	}

# Gzip static files?
print &ui_table_row($text{'advanced_gzip'},
	&ui_radio("gzip", $miniserv{'gzip'},
		  [ [ '', $text{'advanced_gzipauto'} ],
		    [ 0, $text{'advanced_gzip0'} ],
		    [ 1, $text{'advanced_gzip1'} ] ]), undef, [ "valign=middle","valign=middle" ]);

# Redirect type
print &ui_table_row($text{'advanced_redir'},
	&ui_radio("redir", $gconfig{'relative_redir'} ? 1 : 0,
		  [ [ 1, $text{'advanced_redir1'} ],
		    [ 0, $text{'advanced_redir0'} ] ]), undef, [ "valign=middle","valign=middle" ]);

print &ui_table_end();
print &ui_form_end([ [ "save", $text{'save'} ] ]);

&ui_print_footer("", $text{'index_return'});

