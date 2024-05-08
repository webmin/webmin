#!/usr/local/bin/perl
# A single page just for editing smtpd_client_restrictions
# XXX editing access maps?

require './postfix-lib.pl';

$access{'client'} || &error($text{'client_ecannot'});
&ui_print_header(undef, $text{'client_title'}, "");

$default = $text{'opts_default'};
$none = $text{'opts_none'};
$no_ = $text{'opts_no'};

print &ui_form_start("save_client.cgi", "post");
print &ui_table_start($text{'client_title'}, undef, 2);

# Parse current settings, by building a map from names to indexes
@opts = split(/[\s,]+/, &get_current_value('smtpd_client_restrictions'));
for(my $i=0; $i<@opts; $i++) {
	$opts{$opts[$i]} ||= [ ];
	push(@{$opts{$opts[$i]}}, $i);
	}

# Add binary restrictions to list
@grid = ( );
%done = ( );
foreach $r (&list_client_restrictions()) {
	push(@grid, &ui_checkbox("client", $r, $text{'sasl_'.$r},
				 defined($opts{$r})), undef);
	$done{$r} = 1;
	}

# Add restrictions with values
foreach $r (&list_multi_client_restrictions()) {
	@v = @{$opts{$r}};
	$vals = undef;
	if (scalar(@v)) {
		$vals = join(" ", map { $opts[$_+1] } @v);
		}
	push(@grid, &ui_checkbox("client", $r, $text{'sasl_'.$r},
				 scalar(@v)),
		    &ui_textbox("value_$r", $vals, 60).
		    ($r eq "check_client_access" ?
			" ".&map_chooser_button("value_$r", $r) : ""));
	$done{$r} = 1;
	foreach $v (@v) {
		$done{$opts[$v+1]} = 1;
		}
	if ($r eq "check_client_access" && @v) {
		# Can show client access map
		$has_client_access = 1;
		}
	}

# Show text field for the rest
@rest = grep { !$done{$_} } @opts;
push(@grid, &ui_checkbox("other", @rest ? 1 : 0, $text{'client_other'}, 1),
	    &ui_textbox("other_list", join(" ", @rest), 40));

# Show field
print &ui_table_row($text{'client_restrict'},
	&ui_radio("client_def", @opts ? 0 : 1,
		  [ [ 1, $text{'client_restrict1'} ],
		    [ 0, $text{'client_restrict0'} ] ])."<br>\n".
	&ui_grid_table(\@grid, 2));

print &ui_table_end();
print &ui_form_end([ [ undef, $text{'save'} ] ]);

if ($has_client_access) {
	print &ui_hr();
	&generate_map_edit("smtpd_client_restrictions:check_client_access",
		$text{'map_click'}." ".
		"<font size=\"-1\">".&hlink("$text{'help_map_format'}",
			"access")."</font>\n<br>\n", 1,
		$text{'mapping_client'}, $text{'header_value'});
	}

&ui_print_footer("", $text{'index_return'});
