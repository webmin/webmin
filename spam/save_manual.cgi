#!/usr/bin/perl
# Show a config file for manual editing

require './spam-lib.pl';
&ReadParseMime();
&set_config_file_in(\%in);
&can_use_check("manual");
&execute_before("manual");
&error_setup($text{'manual_err'});

# Validate the filename
$conf = &get_config();
@files = &unique(map { $_->{'file'} } @$conf);
push(@files, $config{'amavisdconf'}) if (!$warn_procmail && -r $config{'amavisdconf'});
$in{'manual'} ||= $files[0];
&indexof($in{'manual'}, @files) >= 0 ||
	&error($text{'manual_efile'});

# Write the file
$in{'data'} =~ s/\r//g;
&open_lock_tempfile(MANUAL, ">$in{'manual'}");
&print_tempfile(MANUAL, $in{'data'});
&close_tempfile(MANUAL);

&execute_after("manual");
&webmin_log("manual");
&redirect($redirect_url);
