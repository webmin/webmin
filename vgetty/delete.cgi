#!/usr/local/bin/perl
# delete.cgi
# Delete a bunch of voicemail messages

require './vgetty-lib.pl';
&ReadParse();
@conf = &get_config();
$mdir = &messages_dir(\@conf);
@del = split(/\0/, $in{'del'});
$index = &messages_index(\@conf);
&lock_file($index);
open(INDEX, $index);
@index = map { chomp; $_ } <INDEX>;
close(INDEX);
if (!@index) {
	$bak = &find_value("backup_message", \@conf);
	push(@index, $bak) if (-r "$mdir/$bak");
	}
if ($in{'move'}) {
	$rdir = &receive_dir(\@conf);
	foreach $f (@del) {
		$f =~ /\.\./ && &error($text{'delete_efile'});
		rename("$rdir/$f", "$mdir/$f");
		}
	push(@index, @del);
	&open_tempfile(INDEX, ">$index");
	&print_tempfile(INDEX, map { "$_\n" } @index);
	&close_tempfile(INDEX);
	&unlock_file($index);
	&webmin_log("move", undef, undef, { 'del' => \@del });
	&redirect("list_received.cgi");
	}
else {
	$dir = $in{'mode'} ? &messages_dir(\@conf) : &receive_dir(\@conf);
	foreach $f (@del) {
		$f =~ /\.\./ && &error($text{'delete_efile'});
		unlink("$dir/$f");
		}
	if ($in{'mode'}) {
		@index = grep { &indexof($_, @del) < 0 } @index;
		&open_tempfile(INDEX, ">$index");
		&print_tempfile(INDEX, map { "$_\n" } @index);
		&close_tempfile(INDEX);
		}
	&unlock_file($index);
	&webmin_log("delete", $in{'mode'}, undef, { 'del' => \@del });
	&redirect($in{'mode'} ? "list_messages.cgi" : "list_received.cgi");
	}

