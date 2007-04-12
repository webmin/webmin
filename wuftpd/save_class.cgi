#!/usr/local/bin/perl
# save_class.cgi
# Save user classes

require './wuftpd-lib.pl';
&error_setup($text{'class_err'});
&ReadParse();

&lock_file($config{'ftpaccess'});
$conf = &get_ftpaccess();

# save class options
for($i=0; defined($class = $in{"class_$i"}); $i++) {
	next if (!$class);
	$class =~ /^\S+$/ || &error(&text('class_eclass', $class));
	@types = split(/\0/, $in{"types_$i"});
	@types || &error(&text('class_etypes', $class));
	@addrs = split(/\s+/, $in{"addrs_$i"});
	@addrs || &error(&text('class_eaddrs', $class));
	push(@class, { 'name' => 'class',
		       'star' => $addrs[0] eq '*',
		       'values' => [ $class, join(",", @types), @addrs ] });
	}
@class = sort { $a->{'star'} ? 1 : $b->{'star'} ? -1 : 0 } @class;
&save_directive($conf, 'class', \@class);

# save guest/real user/group options
foreach $g ('guestuser', 'guestgroup', 'realuser', 'realgroup') {
	if ($in{$g}) {
		&save_directive($conf, $g, [ { 'name' => $g,
					       'values' => [ $in{$g} ] } ] );
		}
	else {
		&save_directive($conf, $g, [ ]);
		}
	}

# save allow/deny uid/gid options
&lock_file($config{'ftpusers'});
if ($in{'ftpusers'}) {
	&open_tempfile(FTPUSERS, ">$config{'ftpusers'}");
	foreach $u (split(/\s+/, $in{'ftpusers'})) {
		&print_tempfile(FTPUSERS, $u,"\n");
		}
	&close_tempfile(FTPUSERS);
	}
else {
	unlink($config{'ftpusers'});
	}
&unlock_file($config{'ftpusers'});
foreach $g ('deny-uid', 'deny-gid', 'allow-uid', 'allow-gid') {
	($fg = $g) =~ s/-/_/g;
	if ($in{$fg}) {
		&save_directive($conf, $g, [ { 'name' => $g,
					       'values' => [ $in{$fg} ] } ] );
		}
	else {
		&save_directive($conf, $g, [ ]);
		}
	}

&flush_file_lines();
&unlock_file($config{'ftpaccess'});
&webmin_log("class", undef, undef, \%in);
&redirect("");

