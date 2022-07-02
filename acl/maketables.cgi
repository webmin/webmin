#!/usr/local/bin/perl
# Create all needed tables

use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
require './acl-lib.pl';
our (%in, %text, %config, %access);
$access{'pass'} || &error($text{'sql_ecannot'});
&ReadParse();
&error_setup($text{'make_err'});

my %miniserv; 
&get_miniserv_config(\%miniserv);
my $dbh = &connect_userdb($in{'userdb'});
ref($dbh) || &error($dbh);

&ui_print_unbuffered_header(undef, $text{'make_title'}, "");

# Create the tables
foreach my $sql (&userdb_table_sql($in{'userdb'})) {
	print &text('make_exec', "<tt>".&html_escape($sql)."</tt>"),"<br>\n";
	my $cmd = $dbh->prepare($sql);
	if (!$cmd || !$cmd->execute()) {
		print &text('make_failed', &html_escape($dbh->errstr)),"<p>\n";
		}
	else {
		$cmd->finish();
		print $text{'make_done'},"<p>\n";
		}
	}
&disconnect_userdb($in{'userdb'}, $dbh);

# Check again if OK
my $err = &validate_userdb($in{'userdb'}, 0);
if ($err) {
	print "<b>",&text('make_still', $err),"</b><p>\n";
	}
else {
	&lock_file($ENV{'MINISERV_CONFIG'});
	$miniserv{'userdb'} = $in{'userdb'};
	$miniserv{'userdb_addto'} = $in{'addto'};
	&put_miniserv_config(\%miniserv);
	&unlock_file($ENV{'MINISERV_CONFIG'});
	&reload_miniserv();
	}

&ui_print_footer("", $text{'index_return'});

