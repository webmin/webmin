#!/usr/local/bin/perl
# Save advanced options

require './webmin-lib.pl';
&ReadParse();
&error_setup($text{'advanced_err'});
&get_miniserv_config(\%miniserv);

# Save global temp dir setting
if ($in{'tempdir_def'}) {
	delete($gconfig{'tempdir'});
	}
else {
	-d $in{'tempdir'} || &error($text{'advanced_etemp'});
	&allowed_temp_dir($in{'tempdir'}) ||
		&error(&text('advanced_etempallowed', $in{'tempdir'}));
	$gconfig{'tempdir'} = $in{'tempdir'};
	}

# Save temp clearing options
$gconfig{'tempdirdelete'} = $in{'tempdirdelete'};
if ($in{'tempdelete_def'}) {
	$gconfig{'tempdelete_days'} = '';
	}
else {
	$in{'tempdelete'} =~ /^[0-9\.]+$/ ||
		&error($text{'advanced_etempdelete'});
	$gconfig{'tempdelete_days'} = $in{'tempdelete'};
	}

# Save per-module temp dirs
for($i=0; defined($tmod = $in{'tmod_'.$i}); $i++) {
	next if (!$tmod);
	$tdir = $in{'tdir_'.$i};
	%minfo = &get_module_info($tmod);
	-d $tdir || &error(&text('advanced_etdir', $minfo{'desc'}));
	&allowed_temp_dir($tdir) ||
		&error(&text('advanced_etempallowed', $in{'tempdir'}));
	push(@tdirs, [ $tmod, $tdir ]);
	}
&save_tempdirs(\%gconfig, \@tdirs);

# Save umask
if ($in{'umask_def'}) {
	delete($gconfig{'umask'});
	}
else {
	$in{'umask'} =~ /^[0-7]{3}$/ || &error($text{'advanced_eumask'});
	$gconfig{'umask'} = $in{'umask'};
	}

# Save chattr
if (defined($in{'chattr'})) {
	$gconfig{'chattr'} = $in{'chattr'};
	}

# Save nice level
if ($in{'nice_def'}) {
	delete($gconfig{'nice'});
	}
else {
	$gconfig{'nice'} = $in{'nice'};
	}

# Save scheduling class
if (defined($in{'sclass'})) {
	$gconfig{'sclass'} = $in{'sclass'};
	$gconfig{'sprio'} = $in{'sprio'};
	}

# Save HTTP headers
@hl = ( );
foreach my $l (split(/\r?\n/, $in{'headers'})) {
	$l =~ /^\S+:\s+\S.*$/ || &error($text{'advanced_eheader'});
	push(@hl, $l);
	}
$gconfig{'extra_headers'} = join("\t", @hl);

# Sort config file's keys alphabetically
if (defined($in{'sortconfigs'})) {
	$gconfig{'sortconfigs'} = $in{'sortconfigs'};
	}

&lock_file("$config_directory/config");
&write_file("$config_directory/config", \%gconfig);
&unlock_file("$config_directory/config");

if (defined($in{'preload'})) {
	# Save preload option, forcing new mode
	if ($in{'preload'}) {
		$miniserv{'premodules'} = 'WebminCore';
		}
	else {
		delete($miniserv{'premodules'});
		}
	&save_preloads(\%miniserv, [ ]);
	}

# Save pre-cache option
if ($in{'precache_mode'} == 0) {
	$miniserv{'precache'} = 'none';
	}
elsif ($in{'precache_mode'} == 1) {
	$miniserv{'precache'} = '';
	}
else {
	$in{'precache'} =~ /\S/ || &error($text{'advanced_eprecache'});
	$miniserv{'precache'} = $in{'precache'};
	}

# Save buffer size
if ($in{'bufsize_def'}) {
	delete($miniserv{'bufsize'});
	}
else {
	$in{'bufsize'} =~ /^\d+$/ && $in{'bufsize'} > 0 ||
		&error($text{'advanced_ebufsize'});
	$miniserv{'bufsize'} = $in{'bufsize'};
	}

# Save buffer size
if ($in{'bufsize_binary_def'}) {
	delete($miniserv{'bufsize_binary'});
	}
else {
	$in{'bufsize_binary'} =~ /^\d+$/ && $in{'bufsize_binary'} > 0 ||
		&error($text{'advanced_ebufsize_binary'});
	$miniserv{'bufsize_binary'} = $in{'bufsize_binary'};
	}

&lock_file($ENV{'MINISERV_CONFIG'});
&put_miniserv_config(\%miniserv);
&unlock_file($ENV{'MINISERV_CONFIG'});

&show_restart_page();
&webmin_log("advanced");


sub allowed_temp_dir
{
my ($t) = @_;
return $t eq "/" || $t =~ /^\/[^\/]+\/?$/ ? 0 : 1;
}
