#!/usr/local/bin/perl
# save_logging.cgi
# Save global logging options
use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
our (%access, %text, %in, %config);

require './bind8-lib.pl';
$access{'defaults'} || &error($text{'logging_ecannot'});
&error_setup($text{'files_err'});
&ReadParse();

&lock_file(&make_chroot($config{'named_conf'}));
my $conf = &get_config();
my $logging = &find("logging", $conf);
my (@category, @channel);

if ($in{'mode'} eq 'cats') {
	# Save categories
	my $cat;
	for(my $i=0; defined($cat = $in{"cat_$i"}); $i++) {
		next if (!$cat);
		my @cchan = split(/\0/, $in{"cchan_$i"});
		push(@category, { 'name' => 'category',
				  'values' => [ $cat ],
				  'type' => 1,
				  'members' =>
					[ map { { 'name' => $_ } } @cchan ] });
		}
	@channel = &find("channel", $logging->{'members'}) if ($logging);
	}
else {
	# Save channels
	my $cname;
	for(my $i=0; defined($cname = $in{"cname_$i"}); $i++) {
		next if (!$cname);
		$cname =~ /^\S+$/ || &error(&text('logging_ename', $cname));
		my @mems;
		if ($in{"to_$i"} == 0) {
			$in{"file_$i"} || &error($text{'logging_efile'});
			$in{"file_$i"} =~ /^\// ||
				&error($text{'logging_efile2'});
			my @fvals = ( $in{"file_$i"} );
			if ($in{"vmode_$i"} == 1) {
				push(@fvals, 'versions', 'unlimited');
				}
			elsif ($in{"vmode_$i"} == 2) {
				$in{"ver_$i"} =~ /^\d+$/ ||
					&error(&text('logging_ever', $in{"ver_$i"}));
				push(@fvals, 'versions', $in{"ver_$i"});
				}
			if ($in{"smode_$i"}) {
				$in{"size_$i"} =~ /^\d+[kmg]*$/i ||
					&error(&text('logging_esize', $in{"size_$i"}));
				push(@fvals, 'size', $in{"size_$i"});
				}
			push(@mems, { 'name' => 'file',
				      'values' => \@fvals });
			}
		elsif ($in{"to_$i"} == 1) {
			push(@mems, { 'name' => 'syslog',
				      'values' => [ $in{"syslog_$i"} ] });
			}
		else {
			push(@mems, { 'name' => 'null' });
			}
		if ($in{"sev_$i"} eq 'debug') {
			push(@mems, { 'name' => 'severity',
				      'values' => [ 'debug', $in{"debug_$i"} ] });
			}
		elsif ($in{"sev_$i"}) {
			push(@mems, { 'name' => 'severity',
				      'values' => [ $in{"sev_$i"} ] });
			}
		foreach my $p ('print-category', 'print-severity', 'print-time') {
			push(@mems, { 'name' => $p,
				      'values' => [ $in{"$p-$i"} ] }) if ($in{"$p-$i"});
			}
		push(@channel, { 'name' => 'channel',
				 'values' => [ $cname ],
				 'type' => 1,
				 'members' => \@mems } );
		}
	@category = &find("category", $logging->{'members'}) if ($logging);
	}

# Write out the logging section, creating if needed
if ($logging) {
	&save_directive($logging, 'channel', \@channel, 1);
	&save_directive($logging, 'category', [ ], 1);
	&save_directive($logging, 'category', [ reverse(@category) ], 1);
	}
else {
	$logging = { 'name' => 'logging',
		     'type' => 1,
		     'members' => [ @channel, @category ] };
	&save_directive(&get_config_parent(), 'logging', [ $logging ], 0);
	}
&flush_file_lines();
&unlock_file(&make_chroot($config{'named_conf'}));
&webmin_log("logging", undef, undef, \%in);
&redirect("");

