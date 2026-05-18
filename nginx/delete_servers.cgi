#!/usr/local/bin/perl
# Delete selected server blocks

use strict;
use warnings;
require './nginx-lib.pl';
our (%text, %in, %config, %access);
&ReadParse();
my @items = split(/\0/, $in{'d'} || "");
my $file_action = $in{'toggle'} ? "toggle" :
		  $in{'enable'} ? "enable" :
		  $in{'disable'} ? "disable" : undef;
&error_setup($file_action ? $text{'enable_err'} : $text{'delete_err'});
$access{'edit'} || &error($text{'server_ecannotedit'});

if ($file_action) {
	&can_manage_server_files() || &error($text{'enable_elinkdir'});
	my %add_to = map { $_, 1 } &get_add_to_files();
	my %files;
	foreach my $item (@items) {
		my $file;
		if ($item =~ /^file\t([^\t]+)/) {
			$file = $1;
			}
		else {
			my $server = &find_server($item);
			next if (!$server || !&can_edit_server($server));
			$file = $server->{'file'};
			}
		my $rfile = $file ? &resolve_links($file) : undef;
		$files{$rfile}++ if ($rfile && -f $rfile && $add_to{$rfile} &&
				      &can_manage_server_file($rfile));
		}
	my @files = keys %files;
	@files || &error($text{'enable_enone'});
	foreach my $file (@files) {
		my $err = $file_action eq "toggle" ?
			&server_file_enabled($file) ?
				&disable_server_file($file) :
				&enable_server_file($file) :
			$file_action eq "enable" ?
				&enable_server_file($file) :
				&disable_server_file($file);
		$err && &error($err);
		}
	&webmin_log($file_action, "serverfile", scalar(@files));
	&redirect("");
	exit;
	}
if (!$in{'delete'}) {
	&error($text{'delete_eaction'});
	}

my (@ids, %file_lines);
foreach my $item (@items) {
	if ($item =~ /^file\t([^\t]+)\t(\d+)$/) {
		push(@{$file_lines{$1}}, $2);
		}
	elsif ($item !~ /^file\t/) {
		push(@ids, $item);
		}
	}
@ids || %file_lines || &error($text{'delete_enone'});

# Validate the selected server blocks before locking config files.
foreach my $id (@ids) {
	my $server = &find_server($id);
	$server || &error($text{'server_egone'});
	&can_edit_server($server) || &error($text{'server_ecannot'});
	&is_default_server_block($server) && &error($text{'delete_edefault'});
	}
my %add_to = map { $_, 1 } &get_add_to_files();
my %file_servers;
foreach my $file (keys %file_lines) {
	my $rfile = &resolve_links($file);
	next if (!$rfile || !-f $rfile || !$add_to{$rfile} ||
		 !&can_manage_server_file($rfile));
	my @servers = &find_servers_in_file($rfile);
	foreach my $line (@{$file_lines{$file}}) {
		my ($server) = grep { $_->{'line'} == $line } @servers;
		$server || &error($text{'server_egone'});
		&can_edit_server($server) || &error($text{'server_ecannot'});
		&is_default_server_block($server) && &error($text{'delete_edefault'});
		push(@{$file_servers{$rfile}}, $server);
		}
	}
@ids || %file_servers || &error($text{'delete_enone'});

my @servers;
if (@ids) {
	&lock_all_config_files();
	my $conf = &get_config();
	my $http = &find("http", $conf);
	if (!$http) {
		&unlock_all_config_files();
		&error(&text('index_ehttp', "<tt>$config{'nginx_config'}</tt>"));
		}
	foreach my $id (@ids) {
		my $server = &find_server($id);
		if (!$server) {
			&unlock_all_config_files();
			&error($text{'server_egone'});
			}
		if (!&can_edit_server($server)) {
			&unlock_all_config_files();
			&error($text{'server_ecannot'});
			}
		if (&is_default_server_block($server)) {
			&unlock_all_config_files();
			&error($text{'delete_edefault'});
			}
		push(@servers, $server);
		}
	foreach my $server (@servers) {
		&save_directive($http, [ $server ], [ ]);
		}
	&flush_config_file_lines();
	&unlock_all_config_files();
	}
foreach my $server (@servers) {
	&delete_server_link($server);
	}
my %done_file;
foreach my $server (@servers) {
	next if ($done_file{$server->{'file'}}++);
	&delete_server_file_if_empty($server);
	}
foreach my $file (keys %file_servers) {
	&lock_file($file);
	&delete_servers_from_file($file, @{$file_servers{$file}});
	&unlock_file($file);
	}
my $count = scalar(@servers) +
	    scalar(map { @$_ } values %file_servers);
&webmin_log("delete", "servers", $count);
&redirect("");
