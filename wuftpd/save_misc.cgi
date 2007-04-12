#!/usr/local/bin/perl
# save_log.cgi
# Save miscellaneous options

require './wuftpd-lib.pl';
&error_setup($text{'misc_err'});
&ReadParse();
&lock_file($config{'ftpaccess'});
$conf = &get_ftpaccess();

# Save ls* commands
foreach $l ('lslong', 'lsshort', 'lsplain') {
	if ($in{$l."_def"}) {
		&save_directive($conf, $l, [ ]);
		}
	elsif ($in{$l} !~ /\S/) {
		&error($text{"misc_e$l"});
		}
	else {
		&save_directive($conf, $l, [ { 'name' => $l,
					       'values' => [ $in{$l} ] } ] );
		}
	}

# Save shutdown command
if ($in{'shutdown_def'}) {
	&save_directive($conf, 'shutdown', [ ]);
	}
elsif ($in{'shutdown'} !~ /\S/) {
	&error($text{'misc_eshutdown'});
	}
else {
	&save_directive($conf, 'shutdown',
			[ { 'name' => 'shutdown',
			    'values' => [ $in{'shutdown'} ] } ] );
	}

# Save nice options
for($i=0; defined($ndelta = $in{"ndelta_$i"}); $i++) {
	next if ($ndelta eq '');
	$ndelta =~ /^[\-0-9]+$/ || &error(&text('misc_edelta', $ndelta));
	push(@nice, { 'name' => 'nice',
		      'values' => [ $ndelta, $in{"nclass_$i"} ] } );
	}
&save_directive($conf, 'nice', \@nice);

# Save defumask options
for($i=0; defined($umask = $in{"umask_$i"}); $i++) {
	next if ($umask eq '');
	$umask =~ /^[0-9]+$/ || &error(&text('misc_eumask', $umask));
	push(@umask, { 'name' => 'defumask',
		       'values' => [ $umask, $in{"uclass_$i"} ] } );
	}
&save_directive($conf, 'defumask', \@umask);

&flush_file_lines();
&unlock_file($config{'ftpaccess'});
&webmin_log("misc", undef, undef, \%in);
&redirect("");
