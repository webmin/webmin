#!/usr/local/bin/perl
# save_header.cgi
# Save custom header and body tests

require './spam-lib.pl';
&ReadParse();
&set_config_file_in(\%in);
&can_use_check("header");
&error_setup($text{'header_err'});
&execute_before("header");
&lock_spam_files();
$conf = &get_config();

if (!$module_info{'usermin'}) {
	&parse_yes_no($conf, "allow_user_rules");
	}

@header = &parse_table("header", \&header_parser);
&save_directives($conf, "header", \@header, 1);

@mimeheader = &parse_table("mimeheader", \&header_parser);
&save_directives($conf, "mimeheader", \@mimeheader, 1);

@oldbody = ( &find("body", $conf),
	     &find("rawbody", $conf),
	     &find("fullbody", $conf),
	     &find("full", $conf) );
@body = &parse_table("body", \&body_parser);
&save_directives($conf, \@oldbody, \@body, 0);

@uri = &parse_table("uri", \&uri_parser);
&save_directives($conf, "uri", \@uri, 1);

@meta = &parse_table("meta", \&meta_parser);
&save_directives($conf, "meta", \@meta, 1);

@score = &parse_table("score", \&score_parser);
&save_directives($conf, 'score', \@score, 1);

@describe = &parse_table("describe", \&describe_parser);
&save_directives($conf, 'describe', \@describe, 1);

&flush_file_lines();
&unlock_spam_files();
&execute_after("header");
&webmin_log("header");
&redirect($redirect_url);

# header_parser(rowname, value, ...)
sub header_parser
{
return undef if ($_[1] eq '');
$_[1] =~ /^\S+$/ || &error(&text('header_ename', $_[1]));
if ($_[3] eq 'eval') {
	$_[4] =~ /^\S+\(.*\)$/ || &error(&text('header_eeval', $_[4]));
	return "$_[1] eval:$_[4]";
	}
elsif ($_[3] eq 'exists') {
	$_[2] =~ /^\S+$/ || &error(&text('header_eheader', $_[2]));
	return "$_[1] exists:$_[2]";
	}
else {
	$_[2] =~ /^\S+$/ || &error(&text('header_eheader', $_[2]));
	$_[4] =~ /^\/(.*)\/\S*$/ || &error(&text('header_eregexp', $_[4]));
	return "$_[1] $_[2] $_[3] $_[4]".($_[5] ? " if-unset: $_[5]" : "");
	}
}

# body_parser(rowname, value, ...)
sub body_parser
{
return undef if ($_[1] eq '');
$_[1] =~ /^\S+$/ || &error(&text('header_ename', $_[1]));
local $v;
if ($_[3] == 0) {
	$_[4] =~ /^\/(.*)\/\S*$/ || &error(&text('header_eregexp', $_[4]));
	$v = "$_[1] $_[4]";
	}
else {
	$_[4] =~ /^\S+\(.*\)$/ || &error(&text('header_eeval', $_[4]));
	$v = "$_[1] eval:$_[4]";
	}
return { 'name' => $_[2] == 0 ? 'body' :
		   $_[2] == 1 ? 'rawbody' :
		   $_[2] == 2 ? 'fullbody' : 'full',
	 'value' => $v };
}

sub uri_parser
{
return undef if ($_[1] eq '');
$_[1] =~ /^\S+$/ || &error(&text('header_ename', $_[1]));
$_[2] =~ /^\/(.*)\/\S*$/ || &error(&text('header_eregexp', $_[2]));
return "$_[1] $_[2]";
}

sub meta_parser
{
return undef if ($_[1] eq '');
$_[1] =~ /^\S+$/ || &error(&text('header_ename', $_[1]));
$_[2] =~ /\S/ || &error(&text('header_emeta', $_[1]));
return "$_[1] $_[2]";
}

sub score_parser
{
return undef if (!$_[1]);
$_[1] =~ /^\S+$/ || &error(&text('score_ename', $_[1]));
$_[2] =~ /^\-?\d+(\.\d+)?$/ || $_[2] =~ /^\-?\.\d+$/ ||
	&error(&text('score_epoints', $_[2]));
return "$_[1] $_[2]";
}

sub describe_parser
{
return undef if (!$_[1]);
$_[1] =~ /^\S+$/ || &error(&text('score_ename', $_[1]));
$_[2] =~ /\S/ || &error(&text('score_edesc', $_[1]));
return "$_[1] $_[2]";
}


