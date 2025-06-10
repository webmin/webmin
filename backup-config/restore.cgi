#!/usr/local/bin/perl
# Do an immediate restore

use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
require './backup-config-lib.pl';
our (%in, %text, %config, $module_config_file);
&ReadParseMime();

# Validate inputs
&error_setup($text{'restore_err'});
my $src = &parse_backup_destination("src", \%in);
my @mods = split(/\0/, $in{'mods'});
my @others = split(/[\r\n]+/, $in{'others'});
@mods || @others || &error($text{'restore_emods'});

# Do it ..
my ($mode, $user, $pass, $server, $path, $port) = &parse_backup_url($src);
if ($mode == 3) {
	# Create temp file for uploaded file
	my $temp = &transname();
	open(TEMP, ">$temp");
	print TEMP $in{$path};
	close(TEMP);
	$src = $temp;
	}
&ui_print_header(undef, $text{'restore_title'}, "");
print &text($in{'test'} ? 'restore_testing' : 'restore_doing',
	    &nice_dest($src)),"<p>\n";
my @files;
my $err = &execute_restore(\@mods, $src, \@files, $in{'apply'}, $in{'test'},
			   \@others);
&unlink_file($src) if ($mode == 3);
if ($err) {
	print &text('restore_failed', $err),"<p>\n";
	}
elsif ($in{'test'}) {
	print $text{'restore_done2'},"<p>\n";
	print &ui_table_start(undef, "width=100%", 2);
	print &ui_table_row(undef,
	    "<pre>".join("\n", map { &html_escape($_) } @files)."</pre>", 2);
	print &ui_table_end();
	}
else {
	print &text('restore_done', scalar(@files)),"<p>\n";
	}
$config{'apply'} = $in{'apply'};
&lock_file($module_config_file);
&save_module_config();
&unlock_file($module_config_file);
&webmin_log("restore", undef, $src, { 'mods' => \@mods });
&ui_print_footer("", $text{'index_return2'});

