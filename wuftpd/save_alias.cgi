#!/usr/local/bin/perl
# save_alias.cgi
# Save alias options

require './wuftpd-lib.pl';
&error_setup($text{'alias_err'});
&ReadParse();
&lock_file($config{'ftpaccess'});
$conf = &get_ftpaccess();

# save alias directives
for($i=0; defined($from = $in{"from_$i"}); $i++) {
	$to = $in{"to_$i"};
	next if (!$from);
	$from =~ /^\S+$/ || &error(&text('alias_efrom', $from));
	-d $to || &error(&text('alias_eto', $to));
	push(@alias, { 'name' => 'alias',
		       'values' => [ $from, $to ] } );
	}
&save_directive($conf, 'alias', \@alias);

# save cdpath directives
foreach $c (split(/\s+/, $in{'cdpath'})) {
	-d $c || &error(&text('alias_ecdpath', $c));
	push(@cdpath, { 'name' => 'cdpath',
			'values' => [ $c ] } );
	}
&save_directive($conf, 'cdpath', \@cdpath);

&flush_file_lines();
&unlock_file($config{'ftpaccess'});
&webmin_log("alias", undef, undef, \%in);
&redirect("");
