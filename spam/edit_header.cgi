#!/usr/local/bin/perl
# edit_header.cgi
# Display extra header and body test

require './spam-lib.pl';
&ReadParse();
&set_config_file_in(\%in);
&can_use_check("header");
&ui_print_header($header_subtext, $text{'header_title'}, "");
$conf = &get_config();

print "$text{'header_desc'}<p>\n";
&start_form("save_header.cgi", $text{'header_header'},
	    "<a href='edit_simple.cgi?file=".&urlize($in{'file'}).
	    "&title=".&urlize($in{'title'}).
	    "'>$text{'header_switch'}</a>");

# Allow user-defined rules?
if (!$module_info{'usermin'}) {
	$allow = &find("allow_user_rules", $conf);
	print &ui_table_row($text{'header_allow'},
		&yes_no_field("allow_user_rules", $allow, 0));
	}

# Header tests
@header = &find("header", $conf);
print &ui_table_row($text{'header_test'},
	&edit_table("header",
	    [ $text{'header_tname'}, $text{'header_name'}, $text{'header_op'},
	      $text{'header_pat'}, $text{'header_default'} ],
	    [ map { [ &split_header($_->{'value'}) ] } @header ], [ ], \&header_conv, 2));

print &ui_table_hr();

push(@body, map { [ &split_body($_->{'value'}), 0 ] } &find("body", $conf));
push(@body, map { [ &split_body($_->{'value'}), 1 ] } &find("rawbody", $conf));
push(@body, map { [ &split_body($_->{'value'}), 2 ] } &find("fullbody", $conf));
push(@body, map { [ &split_body($_->{'value'}), 3 ] } &find("full", $conf));
print &ui_table_row($text{'header_body'},
	&edit_table("body",
	    [ $text{'header_tname'}, $text{'header_mode'}, $text{'header_op'},
	      $text{'header_pat'} ], \@body, [ ], \&body_conv, 2));

print &ui_table_hr();

@uri = &find("uri", $conf);
print &ui_table_row($text{'header_uri'},
	&edit_table("uri",
	    [ $text{'header_tname'}, $text{'header_pat'} ],
	    [ map { $_->{'words'} } @uri ], [ 20, 40 ], undef, 2));

print &ui_table_hr();

@meta = &find("meta", $conf);
print &ui_table_row($text{'header_meta'},
	&edit_table("meta",
	    [ $text{'header_tname'}, $text{'header_bool'} ],
	    [ map { $_->{'value'} =~ /^(\S+)\s*(.*)$/ ? [ $1, $2 ] : [ ] } @meta ],
	    [ 20, 40 ], undef, 2));

print &ui_table_hr();

@score = &find("score", $conf);
print &ui_table_row($text{'score_score'},
	&edit_table("score",
		    [ $text{'score_name'}, $text{'score_points'} ],
		    [ map { $_->{'words'} } @score ], [ 30, 6 ]));

@describe = &find("describe", $conf);
print &ui_table_row($text{'score_describe'},
	&edit_table("describe",
	    [ $text{'score_name'}, $text{'score_descr'} ],
	    [ map { $_->{'value'} =~ /^(\S+)\s*(.*)/ ? [ $1, $2 ] : [ ] }
	      @describe ], [ 30, 40 ]));

&end_form(undef, $text{'save'});
&ui_print_footer($redirect_url, $text{'index_return'});

# header_conv(col, name, size, value, &values)
sub header_conv
{
if ($_[0] == 0) {
	return &ui_textbox($_[1], $_[3], 20);
	}
elsif ($_[0] == 1) {
	local $h = $_[3] =~ /^exists:(\S+)$/ ? $1 : $_[3] =~ /^eval:/ ? "" : $_[3];
	return &ui_textbox($_[1], $h, 15);
	}
elsif ($_[0] == 2) {
	local $v = $_[4]->[1] =~ /^exists:/ ? 'exists' :
		   $_[4]->[1] =~ /^eval:/ ? 'eval' : $_[3];
	return &ui_select($_[1], $v,
			  [ [ '=~', $text{'header_op0'} ],
			    [ '!~', $text{'header_op1'} ],
			    [ 'exists', $text{'header_op2'} ],
			    [ 'eval', $text{'header_op3'} ] ], 1, 0, $v);
	}
elsif ($_[0] == 3) {
	return &ui_textbox($_[1], $_[4]->[1] =~ /^eval:(.*)/ ? $1 : $_[3], 20);
	}
elsif ($_[0] == 4) {
	return &ui_textbox($_[1], $_[3], 15);
	}
}

# body_conv(col, name, size, value, &values)
sub body_conv
{
if ($_[0] == 0) {
	return &ui_textbox($_[1], $_[4]->[0], 20);
	}
elsif ($_[0] == 1) {
	return &ui_select($_[1], $_[4]->[2],
			[ [ 0, $text{'header_mode0'} ],
			  [ 1, $text{'header_mode1'} ],
			  [ 2, $text{'header_mode2'} ],
			  [ 3, $text{'header_mode3'} ] ]);
	}
elsif ($_[0] == 2) {
	return &ui_select($_[1], $_[4]->[1] =~ /^eval:/ ? 1 : 0,
			  [ [ 0, $text{'header_op0'} ],
			    [ 1, $text{'header_op3'} ] ]);
	}
elsif ($_[0] == 3) {
	return &ui_textbox($_[1], $_[4]->[1] =~ /^eval:(.*)$/ ? $1 : $_[4]->[1],
			   40);
	}
}

sub split_header
{
if ($_[0] =~ /^(\S+)\s+(eval:\S+\(.*\))/) {
	return ($1, $2);
	}
elsif ($_[0] =~ /^(\S+)\s+(\S+)\s+(\S+)\s+(\/.*\/\S*)\s*(if-unset:\s*(.*))?/) {
	return ($1, $2, $3, $4, $6);
	}
else {
	return ( );
	}
}

sub split_body
{
if ($_[0] =~ /^(\S+)\s+((\/.*\/\S*)|(eval:\S+\(.*\)))/) {
	return ($1, $2);
	}
else {
	return ( );
	}
}

