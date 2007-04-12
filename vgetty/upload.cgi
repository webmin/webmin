#!/usr/local/bin/perl
# upload.cgi
# Convert a WAV file to rmd format

require './vgetty-lib.pl';
&ReadParseMime();
&error_setup($text{'upload_err'});
$in{'wav'} || &error($text{'upload_emessage'});

$temp1 = &transname();
open(TEMP, ">$temp1");
print TEMP $in{'wav'};
close(TEMP);
if (&rmd_file_info($temp1)) {
	# Already in RMD format .. just use
	$rmdfile = $temp1;
	}
else {
	# Convert to PVF format
	$temp2 = &transname();
	$out = &backquote_logged("wavtopvf $temp1 $temp2 2>&1");
	$ec = $?;
	unlink($temp1);
	if ($ec) {
		unlink($temp2);
		&error(&text('upload_ewav', "<pre>$out</pre>"));
		}

	# Convert to RMD format
	@formats = &list_rmd_formats();
	$format = $formats[$in{'format'}];
	$rmdfile = &transname();
	$out = &backquote_logged("pvftormd $format->{'code'} $format->{'bits'} $temp2 $rmdfile 2>&1");
	$ec = $?;
	unlink($temp2);
	if ($ec) {
		unlink($rmdfile);
		&error(&text('upload_epvf', "<pre>$out</pre>"));
		}
	}

# Add to the index
@conf = &get_config();
$dir = &messages_dir(\@conf);
$in{'wav_filename'} =~ s/^.*[\/\\]//;
$in{'wav_filename'} =~ s/\.wav$//i;
if (-r "$dir/$in{'wav_filename'}.rmd") {
	&error(&text('upload_esame', "$in{'wav_filename'}.rmd"));
	}
$index = &messages_index(\@conf);
open(INDEX, $index);
@index = map { chomp; $_ } <INDEX>;
close(INDEX);
if (!@index) {
	$bak = &find_value("backup_message", \@conf);
	push(@index, $bak) if (-r "$dir/$bak");
	}
push(@index, "$in{'wav_filename'}.rmd");
system("mv $rmdfile $dir/$in{'wav_filename'}.rmd");
&open_lock_tempfile(INDEX, ">$index");
&print_tempfile(INDEX, map { "$_\n" } @index);
&close_tempfile(INDEX);
&webmin_log("upload", undef, undef,
	    { 'file' => "$in{'wav_filename'}.rmd" });

# Save the format type
$config{'format'} = $in{'format'};
&write_file("$module_config_directory/config", \%config);
&redirect("list_messages.cgi");

