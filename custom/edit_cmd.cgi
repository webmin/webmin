#!/usr/local/bin/perl
# edit_cmd.cgi
# Display a custom command and its parameters

require './custom-lib.pl';
&ReadParse();

$access{'edit'} || &error($text{'edit_ecannot'});
if ($in{'new'}) {
	&ui_print_header(undef, $text{'create_title'}, "", "create");
	if ($in{'clone'}) {
		$cmd = &get_command($in{'id'}, $in{'idx'});
		}
	}
else {
	&ui_print_header(undef, $text{'edit_title'}, "", "edit");
	$cmd = &get_command($in{'id'}, $in{'idx'});
	}

# Form header
print &ui_form_start("save_cmd.cgi", "post");
print &ui_hidden("new", $in{'new'});
print &ui_hidden("id", $cmd->{'id'});
print &ui_table_start($text{'edit_details'}, "width=100%", 4);

# Command ID
if (!$in{'new'}) {
	print &ui_table_row(&hlink($text{'edit_id'}, "id"),
		"<tt>$cmd->{'id'}</tt>", 3);
	}

# Description, text and HTML
print &ui_table_row(&hlink($text{'edit_desc'}, "desc"),
	&ui_textbox("desc", $cmd->{'desc'}, 60), 3);
print &ui_table_row(&hlink($text{'edit_desc2'}, "desc2"),
	&ui_textarea("html", $cmd->{'html'}, 2, 60), 3);

# Command to run
if ($cmd->{'cmd'} =~ s/^\s*cd\s+(\S+)\s*;\s*//) {
	$dir = $1;
	}
print &ui_table_row(&hlink($text{'edit_cmd'},"command"),
	&ui_textarea("cmd", $cmd->{'cmd'}, 5, 60, "soft"), 3);

# Directory to run in
print &ui_table_row(&hlink($text{'edit_dir'},"dir"),
	&ui_opt_textbox("dir", $dir, 40, $text{'default'})." ".
	&file_chooser_button("dir", 1), 3);

# User to run as
if (&supports_users()) {
	print &ui_table_row(&hlink($text{'edit_user'},"user"),
		&ui_opt_textbox("user", $cmd->{'user'} eq '*' ? undef
			: $cmd->{'user'}, 13, $text{'edit_user_def'})." ".
		&user_chooser_button("user", 0)." ".
		&ui_checkbox("su", 1, $text{'edit_su'}, $cmd->{'su'}), 3);
	}

# Show raw output
print &ui_table_row(&hlink($text{'edit_raw'},"raw"),
	&ui_yesno_radio("raw", $cmd->{'raw'} ? 1 : 0));

# Command ordering on main page
print &ui_table_row(&hlink($text{'edit_order'},"order"),
	&ui_opt_textbox("order", $cmd->{'order'} || "", 6, $text{'default'}));

# Hide from main page?
print &ui_table_row(&hlink($text{'edit_noshow'},"noshow"),
	&ui_yesno_radio("noshow", $cmd->{'noshow'}));

# Visible in Usermin?
print &ui_table_row(&hlink($text{'edit_usermin'},"usermin"),
	&ui_yesno_radio("usermin", $cmd->{'usermin'}));

# Command timeout
print &ui_table_row(&hlink($text{'edit_timeout'},"timeout"),
	&ui_opt_textbox("timeout", $cmd->{'timeout'} || undef, 6,
	  $text{'default'})." ".$text{'edit_secs'});

# Clear environment?
print &ui_table_row(&hlink($text{'edit_clear'},"clear"),
	&ui_yesno_radio("clear", $cmd->{'clear'}));

# Output format
$fmode = $cmd->{'format'} eq 'redirect' ? 2 :
	 $cmd->{'format'} eq 'form' ? 3 :
	 $cmd->{'format'} ? 1 : 0;
print &ui_table_row(&hlink($text{'edit_format'}, "format"),
	&ui_radio("format_def", $fmode,
		  [ [ 0, $text{'edit_format0'} ],
		    [ 2, $text{'edit_format2'} ],
		    [ 3, $text{'edit_format3'} ],
		    [ 1, $text{'edit_format1'}." ".
			 &ui_textbox("format",
			    $fmode == 1 ? $cmd->{'format'} : "", 20) ] ]));

# Show Webmin servers to run on
@servers = &list_servers();
if (@servers > 1) {
	@hosts = @{$cmd->{'hosts'}};
	@hosts = ( 0 ) if (!@hosts);
	print &ui_table_row(&hlink($text{'edit_servers'}, "servers"),
	 &ui_select("hosts", \@hosts,
		 [ map { [ $_->{'id'},
			   !$_->{'host'} ? $_->{'desc'} :
			     $_->{'host'}.
			     ($_->{'desc'} ? ' ('.$_->{'desc'}.')' : '') ] }
		       sort { lc($a->{'host'}) cmp lc($b->{'host'}) } @servers],
		 5, 1), 3);
	}

print &ui_table_end();

# Show parameters
&show_params_inputs($cmd);

if ($in{'new'}) {
	print &ui_form_end([ [ undef, $text{'create'} ] ]);
	}
else {
	print &ui_form_end([ [ undef, $text{'save'} ],
			     [ 'clone', $text{'edit_clone'} ],
			     [ 'delete', $text{'delete'} ] ]);
	}

&ui_print_footer("", $text{'index_return'});

