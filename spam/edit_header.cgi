#!/usr/local/bin/perl
# edit_header.cgi
# Display extra header and body test

require './spam-lib.pl';
&can_use_check("header");
&ui_print_header(undef, $text{'header_title'}, "");
$conf = &get_config();

print "$text{'header_desc'}<p>\n";
&start_form("save_header.cgi", $text{'header_header'}."\n".
		       "(<a href=edit_simple.cgi>$text{'header_switch'}</a>)");

if (!$module_info{'usermin'}) {
	print "<tr> <td><b>$text{'header_allow'}</b></td> <td nowrap colspan=3>";
	$allow = &find("allow_user_rules", $conf);
	&yes_no_field("allow_user_rules", $allow, 0);
	print "</td> </tr>\n";
	}

@header = &find("header", $conf);
print "<tr> <td valign=top><b>$text{'header_test'}</b></td> <td colspan=3>\n";
&edit_table("header",
	    [ $text{'header_tname'}, $text{'header_name'}, $text{'header_op'},
	      $text{'header_pat'}, $text{'header_default'} ],
	    [ map { [ &split_header($_->{'value'}) ] } @header ], [ ], \&header_conv, 2);
print "</td> </tr>\n";

print "<tr> <td colspan=4><hr></td> </tr>\n";

push(@body, map { [ &split_body($_->{'value'}), 0 ] } &find("body", $conf));
push(@body, map { [ &split_body($_->{'value'}), 1 ] } &find("rawbody", $conf));
push(@body, map { [ &split_body($_->{'value'}), 2 ] } &find("fullbody", $conf));
push(@body, map { [ &split_body($_->{'value'}), 3 ] } &find("full", $conf));
print "<tr> <td valign=top><b>$text{'header_body'}</b></td> <td colspan=3>\n";
&edit_table("body",
	    [ $text{'header_tname'}, $text{'header_mode'}, $text{'header_op'},
	      $text{'header_pat'} ], \@body, [ ], \&body_conv, 2);

print "<tr> <td colspan=4><hr></td> </tr>\n";

@uri = &find("uri", $conf);
print "<tr> <td valign=top><b>$text{'header_uri'}</b></td> <td colspan=3>\n";
&edit_table("uri",
	    [ $text{'header_tname'}, $text{'header_pat'} ],
	    [ map { $_->{'words'} } @uri ], [ 20, 40 ], undef, 2);
print "</td> </tr>\n";

print "<tr> <td colspan=4><hr></td> </tr>\n";

@meta = &find("meta", $conf);
print "<tr> <td valign=top><b>$text{'header_meta'}</b></td> <td colspan=3>\n";
&edit_table("meta",
	    [ $text{'header_tname'}, $text{'header_bool'} ],
	    [ map { $_->{'value'} =~ /^(\S+)\s*(.*)$/ ? [ $1, $2 ] : [ ] } @meta ],
	    [ 20, 40 ], undef, 2);

print "<tr> <td colspan=4><hr></td> </tr>\n";

@score = &find("score", $conf);
print "<tr> <td valign=top><b>$text{'score_score'}</b></td> <td colspan=3>\n";
&edit_table("score",
	    [ $text{'score_name'}, $text{'score_points'} ],
	    [ map { $_->{'words'} } @score ], [ 30, 6 ]);
print "</td> </tr>\n";

@describe = &find("describe", $conf);
print "<tr> <td valign=top><b>$text{'score_describe'}</b></td> <td colspan=3>\n";
&edit_table("describe",
	    [ $text{'score_name'}, $text{'score_descr'} ],
	    [ map { $_->{'value'} =~ /^(\S+)\s*(.*)/ ? [ $1, $2 ] : [ ] }
	      @describe ], [ 30, 40 ]);
print "</td> </tr>\n";

&end_form(undef, $text{'save'});
&ui_print_footer("", $text{'index_return'});

# header_conv(col, name, size, value, &values)
sub header_conv
{
if ($_[0] == 0) {
	return sprintf "<input name=$_[1] size=20 value='%s'>",
		&html_escape($_[3]);
	}
elsif ($_[0] == 1) {
	local $h = $_[3] =~ /^exists:(\S+)$/ ? $1 : $_[3] =~ /^eval:/ ? "" : $_[3];
	return sprintf "<input name=$_[1] size=15 value='%s'>",
		&html_escape($h);
	}
elsif ($_[0] == 2) {
	local $rv = "<select name=$_[1]>\n";
	$rv .= sprintf "<option value='=~' %s>%s\n",
		$_[3] eq '=~' ? "selected" : "", $text{'header_op0'};
	$rv .= sprintf "<option value='!~' %s>%s\n",
		$_[3] eq '!~' ? "selected" : "", $text{'header_op1'};
	$rv .= sprintf "<option value='exists' %s>%s\n",
		$_[4]->[1] =~ /^exists:/ ? "selected" : "", $text{'header_op2'};
	$rv .= sprintf "<option value='eval' %s>%s\n",
		$_[4]->[1] =~ /^eval:/ ? "selected" : "", $text{'header_op3'};
	$rv .= "</select>\n";
	return $rv;
	}
elsif ($_[0] == 3) {
	return sprintf "<input name=$_[1] size=20 value='%s'>",
		&html_escape($_[4]->[1] =~ /^eval:(.*)/ ? $1 : $_[3]);
	}
elsif ($_[0] == 4) {
	return sprintf "<input name=$_[1] size=15 value='%s'>",
		&html_escape($_[3]);
	}
}

# body_conv(col, name, size, value, &values)
sub body_conv
{
if ($_[0] == 0) {
	return sprintf "<input name=$_[1] size=20 value='%s'>",
		&html_escape($_[4]->[0]);
	}
elsif ($_[0] == 1) {
	local $rv = "<select name=$_[1]>\n";
	local $m;
	foreach $m (0 .. 3) {
		$rv .= sprintf "<option value=%d %s>%s\n",
		   $m, $m == $_[4]->[2] ? "selected" : "", $text{'header_mode'.$m};
		}
	$rv .= "</select>\n";
	return $rv;
	}
elsif ($_[0] == 2) {
	local $rv = "<select name=$_[1]>\n";
	$rv .= sprintf "<option value=0 %s>%s\n",
		$_[4]->[1] =~ /^eval:/ ? "" : "selected", $text{'header_op0'};
	$rv .= sprintf "<option value=1 %s>%s\n",
		$_[4]->[1] =~ /^eval:/ ? "selected" : "", $text{'header_op3'};
	$rv .= "</select>\n";
	return $rv;
	}
elsif ($_[0] == 3) {
	return sprintf "<input name=$_[1] size=40 value='%s'>",
		&html_escape($_[4]->[1] =~ /^eval:(.*)$/ ? $1 : $_[4]->[1]);
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

