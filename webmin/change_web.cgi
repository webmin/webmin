#!/usr/local/bin/perl
# Save webserver options

require './webmin-lib.pl';
&ReadParse();
&error_setup($text{'web_err'});
&get_miniserv_config(\%miniserv);

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
$gconfig{'error_stack'} = $in{'stack'};

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
$gconfig{'relative_redir'} = $in{'redir'};

# Save global config
&lock_file("$config_directory/config");
&write_file("$config_directory/config", \%gconfig);
&unlock_file("$config_directory/config");

# Save miniserv config
&lock_file($ENV{'MINISERV_CONFIG'});
&put_miniserv_config(\%miniserv);
&unlock_file($ENV{'MINISERV_CONFIG'});

&show_restart_page();
&webmin_log("web");

