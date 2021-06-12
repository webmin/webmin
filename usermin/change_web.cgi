#!/usr/local/bin/perl
# Save webserver options

require './usermin-lib.pl';
&ReadParse();
&error_setup($text{'web_err'});
&get_usermin_miniserv_config(\%miniserv);
&get_usermin_config(\%uconfig);

# Save expires
if ($in{'expires_def'}) {
	delete($miniserv{'expires'});
	}
else {
	$in{'expires'} =~ /^\d+$/ ||
		&error($text{'web_eexpires'});
	$miniserv{'expires'} = $in{'expires'};
	}

# Save per-path expires
for(my $i=0; defined($p = $in{"expirespath_$i"}); $i++) {
	$t = $in{"expirestime_$i"};
	next if ($p !~ /\S/);
	$t =~ /^\d+$/ || &error(&text('web_eexpires2', $i+1));
	push(@expires_paths, [ $p, $t ]);
	}
$miniserv{'expires_paths'} = join("\t", map { $_->[0]."=".$_->[1] }
					    @expires_paths);

# Save stack trace option
$uconfig{'error_stack'} = $in{'stack'};

# Save showing of stderr
$miniserv{'noshowstderr'} = !$in{'showstderr'};

if (!$miniserv{'session'}) {
	# Save password pass option
	$miniserv{'pass_password'} = $in{'pass'};
	}

# Save gzip option
if ($in{'gzip'} == 1) {
	eval "use Compress::Zlib";
	$@ && &error(&text('advanced_egzip', '<tt>Compress::Zlib</tt>'));
	}
$miniserv{'gzip'} = $in{'gzip'};

# Save redirect type
$uconfig{'relative_redir'} = $in{'redir'};

# Save directory list option
$miniserv{'nolistdir'} = !$in{'listdir'};

# Save global config
&lock_file($usermin_config);
&write_file($usermin_config, \%uconfig);
&unlock_file($usermin_config);

# Save miniserv config
&lock_file($usermin_miniserv_config);
&put_usermin_miniserv_config(\%miniserv);
&unlock_file($usermin_miniserv_config);
&restart_usermin_miniserv();

&webmin_log("web");
&redirect("");

