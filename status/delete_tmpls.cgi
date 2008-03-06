#!/usr/local/bin/perl
# Delete several templates

require './status-lib.pl';
$access{'edit'} || &error($text{'tmpls_ecannot'});

# Validate inputs
&error_setup($text{'dtmpls_err'});
&ReadParse();
@d = split(/\0/, $in{'d'});
@d || &error($text{'dtmpls_enone'});

# Check for users
@servs = &list_services();
foreach $d (@d) {
	@users = grep { $_->{'tmpl'} eq $d } @servs;
	if (@users) {
		$tmpl = &get_template($d);
		&error(&text('dtmpls_eusers', "<i>$tmpl->{'desc'}</i>",
			join(", ", map { "<i>$_->{'desc'}</i>" } @users)));
		}
	}

# Waste them
foreach $d (@d) {
	$tmpl = &get_template($d);
	if ($tmpl) {
		&delete_template($tmpl);
		}
	}

&webmin_log("deletes", "tmpl", scalar(@d));
&redirect("list_tmpls.cgi");

