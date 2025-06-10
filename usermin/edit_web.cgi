#!/usr/local/bin/perl
# Show the web serving options form

require './usermin-lib.pl';
&ui_print_header(undef, $text{'web_title'}, "");
&get_usermin_miniserv_config(\%miniserv);
&get_usermin_config(\%uconfig);

print &ui_form_start("change_web.cgi", "post");
print &ui_table_start($text{'web_header'}, undef, 2);

# Default content expiry time
print &ui_table_row($text{'web_expires'},
	&ui_opt_textbox("expires", $miniserv{'expires'}, 10,
			$text{'web_expiresdef'}, $text{'web_expiressecs'}), undef);

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

# Display redirects
my $rtable = &ui_columns_start([ $text{'web_redirhost'},
			         $text{'web_redirport'},
			         $text{'web_redirpref'},
			         $text{'web_redirssl'} ], 'auto');
$rtable .= &ui_columns_row([
	&ui_textbox('redirect_host', $miniserv{'redirect_host'}, 30),
	&ui_textbox('redirect_port', $miniserv{'redirect_port'}, 5),
	&ui_textbox('redirect_prefix', $miniserv{'redirect_prefix'}, 10),
	&ui_checkbox("redirect_ssl", 1, $text{'redirect_ssl'},
			               $miniserv{'redirect_ssl'}),
	], ['', '', '', ' style="text-align: center"']);
$rtable .= &ui_columns_end();
print &ui_table_row($text{'web_redirdesc'}, $rtable);

# Display switch redirect to Usermin URL
print &ui_table_row($text{'web_rediruurl'},
	&ui_opt_textbox("redirect_url", $miniserv{'redirect_url'}, 40, $text{'default'}));


# Show call stack on error
print &ui_table_row($text{'advanced_stack'},
		    &ui_yesno_radio("stack", int($uconfig{'error_stack'})), undef);

# Show CGI errors
print &ui_table_row($text{'advanced_showstderr'},
	    &ui_yesno_radio("showstderr", int(!$miniserv{'noshowstderr'})), undef);

if (!$miniserv{'session'}) {
	# Pass passwords to CGI programs
	print &ui_table_row($text{'advanced_pass'},
		    &ui_yesno_radio("pass", int($miniserv{'pass_password'})), undef);
	}

# Gzip static files?
print &ui_table_row($text{'advanced_gzip'},
	&ui_radio("gzip", $miniserv{'gzip'},
		  [ [ '', $text{'advanced_gzipauto'} ],
		    [ 0, $text{'advanced_gzip0'} ],
		    [ 1, $text{'advanced_gzip1'} ] ]), undef);

# Redirect type
print &ui_table_row($text{'advanced_redir'},
	&ui_radio("redir", $uconfig{'relative_redir'} ? 1 : 0,
		  [ [ 1, $text{'advanced_redir1'} ],
		    [ 0, $text{'advanced_redir0'} ] ]), undef);

# Allow directory listing
print &ui_table_row($text{'advanced_listdir'},
	&ui_yesno_radio("listdir", !$miniserv{'nolistdir'}));

print &ui_table_end();
print &ui_form_end([ [ "save", $text{'save'} ] ]);

&ui_print_footer("", $text{'index_return'});

